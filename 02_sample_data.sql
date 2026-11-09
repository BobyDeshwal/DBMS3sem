-- =============================================================================
-- StaySphere – FILE 02 : Sample Data Insertion
-- =============================================================================
-- PURPOSE : Populate all tables with realistic, coherent test data.
--           Foreign-key order: room_types → rooms → guests → room_rates
--           → reservations → reservation_rooms → extra_charges
--           → room_assignment_history
-- NOTE    : Run AFTER 01_schema_creation.sql
-- =============================================================================

USE staysphere;

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- 1. ROOM TYPES  (room_type_id 1-5)
-- =============================================================================
INSERT INTO room_types (type_name, max_capacity, description, amenities, base_rate) VALUES
('Standard Single',  1, 'Compact room with a queen bed, ideal for solo travellers.',
 'WiFi,AC,TV,Wardrobe', 3500.00),

('Standard Double',  2, 'Spacious room with a king bed for couples.',
 'WiFi,AC,TV,Wardrobe,Mini-fridge', 5000.00),

('Deluxe Double',    3, 'Premium room with garden or pool view, king bed, and work desk.',
 'WiFi,AC,Smart-TV,Mini-bar,Work-desk,Safe', 8000.00),

('Executive Suite',  4, 'Separate living room, king bed, jacuzzi, and city view.',
 'WiFi,AC,Smart-TV,Mini-bar,Jacuzzi,Lounge,Safe,Butler', 15000.00),

('Presidential Suite',6,'Two bedrooms, private dining, butler service, panoramic view.',
 'WiFi,AC,Smart-TV,Mini-bar,Jacuzzi,Private-dining,Butler,Piano', 35000.00);

-- =============================================================================
-- 2. ROOMS  (room_id auto 1-15)
-- =============================================================================
-- Floor 1 : Standard Single (type 1)
INSERT INTO rooms (room_number, room_type_id, floor_number, room_status, smoking, notes) VALUES
('101', 1, 1, 'available',        0, NULL),
('102', 1, 1, 'available',        0, NULL),
('103', 1, 1, 'under_maintenance',0, 'Plumbing repair in progress'),

-- Floor 2 : Standard Double (type 2)
('201', 2, 2, 'available', 0, NULL),
('202', 2, 2, 'available', 0, NULL),
('203', 2, 2, 'available', 1, 'Smoking room'),

-- Floor 3 : Deluxe Double (type 3)
('301', 3, 3, 'available', 0, 'Pool view'),
('302', 3, 3, 'available', 0, 'Garden view'),
('303', 3, 3, 'out_of_order', 0, 'Renovation scheduled'),

-- Floor 4 : Executive Suite (type 4)
('401', 4, 4, 'available', 0, 'City view north'),
('402', 4, 4, 'available', 0, 'City view south'),

-- Floor 5 : Presidential Suite (type 5)
('501', 5, 5, 'available', 0, 'Panoramic east view'),
('502', 5, 5, 'available', 0, 'Panoramic west view'),

-- Additional rooms for richer data
('104', 1, 1, 'available', 0, NULL),
('204', 2, 2, 'available', 0, NULL);

-- =============================================================================
-- 3. GUESTS  (guest_id auto 1-12)
-- =============================================================================
INSERT INTO guests (first_name, last_name, email, phone, national_id,
                    date_of_birth, address, city, country, loyalty_points) VALUES
('Arjun',    'Sharma',    'arjun.sharma@email.com',    '+91-9812345670', 'PASS-IN-001',
 '1988-03-14', '12 Connaught Place', 'New Delhi',   'India', 1200),

('Priya',    'Verma',     'priya.verma@email.com',     '+91-9823456781', 'PASS-IN-002',
 '1992-07-22', '45 MG Road',         'Bengaluru',   'India',  800),

('Rohan',    'Mehta',     'rohan.mehta@email.com',     '+91-9834567892', 'PASS-IN-003',
 '1985-11-05', '78 Park Street',     'Kolkata',     'India',  350),

