-- =============================================================================
-- StaySphere – FILE 08 : Window Function Analytics
-- =============================================================================
-- PURPOSE : Four required window-function analyses:
--           A. RANK()  – room type revenue ranking per month
--           B. SUM() OVER() – cumulative monthly revenue
--           C. LAG()   – gap in days between consecutive guest stays
--           D. NTILE(4) – guest spending tier segmentation
-- NOTE    : Run AFTER 01_schema_creation.sql and 02_sample_data.sql
-- =============================================================================

USE staysphere;

-- =============================================================================
-- REVENUE DEFINITION (used consistently across all four analyses)
-- =============================================================================
-- "Room revenue"  = SUM(booked_rate_per_night × nights) per reservation-room
-- "Total revenue" = Room revenue + extra charges
-- Monthly revenue is attributed to the check_in_date month.
-- ONLY completed reservations contribute to revenue.
-- Cancelled reservations are excluded (no revenue realized).
-- Multi-room reservations: each room's revenue is counted independently;
--   extra charges are attributed once to the reservation (not per room).
-- =============================================================================

-- =============================================================================
-- A. RANK() – Room Type Monthly Revenue Ranking
-- =============================================================================
-- Business purpose:
--   Identify which room category generates the most revenue each month.
--   Management uses this to decide promotions, pricing adjustments, and
--   maintenance scheduling (avoid taking high-revenue rooms offline in peak
--   months).
--
-- PARTITION BY: revenue_month → each month is an independent ranking contest.
-- ORDER BY: room_revenue DESC → highest revenue gets RANK 1.
-- RANK() skips rank numbers after a tie (e.g., 1, 1, 3 – not 1, 1, 2).
-- DENSE_RANK() would give 1, 1, 2 for the same data.
-- =============================================================================

WITH monthly_type_revenue AS (
    SELECT
        DATE_FORMAT(res.check_in_date, '%Y-%m')  AS revenue_month,
        rt.type_name,
        SUM(rr.booked_rate_per_night
            * DATEDIFF(res.check_out_date, res.check_in_date))
                                                 AS room_revenue
    FROM  reservations res
    JOIN  reservation_rooms rr ON res.reservation_id = rr.reservation_id
                              AND rr.unassigned_at IS NULL
    JOIN  rooms r              ON rr.room_id          = r.room_id
    JOIN  room_types rt        ON r.room_type_id      = rt.room_type_id
    WHERE  res.reservation_status = 'completed'
    GROUP BY revenue_month, rt.type_name
)
SELECT
    revenue_month,
    type_name,
    room_revenue,
    RANK() OVER (
        PARTITION BY revenue_month
        ORDER BY     room_revenue DESC
    )                                            AS revenue_rank
FROM  monthly_type_revenue
ORDER BY revenue_month, revenue_rank;

-- SAMPLE INPUT (from dataset):
-- revenue_month | type_name           | room_revenue
-- 2025-01       | Standard Single     | 10500.00
-- 2025-02       | Standard Double     | 15000.00
-- 2025-04       | Deluxe Double       | 38000.00
-- 2025-04       | Executive Suite     | 54000.00
-- ...

-- EXPECTED OUTPUT SNIPPET:
-- 2025-01 | Standard Single     | 10500.00  | 1
-- 2025-02 | Standard Double     | 15000.00  | 1
-- 2025-04 | Executive Suite     | 54000.00  | 1
-- 2025-04 | Deluxe Double       | 38000.00  | 2

-- TIE HANDLING: If two room types have equal revenue in the same month,
-- both receive the same rank and the next rank is skipped.
-- Example: both 10000 → RANK 1, 1; next room gets RANK 3 (not 2).

-- MISSING MONTHS: Months with no completed reservations simply do not appear
-- (no row generated → no rank for that month). A calendar table LEFT JOIN
-- would fill gaps with 0-revenue rows if needed.

-- =============================================================================
-- B. SUM() OVER() – Cumulative Monthly Revenue
-- =============================================================================
-- Business purpose:
--   Track how the hotel's total earnings grow month-over-month throughout
--   the year.  Useful for year-end financial reporting, cash-flow analysis,
--   and revenue target monitoring.
--
-- PARTITION BY: none (cumulative across ALL months)
-- ORDER BY: revenue_month ASC (chronological order)
-- SUM() OVER() adds each month's total revenue to the running sum.
-- =============================================================================

WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(res.check_in_date, '%Y-%m')  AS revenue_month,
        -- Room revenue for the month
        SUM(rr.booked_rate_per_night
            * DATEDIFF(res.check_out_date, res.check_in_date))
                                                 AS room_revenue,
        -- Extra charges for the month
        COALESCE((
            SELECT SUM(ec.amount)
            FROM   extra_charges ec
            JOIN   reservations r2 ON ec.reservation_id = r2.reservation_id
            WHERE  DATE_FORMAT(r2.check_in_date,'%Y-%m')
                   = DATE_FORMAT(res.check_in_date,'%Y-%m')
              AND  r2.reservation_status = 'completed'
        ), 0.00)                                 AS extra_revenue
    FROM  reservations res
    JOIN  reservation_rooms rr ON res.reservation_id = rr.reservation_id
                              AND rr.unassigned_at IS NULL
    WHERE  res.reservation_status = 'completed'
    GROUP BY revenue_month
),
monthly_totals AS (
    SELECT
        revenue_month,
        room_revenue,
        extra_revenue,
        room_revenue + extra_revenue             AS total_revenue
    FROM monthly_revenue
)
SELECT
    revenue_month,
    room_revenue,
    extra_revenue,
    total_revenue,
    SUM(total_revenue) OVER (
        ORDER BY revenue_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                            AS cumulative_revenue
FROM  monthly_totals
ORDER BY revenue_month;

-- SAMPLE EXPECTED OUTPUT:
-- revenue_month | room_revenue | extra_revenue | total_revenue | cumulative_revenue
-- 2025-01       | 10500.00     | 1620.00       | 12120.00      | 12120.00
-- 2025-02       | 15000.00     | 4650.00       | 19650.00      | 31770.00
-- 2025-03       | 0.00         | 0.00          | 0.00          | 31770.00  ← cancelled res
-- 2025-04       | 129000.00    | 3800.00       | 132800.00     | 164570.00
-- ...

-- NOTE: ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW is the explicit
-- frame clause.  For ORDER BY with SUM(), MySQL uses this as the default
-- frame, but being explicit improves readability and portability.

-- NULL HANDLING: revenue_month with no rows → missing from CTE. The
-- cumulative sum skips that month with no gap in the running total.

-- =============================================================================
-- C. LAG() – Gap in Days Between Consecutive Guest Stays
-- =============================================================================
-- Business purpose:
--   Measure how long a guest stays away between visits.
--   A short gap (<30 days) may indicate a highly loyal frequent traveller.
--   A very long gap (>365 days) may be a one-time visitor or lapsed customer
--   worth a re-engagement campaign.
--   Enhancement 3 (repeat-visit analysis) uses this query.
--
-- PARTITION BY: guest_id → each guest's stays are compared independently.
-- ORDER BY: check_in_date ASC → stays in chronological order within guest.
-- LAG(check_out_date, 1) retrieves the previous stay's checkout date.
-- GAP = current check_in_date - previous check_out_date.
-- =============================================================================

WITH guest_stays AS (
    SELECT
        g.guest_id,
        CONCAT(g.first_name,' ',g.last_name)     AS guest_name,
        res.reservation_id,
        res.check_in_date,
        res.check_out_date
    FROM  guests g
    JOIN  reservations res ON g.guest_id = res.guest_id
    WHERE  res.reservation_status = 'completed'
)
SELECT
    guest_id,
    guest_name,
    reservation_id,
    check_in_date,
    check_out_date,
    -- LAG: get previous stay's checkout date for this guest
    LAG(check_out_date, 1) OVER (
        PARTITION BY guest_id
        ORDER BY     check_in_date
    )                                            AS prev_checkout,
    -- Gap in days: NULL for the first stay (no previous stay to compare)
    DATEDIFF(
        check_in_date,
        LAG(check_out_date, 1) OVER (
            PARTITION BY guest_id
            ORDER BY     check_in_date
        )
    )                                            AS gap_days_since_last_stay
FROM  guest_stays
ORDER BY guest_id, check_in_date;

-- SAMPLE EXPECTED OUTPUT:
-- guest_id | guest_name     | reservation_id | check_in | check_out | prev_checkout | gap_days
-- 1        | Arjun Sharma   | 1              | 2025-01-10 | 2025-01-13 | NULL        | NULL
-- 1        | Arjun Sharma   | 13             | 2025-11-20 | 2025-11-23 | 2025-01-13  | 311
-- 7        | Rajan Iyer     | 7              | 2025-06-01 | 2025-06-05 | NULL        | NULL
-- 7        | Rajan Iyer     | 15             | 2025-12-10 | 2025-12-13 | 2025-06-05  | 188
-- 9        | Karan Kapoor   | 9              | 2025-08-01 | 2025-08-06 | NULL        | NULL
-- 9        | Karan Kapoor   | 20             | 2025-08-15 | 2025-08-18 | 2025-08-06  | 9
-- 9        | Karan Kapoor   | 14             | 2025-12-24 | 2025-12-27 | 2025-08-18  | 128

-- NULL HANDLING: First stay per guest always has gap_days = NULL (no LAG row).
-- This is correct and expected behavior; do not filter out NULL rows —
-- they identify the guest's first stay.

-- CANCELLED STAYS: Excluded from the CTE (reservation_status = 'completed').
-- Including cancelled stays would distort the gap metric.

-- =============================================================================
-- C2. Flag unusually long gaps (Enhancement 3 – repeat-visit analysis)
-- =============================================================================
WITH guest_stays AS (
    SELECT
        g.guest_id,
        CONCAT(g.first_name,' ',g.last_name)     AS guest_name,
        res.check_in_date,
        res.check_out_date
    FROM  guests g
    JOIN  reservations res ON g.guest_id = res.guest_id
    WHERE  res.reservation_status = 'completed'
),
gaps AS (
    SELECT
        guest_id,
        guest_name,
        check_in_date,
        DATEDIFF(check_in_date,
            LAG(check_out_date) OVER (
                PARTITION BY guest_id
                ORDER BY check_in_date
            )
        ) AS gap_days
    FROM guest_stays
)
SELECT
    guest_id,
    guest_name,
    check_in_date    AS return_date,
    gap_days,
    CASE
        WHEN gap_days IS NULL      THEN 'First Stay'
        WHEN gap_days <=  30       THEN 'Frequent Visitor (≤30 days)'
        WHEN gap_days <=  90       THEN 'Regular Visitor (31-90 days)'
        WHEN gap_days <= 365       THEN 'Occasional Visitor (91-365 days)'
        ELSE                            'Lapsed Guest (>365 days)'
    END                                          AS visit_pattern
FROM gaps
ORDER BY gap_days DESC;

-- =============================================================================
-- D. NTILE(4) – Guest Spending Tier Segmentation
-- =============================================================================
-- Business purpose:
--   Divide guests into four RELATIVE spending bands based on their total
--   hotel expenditure.  This enables targeted marketing (premium offers to
--   top-tier guests, re-engagement offers to bottom-tier guests).
--
-- IMPORTANT CAVEAT: NTILE creates RELATIVE groups (quartiles based on rank
-- within this dataset).  The top-quartile label (e.g., "Platinum") does NOT
-- mean the guest has spent an objectively large amount — it just means they
-- spent more than 75% of other guests in this dataset.  Thresholds shift as
-- new guests are added.
--
-- PARTITION BY: none (single ranking across all guests)
-- ORDER BY: total_spending ASC (NTILE 1 = lowest spenders)
-- NTILE(4) divides rows into 4 approximately equal buckets.
-- =============================================================================

WITH guest_total_spending AS (
    SELECT
        g.guest_id,
        CONCAT(g.first_name,' ',g.last_name)     AS guest_name,
        g.email,
        -- Room revenue across all completed stays
        COALESCE(SUM(rr.booked_rate_per_night
            * DATEDIFF(res.check_out_date, res.check_in_date)), 0.00)
                                                 AS room_spend,
        -- Extra charges across all completed stays
        COALESCE((
            SELECT SUM(ec.amount)
            FROM   extra_charges ec
            JOIN   reservations r2 ON ec.reservation_id = r2.reservation_id
            WHERE  r2.guest_id = g.guest_id
              AND  r2.reservation_status = 'completed'
        ), 0.00)                                 AS extra_spend
    FROM  guests g
    LEFT JOIN reservations res     ON g.guest_id        = res.guest_id
                                  AND res.reservation_status = 'completed'
    LEFT JOIN reservation_rooms rr ON res.reservation_id = rr.reservation_id
                                  AND rr.unassigned_at IS NULL
    GROUP BY g.guest_id, guest_name, g.email
),
spending_with_total AS (
    SELECT
        guest_id,
        guest_name,
        email,
        room_spend,
        extra_spend,
        room_spend + extra_spend                 AS total_spending
    FROM guest_total_spending
)
SELECT
    guest_id,
    guest_name,
    email,
    room_spend,
    extra_spend,
    total_spending,
    NTILE(4) OVER (
        ORDER BY total_spending ASC
    )                                            AS spending_quartile,
    CASE NTILE(4) OVER (ORDER BY total_spending ASC)
        WHEN 1 THEN 'Bronze (Bottom 25%)'
        WHEN 2 THEN 'Silver (25–50%)'
        WHEN 3 THEN 'Gold (50–75%)'
        WHEN 4 THEN 'Platinum (Top 25%)'
    END                                          AS spending_tier_label
FROM spending_with_total
ORDER BY total_spending DESC;

-- SAMPLE EXPECTED OUTPUT (illustrative):
-- guest_id | guest_name      | total_spending  | quartile | tier
-- 7        | Rajan Iyer      | 452400.00       | 4        | Platinum (Top 25%)
-- 9        | Karan Kapoor    | 186300.00       | 4        | Platinum (Top 25%)
-- 11       | Suresh Kumar    | 56800.00        | 3        | Gold (50–75%)
-- ...
-- 6        | Anjali Nair     | 12600.00        | 1        | Bronze (Bottom 25%)

-- TIE HANDLING: If two guests have equal total_spending, NTILE assigns
-- them to different buckets (it distributes rows by position, not value).
-- This means tied guests may end up in different tiers — a known
-- limitation of NTILE.  Use PERCENT_RANK() for value-based percentile.

-- GUESTS WITH NO COMPLETED STAYS: total_spending = 0 (LEFT JOIN + COALESCE).
-- They appear in the Bronze tier unless removed with a HAVING clause.
-- Including zero-spend guests is intentional: they represent potential
-- customers to re-engage.

-- =============================================================================
-- E. BONUS: DENSE_RANK() – Room Profitability Per Month
-- =============================================================================
-- Shows how DENSE_RANK() differs from RANK() with equal values.

WITH room_monthly AS (
    SELECT
        DATE_FORMAT(res.check_in_date,'%Y-%m')   AS revenue_month,
        rt.type_name,
        SUM(rr.booked_rate_per_night
            * DATEDIFF(res.check_out_date,res.check_in_date))
                                                 AS room_revenue
    FROM reservations res
    JOIN reservation_rooms rr ON res.reservation_id = rr.reservation_id
                              AND rr.unassigned_at IS NULL
    JOIN rooms r              ON rr.room_id = r.room_id
    JOIN room_types rt        ON r.room_type_id = rt.room_type_id
    WHERE res.reservation_status = 'completed'
    GROUP BY revenue_month, rt.type_name
)
SELECT
    revenue_month,
    type_name,
    room_revenue,
    RANK()       OVER (PARTITION BY revenue_month ORDER BY room_revenue DESC) AS rank_val,
    DENSE_RANK() OVER (PARTITION BY revenue_month ORDER BY room_revenue DESC) AS dense_rank_val
FROM room_monthly
ORDER BY revenue_month, rank_val;
-- Observe: When two type_names have equal room_revenue in the same month,
-- RANK() skips the next rank; DENSE_RANK() does not.

-- =============================================================================
-- END OF FILE 08_window_functions.sql
-- =============================================================================

