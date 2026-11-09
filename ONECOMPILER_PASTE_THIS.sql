-- ================================================================
-- STAYSPHERE – ONE FILE VERSION FOR ONECOMPILER.COM/MYSQL
-- ================================================================
-- INSTRUCTIONS:
--   1. Go to https://onecompiler.com/mysql
--   2. Select ALL text in the editor (Ctrl+A) and DELETE it
--   3. Copy ALL of THIS file (Ctrl+A then Ctrl+C)
--   4. Paste into OneCompiler (Ctrl+V)
--   5. Click the green RUN button ▶
-- ================================================================

-- ────────────────────────────────────────────────────────────────
-- PART 1: CREATE ALL TABLES
-- ────────────────────────────────────────────────────────────────

CREATE TABLE room_types (
    room_type_id  TINYINT UNSIGNED NOT NULL AUTO_INCREMENT,
    type_name     VARCHAR(60)      NOT NULL,
    max_capacity  TINYINT UNSIGNED NOT NULL,
    description   TEXT             NOT NULL,
    base_rate     DECIMAL(10,2)    NOT NULL,
    PRIMARY KEY (room_type_id),
    UNIQUE KEY uq_type_name (type_name)
);

CREATE TABLE rooms (
    room_id      SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    room_number  VARCHAR(10)       NOT NULL,
    room_type_id TINYINT UNSIGNED  NOT NULL,
    floor_number TINYINT UNSIGNED  NOT NULL,
    room_status  VARCHAR(30)       NOT NULL DEFAULT 'available',
    PRIMARY KEY (room_id),
    UNIQUE KEY uq_room_number (room_number),
    FOREIGN KEY (room_type_id) REFERENCES room_types(room_type_id)
);

CREATE TABLE room_rates (
    rate_id      INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    room_type_id TINYINT UNSIGNED NOT NULL,
    rate_name    VARCHAR(80)      NOT NULL,
    nightly_rate DECIMAL(10,2)    NOT NULL,
    valid_from   DATE             NOT NULL,
    valid_to     DATE             NOT NULL,
    PRIMARY KEY (rate_id),
    FOREIGN KEY (room_type_id) REFERENCES room_types(room_type_id)
);

CREATE TABLE guests (
    guest_id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
    first_name     VARCHAR(60)  NOT NULL,
    last_name      VARCHAR(60)  NOT NULL,
    email          VARCHAR(120) NOT NULL,
    phone          VARCHAR(20)  NOT NULL,
    city           VARCHAR(80)  NOT NULL,
    loyalty_points INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (guest_id),
    UNIQUE KEY uq_email (email)
);

CREATE TABLE reservations (
    reservation_id     INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    guest_id           INT UNSIGNED  NOT NULL,
    check_in_date      DATE          NOT NULL,
    check_out_date     DATE          NOT NULL,
    num_guests         TINYINT       NOT NULL DEFAULT 1,
    reservation_status VARCHAR(20)   NOT NULL DEFAULT 'confirmed',
    booked_rate_per_night DECIMAL(10,2) NOT NULL,
    special_requests   TEXT,
    PRIMARY KEY (reservation_id),
    FOREIGN KEY (guest_id) REFERENCES guests(guest_id)
);

CREATE TABLE reservation_rooms (
    reservation_id       INT UNSIGNED     NOT NULL,
    room_id              SMALLINT UNSIGNED NOT NULL,
    booked_rate_per_night DECIMAL(10,2)   NOT NULL,
    assigned_at          DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (reservation_id, room_id),
    FOREIGN KEY (reservation_id) REFERENCES reservations(reservation_id),
    FOREIGN KEY (room_id)        REFERENCES rooms(room_id)
);

CREATE TABLE extra_charges (
    charge_id      INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    reservation_id INT UNSIGNED  NOT NULL,
    charge_type    VARCHAR(30)   NOT NULL,
    description    VARCHAR(200)  NOT NULL,
    amount         DECIMAL(10,2) NOT NULL,
    charge_date    DATE          NOT NULL,
    PRIMARY KEY (charge_id),
    FOREIGN KEY (reservation_id) REFERENCES reservations(reservation_id)
);

