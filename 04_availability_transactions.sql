-- =============================================================================
-- StaySphere – FILE 04 : Availability Checking & Transactions
-- =============================================================================
-- PURPOSE : Room availability logic, the correct overlap rule, and
--           transaction-based concurrency control to prevent double bookings.
-- NOTE    : Run AFTER 01_schema_creation.sql and 02_sample_data.sql
-- =============================================================================

USE staysphere;

-- =============================================================================
-- SECTION 1 : THE DATE-OVERLAP RULE
-- =============================================================================
-- Two reservations for the SAME room overlap when:
--
--   existing_check_in  < requested_check_out
--   AND
--   existing_check_out > requested_check_in
--
-- Why checkout-same-as-check-in is NOT an overlap:
--   If Reservation A checks out on 2025-01-13 and Reservation B checks in
--   on 2025-01-13, the guest in A leaves in the morning and B arrives in the
--   afternoon.  The room is vacant at the moment B takes over.
--   With the rule above:
--     A.check_in  < B.check_out → 2025-01-10 < 2025-01-15 → TRUE
--     A.check_out > B.check_in  → 2025-01-13 > 2025-01-13 → FALSE (strict >)
--   One condition is FALSE → NO overlap → booking is allowed.  Correct.
--
-- Pending reservation policy:
--   'pending' reservations created more than 30 minutes ago are treated as
--   expired for availability purposes.  Only ACTIVE statuses block a room:
--     'pending' (< 30 min old), 'confirmed', 'checked_in'
-- =============================================================================

-- =============================================================================
-- SECTION 2 : AVAILABILITY CHECK QUERY
-- =============================================================================

-- ─── 2A. Which rooms are available for a requested period? ────────────────
-- Parameters: requested_check_in = '2025-09-01', requested_check_out = '2025-09-05'
--             room_type_id = 2 (Standard Double), num_guests = 2

SET @req_checkin  = '2025-09-01';
SET @req_checkout = '2025-09-05';
SET @req_type     = 2;
SET @req_guests   = 2;
SET @pending_expiry_min = 30;

SELECT
    r.room_id,
    r.room_number,
    rt.type_name,
    r.floor_number,
    r.room_status,
    rt.max_capacity,
    rt.base_rate
FROM rooms r
JOIN room_types rt ON r.room_type_id = rt.room_type_id
WHERE
    -- 1. Correct room type
    r.room_type_id = @req_type

    -- 2. Room is physically usable (not maintenance / out_of_order)
    AND r.room_status IN ('available', 'occupied')

    -- 3. Room capacity is sufficient
    AND rt.max_capacity >= @req_guests

    -- 4. No active overlapping reservation exists for this room
    AND r.room_id NOT IN (
        SELECT rr.room_id
        FROM   reservation_rooms rr
        JOIN   reservations res ON rr.reservation_id = res.reservation_id
        WHERE
            -- Active statuses that block availability
            res.reservation_status IN ('confirmed', 'checked_in')
            OR (
                res.reservation_status = 'pending'
                AND res.created_at >= DATE_SUB(NOW(), INTERVAL @pending_expiry_min MINUTE)
            )
            -- Overlap condition (strict)
            AND res.check_in_date  < @req_checkout
            AND res.check_out_date > @req_checkin
    )
ORDER BY r.floor_number, r.room_number;

-- Expected for Sep 2025 dates (Standard Double):
--   Room 201 (room_id 4) is free (its occupancy: Feb, Nov)
--   Room 202 (room_id 5) is free (occupied Aug 15-18 only)
--   Room 203 (room_id 6) smoking – still available if guest requests smoking
--   Room 204 (room_id 15) is occupied Aug 1-6; Sep 1-5 is free

-- ─── 2B. Adjacent reservations – demonstrate no false conflict ────────────
-- Room 101: Res 1 (Jan 10-13) and Res 19 (Jan 13-15)
-- Checking if Jan 13 is available for a 1-night stay:

SET @req_checkin  = '2025-01-13';
SET @req_checkout = '2025-01-14';
SET @req_type     = 1;
SET @req_guests   = 1;

SELECT r.room_number, r.room_status,
    CASE WHEN r.room_id IN (
        SELECT rr.room_id
        FROM   reservation_rooms rr
        JOIN   reservations res ON rr.reservation_id = res.reservation_id
        WHERE  res.reservation_status IN ('confirmed','checked_in','completed')
          AND  res.check_in_date  < @req_checkout
          AND  res.check_out_date > @req_checkin
    ) THEN 'BLOCKED' ELSE 'AVAILABLE' END AS availability
FROM rooms r
WHERE r.room_type_id = @req_type;
-- Expected: Room 101 = BLOCKED (Res 19 occupies Jan 13-15)
--           Room 102 = AVAILABLE
--           Room 104 = AVAILABLE

