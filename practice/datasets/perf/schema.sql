-- Performance lab. Loaded into its own schema (search_path set by the loader), so no schema prefixes here.
-- Every index below exists for a reason; questions rely on them. Tables without an index are the CONTRAST cases.

CREATE TABLE customers (
  id         int PRIMARY KEY,                 -- pk index: lookups by id
  email      text NOT NULL,                   -- MIXED CASE on purpose (e.g. 'Maya.Chen123@Example.com')
  country    text NOT NULL,
  created_at timestamptz NOT NULL,
  segment    text NOT NULL
);
-- Expression index: serves `WHERE lower(email) = '...'` (case-insensitive lookup written sargably).
-- It can NOT serve `email = '...'` with a different case, nor `email ILIKE ...`, nor `upper(email)`.
CREATE INDEX customers_lower_email_idx ON customers (lower(email));
-- Plain btree: serves `country = 'x'` (~1/12 of rows: moderately selective, planner may pick bitmap or seq scan).
CREATE INDEX customers_country_idx ON customers (country);

CREATE TABLE orders (
  id          int PRIMARY KEY,                -- pk index
  customer_id int NOT NULL,
  status      text NOT NULL,                  -- skewed: done ~90%, open ~2%, cancelled/returned ~8%
  created_at  timestamptz NOT NULL,           -- spread over ~3 years (2023-2025), unrelated to id order
  amount      numeric(10,2) NOT NULL,
  region      text NOT NULL,                  -- NO index: filters on it must Seq Scan
  note        text                            -- NO index: filters on it must Seq Scan
);
-- Serves `customer_id = n` and joins on customer_id (some customers have hundreds of orders, most have ~3).
CREATE INDEX orders_customer_idx ON orders (customer_id);
-- Serves selective date ranges on created_at written as sargable half-open ranges
-- (NOT `created_at::date = ...` or `date_trunc(...) = ...`, which cannot use it).
CREATE INDEX orders_created_idx ON orders (created_at);
-- PARTIAL index: only the ~2% 'open' rows. Tiny, and used for `status = 'open' AND created_at ...` /
-- `status = 'open'` queries. Not usable when the query does not imply status = 'open'.
CREATE INDEX orders_open_created_idx ON orders (created_at) WHERE status = 'open';
-- Composite + covering: INCLUDE (amount) lets a query touching only customer_id, created_at, amount
-- be answered by an Index Only Scan (no heap visits; the loader's ANALYZE/VACUUM-free load may still
-- show some heap fetches, but the plan node type is Index Only Scan).
CREATE INDEX orders_customer_created_incl_idx ON orders (customer_id, created_at) INCLUDE (amount);

CREATE TABLE order_items (
  order_id int NOT NULL,
  line_no  int NOT NULL,
  sku      text NOT NULL,
  qty      int NOT NULL,
  price    numeric(10,2) NOT NULL,
  PRIMARY KEY (order_id, line_no)             -- pk index: items of one order; also serves joins on order_id
);
-- Serves `sku = '...'` (2000 skus, ~300 lines each: selective).
CREATE INDEX order_items_sku_idx ON order_items (sku);

CREATE TABLE audit_log (
  id     int PRIMARY KEY,                     -- the ONLY index: everything else (at, actor, action) is a Seq Scan
  at     timestamptz NOT NULL,
  actor  text NOT NULL,
  action text NOT NULL
);
