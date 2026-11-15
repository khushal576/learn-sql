-- Deterministic seed: arithmetic on generate_series, never random()/now(), so every load is identical.
-- Sizes: customers 50k, orders 300k, order_items 600k, audit_log 200k.

INSERT INTO customers (id, email, country, created_at, segment)
SELECT g,
       (ARRAY['Aarav','Maya','Liam','Sofia','Noah','Zara','Ethan','Mei','Omar','Lena','Ravi','Chloe'])[1 + g % 12]
         || '.' || (ARRAY['Sharma','Garcia','Smith','Chen','Okafor','Muller','Rossi','Kim','Patel','Silva','Novak'])[1 + (g * 7) % 11]
         || g || '@' || (ARRAY['Example.com','EXAMPLE.org','example.NET'])[1 + g % 3],
       (ARRAY['India','USA','UK','Germany','Brazil','Japan','Canada','Nigeria','France','Spain','Kenya','Chile'])[1 + (g * 5) % 12],
       timestamptz '2022-01-01 00:00:00+00' + ((g::bigint * 7919) % 50000) * interval '31 minutes',
       (ARRAY['consumer','corporate','home_office'])[1 + g % 3]
FROM generate_series(1, 50000) g;

-- 1 in 4 orders goes to one of the first 200 "power" customers (~375 orders each); the rest spread over all 50k (~4 each).
INSERT INTO orders (id, customer_id, status, created_at, amount, region, note)
SELECT g,
       CASE WHEN g % 4 = 0 THEN 1 + ((g::bigint * 7919) % 200)::int
            ELSE 1 + ((g::bigint * 7919) % 50000)::int END,
       CASE WHEN g % 50 = 0 THEN 'open'
            WHEN g % 50 IN (1, 2) THEN 'cancelled'
            WHEN g % 50 IN (3, 4) THEN 'returned'
            ELSE 'done' END,
       timestamptz '2023-01-01 00:00:00+00' + ((g::bigint * 7919) % 300000) * interval '315 seconds',
       5 + ((g::bigint * 37) % 49500) / 100.0,
       (ARRAY['north','south','east','west','central','overseas','online','partner'])[1 + g % 8],
       CASE WHEN g % 10 = 0 THEN NULL ELSE 'note-' || (g % 1000) || '-' || md5(g::text) END
FROM generate_series(1, 300000) g;

INSERT INTO order_items (order_id, line_no, sku, qty, price)
SELECT 1 + (g - 1) % 300000,
       1 + (g - 1) / 300000,
       'SKU-' || lpad(((g::bigint * 31) % 2000)::text, 5, '0'),
       1 + g % 5,
       1 + ((g::bigint * 53) % 20000) / 100.0
FROM generate_series(1, 600000) g;

INSERT INTO audit_log (id, at, actor, action)
SELECT g,
       timestamptz '2023-01-01 00:00:00+00' + ((g::bigint * 7919) % 200000) * interval '473 seconds',
       'user' || (g * 13 % 500),
       (ARRAY['login','logout','view','update','delete','export'])[1 + g % 6]
FROM generate_series(1, 200000) g;