('Sneha',    'Patel',     'sneha.patel@email.com',     '+91-9845678903', 'PASS-IN-004',
 '1995-02-18', '23 Paldi',           'Ahmedabad',   'India', 2100),

('Vikram',   'Singh',     'vikram.singh@email.com',    '+91-9856789014', 'PASS-IN-005',
 '1980-09-30', '56 Civil Lines',     'Jaipur',      'India',  500),

('Anjali',   'Nair',      'anjali.nair@email.com',     '+91-9867890125', 'PASS-IN-006',
 '1998-04-12', '9 Infopark',         'Kochi',       'India',  150),

('Rajan',    'Iyer',      'rajan.iyer@email.com',      '+91-9878901236', 'PASS-IN-007',
 '1975-12-25', '34 Anna Nagar',      'Chennai',     'India', 3500),

('Meera',    'Joshi',     'meera.joshi@email.com',     '+91-9889012347', 'PASS-IN-008',
 '1990-06-08', '67 Banjara Hills',   'Hyderabad',   'India',  700),

('Karan',    'Kapoor',    'karan.kapoor@email.com',    '+91-9890123458', 'PASS-IN-009',
 '1983-08-17', '11 Linking Road',    'Mumbai',      'India', 4200),

('Divya',    'Reddy',     'divya.reddy@email.com',     '+91-9901234569', 'PASS-IN-010',
 '1997-01-29', '89 Jubilee Hills',   'Hyderabad',   'India',  220),

('Suresh',   'Kumar',     'suresh.kumar@email.com',    '+91-9912345670', 'PASS-IN-011',
 '1970-05-03', '2 Ashok Nagar',      'Bhopal',      'India', 1800),

('Lakshmi',  'Menon',     'lakshmi.menon@email.com',   '+91-9923456781', 'PASS-IN-012',
 '1993-10-15', '5 Vazhuthacaud',     'Thiruvananthapuram','India', 950);

-- =============================================================================
-- 4. ROOM RATES
-- =============================================================================
-- Standard Single (room_type_id=1)
INSERT INTO room_rates (room_type_id, rate_name, nightly_rate, valid_from, valid_to) VALUES
(1, 'Standard Single – Regular',   3500.00, '2025-01-01', '2025-03-31'),
(1, 'Standard Single – Summer',    4200.00, '2025-04-01', '2025-06-30'),
(1, 'Standard Single – Monsoon',   3000.00, '2025-07-01', '2025-09-30'),
(1, 'Standard Single – Festive',   5000.00, '2025-10-01', '2025-12-31'),

-- Standard Double (room_type_id=2)
(2, 'Standard Double – Regular',   5000.00, '2025-01-01', '2025-03-31'),
(2, 'Standard Double – Summer',    6000.00, '2025-04-01', '2025-06-30'),
(2, 'Standard Double – Monsoon',   4500.00, '2025-07-01', '2025-09-30'),
(2, 'Standard Double – Festive',   7500.00, '2025-10-01', '2025-12-31'),

-- Deluxe Double (room_type_id=3)
(3, 'Deluxe Double – Regular',     8000.00, '2025-01-01', '2025-03-31'),
(3, 'Deluxe Double – Summer',      9500.00, '2025-04-01', '2025-06-30'),
(3, 'Deluxe Double – Monsoon',     7000.00, '2025-07-01', '2025-09-30'),
(3, 'Deluxe Double – Festive',    12000.00, '2025-10-01', '2025-12-31'),

-- Executive Suite (room_type_id=4)
(4, 'Executive Suite – Regular',  15000.00, '2025-01-01', '2025-03-31'),
(4, 'Executive Suite – Summer',   18000.00, '2025-04-01', '2025-06-30'),
(4, 'Executive Suite – Monsoon',  12000.00, '2025-07-01', '2025-09-30'),
(4, 'Executive Suite – Festive',  22000.00, '2025-10-01', '2025-12-31'),

