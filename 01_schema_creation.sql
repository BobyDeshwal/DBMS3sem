-- =============================================================================
-- StaySphere: An Intelligent Hotel Reservation, Dynamic Pricing &
--             Revenue Analytics System
-- =============================================================================
-- FILE       : 01_schema_creation.sql
-- PURPOSE    : Create the complete database schema (InnoDB, MySQL 8.0+)
-- AUTHOR     : DBMS Project
-- VERSION    : 1.0
-- =============================================================================
-- EXECUTION  : Run this file first before any other script.
--              mysql -u root -p < 01_schema_creation.sql
-- =============================================================================

-- -----------------------------------------------------------------------
-- 0. DATABASE SETUP
-- -----------------------------------------------------------------------
DROP DATABASE IF EXISTS staysphere;
CREATE DATABASE staysphere
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE staysphere;

-- Enforce strict mode and foreign-key checks for this session
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET FOREIGN_KEY_CHECKS = 1;

-- -----------------------------------------------------------------------
-- TABLE 1 : guests
-- PURPOSE  : Master record for every individual who books with the hotel.
--            Stores personal contact details.  A guest may make many
--            reservations over time.
-- NORMALIZATION NOTE
--   1NF – every column is atomic (no multi-valued attributes).
--   2NF – there is no partial dependency because the PK is a single
--         surrogate key (guest_id).
--   3NF – email, phone, and address describe the guest directly; no
--         transitive dependencies exist.
-- -----------------------------------------------------------------------
CREATE TABLE guests (
    guest_id        INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    first_name      VARCHAR(60)     NOT NULL,
    last_name       VARCHAR(60)     NOT NULL,
    email           VARCHAR(120)    NOT NULL,
    phone           VARCHAR(20)     NOT NULL,
    national_id     VARCHAR(40)     NOT NULL  COMMENT 'Passport / national ID number',
    date_of_birth   DATE            NOT NULL,
    address         VARCHAR(255)    NOT NULL,
    city            VARCHAR(80)     NOT NULL,
    country         VARCHAR(80)     NOT NULL DEFAULT 'India',
    loyalty_points  INT             UNSIGNED NOT NULL DEFAULT 0,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_guests        PRIMARY KEY (guest_id),
    -- Candidate key: email must be unique across all guests
    CONSTRAINT uq_guests_email  UNIQUE      (email),
    -- Candidate key: national ID must be unique
    CONSTRAINT uq_guests_natid  UNIQUE      (national_id),
    CONSTRAINT ck_guests_dob    CHECK       (date_of_birth < CURRENT_DATE)
) ENGINE=InnoDB COMMENT='Hotel guest master record';

-- -----------------------------------------------------------------------
-- TABLE 2 : room_types
-- PURPOSE  : Describes categories of rooms (Deluxe, Suite, etc.).
--            Stores capacity and amenity description.
--            Separating room types from individual rooms avoids repeating
--            type descriptions on every room row (3NF: type_name and
--            description depend only on room_type_id, not on room_id).
-- -----------------------------------------------------------------------
CREATE TABLE room_types (
    room_type_id    TINYINT         UNSIGNED NOT NULL AUTO_INCREMENT,
    type_name       VARCHAR(60)     NOT NULL,
    max_capacity    TINYINT         UNSIGNED NOT NULL,
    description     TEXT            NOT NULL,
    amenities       TEXT                     DEFAULT NULL
                                    COMMENT 'Comma-separated amenity list',
    base_rate       DECIMAL(10,2)   NOT NULL COMMENT 'Default nightly rate (INR)',

    CONSTRAINT pk_room_types        PRIMARY KEY (room_type_id),
    CONSTRAINT uq_room_type_name    UNIQUE      (type_name),
    CONSTRAINT ck_room_type_cap     CHECK       (max_capacity >= 1),
    CONSTRAINT ck_room_type_rate    CHECK       (base_rate > 0)
) ENGINE=InnoDB COMMENT='Category / tier of hotel rooms';

