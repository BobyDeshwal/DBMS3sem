-- =============================================================================
-- StaySphere – FILE 03 : CRUD Operations
-- =============================================================================
-- PURPOSE : Demonstrate all four CRUD operations (Create, Read, Update,
--           Delete) across every major entity with constraint-violation
--           examples.
-- NOTE    : Run AFTER 01_schema_creation.sql and 02_sample_data.sql
-- =============================================================================

USE staysphere;

-- =============================================================================
-- SECTION A : CREATE (INSERT)
-- =============================================================================

-- ─── A1. Insert a new guest ────────────────────────────────────────────────
INSERT INTO guests
    (first_name, last_name, email, phone, national_id,
     date_of_birth, address, city, country)
VALUES
    ('Aditya', 'Bose', 'aditya.bose@email.com', '+91-9933445566',
     'PASS-IN-013', '1991-06-20', '15 Park Avenue', 'Mumbai', 'India');
-- Expected: 1 row inserted, guest_id = 13 (auto)

-- ─── A2. Duplicate email – SHOULD FAIL (UNIQUE constraint) ────────────────
-- Uncomment to test:
-- INSERT INTO guests
--     (first_name, last_name, email, phone, national_id,
--      date_of_birth, address, city, country)
-- VALUES ('Fake', 'User', 'arjun.sharma@email.com', '+91-0000000000',
--         'PASS-IN-099', '1990-01-01', 'X', 'X', 'India');
-- Expected: ERROR 1062 – Duplicate entry for key 'uq_guests_email'

-- ─── A3. Insert a new room type ───────────────────────────────────────────
INSERT INTO room_types (type_name, max_capacity, description, amenities, base_rate)
VALUES ('Penthouse', 8,
        'Entire top-floor penthouse with private pool and panoramic view.',
        'WiFi,AC,Smart-TV,Private-Pool,Bar,Butler,Gym', 80000.00);
-- Expected: 1 row inserted, room_type_id = 6

-- ─── A4. Insert a new room ────────────────────────────────────────────────
INSERT INTO rooms (room_number, room_type_id, floor_number, room_status)
VALUES ('601', 6, 6, 'available');
-- Expected: 1 row inserted

-- ─── A5. Insert a rate for the new room type ──────────────────────────────
INSERT INTO room_rates (room_type_id, rate_name, nightly_rate, valid_from, valid_to)
VALUES (6, 'Penthouse – Regular', 80000.00, '2025-01-01', '2025-12-31');
-- Expected: 1 row inserted

-- ─── A6. Overlapping rate period – SHOULD FAIL (trigger) ─────────────────
-- Uncomment to test:
-- INSERT INTO room_rates (room_type_id, rate_name, nightly_rate, valid_from, valid_to)
-- VALUES (6, 'Penthouse – Conflict', 75000.00, '2025-06-01', '2026-01-01');
-- Expected: ERROR 45000 – Rate period overlaps an existing rate

-- ─── A7. Insert a reservation ─────────────────────────────────────────────
INSERT INTO reservations
    (guest_id, check_in_date, check_out_date, num_guests,
     reservation_status, booked_rate_per_night)
VALUES (13, '2025-06-10', '2025-06-13', 2, 'confirmed', 9500.00);
-- Expected: 1 row inserted (reservation_id = 21)

-- ─── A8. Invalid date range – SHOULD FAIL (CHECK constraint) ─────────────
-- Uncomment to test:
-- INSERT INTO reservations
--     (guest_id, check_in_date, check_out_date, num_guests,
--      reservation_status, booked_rate_per_night)
-- VALUES (13, '2025-06-15', '2025-06-10', 1, 'confirmed', 5000.00);
-- Expected: ERROR 3819 – Check constraint 'ck_res_dates' violated

-- ─── A9. Assign a room to reservation 21 ─────────────────────────────────
INSERT INTO reservation_rooms (reservation_id, room_id, booked_rate_per_night)
VALUES (21, 7, 9500.00);

INSERT INTO room_assignment_history
    (reservation_id, room_id, action, action_reason, action_by)
VALUES (21, 7, 'assigned', 'Reservation confirmed', 'staff_raj');

-- ─── A10. FK violation – reference non-existent guest ─────────────────────
-- Uncomment to test:
-- INSERT INTO reservations
--     (guest_id, check_in_date, check_out_date, num_guests,
--      reservation_status, booked_rate_per_night)
-- VALUES (9999, '2025-07-01', '2025-07-03', 1, 'confirmed', 5000.00);
-- Expected: ERROR 1452 – Cannot add or update a child row (FK constraint)

-- ─── A11. Extra charge on confirmed reservation ───────────────────────────
INSERT INTO extra_charges (reservation_id, charge_category, description, amount, charge_date)
VALUES (21, 'food', 'Welcome dinner', 1200.00, '2025-06-10');

-- =============================================================================
-- SECTION B : READ (SELECT)
-- =============================================================================