-- ────────────────────────────────────────────────────────────────
-- PART 2: INSERT SAMPLE DATA
-- ────────────────────────────────────────────────────────────────

-- Room Types
INSERT INTO room_types VALUES
(1,'Standard Single',  1,'Compact room with queen bed.',         3500.00),
(2,'Standard Double',  2,'Spacious room with king bed.',         5000.00),
(3,'Deluxe Double',    3,'Premium room with pool or garden view.',8000.00),
(4,'Executive Suite',  4,'Separate living room and city view.',  15000.00),
(5,'Presidential Suite',6,'Two bedrooms, panoramic view.',       35000.00);

-- Rooms (15 rooms across 5 floors)
INSERT INTO rooms VALUES
(1, '101',1,1,'available'),
(2, '102',1,1,'available'),
(3, '103',1,1,'under_maintenance'),
(4, '201',2,2,'available'),
(5, '202',2,2,'available'),
(6, '203',2,2,'available'),
(7, '301',3,3,'available'),
(8, '302',3,3,'available'),
(9, '303',3,3,'out_of_order'),
(10,'401',4,4,'available'),
(11,'402',4,4,'available'),
(12,'501',5,5,'available'),
(13,'502',5,5,'available'),
(14,'104',1,1,'available'),
(15,'204',2,2,'available');

-- Seasonal Rates (4 seasons × 5 room types = 20 rates)
INSERT INTO room_rates(room_type_id,rate_name,nightly_rate,valid_from,valid_to) VALUES
(1,'Std Single – Regular',  3500.00,'2025-01-01','2025-03-31'),
(1,'Std Single – Summer',   4200.00,'2025-04-01','2025-06-30'),
(1,'Std Single – Monsoon',  3000.00,'2025-07-01','2025-09-30'),
(1,'Std Single – Festive',  5000.00,'2025-10-01','2025-12-31'),
(2,'Std Double – Regular',  5000.00,'2025-01-01','2025-03-31'),
(2,'Std Double – Summer',   6000.00,'2025-04-01','2025-06-30'),
(2,'Std Double – Monsoon',  4500.00,'2025-07-01','2025-09-30'),
(2,'Std Double – Festive',  7500.00,'2025-10-01','2025-12-31'),
(3,'Deluxe – Regular',      8000.00,'2025-01-01','2025-03-31'),
(3,'Deluxe – Summer',       9500.00,'2025-04-01','2025-06-30'),
(3,'Deluxe – Monsoon',      7000.00,'2025-07-01','2025-09-30'),
(3,'Deluxe – Festive',     12000.00,'2025-10-01','2025-12-31'),
(4,'Exec Suite – Regular', 15000.00,'2025-01-01','2025-03-31'),
(4,'Exec Suite – Summer',  18000.00,'2025-04-01','2025-06-30'),
(4,'Exec Suite – Monsoon', 12000.00,'2025-07-01','2025-09-30'),
(4,'Exec Suite – Festive', 22000.00,'2025-10-01','2025-12-31'),
(5,'Presidential – Regular',35000.00,'2025-01-01','2025-03-31'),
(5,'Presidential – Summer', 42000.00,'2025-04-01','2025-06-30'),
(5,'Presidential – Monsoon',28000.00,'2025-07-01','2025-09-30'),
(5,'Presidential – Festive',50000.00,'2025-10-01','2025-12-31');

