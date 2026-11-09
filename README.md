# StaySphere – Hotel Reservation System

## Quick Start Guide

---

### Prerequisites

- **MySQL 8.0+** (InnoDB, `WITH RECURSIVE`, `EXPLAIN ANALYZE`, window functions all require 8.0)
- **MySQL Workbench** (recommended) or any MySQL client

---

### Execution Order

Run the files **strictly in this order**:

```bash
# Via command line (replace -p with your password):
mysql -u root -p < 01_schema_creation.sql
mysql -u root -p staysphere < 02_sample_data.sql
mysql -u root -p staysphere < 03_crud_operations.sql
mysql -u root -p staysphere < 04_availability_transactions.sql
mysql -u root -p staysphere < 05_pricing_billing.sql
mysql -u root -p staysphere < 06_indexes_performance.sql
mysql -u root -p staysphere < 07_views_security.sql
mysql -u root -p staysphere < 08_window_functions.sql
mysql -u root -p staysphere < 09_test_cases.sql
mysql -u root -p staysphere < 10_stored_procedures.sql
```

Or in MySQL Workbench:
1. **File → Open SQL Script** → select file
2. Click the ⚡ (Execute All) button
3. Repeat for each file in order

---

### File Contents

| File | Contents |
|------|----------|
| `01_schema_creation.sql` | Database, 9 tables, 3 triggers, base indexes |
| `02_sample_data.sql` | 12 guests, 15 rooms, 20 reservations, 27 charges |
| `03_crud_operations.sql` | INSERT / SELECT / UPDATE / DELETE with constraint tests |
| `04_availability_transactions.sql` | Overlap rule, availability queries, FOR UPDATE locking |
| `05_pricing_billing.sql` | Per-night rates, multi-room billing, revenue reports |
| `06_indexes_performance.sql` | EXPLAIN before/after, leftmost-prefix analysis |
| `07_views_security.sql` | 4 views, WITH CHECK OPTION, GRANT statements |
| `08_window_functions.sql` | RANK(), SUM() OVER(), LAG(), NTILE(4) |
| `09_test_cases.sql` | 14 test cases with expected results |
| `10_stored_procedures.sql` | make_reservation, cancel_reservation, enhancements |
| `PROJECT_REPORT.md` | Full written report (all 24 sections) |
| `README.md` | This file |

---

### Schema Overview

```
guests ──< reservations >── reservation_rooms ──< rooms >── room_types
                  │                                               │
                  ├──< extra_charges                      room_rates
                  ├──< reservation_audit_log
                  └──< room_assignment_history
```

---

### Key Design Decisions

1. **Multi-room reservations** — `reservation_rooms` bridge table allows one booking to include multiple rooms.
2. **Historical rate preservation** — `booked_rate_per_night` stored at booking time; never recalculated from live rates.
3. **No-overlap rate periods** — A `BEFORE INSERT` trigger on `room_rates` prevents overlapping rate periods for the same room type.
4. **Concurrency-safe booking** — `SELECT … FOR UPDATE` within a transaction prevents double bookings.
5. **Physical vs. booking availability** — `room_status` (maintenance/out_of_order) is independent of reservation-based availability.

---

### Resetting the Database

To start fresh:
```sql
DROP DATABASE IF EXISTS staysphere;
-- Then re-run 01_schema_creation.sql → 02_sample_data.sql
```

---

### Version Notes

| Feature | MySQL Version |
|---------|---------------|
| `WITH RECURSIVE` (recursive CTE) | 8.0+ |
| Window functions (`RANK`, `LAG`, `NTILE`, `SUM OVER`) | 8.0+ |
| `EXPLAIN ANALYZE` | 8.0.18+ |
| `CHECK` constraints enforced | 8.0.16+ |
| `EXPLAIN FORMAT=TREE` | 8.0.16+ |

---

*StaySphere — University DBMS Project*
<img width="647" height="656" alt="Screenshot 2026-11-06 101804" src="https://github.com/user-attachments/assets/34d6c877-7ae5-4d19-aef5-a35020dbda81" />
<img width="642" height="620" alt="Screenshot 2026-11-06 101819" src="https://github.com/user-attachments/assets/a4c6a974-47c8-4fa6-849f-707579404607" />
<img width="666" height="622" alt="Screenshot 2026-11-06 101836" src="https://github.com/user-attachments/assets/d17ce34c-3dd7-456b-b86c-bc4a3a14c7f3" />
<img width="748" height="630" alt="Screenshot 2026-11-06 101846" src="https://github.com/user-attachments/assets/e0549960-14e5-40fe-908b-d3e745462bfb" />



