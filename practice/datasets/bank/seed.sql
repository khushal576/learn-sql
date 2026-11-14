INSERT INTO customers (id, name, city, segment, joined)
SELECT g,
       (ARRAY['Aarav','Maya','Liam','Sofia','Noah','Zara','Ethan','Mei','Omar','Lena','Ravi','Chloe'])[1 + g % 12] || ' ' ||
       (ARRAY['Sharma','Garcia','Smith','Chen','Okafor','Muller','Rossi','Kim','Patel'])[1 + (g * 5) % 9],
       CASE WHEN g % 31 = 0 THEN NULL ELSE (ARRAY['Pune','Austin','Leeds','Berlin','Recife','Osaka','Toronto'])[1 + g % 7] END,
       CASE WHEN g % 10 = 0 THEN 'business' WHEN g % 4 = 0 THEN 'premium' ELSE 'retail' END,
       DATE '2018-01-01' + (g * 17 % 2000)
FROM generate_series(1, 400) g;

-- every customer has a checking account; even customers also a savings account; every 5th a credit account
INSERT INTO accounts (id, customer_id, type, opened_on, status, overdraft_limit)
SELECT row_number() OVER (ORDER BY c.id, t.rank), c.id, t.type, c.joined + t.rank * 30,
       CASE WHEN c.id % 13 = 0 AND t.type = 'checking' THEN 'closed' ELSE 'open' END,
       CASE WHEN t.type = 'checking' AND c.id % 3 = 0 THEN 500 ELSE 0 END
FROM customers c
JOIN (VALUES ('checking', 0), ('savings', 1), ('credit', 2)) t(type, rank)
  ON t.type = 'checking' OR (t.type = 'savings' AND c.id % 2 = 0) OR (t.type = 'credit' AND c.id % 5 = 0);

-- 10-29 transactions per account; consecutive pairs (k, k+1) share the same day on purpose (tie-break / frame questions)
INSERT INTO transactions (id, account_id, tx_date, kind, amount, merchant)
SELECT a.id * 100 + k, a.id,
       DATE '2024-01-01' + ((a.id * 37 + (k / 2) * 53) % 366),
       x.kind,
       CASE x.kind
         WHEN 'deposit'    THEN 100 + (a.id * k * 17) % 900
         WHEN 'withdrawal' THEN -(20 + (a.id * k * 7) % 300)
         WHEN 'purchase'   THEN -(5 + (a.id * k * 13) % 200)
         WHEN 'fee'        THEN -(1 + (a.id + k) % 5)
         ELSE round((((a.id + k) % 40) / 10.0 + 0.5)::numeric, 2)
       END,
       CASE WHEN x.kind = 'purchase' THEN (ARRAY['Grocer','Fuel','Cafe','Rent','Books','Pharmacy','Cinema','Online'])[1 + (a.id + k) % 8] END
FROM accounts a
CROSS JOIN LATERAL generate_series(0, 9 + a.id % 20) k
CROSS JOIN LATERAL (SELECT CASE (a.id + k) % 6
                      WHEN 0 THEN 'deposit' WHEN 1 THEN 'purchase' WHEN 2 THEN 'withdrawal'
                      WHEN 3 THEN 'purchase' WHEN 4 THEN 'deposit'
                      ELSE CASE WHEN a.type = 'savings' THEN 'interest' ELSE 'fee' END END AS kind) x;

INSERT INTO loans (id, customer_id, principal, annual_rate, start_date, term_months, status)
SELECT g, 1 + (g * 7) % 400, 5000 + (g * 911) % 45000, 5.5 + (g % 10) * 0.5,
       DATE '2021-01-01' + (g * 13 % 1100), 12 * (1 + g % 5),
       CASE g % 7 WHEN 0 THEN 'defaulted' WHEN 1 THEN 'paid' ELSE 'active' END
FROM generate_series(1, 150) g;