-- Guests (12 guests)
INSERT INTO guests VALUES
(1, 'Arjun',  'Sharma', 'arjun.sharma@email.com', '+91-9812345670','New Delhi',   1200),
(2, 'Priya',  'Verma',  'priya.verma@email.com',  '+91-9823456781','Bengaluru',    800),
(3, 'Rohan',  'Mehta',  'rohan.mehta@email.com',  '+91-9834567892','Kolkata',       350),
(4, 'Sneha',  'Patel',  'sneha.patel@email.com',  '+91-9845678903','Ahmedabad',    2100),
(5, 'Vikram', 'Singh',  'vikram.singh@email.com', '+91-9856789014','Jaipur',        500),
(6, 'Anjali', 'Nair',   'anjali.nair@email.com',  '+91-9867890125','Kochi',         150),
(7, 'Rajan',  'Iyer',   'rajan.iyer@email.com',   '+91-9878901236','Chennai',      3500),
(8, 'Meera',  'Joshi',  'meera.joshi@email.com',  '+91-9889012347','Hyderabad',     700),
(9, 'Karan',  'Kapoor', 'karan.kapoor@email.com', '+91-9890123458','Mumbai',       4200),
(10,'Divya',  'Reddy',  'divya.reddy@email.com',  '+91-9901234569','Hyderabad',     220),
(11,'Suresh', 'Kumar',  'suresh.kumar@email.com', '+91-9912345670','Bhopal',       1800),
(12,'Lakshmi','Menon',  'lakshmi.menon@email.com','+91-9923456781','Thiruvananthapuram',950);

-- Reservations (20 reservations)
INSERT INTO reservations VALUES
(1, 1,'2025-01-10','2025-01-13',1,'completed', 3500.00,'High floor preferred'),
(2, 2,'2025-02-14','2025-02-17',2,'completed', 5000.00,'Anniversary decoration'),
(3, 3,'2025-03-01','2025-03-04',1,'cancelled', 3500.00, NULL),
(4, 4,'2025-04-05','2025-04-09',2,'completed', 9500.00,'Pool view room'),
(5, 5,'2025-04-12','2025-04-15',3,'completed',18000.00,'Extra bed required'),
(6, 6,'2025-05-20','2025-05-23',1,'completed', 4200.00, NULL),
(7, 7,'2025-06-01','2025-06-05',4,'completed',42000.00,'Private dining setup'),
(8, 8,'2025-07-10','2025-07-14',2,'completed', 7000.00,'Quiet floor please'),
(9, 9,'2025-08-01','2025-08-06',2,'completed', 4500.00, NULL),
(10,10,'2025-09-15','2025-09-18',1,'completed', 3000.00, NULL),
(11,11,'2025-10-20','2025-10-24',3,'completed',12000.00,'Birthday celebration'),
(12,12,'2025-11-05','2025-11-08',2,'completed', 7500.00, NULL),
(13, 1,'2025-11-20','2025-11-23',1,'completed', 5000.00, NULL),
(14, 9,'2025-12-24','2025-12-27',2,'completed',22000.00,'Christmas decoration'),
(15, 7,'2025-12-10','2025-12-13',3,'completed',50000.00,'New Year meeting room'),
(16, 2,'2026-01-15','2026-01-18',2,'confirmed', 5000.00, NULL),
(17, 4,'2026-02-14','2026-02-17',2,'confirmed', 8000.00,'Valentine package'),
(18, 6,'2026-03-01','2026-03-03',1,'pending',   3500.00, NULL),
(19, 2,'2025-01-13','2025-01-15',1,'completed', 3500.00, NULL),
(20, 9,'2025-08-15','2025-08-18',4,'completed', 8000.00,'Two connecting rooms');

-- Room Assignments
INSERT INTO reservation_rooms VALUES
(1, 1, 3500.00, '2025-01-08 10:05:00'),
(2, 4, 5000.00, '2025-02-10 14:05:00'),
(3, 2, 3500.00, '2025-02-20 09:05:00'),
(4, 7, 9500.00, '2025-04-01 16:05:00'),
(5,10,18000.00, '2025-04-08 11:35:00'),
(6,14, 4200.00, '2025-05-15 09:05:00'),
(7,12,42000.00, '2025-05-28 10:05:00'),
(8, 8, 7000.00, '2025-07-05 12:05:00'),
(9,15, 4500.00, '2025-07-28 08:05:00'),
(10,1, 3000.00, '2025-09-10 10:05:00'),
(11,8,12000.00, '2025-10-15 14:05:00'),
(12,4, 7500.00, '2025-11-01 09:05:00'),
(13,15, 5000.00,'2025-11-17 11:05:00'),
(14,11,22000.00,'2025-12-20 10:05:00'),
(15,13,50000.00,'2025-12-05 09:05:00'),
(16, 4, 5000.00,'2026-01-10 10:05:00'),
(17, 7, 8000.00,'2026-02-10 14:05:00'),
(18, 2, 3500.00,'2026-02-28 10:00:00'),
(19, 1, 3500.00,'2025-01-11 10:05:00'),
(20, 4, 8000.00,'2025-08-10 09:05:00'),
(20, 5, 8000.00,'2025-08-10 09:05:00');