-- Presidential Suite (room_type_id=5)
(5, 'Presidential – Regular',     35000.00, '2025-01-01', '2025-03-31'),
(5, 'Presidential – Summer',      42000.00, '2025-04-01', '2025-06-30'),
(5, 'Presidential – Monsoon',     28000.00, '2025-07-01', '2025-09-30'),
(5, 'Presidential – Festive',     50000.00, '2025-10-01', '2025-12-31');

-- =============================================================================
-- 5. RESERVATIONS
-- =============================================================================
-- reservation_id auto-assigned 1..20
INSERT INTO reservations
    (guest_id, check_in_date, check_out_date, num_guests,
     reservation_status, booked_rate_per_night, special_requests,
     confirmed_at, cancelled_at, cancellation_reason)
VALUES
-- Res 1: Arjun Sharma – completed Jan stay, Room 101 (Std Single)
(1, '2025-01-10', '2025-01-13', 1, 'completed', 3500.00,
 'High floor preferred', '2025-01-08 10:00:00', NULL, NULL),

-- Res 2: Priya Verma – completed Feb stay, Room 201 (Std Double)
(2, '2025-02-14', '2025-02-17', 2, 'completed', 5000.00,
 'Anniversary decoration', '2025-02-10 14:00:00', NULL, NULL),

-- Res 3: Rohan Mehta – cancelled
(3, '2025-03-01', '2025-03-04', 1, 'cancelled', 3500.00,
 NULL, '2025-02-20 09:00:00', '2025-02-25 11:00:00', 'Change of plans'),

-- Res 4: Sneha Patel – completed, Deluxe (Apr – summer rate)
(4, '2025-04-05', '2025-04-09', 2, 'completed', 9500.00,
 'Pool view room', '2025-04-01 16:00:00', NULL, NULL),

-- Res 5: Vikram Singh – completed, Exec Suite (Apr)
(5, '2025-04-12', '2025-04-15', 3, 'completed', 18000.00,
 'Extra bed required', '2025-04-08 11:30:00', NULL, NULL),

-- Res 6: Anjali Nair – completed, Std Single (May)
(6, '2025-05-20', '2025-05-23', 1, 'completed', 4200.00,
 NULL, '2025-05-15 09:00:00', NULL, NULL),

-- Res 7: Rajan Iyer – completed, Presidential Suite (Jun)
(7, '2025-06-01', '2025-06-05', 4, 'completed', 42000.00,
 'Private dining setup', '2025-05-28 10:00:00', NULL, NULL),

-- Res 8: Meera Joshi – completed (Jul – monsoon)
(8, '2025-07-10', '2025-07-14', 2, 'completed', 7000.00,
 'Quiet floor please', '2025-07-05 12:00:00', NULL, NULL),

-- Res 9: Karan Kapoor – completed (Aug)
(9, '2025-08-01', '2025-08-06', 2, 'completed', 4500.00,
 NULL, '2025-07-28 08:00:00', NULL, NULL),

-- Res 10: Divya Reddy – completed (Sep)
(10,'2025-09-15', '2025-09-18', 1, 'completed', 3000.00,
 NULL, '2025-09-10 10:00:00', NULL, NULL),

-- Res 11: Suresh Kumar – completed (Oct – festive)
(11,'2025-10-20', '2025-10-24', 3, 'completed', 12000.00,
 'Birthday celebration arrangement', '2025-10-15 14:00:00', NULL, NULL),

-- Res 12: Lakshmi Menon – completed (Nov)
(12,'2025-11-05', '2025-11-08', 2, 'completed', 7500.00,
 NULL, '2025-11-01 09:00:00', NULL, NULL),

-- Res 13: Arjun Sharma – 2nd stay (Nov) – repeat visit analytics
(1, '2025-11-20', '2025-11-23', 1, 'completed', 5000.00,
 NULL, '2025-11-17 11:00:00', NULL, NULL),

