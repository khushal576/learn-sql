-- Deterministic seed: arithmetic on generate_series, never random()/now(), so every load is identical.
-- Scratch temp tables are dropped at the end.
CREATE TEMP TABLE tu AS
SELECT g AS id, (g * 37 % 100) AS sday,
       CASE WHEN g % 100 = 0 THEN 0 WHEN g % 50 = 0 THEN 86399 ELSE (g * 7919) % 86400 END AS ssec
FROM generate_series(1, 800) g;

INSERT INTO users (id, email, full_name, country, tz, plan, signup_at, tags, phone)
SELECT t.id,
       CASE WHEN t.id % 25 = 0 THEN ' ' ELSE '' END || e.mail || CASE WHEN t.id % 29 = 0 THEN ' ' ELSE '' END,
       n.fullname,
       c.country,
       CASE WHEN c.country = 'USA' AND t.id % 3 = 0 THEN 'America/Los_Angeles' ELSE c.tz END,
       CASE WHEN t.id % 10 < 5 THEN 'free' WHEN t.id % 10 < 8 THEN 'pro' ELSE 'team' END,
       TIMESTAMPTZ '2024-01-01 00:00:00+00' + (t.sday * 86400 + t.ssec) * INTERVAL '1 second',
       CASE WHEN t.id % 11 = 0 THEN NULL
            WHEN t.id % 9 = 0 THEN '{}'::text[]
            ELSE (ARRAY['beta','newsletter','vip','mobile','trial','enterprise','churn-risk','Beta'])
                 [1 + t.id % 5 : 1 + t.id % 5 + t.id % 4] END,
       CASE t.id % 7
         WHEN 0 THEN NULL
         WHEN 1 THEN '+91 98765 ' || lpad((t.id * 7 % 100000)::text, 5, '0')
         WHEN 2 THEN '(555) ' || (t.id * 53 % 900 + 100) || '-' || lpad((t.id * 7919 % 10000)::text, 4, '0')
         WHEN 3 THEN '555.' || (t.id * 53 % 900 + 100) || '.' || lpad((t.id * 7919 % 10000)::text, 4, '0')
         WHEN 4 THEN '555' || (t.id * 53 % 900 + 100) || lpad((t.id * 7919 % 10000)::text, 4, '0')
         WHEN 5 THEN '+1 555 ' || (t.id * 53 % 900 + 100) || ' ' || lpad((t.id * 7919 % 10000)::text, 4, '0')
         ELSE '555 ' || (t.id * 53 % 900 + 100) || ' ' || lpad((t.id * 7919 % 10000)::text, 4, '0') END
FROM tu t
CROSS JOIN LATERAL (SELECT (ARRAY['Aarav','Maya','Liam','Sofia','Noah','Zara','Ethan','Mei','Omar','Lena','Ravi','Chloe','Jon','Ana','Kofi','Yuki'])[1 + t.id % 16] AS f,
                           (ARRAY['Sharma','Garcia','Smith','Chen','Okafor','Muller','Rossi','Kim','Patel','Silva','Novak'])[1 + (t.id * 7) % 11] AS l) nm
CROSS JOIN LATERAL (SELECT (ARRAY['India','USA','UK','Germany','Brazil','Japan','New Zealand','Canada'])[1 + t.id % 8] AS country,
                           (ARRAY['Asia/Kolkata','America/New_York','Europe/London','Europe/Berlin','America/Sao_Paulo','Asia/Tokyo','Pacific/Auckland','America/Toronto'])[1 + t.id % 8] AS tz) c
CROSS JOIN LATERAL (
  SELECT CASE WHEN t.id % 7 = 0 THEN upper(b.m) WHEN t.id % 3 = 0 THEN initcap(b.m) ELSE b.m END AS mail
  FROM (SELECT lower(nm.f || '.' || nm.l || t.id || '@' || (ARRAY['example.com','mail.test','corp.example'])[1 + t.id % 3]) AS m) b) e
CROSS JOIN LATERAL (
  SELECT CASE WHEN t.id % 17 = 0 THEN ' ' ELSE '' END ||
         CASE WHEN t.id % 5 = 0 THEN upper(nm.f || ' ' || nm.l)
              WHEN t.id % 4 = 0 THEN lower(nm.f || ' ' || nm.l)
              WHEN t.id % 9 = 0 THEN nm.f || '  ' || nm.l
              WHEN t.id % 13 = 0 THEN lower(nm.f) || ' ' || upper(nm.l)
              ELSE nm.f || ' ' || nm.l END ||
         CASE WHEN t.id % 19 = 0 THEN ' ' ELSE '' END AS fullname) n;