-- Extra Charges
INSERT INTO extra_charges(reservation_id,charge_type,description,amount,charge_date) VALUES
(1,'food',        'Restaurant dinner',        850.00,'2025-01-10'),
(1,'minibar',     'Minibar consumption',       320.00,'2025-01-11'),
(1,'laundry',     'Express laundry',          450.00,'2025-01-12'),
(2,'food',        'Breakfast in room',       1200.00,'2025-02-14'),
(2,'room_service','Late night room service',  650.00,'2025-02-15'),
(2,'spa',         'Couples spa session',     2800.00,'2025-02-16'),
(4,'food',        'Pool-side lunch',         1100.00,'2025-04-06'),
(4,'transport',   'Airport pickup',           800.00,'2025-04-05'),
(5,'room_service','Business meeting snacks', 1500.00,'2025-04-13'),
(7,'food',        'Private dining',          8000.00,'2025-06-01'),
(7,'spa',         'Full spa package',       12000.00,'2025-06-02'),
(7,'transport',   'Chauffeur 4 days',        6000.00,'2025-06-03'),
(9,'food',        'Restaurant (5 nights)',   3200.00,'2025-08-02'),
(9,'laundry',     'Laundry 3 days',           600.00,'2025-08-03'),
(11,'food',       'Birthday dinner',         4500.00,'2025-10-21'),
(11,'spa',        'Rejuvenation spa',        3200.00,'2025-10-22'),
(11,'minibar',    'Minibar 4 nights',        1100.00,'2025-10-23'),
(14,'food',       'Christmas dinner gala',   5500.00,'2025-12-24'),
(14,'room_service','Room service 3 nights',  1800.00,'2025-12-25'),
(14,'transport',  'Christmas chauffeur',     1200.00,'2025-12-24'),
(15,'food',       'Business dinner',         6000.00,'2025-12-10'),
(15,'spa',        'Spa and wellness',        9000.00,'2025-12-11'),
(20,'food',       'Family dining',           4200.00,'2025-08-15'),
(20,'spa',        'Family spa package',      5000.00,'2025-08-16');


-- ================================================================
-- PART 3: DEMO QUERIES (Results appear in the output panel)
-- ================================================================

-- ────────────────────────────────────────────────────
-- QUERY 1: All guests and their reservation count
-- ────────────────────────────────────────────────────
SELECT '=== QUERY 1: Guest Summary ===' AS demo;
SELECT
    g.guest_id,
    CONCAT(g.first_name,' ',g.last_name) AS guest_name,
    g.city,
    COUNT(r.reservation_id)              AS total_bookings,
    SUM(CASE WHEN r.reservation_status='completed' THEN 1 ELSE 0 END) AS completed
FROM guests g
LEFT JOIN reservations r ON g.guest_id = r.guest_id
GROUP BY g.guest_id, guest_name, g.city
ORDER BY total_bookings DESC;

-- ────────────────────────────────────────────────────
-- QUERY 2: Full Bill for Every Completed Reservation
-- ────────────────────────────────────────────────────
SELECT '=== QUERY 2: Full Billing Summary ===' AS demo;
SELECT
    res.reservation_id,
    CONCAT(g.first_name,' ',g.last_name)    AS guest_name,
    rm.room_number,
    rt.type_name,
    res.check_in_date,
    res.check_out_date,
    DATEDIFF(res.check_out_date,res.check_in_date) AS nights,
    rr.booked_rate_per_night               AS rate,
    rr.booked_rate_per_night *
        DATEDIFF(res.check_out_date,res.check_in_date) AS room_charges,
    COALESCE((SELECT SUM(amount) FROM extra_charges ec
              WHERE ec.reservation_id=res.reservation_id),0) AS extra_charges,
    rr.booked_rate_per_night *
        DATEDIFF(res.check_out_date,res.check_in_date)
    + COALESCE((SELECT SUM(amount) FROM extra_charges ec
                WHERE ec.reservation_id=res.reservation_id),0) AS TOTAL_BILL