-- Res 14: Karan Kapoor – 2nd stay (Dec – festive)
(9, '2025-12-24', '2025-12-27', 2, 'completed', 22000.00,
 'Christmas decoration', '2025-12-20 10:00:00', NULL, NULL),

-- Res 15: Rajan Iyer – 2nd stay (Dec)
(7, '2025-12-10', '2025-12-13', 3, 'completed', 50000.00,
 'New Year prep meeting room', '2025-12-05 09:00:00', NULL, NULL),

-- Res 16: Priya Verma – 2nd stay (confirmed, future)
(2, '2026-01-15', '2026-01-18', 2, 'confirmed', 5000.00,
 NULL, '2026-01-10 10:00:00', NULL, NULL),

-- Res 17: Sneha Patel – 2nd stay (confirmed, future)
(4, '2026-02-14', '2026-02-17', 2, 'confirmed', 8000.00,
 'Valentine package', '2026-02-10 14:00:00', NULL, NULL),

-- Res 18: Pending reservation (test expiry logic)
(6, '2026-03-01', '2026-03-03', 1, 'pending', 3500.00,
 NULL, NULL, NULL, NULL),

-- Res 19: Adjacent reservation – check-in same day as Res 1 checkout
-- Res 1 checks out 2025-01-13; Res 19 checks in 2025-01-13 (valid, NO overlap)
(2, '2025-01-13', '2025-01-15', 1, 'completed', 3500.00,
 NULL, '2025-01-11 10:00:00', NULL, NULL),

-- Res 20: Multi-room reservation for Karan Kapoor (Aug – same as Res 9)
-- This represents a SEPARATE reservation (family booking – 2 rooms)
(9, '2025-08-15', '2025-08-18', 4, 'completed', 8000.00,
 'Two connecting rooms', '2025-08-10 09:00:00', NULL, NULL);

-- =============================================================================
-- 6. RESERVATION_ROOMS
-- =============================================================================
INSERT INTO reservation_rooms (reservation_id, room_id, booked_rate_per_night, assigned_at) VALUES
-- Res 1 → Room 101 (Std Single)
(1,  1,  3500.00, '2025-01-08 10:05:00'),
-- Res 2 → Room 201 (Std Double)
(2,  4,  5000.00, '2025-02-10 14:05:00'),
-- Res 3 → Room 102 (cancelled – still recorded)
(3,  2,  3500.00, '2025-02-20 09:05:00'),
-- Res 4 → Room 301 (Deluxe – pool view)
(4,  7,  9500.00, '2025-04-01 16:05:00'),
-- Res 5 → Room 401 (Exec Suite)
(5,  10, 18000.00,'2025-04-08 11:35:00'),
-- Res 6 → Room 104 (Std Single)
(6,  14, 4200.00, '2025-05-15 09:05:00'),
-- Res 7 → Room 501 (Presidential)
(7,  12, 42000.00,'2025-05-28 10:05:00'),
-- Res 8 → Room 302 (Deluxe – garden view)
(8,  8,  7000.00, '2025-07-05 12:05:00'),
-- Res 9 → Room 204 (Std Double)
(9,  15, 4500.00, '2025-07-28 08:05:00'),
-- Res 10 → Room 101 (Std Single)
(10, 1,  3000.00, '2025-09-10 10:05:00'),
-- Res 11 → Room 302 (Deluxe)
(11, 8,  12000.00,'2025-10-15 14:05:00'),
-- Res 12 → Room 201 (Std Double)
(12, 4,  7500.00, '2025-11-01 09:05:00'),
-- Res 13 → Room 204 (Std Double)  Arjun's 2nd stay
(13, 15, 5000.00, '2025-11-17 11:05:00'),
-- Res 14 → Room 402 (Exec Suite)  Karan's 2nd stay
(14, 11, 22000.00,'2025-12-20 10:05:00'),
-- Res 15 → Room 502 (Presidential)  Rajan's 2nd stay
(15, 13, 50000.00,'2025-12-05 09:05:00'),
-- Res 16 → Room 201 (confirmed future)
(16, 4,  5000.00, '2026-01-10 10:05:00'),
-- Res 17 → Room 301 (confirmed future)
(17, 7,  8000.00, '2026-02-10 14:05:00'),
-- Res 18 → Room 102 (pending)
(18, 2,  3500.00, '2026-02-28 10:00:00'),
-- Res 19 → Room 101 (adjacent – same day checkout as Res 1)
(19, 1,  3500.00, '2025-01-11 10:05:00'),
-- Res 20 → Two rooms: 201 and 202 (multi-room)
(20, 4,  8000.00, '2025-08-10 09:05:00'),
(20, 5,  8000.00, '2025-08-10 09:05:00');