-- Active user-days. d = days since the signup UTC day.
--  id%3=0 engaged: runs of (3 + id%10) consecutive days, idle gap (2 + id*3%6) days, 1 + (id/3)%4 runs
--  id%3=1 light:   signup day plus weekly returns (7k + id%2, k <= id%4), some also a day ~3 weeks later
--  id%3=2 minimal: signup day only for even ids, odd ids never come back after signing up
CREATE TEMP TABLE ud AS
SELECT t.id, t.sday, t.ssec, d
FROM tu t
CROSS JOIN LATERAL generate_series(0, 120 - t.sday) d
WHERE CASE t.id % 3
        WHEN 0 THEN d % ((3 + t.id % 10) + (2 + t.id * 3 % 6)) < (3 + t.id % 10)
                    AND d < ((3 + t.id % 10) + (2 + t.id * 3 % 6)) * (1 + (t.id / 3) % 4)
        WHEN 1 THEN d = 0 OR (d >= 7 AND d % 7 = t.id % 2 AND d <= 7 * (t.id % 4) + 1)
                    OR (t.id % 5 = 0 AND d = 20 + t.id % 15)
        ELSE d = 0 AND t.id % 2 = 0 END;

-- Click events inside active days: 2-6 events a day, secs = base + running sum of gaps.
CREATE TEMP TABLE ev0 AS
SELECT x.id AS user_id, x.d, x.j, x.h, x.id * 1000000 + x.d * 100 + x.j AS seq,
       x.base + sum(x.gap) OVER (PARTITION BY x.id, x.d ORDER BY x.j) AS secs
FROM (
  SELECT u.id, u.d, j, h.h,
         CASE WHEN u.d = 0 THEN u.sday * 86400 + u.ssec + 7200
              WHEN u.id % 13 = 0 THEN (u.sday + u.d) * 86400 + 85200
              ELSE (u.sday + u.d) * 86400 + (u.id * 7919 + u.d * 104729) % 18 * 3600 + (u.id * 31 + u.d * 17) % 3600 END AS base,
         CASE WHEN j = 0 THEN 0
              WHEN h.h % 31 = 0 THEN 0
              WHEN (u.id + u.d + j) % 4 = 0 THEN (ARRAY[1799,1800,1801,1800,3600,2700,7200,1800])[1 + h.h % 8]
              ELSE 20 + h.h % 280 END AS gap
  FROM ud u
  CROSS JOIN LATERAL generate_series(0, 1 + (u.id + u.d) % 5) j
  CROSS JOIN LATERAL (SELECT (u.id * 7919 + u.d * 104729 + j * 1299721) % 1000003 AS h) h
) x;
DELETE FROM ev0 WHERE secs >= 121 * 86400;

-- Funnel membership
CREATE TEMP TABLE fu AS
SELECT id,
       (id % 5 < 3) AS activated,
       ((id % 5 < 3 AND id % 7 < 3) OR id % 41 = 0) AS purchaser
FROM tu;

CREATE TEMP TABLE ev_all (user_id int, secs int, seq bigint, name text, props jsonb, device text);

-- signup
INSERT INTO ev_all
SELECT t.id, t.sday * 86400 + t.ssec, t.id * 1000000 - 1, 'signup',
       jsonb_build_object('referrer', CASE WHEN t.id % 4 = 0 THEN NULL ELSE (ARRAY['google','friend','blog','newsletter'])[1 + t.id % 4] END)
         || CASE WHEN t.id % 3 = 0 THEN '{}'::jsonb
                 ELSE jsonb_build_object('utm', jsonb_build_object('source', (ARRAY['ads','organic','email','social'])[1 + t.id % 4],
                                                                    'campaign', (ARRAY['spring','launch','promo','x'])[1 + t.id % 4])) END,
       (ARRAY['web','ios','android','desktop'])[1 + t.id % 4]
FROM tu t;

-- activated (60%): 5-54 min after signup; every 19th activated user only 3 days later (purchases can precede it);
-- every 23rd activates twice
INSERT INTO ev_all
SELECT t.id,
       t.sday * 86400 + t.ssec + CASE WHEN t.id % 19 = 0 THEN 3 * 86400 ELSE (5 + t.id % 50) * 60 END + k * 3600,
       t.id * 1000000 - 2 + k * 0, 'activated',
       jsonb_build_object('method', (ARRAY['email','sso'])[1 + t.id % 2]),
       (ARRAY['web','ios','android','desktop'])[1 + t.id % 4]
FROM tu t JOIN fu ON fu.id = t.id
CROSS JOIN LATERAL generate_series(0, CASE WHEN t.id % 23 = 0 THEN 1 ELSE 0 END) k
WHERE fu.activated AND t.sday * 86400 + t.ssec + CASE WHEN t.id % 19 = 0 THEN 3 * 86400 ELSE (5 + t.id % 50) * 60 END + k * 3600 < 121 * 86400;

