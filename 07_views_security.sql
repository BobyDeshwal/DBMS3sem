-- =============================================================================
-- StaySphere – FILE 07 : Views & Security
-- =============================================================================
-- PURPOSE : Define useful views, demonstrate WITH CHECK OPTION,
--           and implement GRANT-based access control.
-- NOTE    : Run AFTER 01_schema_creation.sql and 02_sample_data.sql
-- =============================================================================

USE staysphere;

-- =============================================================================
-- SECTION 1 : VIEW A – ROOM AVAILABILITY REPORTING VIEW
-- =============================================================================
-- A standard MySQL VIEW cannot accept parameters directly.
-- Strategy: the view exposes all rooms with their "blocked" flag
-- (NULL = free for all future dates).  The caller adds a WHERE clause
-- to filter for a specific date range.

DROP VIEW IF EXISTS vw_room_availability;

CREATE VIEW vw_room_availability AS
SELECT
    r.room_id,
    r.room_number,
    rt.type_name,
    r.floor_number,
    r.room_status,
    rt.max_capacity,
    rt.base_rate,
    r.smoking,
    -- Most recent active reservation for this room (if any)
    MAX(res.reservation_id)   AS current_reservation_id,
    MAX(res.check_in_date)    AS current_check_in,
    MAX(res.check_out_date)   AS current_check_out,
    MAX(res.reservation_status) AS current_status
FROM rooms r
JOIN room_types rt ON r.room_type_id = rt.room_type_id
LEFT JOIN reservation_rooms rr  ON r.room_id = rr.room_id
                                AND rr.unassigned_at IS NULL
LEFT JOIN reservations res      ON rr.reservation_id = res.reservation_id
                                AND res.reservation_status
                                    IN ('confirmed','checked_in','pending')
GROUP BY r.room_id, r.room_number, rt.type_name,
         r.floor_number, r.room_status, rt.max_capacity,
         rt.base_rate, r.smoking;

-- How to check availability for a date range using the view:
-- (Add a date-range filter in the outer query)
SELECT *
FROM   vw_room_availability
WHERE  room_status IN ('available','occupied')
  AND  (current_check_in IS NULL
        OR current_check_out <= '2025-09-01'
        OR current_check_in  >= '2025-09-05')
  AND  type_name = 'Standard Double'
ORDER BY floor_number, room_number;
-- The view exposes room + reservation metadata; the caller applies the
-- overlap filter.  This is the valid workaround for parameterless views.

-- =============================================================================
-- SECTION 2 : VIEW B – GUEST BILLING SUMMARY VIEW
-- =============================================================================
DROP VIEW IF EXISTS vw_guest_billing_summary;

CREATE VIEW vw_guest_billing_summary AS
SELECT
    g.guest_id,
    CONCAT(g.first_name,' ',g.last_name)         AS guest_name,
    g.email,
    g.phone,
    res.reservation_id,
    res.check_in_date,
    res.check_out_date,
    DATEDIFF(res.check_out_date, res.check_in_date)
                                                 AS nights,
    res.reservation_status,
    GROUP_CONCAT(rm.room_number ORDER BY rm.room_number)
                                                 AS rooms,
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
                                                 AS room_charges,
    COALESCE((
        SELECT SUM(ec.amount)
        FROM   extra_charges ec
        WHERE  ec.reservation_id = res.reservation_id
    ), 0.00)                                     AS extra_charges,
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
    + COALESCE((
        SELECT SUM(ec.amount)
        FROM   extra_charges ec
        WHERE  ec.reservation_id = res.reservation_id
    ), 0.00)                                     AS total_bill
FROM  guests g
JOIN  reservations res     ON g.guest_id        = res.guest_id
JOIN  reservation_rooms rr ON res.reservation_id = rr.reservation_id
                          AND rr.unassigned_at IS NULL
JOIN  rooms rm             ON rr.room_id         = rm.room_id
WHERE  res.reservation_status IN ('completed','checked_in')
GROUP BY g.guest_id, guest_name, g.email, g.phone,
         res.reservation_id, res.check_in_date,
         res.check_out_date, res.reservation_status;

-- Query the billing summary
SELECT * FROM vw_guest_billing_summary ORDER BY guest_id, check_in_date;

-- Guest lifetime value from billing view:
SELECT guest_id, guest_name, SUM(total_bill) AS lifetime_value
FROM   vw_guest_billing_summary
GROUP BY guest_id, guest_name
ORDER BY lifetime_value DESC;