-- NOTE: Res 20 attempts to use room 201 (room_id=4) which also has Res 12
-- but Res 12 is Nov 2025 and Res 20 is Aug 2025 – no overlap. Correct.

-- =============================================================================
-- 7. EXTRA CHARGES
-- =============================================================================
INSERT INTO extra_charges (reservation_id, charge_category, description, amount, charge_date) VALUES
-- Res 1 – Arjun Sharma
(1, 'food',         'Restaurant dinner for one',       850.00,  '2025-01-10'),
(1, 'minibar',      'Minibar consumption',             320.00,  '2025-01-11'),
(1, 'laundry',      'Express laundry service',         450.00,  '2025-01-12'),

-- Res 2 – Priya Verma
(2, 'food',         'Breakfast in room (3 days)',      1200.00, '2025-02-14'),
(2, 'room_service', 'Late night room service',         650.00,  '2025-02-15'),
(2, 'spa',          'Couples spa session',             2800.00, '2025-02-16'),

-- Res 4 – Sneha Patel
(4, 'food',         'Pool-side lunch',                 1100.00, '2025-04-06'),
(4, 'transport',    'Airport pickup',                  800.00,  '2025-04-05'),
(4, 'minibar',      'Minibar (4 nights)',              980.00,  '2025-04-08'),

-- Res 5 – Vikram Singh
(5, 'food',         'Extra bed setup meal',            400.00,  '2025-04-12'),
(5, 'room_service', 'Business meeting snacks',         1500.00, '2025-04-13'),

-- Res 7 – Rajan Iyer
(7, 'food',         'Private dining (4 nights)',       8000.00, '2025-06-01'),
(7, 'spa',          'Full spa package',               12000.00, '2025-06-02'),
(7, 'transport',    'Chauffeur 4 days',                6000.00, '2025-06-03'),
(7, 'minibar',      'Premium minibar',                 2400.00, '2025-06-04'),

-- Res 9 – Karan Kapoor
(9, 'food',         'Restaurant visits (5 nights)',   3200.00, '2025-08-02'),
(9, 'laundry',      'Laundry 3 days',                  600.00, '2025-08-03'),

-- Res 11 – Suresh Kumar
(11,'food',         'Birthday dinner – private',       4500.00, '2025-10-21'),
(11,'spa',          'Rejuvenation spa',                3200.00, '2025-10-22'),
(11,'minibar',      'Minibar (4 nights)',              1100.00, '2025-10-23'),

-- Res 14 – Karan Kapoor (2nd stay – Christmas)
(14,'food',         'Christmas dinner gala',           5500.00, '2025-12-24'),
(14,'room_service', 'Room service (3 nights)',         1800.00, '2025-12-25'),
(14,'transport',    'Christmas Eve chauffeur',         1200.00, '2025-12-24'),

-- Res 15 – Rajan Iyer (2nd stay)
(15,'food',         'Business dinner (3 nights)',      6000.00, '2025-12-10'),
(15,'spa',          'Spa and wellness',                9000.00, '2025-12-11'),

-- Res 20 – Karan Kapoor multi-room
(20,'food',         'Family dining (3 nights)',        4200.00, '2025-08-15'),
(20,'spa',          'Family spa package',              5000.00, '2025-08-16');