-- -----------------------------------------------------------------------
-- TABLE 3 : rooms
-- PURPOSE  : Individual physical rooms in the hotel.
--            Each room belongs to exactly one room_type.
--            room_status tracks physical/maintenance availability
--            independently of reservation availability.
--
-- Design decision – room_status vs. reservation availability:
--   room_status = 'available'  means the room is physically usable.
--   A room can be 'available' in status yet still have an active
--   reservation (not free for new bookings).
--   'under_maintenance' means the room cannot be booked regardless of
--   reservations.
--   Availability for booking is derived by querying the reservations
--   table; room_status guards physical state.
-- -----------------------------------------------------------------------
CREATE TABLE rooms (
    room_id         SMALLINT        UNSIGNED NOT NULL AUTO_INCREMENT,
    room_number     VARCHAR(10)     NOT NULL,
    room_type_id    TINYINT         UNSIGNED NOT NULL,
    floor_number    TINYINT         UNSIGNED NOT NULL,
    room_status     ENUM('available','occupied','under_maintenance','out_of_order')
                                    NOT NULL DEFAULT 'available',
    smoking         TINYINT(1)      NOT NULL DEFAULT 0
                                    COMMENT '1 = smoking room',
    notes           VARCHAR(255)             DEFAULT NULL,
    created_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT pk_rooms             PRIMARY KEY (room_id),
    CONSTRAINT uq_room_number       UNIQUE      (room_number),
    CONSTRAINT fk_rooms_type        FOREIGN KEY (room_type_id)
        REFERENCES room_types(room_type_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_rooms_floor       CHECK       (floor_number >= 1)
) ENGINE=InnoDB COMMENT='Physical hotel rooms';

-- -----------------------------------------------------------------------
-- TABLE 4 : room_rates
-- PURPOSE  : Date-range–based nightly rates for each room type.
--            Supports seasonal pricing, promotional rates, and future
--            price changes without altering historical records.
--
-- Design decision – overlapping rate periods:
--   The system PREVENTS overlapping rate periods for the same room_type
--   via application logic (stored procedure check_rate_overlap, defined
--   in 10_stored_procedures.sql).  A BEFORE INSERT trigger enforces the
--   rule at the database layer.  If overlap prevention is relaxed, a
--   rate_priority column (higher = wins) could resolve conflicts, but
--   the simpler non-overlapping approach is used here for clarity.
--
-- Normalization:
--   3NF: rate_name and nightly_rate depend on (room_type_id, valid_from,
--   valid_to), not on any non-key attribute.
-- -----------------------------------------------------------------------
CREATE TABLE room_rates (
    rate_id         INT             UNSIGNED NOT NULL AUTO_INCREMENT,
    room_type_id    TINYINT         UNSIGNED NOT NULL,
    rate_name       VARCHAR(80)     NOT NULL COMMENT 'e.g. "Summer Special"',
    nightly_rate    DECIMAL(10,2)   NOT NULL,
    valid_from      DATE            NOT NULL,
    valid_to        DATE            NOT NULL,

    CONSTRAINT pk_room_rates        PRIMARY KEY (rate_id),
    CONSTRAINT fk_rates_type        FOREIGN KEY (room_type_id)
        REFERENCES room_types(room_type_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_rates_period      CHECK       (valid_to > valid_from),
    CONSTRAINT ck_rates_amount      CHECK       (nightly_rate > 0)
) ENGINE=InnoDB COMMENT='Date-range nightly rates per room type';

-- -----------------------------------------------------------------------
-- TABLE 5 : reservations
-- PURPOSE  : Header record for each booking.
--            A reservation belongs to one guest.  Actual room
--            assignments live in reservation_rooms, supporting a
--            multi-room booking (e.g., family books two rooms).
--
-- Status lifecycle:
--   pending → confirmed → checked_in → completed
--                      → cancelled
--   'pending' reservations held for more than pending_expiry_minutes
--   (defined in the application / stored procedure) are treated as
--   expired and do not block availability.
--
-- Historical rate preservation:
--   booked_rate_per_night is the nightly rate agreed upon at booking.
--   Even if room_rates changes later, invoices use this column.
-- -----------------------------------------------------------------------
CREATE TABLE reservations (
    reservation_id      INT         UNSIGNED NOT NULL AUTO_INCREMENT,
    guest_id            INT         UNSIGNED NOT NULL,
    check_in_date       DATE        NOT NULL,
    check_out_date      DATE        NOT NULL,
    num_guests          TINYINT     UNSIGNED NOT NULL DEFAULT 1,
    reservation_status  ENUM('pending','confirmed','checked_in',
                             'completed','cancelled')
                                    NOT NULL DEFAULT 'pending',
    booked_rate_per_night DECIMAL(10,2) NOT NULL
                                    COMMENT 'Rate locked at booking time',
    special_requests    TEXT                 DEFAULT NULL,
    created_at          DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,
    confirmed_at        DATETIME             DEFAULT NULL,
    cancelled_at        DATETIME             DEFAULT NULL,
    cancellation_reason VARCHAR(255)         DEFAULT NULL,

    CONSTRAINT pk_reservations      PRIMARY KEY (reservation_id),
    CONSTRAINT fk_res_guest         FOREIGN KEY (guest_id)
        REFERENCES guests(guest_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_res_dates         CHECK       (check_out_date > check_in_date),
    CONSTRAINT ck_res_guests        CHECK       (num_guests >= 1)
) ENGINE=InnoDB COMMENT='Reservation header – one record per booking';

-- -----------------------------------------------------------------------
-- TABLE 6 : reservation_rooms
-- PURPOSE  : Maps reservations to specific rooms (many-to-many bridge).
--            A reservation may include multiple rooms; a room can appear
--            in many reservations (at different times).
--
--   booked_rate_per_night here is the per-room nightly rate preserved
--   at booking time.  This allows different rooms in the same reservation
--   to carry different rates (e.g., one suite + one standard).
--
-- Composite PK (reservation_id, room_id) ensures a room is not assigned
-- twice to the same reservation.
-- -----------------------------------------------------------------------
CREATE TABLE reservation_rooms (
    reservation_id      INT         UNSIGNED NOT NULL,
    room_id             SMALLINT    UNSIGNED NOT NULL,
    booked_rate_per_night DECIMAL(10,2) NOT NULL
                                    COMMENT 'Per-room rate locked at booking',
    assigned_at         DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    unassigned_at       DATETIME             DEFAULT NULL
                                    COMMENT 'NULL = currently assigned',

    CONSTRAINT pk_res_rooms         PRIMARY KEY (reservation_id, room_id),
    CONSTRAINT fk_rr_reservation    FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_rr_room           FOREIGN KEY (room_id)
        REFERENCES rooms(room_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_rr_rate           CHECK       (booked_rate_per_night > 0)
) ENGINE=InnoDB COMMENT='Room assignments per reservation (multi-room support)';

-- -----------------------------------------------------------------------
-- TABLE 7 : extra_charges
-- PURPOSE  : Line-item charges added to a reservation beyond room cost:
--            food, laundry, room service, minibar, spa, etc.
--            Keeping charges separate avoids repeating groups in
--            reservations (1NF) and allows per-night or per-item billing.
--
-- Double-counting note:
--   Billing queries SUM(room charges) + SUM(extra_charges) once each.
--   Neither column appears in both aggregations.
-- -----------------------------------------------------------------------
CREATE TABLE extra_charges (
    charge_id           INT         UNSIGNED NOT NULL AUTO_INCREMENT,
    reservation_id      INT         UNSIGNED NOT NULL,
    charge_category     ENUM('food','laundry','room_service','minibar',
                             'spa','transport','telephone','damage',
                             'other')
                                    NOT NULL,
    description         VARCHAR(200)NOT NULL,
    amount              DECIMAL(10,2) NOT NULL,
    charge_date         DATE        NOT NULL,
    created_at          DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_extra_charges     PRIMARY KEY (charge_id),
    CONSTRAINT fk_ec_reservation    FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_ec_amount         CHECK       (amount > 0)
) ENGINE=InnoDB COMMENT='Itemised extra charges against a reservation';

-- -----------------------------------------------------------------------
-- TABLE 8 : room_assignment_history
-- PURPOSE  : Immutable audit trail of every room assignment event.
--            When a guest is reassigned to a different room, the old
--            assignment is closed (unassigned_at set in reservation_rooms)
--            and a new row is added to both reservation_rooms and this
--            history table.  The history table is INSERT-only; rows are
--            never deleted or updated.
-- -----------------------------------------------------------------------
CREATE TABLE room_assignment_history (
    history_id          INT         UNSIGNED NOT NULL AUTO_INCREMENT,
    reservation_id      INT         UNSIGNED NOT NULL,
    room_id             SMALLINT    UNSIGNED NOT NULL,
    action              ENUM('assigned','unassigned','reassigned')
                                    NOT NULL,
    action_reason       VARCHAR(200)         DEFAULT NULL,
    action_by           VARCHAR(60)          DEFAULT NULL
                                    COMMENT 'Staff username or system',
    action_at           DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_rah               PRIMARY KEY (history_id),
    CONSTRAINT fk_rah_reservation   FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_rah_room          FOREIGN KEY (room_id)
        REFERENCES rooms(room_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB COMMENT='Immutable audit trail of room assignment events';

-- -----------------------------------------------------------------------
-- TABLE 9 : reservation_audit_log  (Enhancement 1)
-- PURPOSE  : Captures every status change to a reservation for full
--            audit traceability.  Populated by a BEFORE UPDATE trigger.
-- -----------------------------------------------------------------------
CREATE TABLE reservation_audit_log (
    audit_id            INT         UNSIGNED NOT NULL AUTO_INCREMENT,
    reservation_id      INT         UNSIGNED NOT NULL,
    old_status          VARCHAR(20)          DEFAULT NULL,
    new_status          VARCHAR(20)          DEFAULT NULL,
    changed_by          VARCHAR(60)          DEFAULT NULL,
    change_reason       VARCHAR(255)         DEFAULT NULL,
    changed_at          DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_audit             PRIMARY KEY (audit_id),
    CONSTRAINT fk_audit_res         FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB COMMENT='Audit log of reservation status changes';

-- =============================================================================
-- TRIGGERS
-- =============================================================================

DELIMITER $$

-- ----- Trigger T1: Prevent overlapping room_rates for the same room_type -----
CREATE TRIGGER trg_room_rates_overlap_check
BEFORE INSERT ON room_rates
FOR EACH ROW
BEGIN
    DECLARE overlap_count INT DEFAULT 0;
    SELECT COUNT(*) INTO overlap_count
    FROM   room_rates
    WHERE  room_type_id = NEW.room_type_id
      AND  valid_from   < NEW.valid_to
      AND  valid_to     > NEW.valid_from;

    IF overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT =
            'Rate period overlaps an existing rate for this room type. '
            'Close or adjust the existing period first.';
    END IF;
END$$

-- ----- Trigger T2: Audit log on reservation status change -------------------
CREATE TRIGGER trg_reservation_audit
BEFORE UPDATE ON reservations
FOR EACH ROW
BEGIN
    IF OLD.reservation_status <> NEW.reservation_status THEN
        INSERT INTO reservation_audit_log
            (reservation_id, old_status, new_status, changed_by, changed_at)
        VALUES
            (OLD.reservation_id, OLD.reservation_status,
             NEW.reservation_status, 'system', NOW());
    END IF;
END$$

-- ----- Trigger T3: Auto-set confirmed_at / cancelled_at timestamps ----------
CREATE TRIGGER trg_reservation_timestamps
BEFORE UPDATE ON reservations
FOR EACH ROW
BEGIN
    IF NEW.reservation_status = 'confirmed'
       AND OLD.reservation_status <> 'confirmed' THEN
        SET NEW.confirmed_at = NOW();
    END IF;
    IF NEW.reservation_status = 'cancelled'
       AND OLD.reservation_status <> 'cancelled' THEN
        SET NEW.cancelled_at = NOW();
    END IF;
END$$

DELIMITER ;

-- =============================================================================
-- INDEXES  (core indexes; additional covering indexes in 06_indexes_performance)
-- =============================================================================

-- Availability check: composite index on the bridge table
-- (reservation_id → check_in/out in parent, room_id here)
CREATE INDEX idx_res_rooms_room_dates
    ON reservation_rooms (room_id, assigned_at);

-- Guest email lookup (also enforced by UNIQUE constraint on guests)
-- The UNIQUE constraint already creates an implicit unique index.
-- A plain index would be redundant; the unique constraint is preferred
-- because it both enforces data integrity AND provides fast lookup.
-- (Explained further in 06_indexes_performance.sql)

-- Reservation date range scans
CREATE INDEX idx_reservations_dates
    ON reservations (check_in_date, check_out_date);

-- Reservation by guest (foreign key scan)
CREATE INDEX idx_reservations_guest
    ON reservations (guest_id, reservation_status);

-- Rate lookup by type and date
CREATE INDEX idx_room_rates_type_date
    ON room_rates (room_type_id, valid_from, valid_to);

-- Extra charges by reservation
CREATE INDEX idx_extra_charges_res
    ON extra_charges (reservation_id, charge_date);

-- =============================================================================
-- END OF FILE 01_schema_creation.sql
-- =============================================================================

