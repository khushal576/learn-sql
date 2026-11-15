INSERT INTO rooms (id, number, type, floor, base_rate)
SELECT g, ((g - 1) / 10 + 1) * 100 + (g - 1) % 10 + 1,
       CASE WHEN g % 4 = 0 THEN 'suite' WHEN g % 4 = 1 THEN 'single' ELSE 'double' END,
       (g - 1) / 10 + 1,
       CASE WHEN g % 4 = 0 THEN 260 WHEN g % 4 = 1 THEN 80 ELSE 130 END + (g % 3) * 5
FROM generate_series(1, 40) g;

INSERT INTO guests (id, name, country, loyalty)
SELECT g,
       (ARRAY['Aarav','Maya','Liam','Sofia','Noah','Zara','Ethan','Mei','Omar','Lena','Ravi','Chloe','Jon','Ana','Kofi','Yuki'])[1 + g % 16] || ' ' ||
       (ARRAY['Sharma','Garcia','Smith','Chen','Okafor','Muller','Rossi','Kim','Patel','Silva','Novak'])[1 + (g * 7) % 11],
       (ARRAY['India','Spain','UK','China','Nigeria','Germany','Italy','Korea','Brazil','USA'])[1 + (g * 3) % 10],
       CASE WHEN g % 10 = 0 THEN 'gold' WHEN g % 4 = 0 THEN 'silver' ELSE 'none' END
FROM generate_series(1, 300) g;

-- Regular chains: per room, booking k starts after the previous stay plus a gap. gap 0 = ADJACENT (back-to-back).
-- Stay 1-6 nights (1-night common); rooms 5,10,..,40 have runs of 8 consecutive adjacent bookings; rooms 33-36 get a 30-41 night stay every 6th booking. Rooms 37-40 skip
-- bookings that would start inside their idle window. Statuses: every 9th cancelled, every 17th no_show.
INSERT INTO bookings (id, room_id, guest_id, check_in, check_out, status, nightly_rate)
SELECT row_number() OVER (ORDER BY room_id, check_in), room_id, 1 + (room_id * 13 + k * 29) % 300,
       check_in, check_in + nights,
       CASE WHEN k % 9 = 0 THEN 'cancelled' WHEN k % 17 = 0 THEN 'no_show' ELSE 'confirmed' END,
       base_rate + (k % 5) * 5
FROM (
  SELECT t.*, DATE '2024-01-01' + (room_id % 7) + COALESCE(SUM(nights + gap) OVER (PARTITION BY room_id ORDER BY k
         ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), 0)::int AS check_in
  FROM (
    SELECT r.id AS room_id, k, r.base_rate,
           CASE WHEN r.id BETWEEN 33 AND 36 AND k % 6 = 0 THEN 30 + (r.id + k) % 12 ELSE 1 + (r.id * 7 + k * 5) % 6 END AS nights,
           CASE WHEN r.id % 5 = 0 AND k % 14 BETWEEN 3 AND 10 THEN 0      -- rooms 5,10,..: runs of 8 back-to-back bookings
                WHEN (r.id * 3 + k * 7) % 10 < 3 THEN 0
                WHEN (r.id * 3 + k * 7) % 10 < 8 THEN 2 + (r.id + k) % 6
                ELSE 6 + (r.id + k) % 12 END AS gap
    FROM rooms r CROSS JOIN generate_series(1, 120) k
  ) t
) c
WHERE check_in < DATE '2025-01-01'
  AND NOT (room_id IN (37, 38) AND check_in BETWEEN DATE '2024-03-01' AND DATE '2024-08-15')
  AND NOT (room_id = 39 AND check_in BETWEEN DATE '2024-02-01' AND DATE '2024-09-30')
  AND NOT (room_id = 40 AND check_in BETWEEN DATE '2024-04-01' AND DATE '2024-12-01');

-- 30 DOUBLE-BOOKINGS: extra confirmed 1-night booking on day 2 of an existing confirmed stay of 2+ nights.
INSERT INTO bookings (id, room_id, guest_id, check_in, check_out, status, nightly_rate)
SELECT 5000 + rn, room_id, 1 + (id * 17) % 300, check_in + 1, check_in + 2, 'confirmed', nightly_rate + 10
FROM (SELECT b.*, row_number() OVER (ORDER BY id) AS rn
      FROM bookings b
      WHERE status = 'confirmed' AND check_out - check_in BETWEEN 2 AND 6 AND id % 13 = 0 AND room_id < 33) s
WHERE rn <= 30;

-- 25 cancelled TWINS: same room and dates as a confirmed booking (not one of the double-booked ones), cancelled.
INSERT INTO bookings (id, room_id, guest_id, check_in, check_out, status, nightly_rate)
SELECT 6000 + rn, room_id, 1 + (id * 19) % 300, check_in, check_out, 'cancelled', nightly_rate
FROM (SELECT b.*, row_number() OVER (ORDER BY id) AS rn
      FROM bookings b
      WHERE id < 5000 AND status = 'confirmed' AND id % 41 = 20
        AND NOT EXISTS (SELECT 1 FROM bookings d WHERE d.id > 5000 AND d.id < 5031 AND d.room_id = b.room_id
                          AND d.check_in < b.check_out AND b.check_in < d.check_out)) s
WHERE rn <= 25;

-- 40 maintenance windows, end_date INCLUSIVE, 1-9 days. Many hit existing bookings.
INSERT INTO maintenance (id, room_id, start_date, end_date, reason)
SELECT g, 1 + (g * 7) % 40,
       DATE '2024-01-10' + (g * 9) % 330,
       DATE '2024-01-10' + (g * 9) % 330 + (g % 5) * 2,
       (ARRAY['plumbing','painting','AC repair','carpet','deep clean','electrical'])[1 + g % 6]
FROM generate_series(1, 40) g;

-- 5 seasonal cards per type, contiguous; suite skips 2024-09-01..2024-09-14 on purpose (the rate-card GAP).
INSERT INTO rate_cards (id, room_type, valid_from, valid_to, nightly_rate)
SELECT row_number() OVER (ORDER BY t.ord, s.n), t.type, s.vf, s.vt, round(t.base * s.mult, 2)
FROM (VALUES ('single', 1, 80.0), ('double', 2, 130.0), ('suite', 3, 260.0)) t(type, ord, base)
JOIN (VALUES (1, DATE '2024-01-01', DATE '2024-03-31', 0.9),
             (2, DATE '2024-04-01', DATE '2024-06-30', 1.0),
             (3, DATE '2024-07-01', DATE '2024-08-31', 1.3),
             (4, DATE '2024-09-01', DATE '2024-11-30', 1.0),
             (5, DATE '2024-12-01', DATE '2024-12-31', 1.5)) s(n, vf, vt, mult) ON true
WHERE NOT (t.type = 'suite' AND s.n = 4)
UNION ALL
SELECT 100, 'suite', DATE '2024-09-15', DATE '2024-11-30', 260.00;
