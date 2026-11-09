# StaySphere – Complete Project Report

## An Intelligent Hotel Reservation, Dynamic Pricing & Revenue Analytics System

---

## 1. Project Title and Abstract

**Title:** StaySphere: An Intelligent Hotel Reservation, Dynamic Pricing & Revenue Analytics System

**Technology Stack:** MySQL 8.0+, InnoDB engine, MySQL Workbench

**Abstract:**
StaySphere is a normalized, fully-executable relational database system that models the complete operational and analytical needs of a modern hotel. The system handles multi-room reservations, date-based dynamic pricing, concurrency-safe booking, per-night billing, and rich revenue analytics. The design demonstrates database normalization through 3NF, enforces referential integrity with foreign keys and triggers, prevents double bookings through transactional locking, and delivers business intelligence through SQL window functions. Three original enhancements — a reservation audit trail, revenue profitability reports, and guest repeat-visit analysis — distinguish this project from basic hotel management schemas.

---

## 2. Problem Statement

Hotel management systems face several real database challenges that a naive design fails to address:

1. **Double booking** — Two guests booking the same room for the same dates simultaneously.
2. **Pricing accuracy** — A guest booked at a promotional rate should not be re-billed at a later, higher rate.
3. **Complex availability** — A room under maintenance must not appear available even if no reservation exists.
4. **Revenue blind spots** — Management needs monthly trends, room-type profitability, and guest lifetime value without running slow full-table scans.
5. **Audit compliance** — Every status change to a reservation must be logged immutably for dispute resolution.

StaySphere solves all five problems through careful schema design, transactional integrity, and analytical SQL.

---

## 3. Objectives

1. Design a **3NF-normalized relational schema** with 9 tables covering all hotel entities.
2. Implement **complete CRUD** for all entities with constraint-violation examples.
3. Provide a **concurrency-safe booking engine** using InnoDB transactions and `SELECT … FOR UPDATE`.
4. Support **date-based dynamic pricing** with historical rate preservation.
5. Create **composite indexes** and demonstrate query plan improvements with `EXPLAIN` / `EXPLAIN ANALYZE`.
6. Implement **three views** including one with `WITH CHECK OPTION`.
7. Apply **role-based access control** with `GRANT` statements.
8. Deliver **four window-function analyses**: `RANK()`, cumulative `SUM()`, `LAG()`, and `NTILE(4)`.
9. Build a **14-test test suite** covering all boundary conditions.
10. Add **three original enhancements**: audit trail, revenue growth reports, repeat-visit analysis.

---

## 4. Scope and Assumptions

**In scope:**
- Guest registration and management
- Room type categorization and physical room inventory
- Multi-room, multi-guest reservation lifecycle
- Date-range nightly rates with seasonal variation
- Extra charges (food, spa, transport, etc.)
- Room assignment and reassignment history
- Revenue and billing analytics

**Out of scope:**
- Front-end application layer
- Payment gateway integration
- Employee/HR management
- Housekeeping scheduling
- Mobile check-in

**Assumptions:**
- Checkout date is the last exclusive day (a 3-night stay checking in Jan 10 checks out Jan 13; Jan 13 is not an occupied night).
- A room may be booked by only one active reservation at a time.
- `pending` reservations expire after 30 minutes if not confirmed.
- Rates are always in Indian Rupees (INR).
- All monetary amounts use `DECIMAL(10,2)` for precision.

---

## 5. Functional and Non-Functional Requirements

### Functional Requirements
| ID | Requirement |
|----|-------------|
| FR1 | Register, update, and retrieve guest profiles with unique email enforcement |
| FR2 | Define room types with capacity and amenities |
| FR3 | Manage physical rooms with status (available, maintenance, etc.) |
| FR4 | Create, confirm, check-in, and cancel reservations |
| FR5 | Assign multiple rooms to one reservation |
| FR6 | Store date-range nightly rates per room type (no overlaps) |
| FR7 | Prevent double bookings under concurrent load |
| FR8 | Record itemized extra charges per reservation |
| FR9 | Maintain immutable room assignment history |
| FR10 | Calculate accurate per-night billing across rate boundaries |
| FR11 | Generate monthly revenue reports by room type |
| FR12 | Analyze guest repeat-visit patterns |

