-- =============================================================================
-- StaySphere – FILE 06 : Indexes & Performance Analysis
-- =============================================================================
-- PURPOSE : Create composite indexes, demonstrate EXPLAIN plans, discuss
--           the leftmost-prefix principle, and analyze query behavior.
-- NOTE    : Run AFTER 01_schema_creation.sql and 02_sample_data.sql
--           Indexes in this file SUPPLEMENT those in 01_schema_creation.sql
-- =============================================================================

USE staysphere;

-- =============================================================================
-- SECTION 1 : INDEX STRATEGY EXPLANATION
-- =============================================================================
-- The project requirement specifies:
--   "reservations(room_id, check_in_date, check_out_date)"
--
-- However, room_id is stored in reservation_rooms (the bridge table),
-- NOT in reservations, because this is a multi-room-per-reservation design.
--
-- Creating an index with a column from a different table is not possible in
-- SQL.  The correct approach is:
--
--   Option A (single-room design): Store room_id in reservations directly,
--   then create the composite index as specified.
--
--   Option B (multi-room design, CHOSEN HERE): Create:
--     (a) composite index on reservation_rooms(room_id, reservation_id)
--     (b) composite index on reservations(check_in_date, check_out_date)
--   The query optimizer uses BOTH indexes via an index merge or nested-loop
--   join.  This is semantically equivalent for the availability query.
--
-- This file also creates the index on guest email for fast lookup and
-- explains why it is implemented as a UNIQUE constraint rather than a
-- plain index.
-- =============================================================================

-- =============================================================================
-- SECTION 2 : CAPTURE BASELINE EXPLAIN (BEFORE additional indexes)
-- =============================================================================

-- ─── 2A. Baseline – availability query plan ───────────────────────────────
-- NOTE: The output below is illustrative. Run in MySQL Workbench to see
--       actual numbers, which depend on your MySQL version and statistics.

EXPLAIN FORMAT=TRADITIONAL
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

-- ─── 2B. Baseline – monthly revenue query ────────────────────────────────
EXPLAIN FORMAT=TRADITIONAL
SELECT DATE_FORMAT(res.check_in_date, '%Y-%m') AS revenue_month,
       SUM(rr.booked_rate_per_night * DATEDIFF(res.check_out_date, res.check_in_date))
FROM   reservations res
JOIN   reservation_rooms rr ON res.reservation_id = rr.reservation_id
WHERE  res.reservation_status = 'completed'
GROUP BY revenue_month;

-- =============================================================================
-- SECTION 3 : CREATE INDEXES
-- =============================================================================

-- ─── 3A. Primary availability index (multi-room design) ──────────────────
-- reservation_rooms: composite on room_id + reservation_id
-- Supports: find all reservations for a given room quickly
CREATE INDEX idx_rr_room_res
    ON reservation_rooms (room_id, reservation_id);
-- Explanation:
--   Leftmost prefix: room_id alone → useful for "all bookings for room X"
--   room_id + reservation_id → useful for join to reservations table
--   The date range comes from the reservations table via the join.

-- ─── 3B. Reservations date range index ───────────────────────────────────
-- Supports overlap detection and monthly aggregation
CREATE INDEX idx_res_checkin_checkout
    ON reservations (check_in_date, check_out_date, reservation_status);
-- Explanation:
--   check_in_date alone → leftmost prefix; supports date range scans
--   check_in_date + check_out_date → narrows overlap condition
--   Adding reservation_status as a third column allows covering-index
--   reads that avoid touching the table for status filters.
-- Leftmost-prefix note:
--   A query filtering only on check_out_date (without check_in_date)
--   CANNOT use this index efficiently because check_out_date is not
--   the leftmost column.  Such a query would trigger a full index scan
--   or table scan.

-- ─── 3C. Guest email – UNIQUE vs plain INDEX ─────────────────────────────
-- Already created as UNIQUE constraint in 01_schema_creation.sql.
-- A UNIQUE constraint creates an implicit B-tree index; we do NOT add
-- a redundant plain index.
--
-- Why UNIQUE instead of plain INDEX?
--   1. Enforces business rule: no two guests share the same email.
--   2. Provides fast O(log n) lookup for login/search operations.
--   3. A plain INDEX would allow duplicate emails, compromising data
--      integrity.  The UNIQUE constraint combines integrity + performance.
--
-- Verify the index exists:
SHOW INDEX FROM guests WHERE Column_name = 'email';

-- ─── 3D. Extra charges lookup index ──────────────────────────────────────
CREATE INDEX idx_ec_res_date
    ON extra_charges (reservation_id, charge_date);
-- Supports billing queries that aggregate charges per reservation.

-- ─── 3E. Room assignment history index ───────────────────────────────────
CREATE INDEX idx_rah_res_action
    ON room_assignment_history (reservation_id, action_at);

-- =============================================================================
-- SECTION 4 : POST-INDEX EXPLAIN
-- =============================================================================

-- ─── 4A. Post-index – availability query ─────────────────────────────────
EXPLAIN FORMAT=TRADITIONAL
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
-- Post-index expected improvements:
--   reservations table: type=range on idx_res_checkin_checkout (key_len ↑)
--   reservation_rooms : type=ref  on idx_rr_room_res
--   Estimated rows scanned ↓ significantly

-- ─── 4B. EXPLAIN ANALYZE (MySQL 8.0.18+) ────────────────────────────────
-- EXPLAIN ANALYZE runs the query and provides actual row counts + timing.
-- Comment out if your version < 8.0.18
EXPLAIN ANALYZE
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