-- =============================================================================
-- SECTION 3 : VIEW C – RESTRICTED FRONT-DESK VIEW
-- =============================================================================
-- Front-desk staff need: guest name, email, phone, reservation dates, room,
-- status, and total bill.  They do NOT need: national_id, date_of_birth,
-- loyalty_points internal details, or billing breakdown.
--
-- IMPORTANT LIMITATION: This view restricts columns only when accessed through
-- the view.  If front-desk staff have direct SELECT privilege on the guests
-- table, they can bypass this column restriction.  REVOKE direct table access
-- and GRANT only view access to enforce column-level security.

DROP VIEW IF EXISTS vw_frontdesk;

CREATE VIEW vw_frontdesk AS
SELECT
    res.reservation_id,
    CONCAT(g.first_name,' ',g.last_name)    AS guest_name,
    g.email,
    g.phone,
    GROUP_CONCAT(rm.room_number ORDER BY rm.room_number)
                                            AS rooms,
    res.check_in_date,
    res.check_out_date,
    res.reservation_status,
    res.num_guests,
    res.special_requests,
    vgb.total_bill
FROM  reservations res
JOIN  guests g              ON res.guest_id        = g.guest_id
JOIN  reservation_rooms rr  ON res.reservation_id  = rr.reservation_id
                           AND rr.unassigned_at IS NULL
JOIN  rooms rm              ON rr.room_id           = rm.room_id
LEFT JOIN vw_guest_billing_summary vgb
                            ON res.reservation_id   = vgb.reservation_id
GROUP BY res.reservation_id, guest_name, g.email, g.phone,
         res.check_in_date, res.check_out_date,
         res.reservation_status, res.num_guests,
         res.special_requests, vgb.total_bill;

-- Usage: front-desk checks today's arrivals
SELECT *
FROM   vw_frontdesk
WHERE  check_in_date = CURRENT_DATE
  AND  reservation_status = 'confirmed'
ORDER BY guest_name;

-- =============================================================================
-- SECTION 4 : WITH CHECK OPTION DEMONSTRATION
-- =============================================================================
-- WITH CHECK OPTION prevents INSERT or UPDATE through a view from creating
-- rows that the view's own WHERE clause would not return.
-- It does NOT replace table-level CHECK constraints or GRANT permissions;
-- it specifically guards the view's own filter condition.

-- ─── 4A. Create an updatable view for pending reservations ────────────────
DROP VIEW IF EXISTS vw_pending_reservations;

CREATE VIEW vw_pending_reservations AS
SELECT
    reservation_id,
    guest_id,
    check_in_date,
    check_out_date,
    num_guests,
    reservation_status,
    booked_rate_per_night,
    special_requests
FROM reservations
WHERE reservation_status = 'pending'
WITH CHECK OPTION;
-- WITH CHECK OPTION: any INSERT or UPDATE through this view must result in
-- a row where reservation_status = 'pending'.

-- ─── 4B. Valid modification – stays within view condition ─────────────────
-- Update special_requests on a pending reservation
UPDATE vw_pending_reservations
SET    special_requests = 'Late check-in at 22:00'
WHERE  reservation_id = 18;
-- Expected: 1 row updated (reservation_id 18 is still 'pending' after update)

-- ─── 4C. INVALID modification – violates view condition ──────────────────
-- Attempt to change status to 'confirmed' through the pending view
-- Uncomment to test:
-- UPDATE vw_pending_reservations
-- SET    reservation_status = 'confirmed'
-- WHERE  reservation_id = 18;
-- Expected: ERROR 1369 – CHECK OPTION failed 'staysphere.vw_pending_reservations'
-- Explanation: After the update, reservation_status = 'confirmed', which is
-- NOT 'pending'.  The view's WITH CHECK OPTION rejects the change.

-- ─── 4D. Difference between WITH CHECK OPTION, table constraints, and GRANT
-- WITH CHECK OPTION: guards only what the view's WHERE clause filters.
--   Cannot enforce complex business rules (e.g., date logic).
-- Table constraints (CHECK, FK, UNIQUE): enforced at the engine level for
--   ALL writes, regardless of which view or direct table access is used.
-- GRANT permissions: control WHO can read/write.  A user without INSERT
--   privilege cannot INSERT even through a view.

-- =============================================================================
-- SECTION 5 : GRANT STATEMENTS AND ACCESS CONTROL
-- =============================================================================
-- NOTE: Run these as a MySQL user with GRANT OPTION (typically root).

-- ─── 5A. Create user roles ────────────────────────────────────────────────
-- Front-desk staff: read reservations, update status, create new reservations
CREATE USER IF NOT EXISTS 'frontdesk_user'@'localhost'
    IDENTIFIED BY 'FD_Secure#2025';