-- =============================================================================
-- 8. ROOM ASSIGNMENT HISTORY  (initial assignments)
-- =============================================================================
INSERT INTO room_assignment_history
    (reservation_id, room_id, action, action_reason, action_by, action_at)
VALUES
(1,  1,  'assigned',   'Initial check-in assignment', 'staff_raj',    '2025-01-08 10:05:00'),
(2,  4,  'assigned',   'Initial check-in assignment', 'staff_priti',  '2025-02-10 14:05:00'),
(3,  2,  'assigned',   'Initial check-in assignment', 'staff_raj',    '2025-02-20 09:05:00'),
(3,  2,  'unassigned', 'Reservation cancelled',       'system',       '2025-02-25 11:00:00'),
(4,  7,  'assigned',   'Pool view room assigned',     'staff_priti',  '2025-04-01 16:05:00'),
(5,  10, 'assigned',   'Exec suite assigned',         'staff_raj',    '2025-04-08 11:35:00'),
(6,  14, 'assigned',   'Room 104 assigned',           'staff_anand',  '2025-05-15 09:05:00'),
(7,  12, 'assigned',   'Presidential suite assigned', 'manager_dev',  '2025-05-28 10:05:00'),
(8,  8,  'assigned',   'Garden view assigned',        'staff_raj',    '2025-07-05 12:05:00'),
(9,  15, 'assigned',   'Room 204 assigned',           'staff_priti',  '2025-07-28 08:05:00'),
(10, 1,  'assigned',   'Room 101 assigned',           'staff_anand',  '2025-09-10 10:05:00'),
(11, 8,  'assigned',   'Room 302 assigned',           'staff_raj',    '2025-10-15 14:05:00'),
(12, 4,  'assigned',   'Room 201 assigned',           'staff_priti',  '2025-11-01 09:05:00'),
(13, 15, 'assigned',   'Room 204 assigned',           'staff_anand',  '2025-11-17 11:05:00'),
(14, 11, 'assigned',   'Exec suite 402 assigned',     'manager_dev',  '2025-12-20 10:05:00'),
(15, 13, 'assigned',   'Presidential 502 assigned',   'manager_dev',  '2025-12-05 09:05:00'),
(16, 4,  'assigned',   'Room 201 pre-assigned',       'staff_raj',    '2026-01-10 10:05:00'),
(17, 7,  'assigned',   'Room 301 pre-assigned',       'staff_priti',  '2026-02-10 14:05:00'),
(18, 2,  'assigned',   'Pending – room held',         'system',       '2026-02-28 10:00:00'),
(19, 1,  'assigned',   'Adjacent stay – room 101',    'staff_raj',    '2025-01-11 10:05:00'),
(20, 4,  'assigned',   'Multi-room booking – R201',   'staff_anand',  '2025-08-10 09:05:00'),
(20, 5,  'assigned',   'Multi-room booking – R202',   'staff_anand',  '2025-08-10 09:05:00');

-- =============================================================================
-- VERIFY ROW COUNTS
-- =============================================================================
SELECT 'room_types'              AS tbl, COUNT(*) AS rows FROM room_types
UNION ALL
SELECT 'rooms',                           COUNT(*)         FROM rooms
UNION ALL
SELECT 'guests',                          COUNT(*)         FROM guests
UNION ALL
SELECT 'room_rates',                      COUNT(*)         FROM room_rates
UNION ALL
SELECT 'reservations',                    COUNT(*)         FROM reservations
UNION ALL
SELECT 'reservation_rooms',               COUNT(*)         FROM reservation_rooms
UNION ALL
SELECT 'extra_charges',                   COUNT(*)         FROM extra_charges
UNION ALL
SELECT 'room_assignment_history',         COUNT(*)         FROM room_assignment_history;

-- =============================================================================
-- END OF FILE 02_sample_data.sql
-- =============================================================================

