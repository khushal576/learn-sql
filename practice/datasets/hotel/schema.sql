CREATE TABLE rooms (
  id        int PRIMARY KEY,
  number    text NOT NULL,                       -- floor*100 + position, e.g. '203'
  type      text NOT NULL CHECK (type IN ('single', 'double', 'suite')),
  floor     int NOT NULL,
  base_rate numeric(8,2) NOT NULL
);
CREATE TABLE guests (
  id      int PRIMARY KEY,
  name    text NOT NULL,
  country text NOT NULL,
  loyalty text NOT NULL CHECK (loyalty IN ('none', 'silver', 'gold'))
);
-- check_out is EXCLUSIVE: the guest leaves that morning. A booking [in, out) of nights in..out-1.
-- Two bookings of one room overlap iff a.check_in < b.check_out AND b.check_in < a.check_out.
-- Deliberate features (all in 2024):
--  * ~30% of consecutive bookings in a room are ADJACENT (check_out = next check_in): NOT an overlap; chains of
--    back-to-back bookings exist (see seed comments)
--  * 30 genuine DOUBLE-BOOKINGS: a 1-night confirmed booking (ids 5001-5030) inside another confirmed booking of the same room
--  * 25 cancelled TWINS (ids 6001-6025): cancelled, same room and exact same dates as a confirmed booking - must be ignored
--  * some cancelled / no_show rows in the normal chains (never overlap anything)
--  * long stays of 30+ nights in rooms 33-36 that span month ends
--  * 1-night (same-day turnover) stays are common (check_out = check_in + 1)
--  * rooms 37-40 have long idle gaps (no bookings for months)
CREATE TABLE bookings (
  id           int PRIMARY KEY,
  room_id      int NOT NULL REFERENCES rooms (id),
  guest_id     int NOT NULL REFERENCES guests (id),
  check_in     date NOT NULL,
  check_out    date NOT NULL CHECK (check_out > check_in),
  status       text NOT NULL CHECK (status IN ('confirmed', 'cancelled', 'no_show')),
  nightly_rate numeric(8,2) NOT NULL
);
-- NOTE the difference: here BOTH ends are INCLUSIVE (room is out of service from start_date through end_date, whole days).
-- A maintenance window and a booking overlap iff start_date < check_out AND check_in <= end_date.
-- Some windows overlap confirmed bookings on purpose (conflicts to find).
CREATE TABLE maintenance (
  id         int PRIMARY KEY,
  room_id    int NOT NULL REFERENCES rooms (id),
  start_date date NOT NULL,
  end_date   date NOT NULL CHECK (end_date >= start_date),
  reason     text NOT NULL
);
-- Seasonal rates per room type: contiguous, non-overlapping ranges, valid_to INCLUSIVE (next valid_from = valid_to + 1).
-- ONE DELIBERATE GAP: room type 'suite' has no rate from 2024-09-01 to 2024-09-14 (autumn card starts 2024-09-15).
CREATE TABLE rate_cards (
  id          int PRIMARY KEY,
  room_type   text NOT NULL CHECK (room_type IN ('single', 'double', 'suite')),
  valid_from  date NOT NULL,
  valid_to    date NOT NULL CHECK (valid_to >= valid_from),
  nightly_rate numeric(8,2) NOT NULL
);
CREATE INDEX ON bookings (room_id, check_in);
CREATE INDEX ON bookings (guest_id);
CREATE INDEX ON maintenance (room_id);