FROM reservations res
JOIN guests g              ON res.guest_id       = g.guest_id
JOIN reservation_rooms rr  ON res.reservation_id = rr.reservation_id
JOIN rooms rm              ON rr.room_id          = rm.room_id
JOIN room_types rt         ON rm.room_type_id     = rt.room_type_id
WHERE res.reservation_status = 'completed'
ORDER BY TOTAL_BILL DESC;

-- ────────────────────────────────────────────────────
-- QUERY 3: Room Availability Check (Sep 1–5, 2025)
-- ────────────────────────────────────────────────────
SELECT '=== QUERY 3: Available Rooms Sep 1-5, 2025 ===' AS demo;
SELECT
    r.room_number,
    rt.type_name,
    r.floor_number,
    rt.max_capacity,
    rt.base_rate AS price_per_night,
    'AVAILABLE' AS status
FROM rooms r
JOIN room_types rt ON r.room_type_id = rt.room_type_id
WHERE
    r.room_status IN ('available','occupied')
    AND r.room_id NOT IN (
        SELECT rr.room_id
        FROM reservation_rooms rr
        JOIN reservations res ON rr.reservation_id = res.reservation_id
        WHERE res.reservation_status IN ('confirmed','checked_in')
          AND res.check_in_date  < '2025-09-05'
          AND res.check_out_date > '2025-09-01'
    )
ORDER BY r.floor_number, r.room_number;

-- ────────────────────────────────────────────────────
-- QUERY 4: RANK() – Room Type Revenue per Month
-- ────────────────────────────────────────────────────
SELECT '=== QUERY 4: Room Type Revenue RANK by Month ===' AS demo;
WITH monthly AS (
    SELECT
        DATE_FORMAT(res.check_in_date,'%Y-%m') AS revenue_month,
        rt.type_name,
        SUM(rr.booked_rate_per_night *
            DATEDIFF(res.check_out_date,res.check_in_date)) AS room_revenue
    FROM reservations res
    JOIN reservation_rooms rr ON res.reservation_id = rr.reservation_id
    JOIN rooms rm              ON rr.room_id          = rm.room_id
    JOIN room_types rt         ON rm.room_type_id     = rt.room_type_id
    WHERE res.reservation_status = 'completed'
    GROUP BY revenue_month, rt.type_name
)
SELECT
    revenue_month,
    type_name,
    room_revenue,
    RANK() OVER (PARTITION BY revenue_month ORDER BY room_revenue DESC) AS revenue_rank
FROM monthly
ORDER BY revenue_month, revenue_rank;

