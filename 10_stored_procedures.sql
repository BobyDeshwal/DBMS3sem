-- =============================================================================
-- StaySphere – FILE 10 : Stored Procedures & Enhancements
-- =============================================================================
-- PURPOSE : Safe reservation creation procedure, room-rate lookup,
--           cancellation analysis, and all three additional enhancements.
-- NOTE    : Run AFTER 01_schema_creation.sql and 02_sample_data.sql
-- =============================================================================

USE staysphere;

DELIMITER $$

-- =============================================================================
-- STORED PROCEDURE 1 : make_reservation
-- PURPOSE : Safely creates a reservation using the correct overlap check,
--           locks the room row with SELECT … FOR UPDATE, looks up the current
--           nightly rate, validates capacity, and inserts the reservation.
-- =============================================================================
DROP PROCEDURE IF EXISTS make_reservation$$

CREATE PROCEDURE make_reservation(
    IN  p_guest_id       INT UNSIGNED,
    IN  p_room_id        SMALLINT UNSIGNED,
    IN  p_check_in       DATE,
    IN  p_check_out      DATE,
    IN  p_num_guests     TINYINT UNSIGNED,
    OUT p_reservation_id INT UNSIGNED,
    OUT p_message        VARCHAR(255)
)
BEGIN
    DECLARE v_room_status     VARCHAR(30)   DEFAULT NULL;
    DECLARE v_room_type_id    TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_max_capacity    TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_nightly_rate    DECIMAL(10,2) DEFAULT NULL;
    DECLARE v_conflict        INT           DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_message = 'Internal error – transaction rolled back.';
    END;

    -- 1. Validate date range
    IF p_check_out <= p_check_in THEN
        SET p_reservation_id = NULL;
        SET p_message = 'ERROR: Check-out date must be after check-in date.';
        LEAVE make_reservation_label;
    END IF;

    START TRANSACTION;

    -- 2. Lock the room row exclusively
    SELECT room_status, room_type_id
    INTO   v_room_status, v_room_type_id
    FROM   rooms
    WHERE  room_id = p_room_id
    FOR UPDATE;

    IF v_room_type_id IS NULL THEN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_message = 'ERROR: Room not found.';
        LEAVE make_reservation_label;
    END IF;

    -- 3. Check physical availability (maintenance / out_of_order)
    IF v_room_status IN ('under_maintenance','out_of_order') THEN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_message = CONCAT('ERROR: Room is ', v_room_status, ' and cannot be booked.');
        LEAVE make_reservation_label;
    END IF;

    -- 4. Check guest capacity
    SELECT max_capacity INTO v_max_capacity
    FROM   room_types WHERE room_type_id = v_room_type_id;

    IF p_num_guests > v_max_capacity THEN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_message = CONCAT('ERROR: Room capacity is ', v_max_capacity,
                               '; cannot accommodate ', p_num_guests, ' guests.');
        LEAVE make_reservation_label;
    END IF;

    -- 5. Check for date overlap with active reservations
    SELECT COUNT(*) INTO v_conflict
    FROM   reservation_rooms rr
    JOIN   reservations res ON rr.reservation_id = res.reservation_id
    WHERE  rr.room_id = p_room_id
      AND  res.reservation_status IN ('confirmed','checked_in')
      AND  res.check_in_date  < p_check_out
      AND  res.check_out_date > p_check_in;

    IF v_conflict > 0 THEN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_message = 'ERROR: Room is not available for the requested dates.';
        LEAVE make_reservation_label;
    END IF;

    -- 6. Look up the nightly rate applicable on check-in date
    SELECT nightly_rate INTO v_nightly_rate
    FROM   room_rates
    WHERE  room_type_id = v_room_type_id
      AND  valid_from  <= p_check_in
      AND  valid_to    >= p_check_in
    LIMIT  1;

    IF v_nightly_rate IS NULL THEN
        -- Fall back to base_rate from room_types
        SELECT base_rate INTO v_nightly_rate
        FROM   room_types WHERE room_type_id = v_room_type_id;
    END IF;

    -- 7. Create reservation
    INSERT INTO reservations
        (guest_id, check_in_date, check_out_date, num_guests,
         reservation_status, booked_rate_per_night)
    VALUES
        (p_guest_id, p_check_in, p_check_out, p_num_guests,
         'confirmed', v_nightly_rate);

    SET p_reservation_id = LAST_INSERT_ID();

    -- 8. Assign room
    INSERT INTO reservation_rooms
        (reservation_id, room_id, booked_rate_per_night)
    VALUES (p_reservation_id, p_room_id, v_nightly_rate);

    -- 9. Record assignment history
    INSERT INTO room_assignment_history
        (reservation_id, room_id, action, action_reason, action_by)
    VALUES (p_reservation_id, p_room_id, 'assigned',
            'Created via make_reservation procedure', 'system');

    -- 10. Commit
    COMMIT;

    SET p_message = CONCAT('SUCCESS: Reservation ', p_reservation_id,
                           ' created. Room ', p_room_id,
                           ' @ ₹', v_nightly_rate, '/night.');