-- ─── B1. List all guests with their total reservations ────────────────────
SELECT
    g.guest_id,
    CONCAT(g.first_name, ' ', g.last_name) AS guest_name,
    g.email,
    g.city,
    COUNT(r.reservation_id)                 AS total_reservations,
    SUM(CASE WHEN r.reservation_status = 'completed' THEN 1 ELSE 0 END)
                                            AS completed_stays
FROM guests g
LEFT JOIN reservations r ON g.guest_id = r.guest_id
GROUP BY g.guest_id, guest_name, g.email, g.city
ORDER BY total_reservations DESC;

-- ─── B2. Rooms with their type and current status ─────────────────────────
SELECT
    r.room_id,
    r.room_number,
    rt.type_name,
    r.floor_number,
    r.room_status,
    rt.base_rate,
    r.notes
FROM rooms r
JOIN room_types rt ON r.room_type_id = rt.room_type_id
ORDER BY r.floor_number, r.room_number;

-- ─── B3. All reservations with guest name and room info ───────────────────
SELECT
    res.reservation_id,
    CONCAT(g.first_name,' ',g.last_name)    AS guest_name,
    GROUP_CONCAT(rm.room_number ORDER BY rm.room_number)
                                            AS rooms_assigned,
    res.check_in_date,
    res.check_out_date,
    DATEDIFF(res.check_out_date, res.check_in_date)
                                            AS nights,
    res.reservation_status,
    res.booked_rate_per_night
FROM reservations res
JOIN guests g               ON res.guest_id       = g.guest_id
LEFT JOIN reservation_rooms rr ON res.reservation_id = rr.reservation_id
LEFT JOIN rooms rm          ON rr.room_id          = rm.room_id
GROUP BY res.reservation_id, guest_name,
         res.check_in_date, res.check_out_date,
         res.reservation_status, res.booked_rate_per_night
ORDER BY res.check_in_date;

-- ─── B4. Current active rates per room type ───────────────────────────────
SELECT
    rt.type_name,
    rr.rate_name,
    rr.nightly_rate,
    rr.valid_from,
    rr.valid_to
FROM room_rates rr
JOIN room_types rt ON rr.room_type_id = rt.room_type_id
WHERE CURRENT_DATE BETWEEN rr.valid_from AND rr.valid_to
ORDER BY rt.type_name;

-- ─── B5. Extra charges summary per reservation ────────────────────────────
SELECT
    ec.reservation_id,
    CONCAT(g.first_name,' ',g.last_name) AS guest_name,
    ec.charge_category,
    SUM(ec.amount)                        AS category_total
FROM extra_charges ec
JOIN reservations res ON ec.reservation_id = res.reservation_id
JOIN guests g         ON res.guest_id       = g.guest_id
GROUP BY ec.reservation_id, guest_name, ec.charge_category
ORDER BY ec.reservation_id, category_total DESC;

-- ─── B6. Guests with NO completed reservation (no stays) ─────────────────
SELECT
    g.guest_id,
    CONCAT(g.first_name,' ',g.last_name) AS guest_name,
    g.email
FROM guests g
WHERE NOT EXISTS (
    SELECT 1
    FROM reservations r
    WHERE r.guest_id          = g.guest_id
      AND r.reservation_status = 'completed'
);

-- =============================================================================
-- SECTION C : UPDATE
-- =============================================================================

-- ─── C1. Update guest contact details ─────────────────────────────────────
UPDATE guests
SET    phone   = '+91-9933445577',
       address = '18 Park Avenue, Bandra'
WHERE  guest_id = 13;
-- Expected: 1 row affected

-- ─── C2. Confirm a reservation ────────────────────────────────────────────
-- (Trigger trg_reservation_timestamps will set confirmed_at automatically)
-- (Trigger trg_reservation_audit will log the status change)
UPDATE reservations
SET    reservation_status = 'confirmed'
WHERE  reservation_id = 18;
-- Expected: 1 row affected; audit log row inserted by trigger

-- ─── C3. Cancel a reservation ─────────────────────────────────────────────
-- The cancelled_at timestamp is set by the trigger
UPDATE reservations
SET    reservation_status  = 'cancelled',
       cancellation_reason = 'Guest requested cancellation'
WHERE  reservation_id = 21;
-- Expected: 1 row affected; audit log updated

-- ─── C4. Mark a room under maintenance ────────────────────────────────────
UPDATE rooms
SET    room_status = 'under_maintenance',
       notes       = 'AC unit replaced – back online 2025-07-01'
WHERE  room_id = 1;
-- Expected: 1 row affected

-- ─── C5. Update loyalty points for a guest ────────────────────────────────
UPDATE guests
SET    loyalty_points = loyalty_points + 500
WHERE  guest_id = 1;

-- ─── C6. Adjust a room rate (change future rate, not overlapping) ─────────
-- First verify no overlap, then update
UPDATE room_rates
SET    nightly_rate = 3200.00
WHERE  rate_id = 3;   -- Std Single – Monsoon 2025 (already past, safe)
-- Expected: 1 row affected