-- Manager: full read, can update rates and view revenue reports
CREATE USER IF NOT EXISTS 'manager_user'@'localhost'
    IDENTIFIED BY 'Mgr_Secure#2025';

-- Read-only analyst: can run reporting queries but cannot modify data
CREATE USER IF NOT EXISTS 'analyst_user'@'localhost'
    IDENTIFIED BY 'Analyst_Secure#2025';

-- ─── 5B. Front-desk privileges ───────────────────────────────────────────
-- Grant access ONLY to the restricted view (NOT the underlying tables)
GRANT SELECT ON staysphere.vw_frontdesk              TO 'frontdesk_user'@'localhost';
GRANT SELECT ON staysphere.vw_room_availability      TO 'frontdesk_user'@'localhost';
GRANT SELECT ON staysphere.vw_pending_reservations   TO 'frontdesk_user'@'localhost';
GRANT UPDATE ON staysphere.vw_pending_reservations   TO 'frontdesk_user'@'localhost';
-- Allow creating new reservations (INSERT on reservations + reservation_rooms)
GRANT INSERT ON staysphere.reservations              TO 'frontdesk_user'@'localhost';
GRANT INSERT ON staysphere.reservation_rooms         TO 'frontdesk_user'@'localhost';
GRANT INSERT ON staysphere.extra_charges             TO 'frontdesk_user'@'localhost';
-- Allow confirming / checking in reservations (UPDATE status column only)
GRANT UPDATE (reservation_status, confirmed_at, special_requests)
      ON staysphere.reservations                     TO 'frontdesk_user'@'localhost';
-- Explicitly DENY access to sensitive guest data
REVOKE SELECT ON staysphere.guests                   FROM 'frontdesk_user'@'localhost';

-- ─── 5C. Manager privileges ──────────────────────────────────────────────
GRANT SELECT  ON staysphere.*                        TO 'manager_user'@'localhost';
GRANT UPDATE  ON staysphere.room_rates               TO 'manager_user'@'localhost';
GRANT INSERT  ON staysphere.room_rates               TO 'manager_user'@'localhost';
GRANT UPDATE  ON staysphere.rooms                    TO 'manager_user'@'localhost';
GRANT UPDATE  ON staysphere.reservations             TO 'manager_user'@'localhost';
GRANT INSERT  ON staysphere.reservations             TO 'manager_user'@'localhost';
GRANT INSERT  ON staysphere.reservation_rooms        TO 'manager_user'@'localhost';
GRANT SELECT  ON staysphere.vw_guest_billing_summary TO 'manager_user'@'localhost';

-- ─── 5D. Analyst privileges ──────────────────────────────────────────────
GRANT SELECT ON staysphere.vw_guest_billing_summary  TO 'analyst_user'@'localhost';
GRANT SELECT ON staysphere.vw_room_availability      TO 'analyst_user'@'localhost';
GRANT SELECT ON staysphere.reservations              TO 'analyst_user'@'localhost';
GRANT SELECT ON staysphere.reservation_rooms         TO 'analyst_user'@'localhost';
GRANT SELECT ON staysphere.extra_charges             TO 'analyst_user'@'localhost';
GRANT SELECT ON staysphere.room_rates                TO 'analyst_user'@'localhost';
-- Analyst cannot see personally identifiable guest data:
-- No grant on guests table → any query joining guests will fail for analyst

FLUSH PRIVILEGES;

-- ─── 5E. Verify grants ────────────────────────────────────────────────────
SHOW GRANTS FOR 'frontdesk_user'@'localhost';
SHOW GRANTS FOR 'manager_user'@'localhost';
SHOW GRANTS FOR 'analyst_user'@'localhost';

-- =============================================================================
-- SECTION 6 : VIEW LIMITATION DISCUSSION
-- =============================================================================
-- Column restriction through views:
--   When a user is granted SELECT on a view but NOT on the underlying table,
--   the view effectively hides columns.  This works as long as:
--     a) The user has no direct table privileges.
--     b) The view is defined with SQL SECURITY DEFINER (default in MySQL),
--        meaning it runs with the definer's privileges, not the invoker's.
--
-- Gaps in view-based security:
--   1. If MySQL's INFORMATION_SCHEMA is accessible, the user can learn table
--      structure even without data access.
--   2. SHOW CREATE TABLE is blocked if the user has no table privilege, but
--      SHOW TABLES still lists table names.
--   3. For stronger column-level security, combine views with:
--      - Column-level GRANT (MySQL supports GRANT SELECT (col1, col2) ON ...)
--      - Application-level authentication / authorization layers

-- =============================================================================
-- END OF FILE 07_views_security.sql
-- =============================================================================

