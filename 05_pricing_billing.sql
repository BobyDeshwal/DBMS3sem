-- =============================================================================
-- StaySphere – FILE 05 : Dynamic Pricing & Billing
-- =============================================================================
-- PURPOSE : Accurate per-night billing using date-range rates, extra charges,
--           cumulative totals, and guest spending summaries.
-- NOTE    : Run AFTER 01_schema_creation.sql and 02_sample_data.sql
-- =============================================================================

USE staysphere;

-- =============================================================================
-- SECTION 1 : PER-NIGHT RATE RESOLUTION
-- =============================================================================
-- The billing engine must determine the applicable rate for EACH occupied
-- night individually (because a stay may span a rate-change boundary).
--
-- Example: Res 11 (Suresh Kumar) checks in Oct 20, checks out Oct 24.
--   Nights: Oct 20, Oct 21, Oct 22, Oct 23  (checkout is EXCLUSIVE)
--   All 4 nights fall within the Festive period (Oct 1 – Dec 31) @ 12,000/night.
--   Total room charge = 4 × 12,000 = 48,000
--
-- For stays spanning two rate periods:
--   Use a recursive CTE or a calendar approach to expand each stay into
--   individual nights and join with room_rates.
-- =============================================================================

-- ─── 1A. Generate nightly breakdown using recursive CTE ───────────────────
-- MySQL 8.0 supports WITH RECURSIVE. Each night is one row.
-- We join each night to the applicable rate in room_rates.

WITH RECURSIVE nights AS (
    -- Seed: first night of each reservation-room pair
    SELECT
        rr.reservation_id,
        rr.room_id,
        rr.booked_rate_per_night,
        res.check_in_date          AS night_date,
        res.check_out_date         AS checkout_date,
        res.reservation_status,
        res.guest_id,
        r.room_type_id
    FROM reservation_rooms rr
    JOIN reservations res ON rr.reservation_id = res.reservation_id
    JOIN rooms r          ON rr.room_id        = r.room_id
    WHERE rr.unassigned_at IS NULL           -- current assignment only

    UNION ALL

    -- Recursive: add one day at a time until checkout - 1
    SELECT
        n.reservation_id,
        n.room_id,
        n.booked_rate_per_night,
        DATE_ADD(n.night_date, INTERVAL 1 DAY),
        n.checkout_date,
        n.reservation_status,
        n.guest_id,
        n.room_type_id
    FROM nights n
    WHERE DATE_ADD(n.night_date, INTERVAL 1 DAY) < n.checkout_date
)
SELECT
    n.reservation_id,
    n.room_id,
    n.night_date,
    -- Use the booked rate (historical preservation) – no live rate lookup
    n.booked_rate_per_night        AS rate_applied
FROM nights n
WHERE n.reservation_status IN ('completed','checked_in')
ORDER BY n.reservation_id, n.room_id, n.night_date;

-- ─── 1B. Why we use booked_rate_per_night instead of live room_rates ───────
-- Historical rate preservation:
--   A guest who booked at 9,500/night in February should be billed at
--   9,500/night even if the rate changes to 12,000 before checkout.
--   The booked_rate_per_night column in reservation_rooms captures the rate
--   at the time of booking and is immutable thereafter.
--
-- Live rate lookup (room_rates table) is only needed when CREATING a new
-- reservation, to determine the booked_rate_per_night to store.

-- ─── 1C. Look up current rate for a new booking ───────────────────────────
-- Finding the correct rate when creating a reservation for dates that span
-- multiple rate periods:
-- (Stored procedure make_reservation in 10_stored_procedures.sql handles this
--  with a SELECT + cursor; shown here as a direct query for illustration)

SELECT rr.rate_name, rr.nightly_rate, rr.valid_from, rr.valid_to
FROM   room_rates rr
WHERE  rr.room_type_id = 3                      -- Deluxe Double
  AND  rr.valid_from  <= '2025-04-05'           -- rate in effect on check-in
  AND  rr.valid_to    >= '2025-04-05'
LIMIT  1;
-- Expected: Deluxe Double – Summer @ 9,500.00 (Apr 1 – Jun 30)

-- =============================================================================
-- SECTION 2 : RESERVATION BILLING CALCULATION
-- =============================================================================

-- ─── 2A. Full bill for a single reservation ───────────────────────────────
-- Calculates: nights, room charges (using booked rate), extra charges, total