-- click events: purchaser users turn some into 'purchase'
INSERT INTO ev_all
SELECT e.user_id, e.secs, e.seq, nm.name,
       CASE nm.name
         WHEN 'purchase' THEN jsonb_build_object('items',
              (SELECT jsonb_agg(jsonb_build_object('sku', (ARRAY['A1','B2','C3','D4','E5'])[1 + (e.h + k) % 5], 'qty', 1 + (e.h + k) % 3))
               FROM generate_series(1, 1 + e.h % 3) k),
              'coupon', CASE WHEN e.h % 4 = 0 THEN 'SPRING10' ELSE NULL END)
         WHEN 'page_view' THEN jsonb_build_object('page', (ARRAY['/home','/pricing','/docs','/blog','/pricing/team','/settings'])[1 + e.h % 6])
              || CASE WHEN e.h % 3 = 0 THEN jsonb_build_object('utm', jsonb_build_object('source', (ARRAY['ads','organic','email','social'])[1 + e.h % 4], 'campaign', (ARRAY['spring','launch','promo','x'])[1 + e.h % 4])) ELSE '{}'::jsonb END
              || CASE WHEN e.h % 5 = 0 THEN jsonb_build_object('referrer', NULL) ELSE '{}'::jsonb END
         WHEN 'feature_used' THEN jsonb_build_object('feature', (ARRAY['export','dashboard','alerts','api','share'])[1 + e.h % 5], 'duration_ms', 200 + e.h % 9000)
              || CASE WHEN e.h % 4 = 0 THEN jsonb_build_object('tags', jsonb_build_array('pro', (ARRAY['new','beta','legacy'])[1 + e.h % 3])) ELSE '{}'::jsonb END
         ELSE CASE e.h % 3 WHEN 0 THEN NULL WHEN 1 THEN '{}'::jsonb ELSE 'null'::jsonb END
       END,
       CASE WHEN e.h % 33 = 0 THEN NULL ELSE (ARRAY['web','ios','android','desktop'])[1 + (e.user_id * 3 + e.d / 14) % 4] END
FROM ev0 e
JOIN fu ON fu.id = e.user_id
CROSS JOIN LATERAL (SELECT CASE WHEN e.j = 0 THEN 'page_view'
                                WHEN fu.purchaser AND (e.j + e.d + e.user_id) % 3 = 0 THEN 'purchase'
                                WHEN (e.user_id + e.d + e.j) % 7 = 0 THEN 'logout'
                                WHEN (e.user_id + e.d + e.j) % 7 < 4 THEN 'page_view'
                                ELSE 'feature_used' END AS name) nm;

-- one guaranteed first purchase a day (+ id%24 hours) after signup for every purchaser (light users have few click days)
INSERT INTO ev_all
SELECT t.id, t.sday * 86400 + t.ssec + 86400 + (t.id % 24) * 3600, t.id * 1000000 - 3, 'purchase',
       jsonb_build_object('items', jsonb_build_array(jsonb_build_object('sku', (ARRAY['A1','B2','C3','D4','E5'])[1 + t.id % 5], 'qty', 1 + t.id % 3)),
                          'coupon', 'WELCOME'),
       (ARRAY['web','ios','android','desktop'])[1 + t.id % 4]
FROM tu t JOIN fu ON fu.id = t.id
WHERE fu.purchaser AND t.sday * 86400 + t.ssec + 86400 + (t.id % 24) * 3600 < 121 * 86400;