END$$

-- Label workaround (MySQL needs the label on the PROCEDURE body)
-- The LEAVE statement above must reference a label; restructure:
DROP PROCEDURE IF EXISTS make_reservation$$

CREATE PROCEDURE make_reservation(
    IN  p_guest_id       INT UNSIGNED,
    IN  p_room_id        SMALLINT UNSIGNED,
    IN  p_check_in       DATE,
    IN  p_check_out      DATE,
    IN  p_num_guests     TINYINT UNSIGNED,
    OUT p_reservation_id INT UNSIGNED,
    OUT p_message        VARCHAR(255)
)
make_reservation_label: BEGIN
    DECLARE v_room_status     VARCHAR(30)   DEFAULT NULL;
    DECLARE v_room_type_id    TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_max_capacity    TINYINT UNSIGNED DEFAULT NULL;
    DECLARE v_nightly_rate    DECIMAL(10,2) DEFAULT NULL;
    DECLARE v_conflict        INT           DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_message = 'Internal error – transaction rolled back.';
    END;

    -- 1. Validate date range
    IF p_check_out <= p_check_in THEN
        SET p_reservation_id = NULL;
        SET p_message = 'ERROR: Check-out date must be after check-in date.';
        LEAVE make_reservation_label;
    END IF;

    START TRANSACTION;

    -- 2. Lock the room row exclusively
    SELECT room_status, room_type_id
    INTO   v_room_status, v_room_type_id
    FROM   rooms
    WHERE  room_id = p_room_id
    FOR UPDATE;

    IF v_room_type_id IS NULL THEN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_message = 'ERROR: Room not found.';
        LEAVE make_reservation_label;
    END IF;

    -- 3. Check physical availability
    IF v_room_status IN ('under_maintenance','out_of_order') THEN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_message = CONCAT('ERROR: Room is ', v_room_status, ' and cannot be booked.');
        LEAVE make_reservation_label;
    END IF;

    -- 4. Check guest capacity
    SELECT max_capacity INTO v_max_capacity
    FROM   room_types WHERE room_type_id = v_room_type_id;

    IF p_num_guests > v_max_capacity THEN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_message = CONCAT('ERROR: Room capacity is ', v_max_capacity,
                               '; cannot accommodate ', p_num_guests, ' guests.');
        LEAVE make_reservation_label;
    END IF;

    -- 5. Check date overlap
    SELECT COUNT(*) INTO v_conflict
    FROM   reservation_rooms rr
    JOIN   reservations res ON rr.reservation_id = res.reservation_id
    WHERE  rr.room_id = p_room_id
      AND  res.reservation_status IN ('confirmed','checked_in')
      AND  res.check_in_date  < p_check_out
      AND  res.check_out_date > p_check_in;

    IF v_conflict > 0 THEN
        ROLLBACK;
        SET p_reservation_id = NULL;
        SET p_message = 'ERROR: Room is not available for the requested dates.';
        LEAVE make_reservation_label;
    END IF;

    -- 6. Look up nightly rate
    SELECT nightly_rate INTO v_nightly_rate
    FROM   room_rates
    WHERE  room_type_id = v_room_type_id
      AND  valid_from  <= p_check_in
      AND  valid_to    >= p_check_in
    LIMIT  1;

    IF v_nightly_rate IS NULL THEN
        SELECT base_rate INTO v_nightly_rate
        FROM   room_types WHERE room_type_id = v_room_type_id;
    END IF;

    -- 7. Insert reservation
    INSERT INTO reservations
        (guest_id, check_in_date, check_out_date, num_guests,
         reservation_status, booked_rate_per_night)
    VALUES
        (p_guest_id, p_check_in, p_check_out, p_num_guests,
         'confirmed', v_nightly_rate);

    SET p_reservation_id = LAST_INSERT_ID();

    -- 8. Insert room assignment
    INSERT INTO reservation_rooms
        (reservation_id, room_id, booked_rate_per_night)
    VALUES (p_reservation_id, p_room_id, v_nightly_rate);

    -- 9. Record history
    INSERT INTO room_assignment_history
        (reservation_id, room_id, action, action_reason, action_by)
    VALUES (p_reservation_id, p_room_id, 'assigned',
            'Created via make_reservation', 'system');

    COMMIT;

    SET p_message = CONCAT('SUCCESS: Reservation ', p_reservation_id,
                           ' created at ₹', v_nightly_rate, '/night.');
END$$