-- ─── 2C. Cancelled reservations do NOT block availability ─────────────────
-- Res 3 was cancelled (Room 102, Mar 1-4)
SET @req_checkin  = '2025-03-01';
SET @req_checkout = '2025-03-04';
SET @req_type     = 1;
SET @req_guests   = 1;

SELECT r.room_number,
    CASE WHEN r.room_id IN (
        SELECT rr.room_id
        FROM   reservation_rooms rr
        JOIN   reservations res ON rr.reservation_id = res.reservation_id
        WHERE  res.reservation_status IN ('confirmed','checked_in')
          AND  res.check_in_date  < @req_checkout
          AND  res.check_out_date > @req_checkin
    ) THEN 'BLOCKED' ELSE 'AVAILABLE' END AS availability
FROM rooms r
WHERE r.room_type_id = @req_type;
-- Expected: Room 102 = AVAILABLE (Res 3 was cancelled)

-- =============================================================================
-- SECTION 3 : TRANSACTION & CONCURRENCY CONTROL
-- =============================================================================
-- Problem: Two staff members attempt to book the same room for the same
--          dates simultaneously.  Without locking, both SELECT queries
--          return "available" and both INSERTs succeed → double booking.
--
-- Solution: Use SELECT ... FOR UPDATE within a transaction to acquire an
--           exclusive row lock on the rooms row before checking availability.
--           InnoDB's row-level locking ensures only one transaction holds
--           the lock at a time; the second waits.
--
-- Locking Protocol:
--   1. BEGIN transaction.
--   2. SELECT ... FOR UPDATE on rooms (locks the physical room row).
--   3. Check availability in reservation_rooms (the locked room row
--      prevents any concurrent insert from passing step 2 simultaneously).
--   4. If available → INSERT reservation + reservation_rooms.
--   5. COMMIT (releases lock).
--   6. If unavailable → ROLLBACK.
--
-- Note on gap locks:
--   InnoDB in REPEATABLE READ (default) uses gap locks on index ranges,
--   which further prevents phantom reads between step 2 and 4.
-- =============================================================================

-- ─── 3A. Safe booking transaction ────────────────────────────────────────
-- We wrap the entire availability-check-and-insert in a single transaction
-- with FOR UPDATE locking.

-- TRANSACTION 1 (Staff A books Room 201, Sep 1-5)
-- ─────────────────────────────────────────────────
START TRANSACTION;

-- Step 1: Lock the target room row exclusively
SELECT room_id, room_status, room_type_id
FROM   rooms
WHERE  room_id = 4              -- Room 201 (Standard Double)
FOR UPDATE;

-- Step 2: Verify room is physically usable
-- (If room_status is 'under_maintenance', ROLLBACK here)

-- Step 3: Check for date overlap with active reservations
SELECT COUNT(*) AS conflict_count
INTO   @conflict
FROM   reservation_rooms rr
JOIN   reservations res ON rr.reservation_id = res.reservation_id
WHERE  rr.room_id = 4
  AND  res.reservation_status IN ('confirmed','checked_in')
  AND  res.check_in_date  < '2025-09-05'
  AND  res.check_out_date > '2025-09-01';

-- Step 4: If no conflict, insert reservation
-- (In practice a stored procedure performs the IF check; shown inline here)
-- @conflict = 0 → proceed:
INSERT INTO reservations
    (guest_id, check_in_date, check_out_date, num_guests,
     reservation_status, booked_rate_per_night)
VALUES (2, '2025-09-01', '2025-09-05', 2, 'confirmed', 4500.00);

SET @new_res_id = LAST_INSERT_ID();

INSERT INTO reservation_rooms (reservation_id, room_id, booked_rate_per_night)
VALUES (@new_res_id, 4, 4500.00);

INSERT INTO room_assignment_history (reservation_id, room_id, action, action_by)
VALUES (@new_res_id, 4, 'assigned', 'staff_a');

COMMIT;
-- Expected: Transaction committed; reservation created.

-- ─── 3B. Simulate concurrent conflicting booking (what the lock prevents) ──
-- TRANSACTION 2 runs concurrently and tries to book the same room/dates.
-- Because Transaction 1 holds FOR UPDATE on room_id=4, Transaction 2's
-- SELECT ... FOR UPDATE blocks until Transaction 1 COMMITS or ROLLBACKs.
-- After Transaction 1 commits, Transaction 2 acquires the lock, re-checks
-- availability, finds @conflict > 0, and ROLLBACKS.

-- Demonstration (run in a second session after Transaction 1 commits):
START TRANSACTION;

SELECT room_id FROM rooms WHERE room_id = 4 FOR UPDATE;