### Non-Functional Requirements
| ID | Requirement |
|----|-------------|
| NFR1 | All critical booking operations complete within a single ACID transaction |
| NFR2 | Index coverage reduces availability query cost from `ALL` to `range` |
| NFR3 | UNIQUE constraint on email prevents duplicate guest records |
| NFR4 | `WITH CHECK OPTION` enforces view-level data validity |
| NFR5 | `DECIMAL(10,2)` ensures monetary precision without floating-point errors |
| NFR6 | Triggers automatically log every reservation status change |

---

## 6. System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    MySQL 8.0+ (InnoDB)                  │
│                                                         │
│  ┌──────────┐   ┌──────────┐   ┌──────────────────┐    │
│  │  guests  │   │room_types│   │    room_rates     │    │
│  └────┬─────┘   └────┬─────┘   └────────┬─────────┘    │
│       │              │                  │              │
│  ┌────▼─────────────▼───────┐          │              │
│  │        rooms              │◄─────────┘              │
│  └─────────────┬─────────────┘                         │
│                │                                        │
│  ┌─────────────▼──────────────┐                        │
│  │        reservations        │                        │
│  └──┬─────────────────────────┘                        │
│     │                                                   │
│  ┌──▼──────────────────┐  ┌─────────────────────┐      │
│  │  reservation_rooms  │  │   extra_charges      │      │
│  └──┬──────────────────┘  └─────────────────────┘      │
│     │                                                   │
│  ┌──▼───────────────────┐  ┌──────────────────────┐    │
│  │room_assignment_history│  │reservation_audit_log │    │
│  └──────────────────────┘  └──────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

**File Execution Order:**
```
01_schema_creation.sql     ← Database + all tables + triggers + indexes
02_sample_data.sql         ← All INSERT statements
03_crud_operations.sql     ← CRUD demonstration
04_availability_transactions.sql ← Booking engine
05_pricing_billing.sql     ← Billing calculations
06_indexes_performance.sql ← EXPLAIN analysis
07_views_security.sql      ← Views + GRANT
08_window_functions.sql    ← Analytics
09_test_cases.sql          ← Test suite
10_stored_procedures.sql   ← Procedures + enhancements
```

---

## 7. ER Diagram Specification

### Entities and Attributes

| Entity | Primary Key | Key Attributes |
|--------|-------------|----------------|
| guests | guest_id | email (CK), national_id (CK), first_name, last_name, loyalty_points |
| room_types | room_type_id | type_name (CK), max_capacity, base_rate |
| rooms | room_id | room_number (CK), room_type_id (FK), floor_number, room_status |
| room_rates | rate_id | room_type_id (FK), nightly_rate, valid_from, valid_to |
| reservations | reservation_id | guest_id (FK), check_in_date, check_out_date, reservation_status |
| reservation_rooms | (reservation_id, room_id) | booked_rate_per_night |
| extra_charges | charge_id | reservation_id (FK), charge_category, amount |
| room_assignment_history | history_id | reservation_id (FK), room_id (FK), action |
| reservation_audit_log | audit_id | reservation_id (FK), old_status, new_status |

### Relationships and Cardinalities

```
guests       ||──o{ reservations               (1 guest → many reservations)
room_types   ||──o{ rooms                      (1 type → many rooms)
room_types   ||──o{ room_rates                 (1 type → many rate periods)
reservations ||──o{ reservation_rooms           (1 reservation → many rooms)
rooms        ||──o{ reservation_rooms           (1 room → many reservations over time)
reservations ||──o{ extra_charges               (1 reservation → many charges)
reservations ||──o{ room_assignment_history     (1 reservation → many history rows)
rooms        ||──o{ room_assignment_history     (1 room → many history events)
reservations ||──o{ reservation_audit_log       (1 reservation → many audit entries)
```