-- =============================================================================
-- STORED PROCEDURE 2 : cancel_reservation
-- =============================================================================
DROP PROCEDURE IF EXISTS cancel_reservation$$

CREATE PROCEDURE cancel_reservation(
    IN  p_reservation_id INT UNSIGNED,
    IN  p_reason         VARCHAR(255),
    IN  p_staff          VARCHAR(60),
    OUT p_message        VARCHAR(255)
)
BEGIN
    DECLARE v_status VARCHAR(20);

    SELECT reservation_status INTO v_status
    FROM   reservations WHERE reservation_id = p_reservation_id;

    IF v_status IS NULL THEN
        SET p_message = 'ERROR: Reservation not found.';
    ELSEIF v_status IN ('cancelled','completed') THEN
        SET p_message = CONCAT('ERROR: Cannot cancel a reservation with status: ', v_status);
    ELSE
        START TRANSACTION;

        UPDATE reservations
        SET    reservation_status  = 'cancelled',
               cancellation_reason = p_reason,
               cancelled_at        = NOW()
        WHERE  reservation_id = p_reservation_id;

        -- Mark all room assignments as unassigned
        UPDATE reservation_rooms
        SET    unassigned_at = NOW()
        WHERE  reservation_id = p_reservation_id
          AND  unassigned_at IS NULL;

        -- Log the unassignment in history
        INSERT INTO room_assignment_history
            (reservation_id, room_id, action, action_reason, action_by)
        SELECT p_reservation_id, room_id, 'unassigned',
               CONCAT('Cancellation: ', p_reason), p_staff
        FROM   reservation_rooms
        WHERE  reservation_id = p_reservation_id;

        COMMIT;
        SET p_message = CONCAT('SUCCESS: Reservation ', p_reservation_id, ' cancelled.');
    END IF;
END$$

-- =============================================================================
-- STORED PROCEDURE 3 : get_room_revenue_report  (Enhancement 2)
-- PURPOSE : Revenue growth and room-type profitability report
-- =============================================================================
DROP PROCEDURE IF EXISTS get_room_revenue_report$$

CREATE PROCEDURE get_room_revenue_report(
    IN p_year INT
)
BEGIN
    SELECT
        DATE_FORMAT(res.check_in_date, '%Y-%m')       AS month,
        rt.type_name,
        COUNT(DISTINCT res.reservation_id)            AS reservations,
        SUM(rr.booked_rate_per_night
            * DATEDIFF(res.check_out_date, res.check_in_date))
                                                      AS room_revenue,
        COALESCE((
            SELECT SUM(ec.amount)
            FROM   extra_charges ec
            WHERE  ec.reservation_id = res.reservation_id
        ), 0.00)                                      AS extra_revenue,
        SUM(rr.booked_rate_per_night
            * DATEDIFF(res.check_out_date, res.check_in_date))
        + COALESCE((
            SELECT SUM(ec.amount)
            FROM   extra_charges ec
            WHERE  ec.reservation_id = res.reservation_id
        ), 0.00)                                      AS total_revenue,
        -- Month-over-month growth (window function)
        SUM(rr.booked_rate_per_night
            * DATEDIFF(res.check_out_date, res.check_in_date))
        - LAG(SUM(rr.booked_rate_per_night
            * DATEDIFF(res.check_out_date, res.check_in_date))) OVER (
            PARTITION BY rt.type_name
            ORDER BY DATE_FORMAT(res.check_in_date,'%Y-%m')
        )                                             AS room_revenue_growth
    FROM  reservations res
    JOIN  reservation_rooms rr ON res.reservation_id = rr.reservation_id
                              AND rr.unassigned_at IS NULL
    JOIN  rooms r              ON rr.room_id          = r.room_id
    JOIN  room_types rt        ON r.room_type_id      = rt.room_type_id
    WHERE  res.reservation_status = 'completed'
      AND  YEAR(res.check_in_date) = p_year
    GROUP BY month, rt.type_name
    ORDER BY month, room_revenue DESC;
END$$

-- =============================================================================
-- STORED PROCEDURE 4 : cancellation_analysis  (Enhancement 4)
-- =============================================================================
DROP PROCEDURE IF EXISTS cancellation_analysis$$

CREATE PROCEDURE cancellation_analysis()
BEGIN
    SELECT
        DATE_FORMAT(cancelled_at,'%Y-%m')           AS cancel_month,
        COUNT(*)                                    AS cancellations,
        ROUND(AVG(DATEDIFF(check_in_date, cancelled_at)), 1)
                                                    AS avg_days_before_checkin,
        GROUP_CONCAT(DISTINCT cancellation_reason
                     ORDER BY cancellation_reason
                     SEPARATOR ' | ')              AS reasons
    FROM  reservations
    WHERE  reservation_status = 'cancelled'
      AND  cancelled_at IS NOT NULL
    GROUP BY cancel_month
    ORDER BY cancel_month;