-- =============================================================================
-- SECTION D : DELETE
-- =============================================================================

-- ─── D1. Delete an extra charge ───────────────────────────────────────────
-- First find the charge_id inserted in A11
-- Extra charge for res 21 "Welcome dinner" – charge_id can be found by:
SELECT charge_id FROM extra_charges WHERE reservation_id = 21;

-- Then delete:
DELETE FROM extra_charges
WHERE  reservation_id = 21
  AND  description    = 'Welcome dinner';
-- Expected: 1 row deleted

-- ─── D2. Attempt to delete a guest who has reservations – SHOULD FAIL ─────
-- Uncomment to test:
-- DELETE FROM guests WHERE guest_id = 1;
-- Expected: ERROR 1451 – Cannot delete (FK constraint on reservations)

-- ─── D3. Attempt to delete a room type with rooms – SHOULD FAIL ───────────
-- Uncomment to test:
-- DELETE FROM room_types WHERE room_type_id = 1;
-- Expected: ERROR 1451 – Cannot delete (FK constraint on rooms)

-- ─── D4. Soft-delete pattern: cancel instead of deleting reservation ───────
-- (Best practice: never hard-delete reservations; use status = 'cancelled')
UPDATE reservations
SET    reservation_status  = 'cancelled',
       cancellation_reason = 'Admin soft-delete equivalent'
WHERE  reservation_id = 18;

-- ─── D5. Delete a guest with NO reservations (safe) ──────────────────────
-- Guest 13 (Aditya Bose) has res 21 which is now cancelled.
-- In our FK policy, cancelled reservations still reference the guest.
-- Only delete if no references remain.
-- This would fail due to existing (cancelled) reservation:
-- DELETE FROM guests WHERE guest_id = 13;
-- To truly clean up, delete reservation_rooms first, then reservation, then guest:
DELETE FROM extra_charges        WHERE reservation_id = 21;
DELETE FROM reservation_rooms    WHERE reservation_id = 21;
DELETE FROM room_assignment_history WHERE reservation_id = 21;
DELETE FROM reservation_audit_log   WHERE reservation_id = 21;
DELETE FROM reservations         WHERE reservation_id = 21;
DELETE FROM guests               WHERE guest_id = 13;
-- Expected: Each DELETE affects exactly 1 row (cascading in dependency order)

-- =============================================================================
-- SECTION E : CONSTRAINT VIOLATION DEMONSTRATIONS
-- =============================================================================

-- ─── E1. Check constraint – zero guests not allowed ───────────────────────
-- Uncomment to test:
-- INSERT INTO reservations
--     (guest_id, check_in_date, check_out_date, num_guests,
--      reservation_status, booked_rate_per_night)
-- VALUES (1, '2025-08-01', '2025-08-03', 0, 'confirmed', 3500.00);
-- Expected: ERROR 3819 – Check constraint 'ck_res_guests' violated

-- ─── E2. Room capacity vs guest count (application-level check) ───────────
-- Room 101 is Standard Single, max_capacity = 1
-- Booking for 3 guests in a single room should be blocked by stored procedure
-- (see 10_stored_procedures.sql), not a table constraint alone.

-- ─── E3. Extra charge negative amount – SHOULD FAIL ──────────────────────
-- Uncomment to test:
-- INSERT INTO extra_charges (reservation_id, charge_category, description, amount, charge_date)
-- VALUES (1, 'food', 'Refund attempt', -500.00, '2025-01-11');
-- Expected: ERROR 3819 – Check constraint 'ck_ec_amount' violated

-- ─── E4. Room rate zero price – SHOULD FAIL ───────────────────────────────
-- Uncomment to test:
-- INSERT INTO room_rates (room_type_id, rate_name, nightly_rate, valid_from, valid_to)
-- VALUES (1, 'Free Night', 0.00, '2026-05-01', '2026-05-31');
-- Expected: ERROR 3819 – Check constraint 'ck_rates_amount' violated

-- ─── E5. Duplicate room assignment to same reservation ────────────────────
-- Uncomment to test (composite PK violation):
-- INSERT INTO reservation_rooms (reservation_id, room_id, booked_rate_per_night)
-- VALUES (1, 1, 3500.00);
-- Expected: ERROR 1062 – Duplicate entry '1-1' for key 'pk_res_rooms'

-- ─── E6. Read the reservation audit log ──────────────────────────────────
SELECT
    ral.audit_id,
    ral.reservation_id,
    CONCAT(g.first_name,' ',g.last_name) AS guest_name,
    ral.old_status,
    ral.new_status,
    ral.changed_at
FROM reservation_audit_log ral
JOIN reservations res ON ral.reservation_id = res.reservation_id
JOIN guests g         ON res.guest_id        = g.guest_id
ORDER BY ral.changed_at;

-- =============================================================================
-- END OF FILE 03_crud_operations.sql
-- =============================================================================