**Participation constraints:**
- A reservation MUST have at least one room assigned (total participation on reservation_rooms from reservations side).
- A room_rate MUST belong to exactly one room_type (total participation).
- A guest may have zero reservations (partial participation from guests side).

---

## 8. Relational Schema

```sql
guests(guest_id PK, first_name, last_name, email UQ, phone,
       national_id UQ, date_of_birth, address, city, country,
       loyalty_points, created_at, updated_at)

room_types(room_type_id PK, type_name UQ, max_capacity,
           description, amenities, base_rate)

rooms(room_id PK, room_number UQ, room_type_id FK→room_types,
      floor_number, room_status, smoking, notes)

room_rates(rate_id PK, room_type_id FK→room_types, rate_name,
           nightly_rate, valid_from, valid_to)
  CONSTRAINT: valid_to > valid_from
  TRIGGER: no overlapping periods for same room_type_id

reservations(reservation_id PK, guest_id FK→guests,
             check_in_date, check_out_date, num_guests,
             reservation_status, booked_rate_per_night,
             special_requests, created_at, confirmed_at, cancelled_at,
             cancellation_reason)
  CONSTRAINT: check_out_date > check_in_date

reservation_rooms(reservation_id FK→reservations, room_id FK→rooms,
                  booked_rate_per_night, assigned_at, unassigned_at)
  PK: (reservation_id, room_id)

extra_charges(charge_id PK, reservation_id FK→reservations,
              charge_category, description, amount, charge_date)
  CONSTRAINT: amount > 0

room_assignment_history(history_id PK, reservation_id FK→reservations,
                        room_id FK→rooms, action, action_reason,
                        action_by, action_at)

reservation_audit_log(audit_id PK, reservation_id FK→reservations,
                      old_status, new_status, changed_by, changed_at)
```

---

## 9. Normalization Explanation

### 1NF (First Normal Form)
**Rule:** Every column must be atomic; no repeating groups.

**Violation avoided:** A naïve design might store extra charges as `extra_charges_json TEXT` in the reservations table (e.g., `[{"type":"food","amount":850}]`). This is not atomic and makes querying impossible without string parsing.

**Our solution:** The `extra_charges` table stores one charge per row. Each row is atomic — one category, one description, one amount, one date.

### 2NF (Second Normal Form)
**Rule:** No partial dependencies on a composite primary key.

**Violation avoided:** If we used `(reservation_id, room_id)` as the PK of `reservations` and stored `guest_name` in that table, `guest_name` would depend only on the reservation, not on the room — a partial dependency.

**Our solution:** `reservations` has a single-column surrogate PK (`reservation_id`). Room assignments live in `reservation_rooms`. `booked_rate_per_night` in `reservation_rooms` depends on the full composite PK `(reservation_id, room_id)` — the rate can differ per room within the same reservation — so there is no partial dependency.

### 3NF (Third Normal Form)
**Rule:** No transitive dependencies (non-key attribute depending on another non-key attribute).

**Violation avoided:** If `reservations` stored `room_type_name` and `room_max_capacity`, these would depend on `room_type_id` (a non-key attribute), not on `reservation_id`. This is a transitive dependency: `reservation_id → room_type_id → room_type_name`.

**Our solution:** Room type details live in `room_types`. `rooms` references `room_types` by FK. `reservation_rooms` references `rooms`. Type name and capacity are never duplicated in reservation rows.

**Update anomaly prevented:** If the room type name changes from "Deluxe Double" to "Deluxe King", only one row in `room_types` needs updating. In a denormalized design, hundreds of reservation rows would need updating — and missing one would cause inconsistency.

---

## 10. SQL Schema Creation Script

→ See [`01_schema_creation.sql`](01_schema_creation.sql)

Key design decisions documented inline:
- `room_status` vs. reservation availability distinction
- Trigger-enforced rate non-overlap
- Composite PK on `reservation_rooms`
- Audit trigger on `reservations`