-- ────────────────────────────────────────────────────
-- QUERY 5: Cumulative Monthly Revenue (SUM OVER)
-- ────────────────────────────────────────────────────
SELECT '=== QUERY 5: Cumulative Revenue by Month ===' AS demo;
WITH monthly_total AS (
    SELECT
        DATE_FORMAT(res.check_in_date,'%Y-%m') AS revenue_month,
        SUM(rr.booked_rate_per_night *
            DATEDIFF(res.check_out_date,res.check_in_date)) AS room_revenue
    FROM reservations res
    JOIN reservation_rooms rr ON res.reservation_id = rr.reservation_id
    WHERE res.reservation_status = 'completed'
    GROUP BY revenue_month
)
SELECT
    revenue_month,
    room_revenue,
    SUM(room_revenue) OVER (ORDER BY revenue_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_revenue
FROM monthly_total
ORDER BY revenue_month;

-- ────────────────────────────────────────────────────
-- QUERY 6: LAG() – Gap Between Consecutive Guest Stays
-- ────────────────────────────────────────────────────
SELECT '=== QUERY 6: Days Between Guest Stays (LAG) ===' AS demo;
WITH stays AS (
    SELECT
        g.guest_id,
        CONCAT(g.first_name,' ',g.last_name) AS guest_name,
        res.check_in_date,
        res.check_out_date
    FROM guests g
    JOIN reservations res ON g.guest_id = res.guest_id
    WHERE res.reservation_status = 'completed'
)
SELECT
    guest_name,
    check_in_date,
    check_out_date,
    LAG(check_out_date) OVER (PARTITION BY guest_id ORDER BY check_in_date) AS prev_checkout,
    DATEDIFF(check_in_date,
        LAG(check_out_date) OVER (PARTITION BY guest_id ORDER BY check_in_date)
    ) AS gap_days
FROM stays
ORDER BY guest_id, check_in_date;

-- ────────────────────────────────────────────────────
-- QUERY 7: NTILE(4) – Guest Spending Tiers
-- ────────────────────────────────────────────────────
SELECT '=== QUERY 7: Guest Spending Tiers (NTILE 4) ===' AS demo;
WITH spending AS (
    SELECT
        g.guest_id,
        CONCAT(g.first_name,' ',g.last_name) AS guest_name,
        COALESCE(SUM(rr.booked_rate_per_night *
            DATEDIFF(res.check_out_date,res.check_in_date)),0)
        + COALESCE((SELECT SUM(ec.amount) FROM extra_charges ec
                    JOIN reservations r2 ON ec.reservation_id=r2.reservation_id
                    WHERE r2.guest_id=g.guest_id
                      AND r2.reservation_status='completed'),0) AS total_spending
    FROM guests g
    LEFT JOIN reservations res ON g.guest_id=res.guest_id
                               AND res.reservation_status='completed'
    LEFT JOIN reservation_rooms rr ON res.reservation_id=rr.reservation_id
    GROUP BY g.guest_id, guest_name
)
SELECT
    guest_name,
    total_spending,
    NTILE(4) OVER (ORDER BY total_spending ASC) AS quartile,
    CASE NTILE(4) OVER (ORDER BY total_spending ASC)
        WHEN 1 THEN 'Bronze'
        WHEN 2 THEN 'Silver'
        WHEN 3 THEN 'Gold'
        WHEN 4 THEN 'Platinum'
    END AS spending_tier
FROM spending
ORDER BY total_spending DESC;

-- ────────────────────────────────────────────────────
-- QUERY 8: Top Guests by Lifetime Value
-- ────────────────────────────────────────────────────
SELECT '=== QUERY 8: Guest Lifetime Value ===' AS demo;
SELECT
    g.guest_id,
    CONCAT(g.first_name,' ',g.last_name) AS guest_name,
    g.city,
    COUNT(DISTINCT res.reservation_id)   AS total_stays,
    SUM(rr.booked_rate_per_night *
        DATEDIFF(res.check_out_date,res.check_in_date)) AS room_spend,
    COALESCE((SELECT SUM(ec.amount) FROM extra_charges ec
              JOIN reservations r2 ON ec.reservation_id=r2.reservation_id
              WHERE r2.guest_id=g.guest_id
                AND r2.reservation_status='completed'),0) AS extra_spend,
    SUM(rr.booked_rate_per_night *
        DATEDIFF(res.check_out_date,res.check_in_date))
    + COALESCE((SELECT SUM(ec.amount) FROM extra_charges ec
                JOIN reservations r2 ON ec.reservation_id=r2.reservation_id
                WHERE r2.guest_id=g.guest_id
                  AND r2.reservation_status='completed'),0) AS LIFETIME_VALUE
FROM guests g
JOIN reservations res     ON g.guest_id=res.guest_id
                         AND res.reservation_status='completed'
JOIN reservation_rooms rr ON res.reservation_id=rr.reservation_id
GROUP BY g.guest_id, guest_name, g.city
ORDER BY LIFETIME_VALUE DESC;

-- ================================================================
-- END – You should see 8 result tables in the output!
-- ================================================================