SELECT
    res.reservation_id,
    CONCAT(g.first_name,' ',g.last_name)       AS guest_name,
    res.check_in_date,
    res.check_out_date,
    DATEDIFF(res.check_out_date, res.check_in_date)
                                               AS nights,
    -- Room charges: SUM of (booked_rate × nights) across all assigned rooms
    -- Using SUM to support multi-room reservations correctly
    SUM(DISTINCT rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
                                               AS room_charges,
    -- Extra charges: SUM of all line items for this reservation
    COALESCE((
        SELECT SUM(ec.amount)
        FROM   extra_charges ec
        WHERE  ec.reservation_id = res.reservation_id
    ), 0.00)                                   AS extra_charges_total,
    -- Grand total
    SUM(DISTINCT rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
    + COALESCE((
        SELECT SUM(ec.amount)
        FROM   extra_charges ec
        WHERE  ec.reservation_id = res.reservation_id
    ), 0.00)                                   AS grand_total
FROM  reservations res
JOIN  guests g              ON res.guest_id       = g.guest_id
JOIN  reservation_rooms rr  ON res.reservation_id = rr.reservation_id
                           AND rr.unassigned_at IS NULL
WHERE res.reservation_id = 7          -- Rajan Iyer – Presidential Suite, Jun 2025
GROUP BY res.reservation_id, guest_name,
         res.check_in_date, res.check_out_date;
-- Expected:
--   nights         = 4  (Jun 1 to Jun 5)
--   room_charges   = 42,000 × 4 = 168,000
--   extra_charges  = 8,000 + 12,000 + 6,000 + 2,400 = 28,400
--   grand_total    = 196,400

-- ─── 2B. Multi-room reservation billing (Res 20 – two rooms) ─────────────
-- Avoid double-counting: each room contributes its own booked_rate × nights.
-- Extra charges are for the whole reservation (not per room).

SELECT
    res.reservation_id,
    CONCAT(g.first_name,' ',g.last_name)   AS guest_name,
    DATEDIFF(res.check_out_date, res.check_in_date)
                                           AS nights,
    COUNT(rr.room_id)                      AS rooms_booked,
    -- Room charges: sum each room's rate × nights
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
                                           AS total_room_charges,
    -- Extra charges: one-time aggregate (not multiplied by room count)
    COALESCE((
        SELECT SUM(ec.amount)
        FROM   extra_charges ec
        WHERE  ec.reservation_id = res.reservation_id
    ), 0.00)                               AS extra_charges_total,
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
    + COALESCE((
        SELECT SUM(ec.amount)
        FROM   extra_charges ec
        WHERE  ec.reservation_id = res.reservation_id
    ), 0.00)                               AS grand_total
FROM  reservations res
JOIN  guests g              ON res.guest_id       = g.guest_id
JOIN  reservation_rooms rr  ON res.reservation_id = rr.reservation_id
                           AND rr.unassigned_at IS NULL
WHERE res.reservation_id = 20
GROUP BY res.reservation_id, guest_name,
         res.check_in_date, res.check_out_date;
-- Expected:
--   rooms_booked      = 2
--   nights            = 3  (Aug 15 to Aug 18)
--   total_room_charges= (8,000+8,000) × 3 = 48,000
--   extra_charges     = 4,200 + 5,000 = 9,200
--   grand_total       = 57,200

-- ─── 2C. Complete billing for all completed reservations ─────────────────
SELECT
    res.reservation_id,
    CONCAT(g.first_name,' ',g.last_name)   AS guest_name,
    res.check_in_date,
    res.check_out_date,
    DATEDIFF(res.check_out_date, res.check_in_date)  AS nights,
    GROUP_CONCAT(rm.room_number)           AS rooms,
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
                                           AS room_charges,
    COALESCE((
        SELECT SUM(ec.amount)
        FROM extra_charges ec
        WHERE ec.reservation_id = res.reservation_id
    ), 0.00)                               AS extra_charges,
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
    + COALESCE((
        SELECT SUM(ec.amount)
        FROM extra_charges ec
        WHERE ec.reservation_id = res.reservation_id
    ), 0.00)                               AS total_bill
FROM  reservations res
JOIN  guests g              ON res.guest_id       = g.guest_id
JOIN  reservation_rooms rr  ON res.reservation_id = rr.reservation_id
                           AND rr.unassigned_at IS NULL
JOIN  rooms rm              ON rr.room_id          = rm.room_id
WHERE res.reservation_status = 'completed'
GROUP BY res.reservation_id, guest_name,
         res.check_in_date, res.check_out_date
ORDER BY total_bill DESC;

-- =============================================================================
-- SECTION 3 : GUEST TOTAL SPENDING
-- =============================================================================

-- ─── 3A. Total spending per guest over all completed reservations ─────────
SELECT
    g.guest_id,
    CONCAT(g.first_name,' ',g.last_name)   AS guest_name,
    COUNT(DISTINCT res.reservation_id)     AS completed_stays,
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
                                           AS total_room_revenue,
    COALESCE((
        SELECT SUM(ec.amount)
        FROM   extra_charges ec
        JOIN   reservations r2 ON ec.reservation_id = r2.reservation_id
        WHERE  r2.guest_id = g.guest_id
          AND  r2.reservation_status = 'completed'
    ), 0.00)                               AS total_extra_charges,
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
    + COALESCE((
        SELECT SUM(ec.amount)
        FROM   extra_charges ec
        JOIN   reservations r2 ON ec.reservation_id = r2.reservation_id
        WHERE  r2.guest_id = g.guest_id
          AND  r2.reservation_status = 'completed'
    ), 0.00)                               AS total_spending
FROM  guests g
JOIN  reservations res      ON g.guest_id         = res.guest_id
                           AND res.reservation_status = 'completed'
JOIN  reservation_rooms rr  ON res.reservation_id = rr.reservation_id
                           AND rr.unassigned_at IS NULL
GROUP BY g.guest_id, guest_name
ORDER BY total_spending DESC;

-- ─── 3B. Spending in a specific date range ───────────────────────────────
SET @period_start = '2025-06-01';
SET @period_end   = '2025-12-31';

SELECT
    g.guest_id,
    CONCAT(g.first_name,' ',g.last_name)   AS guest_name,
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
    + COALESCE((
        SELECT SUM(ec.amount)
        FROM   extra_charges ec
        WHERE  ec.reservation_id = res.reservation_id
    ), 0.00)                               AS period_spending
FROM  reservations res
JOIN  guests g             ON res.guest_id        = g.guest_id
JOIN  reservation_rooms rr ON res.reservation_id  = rr.reservation_id
                          AND rr.unassigned_at IS NULL
WHERE  res.reservation_status = 'completed'
  AND  res.check_in_date BETWEEN @period_start AND @period_end
GROUP BY g.guest_id, guest_name
ORDER BY period_spending DESC;

-- =============================================================================
-- SECTION 4 : MONTHLY REVENUE REPORT
-- =============================================================================

-- ─── 4A. Monthly room revenue and extra revenue by month ─────────────────
SELECT
    DATE_FORMAT(res.check_in_date, '%Y-%m')        AS revenue_month,
    COUNT(DISTINCT res.reservation_id)             AS completed_reservations,
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
                                                   AS room_revenue,
    COALESCE((
        SELECT SUM(ec.amount)
        FROM   extra_charges ec
        JOIN   reservations r2 ON ec.reservation_id = r2.reservation_id
        WHERE  DATE_FORMAT(r2.check_in_date,'%Y-%m')
               = DATE_FORMAT(res.check_in_date,'%Y-%m')
          AND  r2.reservation_status = 'completed'
    ), 0.00)                                       AS extra_revenue,
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
    + COALESCE((
        SELECT SUM(ec.amount)
        FROM   extra_charges ec
        JOIN   reservations r2 ON ec.reservation_id = r2.reservation_id
        WHERE  DATE_FORMAT(r2.check_in_date,'%Y-%m')
               = DATE_FORMAT(res.check_in_date,'%Y-%m')
          AND  r2.reservation_status = 'completed'
    ), 0.00)                                       AS total_monthly_revenue
FROM  reservations res
JOIN  reservation_rooms rr ON res.reservation_id  = rr.reservation_id
                          AND rr.unassigned_at IS NULL
WHERE  res.reservation_status = 'completed'
GROUP BY revenue_month
ORDER BY revenue_month;

-- ─── 4B. Revenue by room type ─────────────────────────────────────────────
SELECT
    rt.type_name,
    COUNT(DISTINCT res.reservation_id)             AS reservations,
    SUM(rr.booked_rate_per_night
        * DATEDIFF(res.check_out_date, res.check_in_date))
                                                   AS room_type_revenue
FROM  reservations res
JOIN  reservation_rooms rr ON res.reservation_id  = rr.reservation_id
                          AND rr.unassigned_at IS NULL
JOIN  rooms r              ON rr.room_id           = r.room_id
JOIN  room_types rt        ON r.room_type_id       = rt.room_type_id
WHERE  res.reservation_status = 'completed'
GROUP BY rt.room_type_id, rt.type_name
ORDER BY room_type_revenue DESC;

-- ─── 4C. Conflicting-rate-period detection query ─────────────────────────
-- Find any room types that somehow have overlapping rate periods
-- (should return 0 rows if trigger is working)
SELECT
    a.room_type_id,
    rt.type_name,
    a.rate_id       AS rate_a,
    a.rate_name     AS name_a,
    a.valid_from    AS from_a,
    a.valid_to      AS to_a,
    b.rate_id       AS rate_b,
    b.rate_name     AS name_b,
    b.valid_from    AS from_b,
    b.valid_to      AS to_b
FROM room_rates a
JOIN room_rates b  ON a.room_type_id = b.room_type_id
                   AND a.rate_id     < b.rate_id
                   AND a.valid_from  < b.valid_to
                   AND a.valid_to    > b.valid_from
JOIN room_types rt ON a.room_type_id = rt.room_type_id;
-- Expected: Empty result set (trigger prevents overlaps)

-- =============================================================================
-- END OF FILE 05_pricing_billing.sql
-- =============================================================================

