-- SaaS product-analytics dataset. All event times are 2024-01-01 00:00 UTC .. 2024-04-30 23:59:59 UTC.
--
-- users: ~800 rows. The TEXT IS MESSY ON PURPOSE (string-cleaning questions):
--   * email   : mixed case (lower / Initcap / UPPER); some rows have a leading or trailing space. lower(trim(email)) is unique.
--   * full_name: double spaces between words, all-lower / ALL-UPPER / normal case, some with leading/trailing spaces.
--   * phone   : 5 formats ('+91 98765 43210', '(555) 123-4567', '555.123.4567', '5551234567', '+1 555 123 4567',
--               '555 123 4567'); ~1 in 7 is NULL.
--   * tags    : text[] with 1-4 tags, some EMPTY arrays ('{}'), some NULL (NULL is not the same as empty). The tag 'Beta'
--               and 'beta' both exist (case matters).
--   * tz      : IANA names: Asia/Kolkata, America/New_York, America/Los_Angeles, Europe/London, Europe/Berlin,
--               America/Sao_Paulo, Asia/Tokyo, Pacific/Auckland, America/Toronto.
--   * signup_at: spread over the first ~100 days; a few exactly at 00:00:00 UTC or 23:59:59 UTC (day-boundary cases).
CREATE TABLE users (
  id        int PRIMARY KEY,
  email     text NOT NULL,
  full_name text NOT NULL,
  country   text NOT NULL,
  tz        text NOT NULL,
  plan      text NOT NULL CHECK (plan IN ('free', 'pro', 'team')),
  signup_at timestamptz NOT NULL,
  tags      text[],
  phone     text
);

-- events: ~25k clickstream rows. id is assigned in (ts, user_id) order.
--   * Users act in SESSIONS: bursts of events separated by a gap. Gaps between consecutive events of a user are mostly
--     20-300 seconds; session breaks are 1799, 1800 (exactly 30 min), 1801, 2700, 3600 or 7200 seconds, so
--     "gap > 30 min" and "gap >= 30 min" give different session counts.
--   * Ties: several events of one user share the IDENTICAL ts (about 3% of events), so ORDER BY ts needs a tie-break.
--   * Some activity runs across midnight UTC (23:40 start); explicit probe events sit around 2024-02-29/03-01 midnight
--     UTC, and around DST changes: America/New_York 2024-03-10 07:00 UTC, Europe/Berlin 2024-03-31 01:00 UTC,
--     Pacific/Auckland 2024-04-06 14:00 UTC (props.probe = 'dst' / 'midnight' / 'range-edge'). Those probes exist only
--     for users whose signup_at is earlier than the probe.
--   * Every user has exactly one 'signup' event at users.signup_at. FUNNEL: ~60% have 'activated', ~28% have 'purchase'.
--     Some users have 'purchase' BEFORE 'activated' (activated delayed 3 days), some have 'activated' twice, and a few
--     purchased without ever activating (steps skipped / out of order / repeated).
--   * DAILY STREAKS: a third of the users are 'engaged': active on runs of 3-12 consecutive UTC days, separated by
--     2-7 idle days, 1-4 runs each. The rest return weekly a few times or never (retention cohorts by signup week).
--   * props jsonb: nested objects and arrays, keys that are sometimes missing, JSON null values
--     (e.g. "referrer": null  is different from a missing key), a few props that are the JSON value null
--     ('null'::jsonb, not SQL NULL), some '{}' and some SQL NULL.
--       signup      {"utm": {"source","campaign"} (sometimes absent), "referrer": text|null}
--       activated   {"method": "email"|"sso"}
--       page_view   {"page": "/pricing"..., "utm": {...} (sometimes absent), "referrer": null (sometimes)}
--       feature_used {"feature": ..., "duration_ms": int, "tags": [..] (sometimes)}
--       purchase    {"items": [{"sku","qty"}, ...], "coupon": text|null}
--       logout      NULL, '{}' or 'null'::jsonb
--   * device is NULL for ~3% of events.
CREATE TABLE events (
  id      int PRIMARY KEY,
  user_id int NOT NULL REFERENCES users (id),
  ts      timestamptz NOT NULL,
  name    text NOT NULL,
  props   jsonb,
  device  text
);

-- subscriptions: ended_on NULL = still active. Some users have two rows: back-to-back (second starts the day after the
-- first ends) or with a GAP of 30-60 days between them.
CREATE TABLE subscriptions (
  id         int PRIMARY KEY,
  user_id    int NOT NULL REFERENCES users (id),
  plan       text NOT NULL CHECK (plan IN ('free', 'pro', 'team')),
  started_on date NOT NULL,
  ended_on   date
);

-- purchases: one row per 'purchase' event (same user_id and ts), so events and purchases can be joined on (user_id, ts).
CREATE TABLE purchases (
  id       int PRIMARY KEY,
  user_id  int NOT NULL REFERENCES users (id),
  ts       timestamptz NOT NULL,
  amount   numeric(10,2) NOT NULL,
  currency text NOT NULL
);

CREATE INDEX ON events (user_id, ts);
CREATE INDEX ON events (name, ts);
CREATE INDEX ON subscriptions (user_id);
CREATE INDEX ON purchases (user_id, ts);