-- ─── 4C. Post-index – monthly revenue ────────────────────────────────────
EXPLAIN FORMAT=TRADITIONAL
SELECT DATE_FORMAT(res.check_in_date, '%Y-%m') AS revenue_month,
       SUM(rr.booked_rate_per_night * DATEDIFF(res.check_out_date, res.check_in_date))
FROM   reservations res
JOIN   reservation_rooms rr ON res.reservation_id = rr.reservation_id
WHERE  res.reservation_status = 'completed'
GROUP BY revenue_month;
-- Post-index: reservations uses idx_res_checkin_checkout (status in 3rd col);
-- reservation_rooms uses PRIMARY or idx_rr_room_res; row scans ↓

-- ─── 4D. Guest email search – index usage ────────────────────────────────
EXPLAIN FORMAT=TRADITIONAL
SELECT guest_id, first_name, last_name, loyalty_points
FROM   guests
WHERE  email = 'rajan.iyer@email.com';
-- Expected: type=const, key=uq_guests_email (unique scan, rows=1)

-- =============================================================================
-- SECTION 5 : EXPLAIN FIELD-BY-FIELD ANALYSIS GUIDE
-- =============================================================================
-- The following table maps EXPLAIN output fields to their meanings.
-- This is instructional text (SQL comment); reference it during viva.
--
-- FIELD           MEANING
-- id              Query block number; subqueries get higher ids
-- select_type     SIMPLE / PRIMARY / SUBQUERY / DEPENDENT SUBQUERY / UNION
-- table           Table being accessed
-- partitions      Matched partitions (NULL if no partitioning)
-- type            Access method (best to worst):
--                   system > const > eq_ref > ref > range > index > ALL
-- possible_keys   Indexes MySQL considered
-- key             Index MySQL actually chose
-- key_len         Bytes of the index MySQL uses (longer = more columns used)
-- ref             Column or constant compared to the index
-- rows            Estimated rows MySQL expects to examine
-- filtered        % of rows remaining after WHERE filtering
-- Extra           Additional notes:
--                   "Using index"        → covering index (no table access)
--                   "Using where"        → WHERE applied after index read
--                   "Using filesort"     → ORDER BY cannot use index
--                   "Using temporary"    → temporary table for GROUP BY
--                   "Using index condition" → Index Condition Pushdown (ICP)

-- =============================================================================
-- SECTION 6 : LEFTMOST-PREFIX PRINCIPLE DEMONSTRATION
-- =============================================================================

-- Index: idx_res_checkin_checkout (check_in_date, check_out_date, reservation_status)

-- ─── 6A. Full prefix – can use index ─────────────────────────────────────
EXPLAIN FORMAT=TRADITIONAL
SELECT reservation_id FROM reservations
WHERE  check_in_date   BETWEEN '2025-04-01' AND '2025-06-30'
  AND  check_out_date  > '2025-04-01'
  AND  reservation_status = 'completed';
-- Expected: type=range, key=idx_res_checkin_checkout, key_len covers 3 cols

-- ─── 6B. Middle column only – leftmost column MISSING → full index scan ──
EXPLAIN FORMAT=TRADITIONAL
SELECT reservation_id FROM reservations
WHERE  check_out_date = '2025-06-05';
-- Expected: type=index or ALL (check_out_date is 2nd column; index not useful
-- for a range on the 2nd column without filtering the 1st column first).
-- MySQL may still use the index for full index scan but it's not efficient.

-- ─── 6C. Only leftmost column – partial range ────────────────────────────
EXPLAIN FORMAT=TRADITIONAL
SELECT reservation_id FROM reservations
WHERE  check_in_date BETWEEN '2025-07-01' AND '2025-09-30';
-- Expected: type=range, key=idx_res_checkin_checkout, partial prefix (1 col)

-- =============================================================================
-- SECTION 7 : INDEX MAINTENANCE COST DISCUSSION
-- =============================================================================
-- (Instructional — illustrative statements with commentary)
--
-- READ benefit  : Index allows B-tree lookup in O(log n) vs O(n) table scan.
--                 Availability queries, billing queries, and guest searches
--                 all benefit significantly.
--
-- WRITE cost    : Every INSERT/UPDATE/DELETE on indexed columns must update
--                 the B-tree structure.  For a hotel with heavy booking
--                 activity, reservation_rooms inserts (at check-in) incur
--                 index maintenance overhead on idx_rr_room_res.
--
-- Trade-off guidance:
--   – Keep indexes on high-selectivity columns (email, room_id + dates).
--   – Remove redundant indexes (e.g., do NOT duplicate the UNIQUE key
--     on email with a separate plain index).
--   – Monitor with SHOW INDEX ... and INFORMATION_SCHEMA.STATISTICS.
--   – Use ANALYZE TABLE periodically to refresh index statistics.

ANALYZE TABLE reservations;
ANALYZE TABLE reservation_rooms;
ANALYZE TABLE guests;

-- =============================================================================
-- SECTION 8 : ALL CURRENT INDEXES ON KEY TABLES
-- =============================================================================
SHOW INDEX FROM reservations;
SHOW INDEX FROM reservation_rooms;
SHOW INDEX FROM guests;
SHOW INDEX FROM room_rates;
SHOW INDEX FROM extra_charges;

-- =============================================================================
-- END OF FILE 06_indexes_performance.sql
-- =============================================================================