END$$

DELIMITER ;

-- =============================================================================
-- EXECUTE STORED PROCEDURES – DEMONSTRATION
-- =============================================================================

-- ─── Test make_reservation: valid booking ────────────────────────────────
CALL make_reservation(
    6,          -- Anjali Nair
    6,          -- Room 203 (Std Double smoking)
    '2026-05-01',
    '2026-05-04',
    1,
    @new_res_id,
    @msg
);
SELECT @new_res_id AS new_reservation_id, @msg AS message;
-- Expected: SUCCESS with reservation_id and rate

-- ─── Test make_reservation: maintenance room ─────────────────────────────
CALL make_reservation(
    1,          -- Arjun Sharma
    3,          -- Room 103 (under_maintenance)
    '2026-05-10',
    '2026-05-13',
    1,
    @new_res_id2,
    @msg2
);
SELECT @new_res_id2 AS new_reservation_id, @msg2 AS message;
-- Expected: ERROR – Room is under_maintenance

-- ─── Test make_reservation: capacity exceeded ────────────────────────────
CALL make_reservation(
    1,          -- Arjun Sharma
    1,          -- Room 101 (Std Single, max 1 guest)
    '2026-06-01',
    '2026-06-03',
    3,          -- 3 guests in a single room → error
    @new_res_id3,
    @msg3
);
SELECT @new_res_id3 AS new_reservation_id, @msg3 AS message;
-- Expected: ERROR – Room capacity is 1; cannot accommodate 3 guests

-- ─── Test cancel_reservation ─────────────────────────────────────────────
-- Cancel the booking made by make_reservation test
CALL cancel_reservation(
    @new_res_id,
    'Demonstration cancellation',
    'test_system',
    @cancel_msg
);
SELECT @cancel_msg AS cancel_message;

-- ─── Run revenue report for 2025 ─────────────────────────────────────────
CALL get_room_revenue_report(2025);

-- ─── Run cancellation analysis ────────────────────────────────────────────
CALL cancellation_analysis();

-- =============================================================================
-- ENHANCEMENT 1 : Reservation Audit Trail
-- =============================================================================
-- (Already implemented: reservation_audit_log table + trg_reservation_audit
--  trigger in 01_schema_creation.sql)

-- View the full audit trail:
SELECT
    ral.audit_id,
    ral.reservation_id,
    CONCAT(g.first_name,' ',g.last_name)    AS guest_name,
    ral.old_status,
    ral.new_status,
    ral.changed_by,
    ral.changed_at
FROM  reservation_audit_log ral
JOIN  reservations res ON ral.reservation_id = res.reservation_id
JOIN  guests g         ON res.guest_id        = g.guest_id
ORDER BY ral.changed_at;

-- =============================================================================
-- ENHANCEMENT 2 : Revenue Growth & Room-Type Profitability
-- =============================================================================
-- (Implemented in PROCEDURE get_room_revenue_report above)
-- Additional: Year-over-year comparison placeholder

SELECT
    rt.type_name,
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date)) AS annual_revenue,
    COUNT(DISTINCT res.reservation_id)                     AS bookings,
    ROUND(AVG(DATEDIFF(res.check_out_date, res.check_in_date)), 1)
                                                           AS avg_stay_nights
FROM  reservations res
JOIN  reservation_rooms rr ON res.reservation_id = rr.reservation_id
                          AND rr.unassigned_at IS NULL
JOIN  rooms r              ON rr.room_id = r.room_id
JOIN  room_types rt        ON r.room_type_id = rt.room_type_id
WHERE  res.reservation_status = 'completed'
GROUP BY rt.type_name
ORDER BY annual_revenue DESC;

-- =============================================================================
-- ENHANCEMENT 3 : Guest Repeat-Visit Analysis
-- =============================================================================
-- (Core LAG() query in 08_window_functions.sql – C2)

-- Summary table: guests with multiple stays
SELECT
    g.guest_id,
    CONCAT(g.first_name,' ',g.last_name)    AS guest_name,
    COUNT(res.reservation_id)               AS total_stays,
    MIN(res.check_in_date)                  AS first_stay,
    MAX(res.check_in_date)                  AS last_stay,
    DATEDIFF(MAX(res.check_in_date),
             MIN(res.check_in_date))        AS days_as_guest,
    g.loyalty_points
FROM  guests g
JOIN  reservations res ON g.guest_id = res.guest_id
                      AND res.reservation_status = 'completed'
GROUP BY g.guest_id, guest_name, g.loyalty_points
HAVING total_stays > 1
ORDER BY total_stays DESC, days_as_guest DESC;

-- =============================================================================
-- END OF FILE 10_stored_procedures.sql
-- =============================================================================