-- Probe events: midnight UTC, leap day, DST switches, range edges (only after the user's signup)
INSERT INTO ev_all
SELECT t.id, p.secs, t.id * 1000000 + 90000 + p.n, 'page_view', jsonb_build_object('page', '/home', 'probe', p.kind), 'web'
FROM tu t
JOIN users u ON u.id = t.id
JOIN (VALUES
  (1, 'dst', 'America/New_York',     (SELECT extract(epoch FROM TIMESTAMPTZ '2024-03-10 06:59:59+00' - TIMESTAMPTZ '2024-01-01 00:00:00+00'))::int),
  (2, 'dst', 'America/New_York',     (SELECT extract(epoch FROM TIMESTAMPTZ '2024-03-10 07:00:00+00' - TIMESTAMPTZ '2024-01-01 00:00:00+00'))::int),
  (3, 'dst', 'Europe/Berlin',        (SELECT extract(epoch FROM TIMESTAMPTZ '2024-03-31 00:59:59+00' - TIMESTAMPTZ '2024-01-01 00:00:00+00'))::int),
  (4, 'dst', 'Europe/Berlin',        (SELECT extract(epoch FROM TIMESTAMPTZ '2024-03-31 01:00:00+00' - TIMESTAMPTZ '2024-01-01 00:00:00+00'))::int),
  (5, 'dst', 'Pacific/Auckland',     (SELECT extract(epoch FROM TIMESTAMPTZ '2024-04-06 13:59:59+00' - TIMESTAMPTZ '2024-01-01 00:00:00+00'))::int),
  (6, 'dst', 'Pacific/Auckland',     (SELECT extract(epoch FROM TIMESTAMPTZ '2024-04-06 14:00:00+00' - TIMESTAMPTZ '2024-01-01 00:00:00+00'))::int)
) p(n, kind, tz, secs) ON p.tz = u.tz
WHERE t.id % 5 = 0 AND p.secs > t.sday * 86400 + t.ssec;

INSERT INTO ev_all
SELECT t.id, p.secs, t.id * 1000000 + 90100 + p.n, 'page_view', jsonb_build_object('page', '/home', 'probe', p.kind), 'web'
FROM tu t
JOIN (VALUES
  (1, 'midnight', (59 * 86400) - 1),            -- 2024-02-29 23:59:59 UTC
  (2, 'midnight', (59 * 86400)),                -- 2024-03-01 00:00:00 UTC
  (3, 'midnight', (59 * 86400) + 1)
) p(n, kind, secs) ON true
WHERE t.id % 20 = 0 AND p.secs > t.sday * 86400 + t.ssec;

INSERT INTO ev_all
SELECT t.id, p.secs, t.id * 1000000 + 90200 + p.n, 'feature_used', jsonb_build_object('feature', 'export', 'probe', 'range-edge'), 'desktop'
FROM tu t
JOIN (VALUES (1, 0), (2, 121 * 86400 - 1)) p(n, secs) ON true
WHERE t.id % 100 = 0 AND p.secs >= t.sday * 86400 + t.ssec;

INSERT INTO events (id, user_id, ts, name, props, device)
SELECT row_number() OVER (ORDER BY secs, user_id, seq), user_id,
       TIMESTAMPTZ '2024-01-01 00:00:00+00' + secs * INTERVAL '1 second', name, props, device
FROM ev_all;

INSERT INTO purchases (id, user_id, ts, amount, currency)
SELECT row_number() OVER (ORDER BY e.id), e.user_id, e.ts,
       (9 + (e.id * 37) % 300) + ((e.id * 11) % 100) / 100.0,
       (ARRAY['INR','USD','GBP','EUR','BRL','JPY','NZD','CAD'])[1 + e.user_id % 8]
FROM events e WHERE e.name = 'purchase' AND e.props ? 'items';

-- Subscriptions: first row for users with id%5 in (1,2,3); second row for those with id%4=0 (back-to-back or gap)
CREATE TEMP TABLE s1 AS
SELECT u.id AS user_id,
       CASE WHEN u.id % 2 = 0 THEN 'pro' ELSE 'team' END AS plan,
       (u.signup_at AT TIME ZONE 'UTC')::date + u.id % 10 AS started_on,
       (u.signup_at AT TIME ZONE 'UTC')::date + u.id % 10 + 20 + (u.id * 13) % 70 AS ended_on
FROM users u WHERE u.id % 5 IN (1, 2, 3);

INSERT INTO subscriptions (id, user_id, plan, started_on, ended_on)
SELECT row_number() OVER (ORDER BY user_id, n), user_id, plan, started_on, ended_on
FROM (
  SELECT s.user_id, 1 AS n, s.plan, s.started_on,
         CASE WHEN s.ended_on > DATE '2024-04-30' OR (s.user_id % 4 <> 0 AND s.user_id % 3 = 0) THEN NULL ELSE s.ended_on END AS ended_on
  FROM s1 s
  UNION ALL
  SELECT s.user_id, 2, CASE WHEN s.plan = 'pro' THEN 'team' ELSE 'pro' END,
         s.ended_on + CASE WHEN s.user_id % 8 = 0 THEN 1 ELSE 30 + s.user_id % 31 END,
         CASE WHEN (s.user_id / 4) % 3 = 0 THEN NULL
              ELSE s.ended_on + CASE WHEN s.user_id % 8 = 0 THEN 1 ELSE 30 + s.user_id % 31 END + 25 + s.user_id % 40 END
  FROM s1 s
  WHERE s.user_id % 4 = 0 AND s.ended_on + CASE WHEN s.user_id % 8 = 0 THEN 1 ELSE 30 + s.user_id % 31 END <= DATE '2024-04-30'
) q
-- second rows that would end in the future stay active (NULL)
;
UPDATE subscriptions SET ended_on = NULL WHERE ended_on > DATE '2024-04-30';

DROP TABLE tu; DROP TABLE ud; DROP TABLE ev0; DROP TABLE fu; DROP TABLE ev_all; DROP TABLE s1;
