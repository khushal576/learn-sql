-- Deterministic seed: arithmetic on generate_series, never random(), so every load is identical.
INSERT INTO categories (id, name, parent_id) VALUES
  (1,'Electronics',NULL),(2,'Computers',1),(3,'Laptops',2),(4,'Desktops',2),(5,'Phones',1),(6,'Accessories',1),
  (7,'Home',NULL),(8,'Kitchen',7),(9,'Furniture',7),(10,'Garden',7),
  (11,'Clothing',NULL),(12,'Men',11),(13,'Women',11),(14,'Books',NULL);

INSERT INTO customers (id, name, email, country, city, segment, signup_date)
SELECT g,
       f.first || ' ' || l.last,
       lower(f.first || '.' || l.last || g || '@example.com'),
       c.country,
       CASE WHEN g % 23 = 0 THEN NULL ELSE c.city END,
       (ARRAY['consumer','corporate','home_office'])[1 + g % 3],
       DATE '2022-01-01' + (g * 37 % 900)
FROM generate_series(1, 600) g
CROSS JOIN LATERAL (SELECT (ARRAY['Aarav','Maya','Liam','Sofia','Noah','Zara','Ethan','Mei','Omar','Lena','Ravi','Chloe','Jon','Ana','Kofi','Yuki'])[1 + g % 16] AS first) f
CROSS JOIN LATERAL (SELECT (ARRAY['Sharma','Garcia','Smith','Chen','Okafor','Muller','Rossi','Kim','Patel','Silva','Novak'])[1 + (g * 7) % 11] AS last) l
CROSS JOIN LATERAL (
  SELECT (ARRAY['India','USA','UK','Germany','Brazil','Japan','Canada','Nigeria'])[1 + (g * 5) % 8] AS country,
         (ARRAY['Pune','Austin','Leeds','Berlin','Recife','Osaka','Toronto','Lagos'])[1 + (g * 5) % 8] AS city
) c;

INSERT INTO products (id, name, category_id, price, cost, active, created_at)
SELECT g,
       (ARRAY['Pro','Lite','Max','Mini','Ultra','Eco'])[1 + g % 6] || ' ' ||
       (ARRAY['Laptop','Desktop','Phone','Charger','Blender','Sofa','Shirt','Dress','Novel','Planner'])[1 + (g * 3) % 10] || ' ' || g,
       (ARRAY[3,4,5,6,8,9,10,12,13,14])[1 + g % 10],
       (5 + (g * 37 % 500)) + 0.99,
       round(((5 + (g * 37 % 500)) + 0.99) * (0.40 + (g % 5) * 0.10), 2),
       g % 17 <> 0,
       DATE '2022-01-01' + (g * 5 % 600)
FROM generate_series(1, 120) g;

INSERT INTO orders (id, customer_id, order_date, status, shipped_date)
SELECT g,
       1 + CASE WHEN g % 3 = 0 THEN (g * 7919) % 90 ELSE (g * 7919) % 540 END,   -- customers 1-90 order more; 541-600 never order
       DATE '2023-01-01' + (g * 7 / 60),
       CASE WHEN g % 20 = 0 THEN 'cancelled'
            WHEN g % 20 IN (1, 2) THEN 'returned'
            WHEN g % 20 IN (3, 4) THEN 'placed'
            WHEN g % 20 = 5 THEN 'shipped'
            ELSE 'delivered' END,
       CASE WHEN g % 20 IN (0, 3, 4) THEN NULL ELSE DATE '2023-01-01' + (g * 7 / 60) + 1 + g % 5 END
FROM generate_series(1, 6000) g;

INSERT INTO order_items (order_id, line_no, product_id, quantity, unit_price)
SELECT o.id, ln,
       1 + (o.id * 13 + ln * 29) % 110,                      -- products 111-120 never sold
       1 + (o.id + ln) % 4,
       p.price - CASE WHEN (o.id + ln) % 10 = 0 THEN 2 ELSE 0 END
FROM orders o
CROSS JOIN LATERAL generate_series(1, 1 + o.id % 4) ln
JOIN products p ON p.id = 1 + (o.id * 13 + ln * 29) % 110;

INSERT INTO payments (id, order_id, method, amount, paid_at)
SELECT row_number() OVER (ORDER BY o.id), o.id,
       (ARRAY['card','upi','paypal','bank_transfer'])[1 + o.id % 4],
       (SELECT sum(quantity * unit_price) FROM order_items i WHERE i.order_id = o.id),
       o.order_date + TIME '09:00' + (o.id % 600) * INTERVAL '1 minute'
FROM orders o
WHERE o.status NOT IN ('cancelled', 'placed');                -- cancelled and unpaid (placed) orders have no payment

INSERT INTO reviews (id, product_id, customer_id, rating, created_at, body)
SELECT g,
       1 + (g * 7) % 110,
       1 + (g * 13) % 540,
       1 + (g * g + g / 3) % 5,
       DATE '2023-02-01' + (g * 11 % 650),
       CASE WHEN g % 3 = 0 THEN NULL ELSE 'Review text ' || g END
FROM generate_series(1, 2500) g;