SELECT COUNT(*) AS conflict_count
INTO   @conflict2
FROM   reservation_rooms rr
JOIN   reservations res ON rr.reservation_id = res.reservation_id
WHERE  rr.room_id = 4
  AND  res.reservation_status IN ('confirmed','checked_in')
  AND  res.check_in_date  < '2025-09-05'
  AND  res.check_out_date > '2025-09-01';

-- @conflict2 > 0 → ROLLBACK
ROLLBACK;
-- Expected: No double booking; Transaction 2 gracefully rolls back.

-- ─── 3C. Cleanup: remove the demonstration booking ───────────────────────
-- (The booking created in 3A is a test booking; clean it up)
SET @cleanup_res_id = (
    SELECT reservation_id FROM reservations
    WHERE  guest_id = 2
      AND  check_in_date = '2025-09-01'
    LIMIT  1
);

START TRANSACTION;
DELETE FROM extra_charges           WHERE reservation_id = @cleanup_res_id;
DELETE FROM reservation_rooms       WHERE reservation_id = @cleanup_res_id;
DELETE FROM room_assignment_history WHERE reservation_id = @cleanup_res_id;
DELETE FROM reservation_audit_log   WHERE reservation_id = @cleanup_res_id;
DELETE FROM reservations            WHERE reservation_id = @cleanup_res_id;
COMMIT;

-- ─── 3D. Room reassignment during stay ───────────────────────────────────
-- Guest in Res 8 (Meera Joshi, Room 302) is moved to Room 301 mid-stay
-- because of a maintenance issue.

START TRANSACTION;

-- Lock both rooms
SELECT room_id FROM rooms WHERE room_id IN (8, 7) FOR UPDATE;

-- Close old assignment
UPDATE reservation_rooms
SET    unassigned_at = NOW()
WHERE  reservation_id = 8 AND room_id = 8;

-- Create new assignment
INSERT INTO reservation_rooms (reservation_id, room_id, booked_rate_per_night)
VALUES (8, 7, 7000.00);

-- Record history
INSERT INTO room_assignment_history
    (reservation_id, room_id, action, action_reason, action_by)
VALUES
    (8, 8, 'unassigned', 'AC malfunction – moved to 301', 'manager_dev'),
    (8, 7, 'reassigned', 'Guest moved from 302 to 301',   'manager_dev');

-- Mark old room for maintenance
UPDATE rooms SET room_status = 'under_maintenance',
                notes = 'AC malfunction Jul 2025'
WHERE  room_id = 8;

COMMIT;
-- Expected: Res 8 now has two room entries in reservation_rooms;
--           history shows unassigned + reassigned events.

-- ─── 3E. Check-in and check-out status transitions ───────────────────────
START TRANSACTION;
UPDATE reservations
SET    reservation_status = 'checked_in'
WHERE  reservation_id = 16
  AND  reservation_status = 'confirmed';

UPDATE rooms
SET    room_status = 'occupied'
WHERE  room_id = 4;
COMMIT;
-- Expected: Reservation 16 transitions to checked_in; Room 201 → occupied

-- Simulate check-out
START TRANSACTION;
UPDATE reservations
SET    reservation_status = 'completed'
WHERE  reservation_id = 16
  AND  reservation_status = 'checked_in';

UPDATE rooms
SET    room_status = 'available'
WHERE  room_id = 4;
COMMIT;

-- ─── 3F. Maintenance restriction – cannot book under_maintenance room ─────
-- Room 103 is 'under_maintenance'.  Availability query filters it out.
SET @req_checkin  = '2025-11-01';
SET @req_checkout = '2025-11-04';
SET @req_type     = 1;

SELECT r.room_number, r.room_status
FROM   rooms r
WHERE  r.room_type_id = @req_type
  AND  r.room_status IN ('available','occupied')
ORDER BY r.room_number;
-- Expected: Room 103 NOT in result (under_maintenance).
-- Room 101 (reset status after test), 102, 104 appear.

-- =============================================================================
-- SECTION 4 : EXPLAIN AVAILABILITY QUERY PLAN
-- =============================================================================
EXPLAIN
SELECT r.room_id, r.room_number, rt.type_name
FROM   rooms r
JOIN   room_types rt ON r.room_type_id = rt.room_type_id
WHERE  r.room_type_id = 2
  AND  r.room_status IN ('available','occupied')
  AND  r.room_id NOT IN (
      SELECT rr.room_id
      FROM   reservation_rooms rr
      JOIN   reservations res ON rr.reservation_id = res.reservation_id
      WHERE  res.reservation_status IN ('confirmed','checked_in')
        AND  res.check_in_date  < '2025-09-05'
        AND  res.check_out_date > '2025-09-01'
  );
-- Read the plan output in 06_indexes_performance.sql for full EXPLAIN analysis.

-- =============================================================================
-- END OF FILE 04_availability_transactions.sql
-- =============================================================================