---

## 11. Sample Data Insertion Script

→ See [`02_sample_data.sql`](02_sample_data.sql)

Dataset covers:
- 12 guests across 8 Indian cities
- 5 room types (Standard Single → Presidential Suite)
- 15 physical rooms across 5 floors
- 20 room rates (4 seasonal per type)
- 20 reservations: completed, confirmed, cancelled, pending
- 22 reservation-room assignments (including 2-room multi-room booking)
- 27 extra charges
- 22 assignment history events

---

## 12. CRUD Implementation

→ See [`03_crud_operations.sql`](03_crud_operations.sql)

| Operation | Example |
|-----------|---------|
| INSERT | New guest, new room type, new reservation, extra charge |
| SELECT | Guest list, room availability, billing summary, active rates |
| UPDATE | Guest contact, reservation status, room to maintenance |
| DELETE | Safe deletion chain respecting FK constraints |
| Constraint violations | Duplicate email, invalid dates, FK violation, negative charge |

---

## 13. Reservation & Availability Queries

→ See [`04_availability_transactions.sql`](04_availability_transactions.sql)

### Date Overlap Rule
```sql
-- Overlap exists when BOTH conditions are TRUE:
existing_check_in  < requested_check_out
AND
existing_check_out > requested_check_in
```

**Same-day adjacent bookings** (checkout day = next guest's check-in day) do NOT overlap because `existing_check_out > requested_check_in` evaluates to `date = date` which is `FALSE` with strict `>`.

---

## 14. Transaction and Concurrency Control

→ See [`04_availability_transactions.sql`](04_availability_transactions.sql) — Section 3

### Locking Protocol

```
Session A                          Session B
─────────────────────────────────  ─────────────────────────────────
START TRANSACTION
SELECT room_id ... FOR UPDATE ──→  (Session B blocks here if
                                    trying same room)
Check availability (count=0)
INSERT reservation
INSERT reservation_rooms
COMMIT ──────────────────────────→ Session B unblocks
                                   SELECT ... FOR UPDATE (now held)
                                   Check availability (count=1)
                                   ROLLBACK (conflict found)
```

**InnoDB guarantees:** `FOR UPDATE` places an exclusive row lock. Under `REPEATABLE READ` isolation (default), gap locks on index ranges also prevent phantom inserts between the check and the insert.

---

## 15. Pricing and Billing Queries

→ See [`05_pricing_billing.sql`](05_pricing_billing.sql)

### Rate Resolution
At booking time, the stored procedure looks up the rate active on the check-in date:
```sql
SELECT nightly_rate FROM room_rates
WHERE room_type_id = v_room_type_id
  AND valid_from <= p_check_in
  AND valid_to   >= p_check_in
LIMIT 1;
```
This rate is stored in `reservation_rooms.booked_rate_per_night` and never changes.

### Billing Formula
```
Room Charges   = SUM(booked_rate_per_night × nights) per room
Extra Charges  = SUM(amount) from extra_charges for the reservation
Total Bill     = Room Charges + Extra Charges
```

**Multi-room anti-double-counting:** Extra charges are aggregated once per reservation (via correlated subquery), not multiplied by the number of rooms.

---

## 16. Index Creation and Execution Plan Comparison

→ See [`06_indexes_performance.sql`](06_indexes_performance.sql)

### Index Summary

| Index | Table | Columns | Purpose |
|-------|-------|---------|---------|
| uq_guests_email | guests | email | Unique; integrity + fast lookup |
| idx_rr_room_res | reservation_rooms | room_id, reservation_id | Availability join |
| idx_res_checkin_checkout | reservations | check_in_date, check_out_date, reservation_status | Date range + status filter |
| idx_room_rates_type_date | room_rates | room_type_id, valid_from, valid_to | Rate lookup |
| idx_ec_res_date | extra_charges | reservation_id, charge_date | Billing aggregation |

### Leftmost-Prefix Principle
For `idx_res_checkin_checkout(check_in_date, check_out_date, reservation_status)`:
- Query filtering on `check_in_date` alone → uses index (leftmost)
- Query filtering on `check_in_date AND check_out_date` → uses more of the index
- Query filtering on `check_out_date` alone (no `check_in_date`) → cannot use this index efficiently

### EXPLAIN Type Progression
```
Before index: type=ALL  (full table scan, ~20 rows)
After index:  type=range on idx_res_checkin_checkout
              type=ref  on idx_rr_room_res
```

---

## 17. Views and WITH CHECK OPTION

→ See [`07_views_security.sql`](07_views_security.sql)

| View | Purpose |
|------|---------|
| `vw_room_availability` | All rooms with current booking status; caller applies date filter |
| `vw_guest_billing_summary` | Full bill per reservation (nights, room charges, extras, total) |
| `vw_frontdesk` | Minimal guest+booking data for front-desk staff |
| `vw_pending_reservations` | Updatable view with `WITH CHECK OPTION` |

### WITH CHECK OPTION Demonstration
```sql
-- VALID: stays within the view's WHERE (status = 'pending')
UPDATE vw_pending_reservations SET special_requests = 'Late check-in' WHERE reservation_id = 18;
-- ✓ Succeeds

-- INVALID: changes status to 'confirmed' — row would leave the view's filter
UPDATE vw_pending_reservations SET reservation_status = 'confirmed' WHERE reservation_id = 18;
-- ✗ ERROR 1369: CHECK OPTION failed 'staysphere.vw_pending_reservations'
```

---

## 18. GRANT Statements and Access Control

→ See [`07_views_security.sql`](07_views_security.sql) — Section 5

| User | Access |
|------|--------|
| `frontdesk_user` | SELECT on vw_frontdesk, vw_room_availability; INSERT on reservations; UPDATE limited columns |
| `manager_user` | Full SELECT + rate management + reservation management |
| `analyst_user` | SELECT on billing/availability views and non-PII tables only |

**Column-level restriction:** Views hide columns (e.g., `national_id`, `date_of_birth`) when users have no direct table access. This requires revoking direct table grants and granting only view access.

---

## 19. Window Function Analytics

→ See [`08_window_functions.sql`](08_window_functions.sql)

### A. RANK() — Room Type Monthly Revenue Ranking
```sql
RANK() OVER (PARTITION BY revenue_month ORDER BY room_revenue DESC)
```
Equal revenues in the same month receive the same rank; the next rank is skipped.

### B. SUM() OVER() — Cumulative Revenue
```sql
SUM(total_revenue) OVER (ORDER BY revenue_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
```
Builds a running total across all months in chronological order.

### C. LAG() — Gap Between Guest Stays
```sql
DATEDIFF(check_in_date, LAG(check_out_date, 1) OVER (PARTITION BY guest_id ORDER BY check_in_date))
```
Calculates days between consecutive stays per guest. First stay returns NULL (no previous stay).

### D. NTILE(4) — Guest Spending Tier
```sql
NTILE(4) OVER (ORDER BY total_spending ASC)
```
Divides guests into four relative quartiles (Bronze → Platinum). These are relative rankings, not absolute thresholds.

---

## 20. Test Cases and Expected Results

→ See [`09_test_cases.sql`](09_test_cases.sql)

| # | Test | Expected Result |
|---|------|----------------|
| 1 | Successful reservation creation | PASS — reservation_id assigned |
| 2 | Invalid date range (checkout = checkin) | FAIL — ERROR 3819 CHECK constraint |
| 3 | Overlapping booking attempt | conflict_count = 1 → booking rejected |
| 4 | Concurrent booking conflict | Transaction 2 rolls back after T1 commits |
| 5 | Cancelled reservation availability | PASS — cancelled res does not block |
| 6 | Maintenance room blocked | PASS — room_id 3 not in bookable list |
| 7 | Duplicate email | FAIL — ERROR 1062 UNIQUE constraint |
| 8 | Invalid view update (WITH CHECK OPTION) | FAIL — ERROR 1369 CHECK OPTION |
| 9 | Multi-rate billing accuracy | nights=4, room=48000, extra=8800, total=56800 |
| 10 | Guest with no stays | 0 reservations, 0 revenue |
| 11 | Adjacent reservations | conflict_count = 0 → allowed |
| 12 | Rate overlap prevention | FAIL — ERROR 45000 trigger |
| 13 | FK cascade and restriction | FAIL — ERROR 1451 RESTRICT |
| 14 | Multi-room double-count prevention | extra charges counted once |

---

## 21. Query Outputs and Demonstration Instructions

### Running the project in MySQL Workbench

1. Open MySQL Workbench and connect to your MySQL 8.0+ instance.
2. Open each SQL file using **File → Open SQL Script**.
3. Execute in this exact order:
   ```
   01_schema_creation.sql
   02_sample_data.sql
   03_crud_operations.sql
   04_availability_transactions.sql
   05_pricing_billing.sql
   06_indexes_performance.sql
   07_views_security.sql
   08_window_functions.sql
   09_test_cases.sql
   10_stored_procedures.sql
   ```
4. Or run all at once via command line:
   ```bash
   mysql -u root -p < 01_schema_creation.sql
   mysql -u root -p staysphere < 02_sample_data.sql
   # ... (repeat for each file)
   ```

### Key demonstrations
- **Availability query:** Run Section 2 of `04_availability_transactions.sql` and vary the date parameters.
- **EXPLAIN comparison:** Run Sections 2 and 4 of `06_indexes_performance.sql` to see before/after plans.
- **Window functions:** Run all four sections of `08_window_functions.sql` and observe `RANK()` ties.
- **Concurrency test:** Open two MySQL Workbench connections and run Transactions 1 and 2 from Section 3 of `04_availability_transactions.sql` simultaneously.

---

## 22. Limitations and Future Enhancements

### Current Limitations
1. The rate-overlap trigger uses `BEFORE INSERT` only; a separate trigger or procedure should handle `UPDATE` on `room_rates`.
2. The `pending` reservation expiry (30 minutes) is enforced in application queries, not by a MySQL Event (which would require the Event Scheduler to be enabled).
3. Column-level restriction through views is bypassable if the user has direct table grants; application-level authentication provides a stronger enforcement layer.
4. Sample data covers 2025; window-function queries will produce sparse results for future years until new data is added.
5. No partitioning is implemented; for large hotels (millions of rows), partitioning `reservations` by year would improve query performance.

### Future Enhancements
1. **MySQL Event Scheduler** to auto-cancel expired `pending` reservations.
2. **Partitioning** on `reservations(check_in_date)` for time-series performance.
3. **Full-text search** on `special_requests` and `notes` columns.
4. **Overbooking model** — allow a configurable buffer of extra bookings per room type with automatic waitlist management.
5. **Loyalty program engine** — automatically calculate and award loyalty points at checkout using a stored procedure.
6. **Real-time occupancy dashboard** — a view showing current day's checked-in rooms, today's arrivals, and today's departures.

---

## 23. Conclusion

StaySphere demonstrates every core DBMS concept required for a university project:

- **Schema design:** 9-table 3NF-normalized schema with clear entity relationships
- **Integrity:** Primary keys, foreign keys, UNIQUE constraints, CHECK constraints, and triggers
- **CRUD:** Complete operations across all entities with documented failure cases
- **Concurrency:** InnoDB `SELECT … FOR UPDATE` transaction protocol prevents double bookings
- **Dynamic pricing:** Date-range rates, historical rate preservation, multi-rate billing
- **Performance:** Composite indexes, `EXPLAIN`/`EXPLAIN ANALYZE`, leftmost-prefix analysis
- **Security:** Views, `WITH CHECK OPTION`, `GRANT`/`REVOKE` for three user roles
- **Analytics:** `RANK()`, `SUM() OVER()`, `LAG()`, and `NTILE(4)` window functions

The three original enhancements (audit trail, revenue growth reports, repeat-visit analysis) elevate the project beyond a basic hotel management schema into a genuine revenue intelligence system.

---

## 24. Viva Questions and Accurate Answers

**Q1. Why use InnoDB instead of MyISAM?**
> InnoDB supports ACID transactions, row-level locking, foreign key constraints, and MVCC (Multi-Version Concurrency Control). MyISAM offers none of these, making it unsuitable for a transactional booking system.

**Q2. Explain the date-overlap rule. Why is strict `>` used?**
> Two reservations overlap when `existing_check_in < requested_check_out AND existing_check_out > requested_check_in`. Strict `>` (not `>=`) means checkout on the same day as another guest's check-in does not constitute overlap — the room is physically free on that day.

**Q3. What is the leftmost-prefix principle?**
> For a composite index `(A, B, C)`, MySQL can use the index for queries filtering on `A`, `A AND B`, or `A AND B AND C`. It cannot use the index efficiently for queries filtering only on `B` or `C` because the B-tree is sorted first by A.

**Q4. What does `WITH CHECK OPTION` do?**
> It prevents INSERT or UPDATE through a view from producing rows that the view's own `WHERE` clause would exclude. It does not replace table constraints or GRANT permissions — it only guards the view's filter.

**Q5. How does `SELECT … FOR UPDATE` prevent double booking?**
> It places an exclusive row lock on the rooms row within the transaction. Any concurrent transaction attempting `SELECT … FOR UPDATE` on the same row must wait until the first transaction commits or rolls back, ensuring only one thread can check availability and insert a reservation for a given room at a time.

**Q6. What is the difference between `RANK()` and `DENSE_RANK()`?**
> Both assign the same rank to tied rows. `RANK()` skips the next rank after a tie (1, 1, 3), while `DENSE_RANK()` does not skip (1, 1, 2).

**Q7. Why is `booked_rate_per_night` stored in `reservation_rooms` instead of looked up from `room_rates`?**
> For historical rate preservation. If a guest books at ₹9,500/night and the rate later changes to ₹12,000, billing must use the original agreed rate. The `booked_rate_per_night` column is set at booking time and is immutable.

**Q8. How does `NTILE(4)` distribute guests with equal spending?**
> `NTILE` distributes rows by position, not value. Tied guests are assigned to different buckets based on their row ordering. This means two guests with identical spending may appear in different tiers — a known limitation of `NTILE`. `PERCENT_RANK()` would give identical results for equal values.

**Q9. Why is the guest email a UNIQUE constraint instead of a plain INDEX?**
> A UNIQUE constraint both enforces data integrity (no two guests can share an email) AND creates a B-tree index for fast `O(log n)` lookups. A plain index would allow duplicates, violating the business rule that email is a unique identifier for a guest.

**Q10. What is 3NF and give an example from this schema?**
> Third Normal Form requires that every non-key attribute depends only on the primary key, not on another non-key attribute (no transitive dependencies). Example: `room_type_name` is not stored in `reservations` because it would depend on `room_type_id` (a non-key attribute), not on `reservation_id`. Instead, `rooms.room_type_id` references `room_types`, and the name is retrieved via a JOIN.

**Q11. What happens to a `FOR UPDATE` lock if the transaction is rolled back?**
> The lock is released immediately on `ROLLBACK`. Any waiting transaction can then acquire the lock and proceed. This is why the second concurrent booking attempt in Section 3 of `04_availability_transactions.sql` will correctly find the conflict only after Transaction 1 commits.

**Q12. Explain how the view-based access control works for `frontdesk_user`.**
> `frontdesk_user` is granted SELECT only on `vw_frontdesk` and `vw_room_availability`, not on the underlying `guests` table. When querying through the view, MySQL evaluates the view with the definer's privileges (SQL SECURITY DEFINER is the default), so the query succeeds. But if `frontdesk_user` tries `SELECT * FROM guests` directly, it gets an "access denied" error because no table-level grant exists.

---

*End of StaySphere Project Report*

