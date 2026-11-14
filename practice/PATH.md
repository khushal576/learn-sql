# SQL interview practice path

Goal: crack SQL interviews (Postgres flavour) with depth. About 220 scenario questions in the order you should do them.
Built on your own notes: `sql/chp*.sql` (each stage names its chapters — read the chapter first, then do the stage).
The practice tool is `SQL Practice` in Toolbox; questions live in `questions/<topic>/<id>.yaml`.

## How every question is written

- **Scenario, not syntax.** A role and a business ask: *"You're the analyst at an online shop. Marketing wants the 3 highest-spending customers in each country for a loyalty campaign…"*
- **One trap per question** (ties, NULLs, double counting, time zones, empty groups, default window frame…). Easy ones have no trap, from medium up every question has one.
- **A fixed output shape** (column names and order) so the answer can be compared automatically.
- **After you solve it** the tool shows: the trap, the interviewer's follow-up ("what if two employees tie?", "what if the table had 1 billion rows?"), and 1–2 alternative solutions.
- **Mix per topic:** 25 % easy · 40 % medium · 25 % hard · 10 % brutal.

## The path (do the stages in order)

| # | Stage | Notes chapters | Qs | What it drills (the interview traps) | Datasets |
|---|---|---|---|---|---|
| 0 | Warm-up: select basics | chp1, chp2 | 12 | NULL logic (`= NULL`, `NOT IN` with NULLs), BETWEEN is inclusive, LIKE/ILIKE, CASE, DISTINCT ON, NULLS FIRST | ecommerce, hr |
| 1 | Joins and set operations | chp3 | 20 | anti-join (3 ways), **fan-out double counting**, self-join (employee vs manager), non-equi join, FULL JOIN reconciliation, LATERAL, UNION vs UNION ALL, EXCEPT/INTERSECT | ecommerce, hr, school |
| 2 | Aggregation | chp7, chp11 | 20 | COUNT(*) vs COUNT(col) vs COUNT(DISTINCT), HAVING vs WHERE, FILTER / conditional aggregation, % of total, **average of averages**, ROLLUP/GROUPING SETS, pivot, median/percentile | ecommerce, bank |
| 3 | Subqueries | chp12 | 16 | correlated subquery, EXISTS vs IN, scalar subquery returning 2 rows, **"customers who bought ALL products" (relational division)**, 2nd/Nth highest | school, ecommerce |
| 4 | Window functions | chp10 | 30 | ROW_NUMBER vs RANK vs DENSE_RANK, **top-N per group with ties**, running totals, moving average, LAG/LEAD (month-over-month), **default frame trap** (RANGE vs ROWS, LAST_VALUE), NTILE, dedupe keep latest | ecommerce, hr, bank |
| 5 | CTEs and recursion | chp9 | 18 | chained CTEs, org-chart depth and path, category tree, bill of materials, graph reachability with **cycle protection**, generate_series calendars (fill missing days) | hr, ecommerce, logistics |
| 6 | Dates and strings | chp6, chp8 | 16 | month/week boundaries, DATE_TRUNC, **timezone traps**, age, business days, regex extraction, STRING_AGG ordering, last day of month, "last 30 days" off-by-one | events, ecommerce |
| 7 | **Interview patterns** | chp25 | 30 | gaps and islands, **sessionization**, longest streak, funnel conversion, **retention cohorts**, merge overlapping intervals, running balance, median, rolling distinct users, histogram buckets | events, bank, hotel |
| 8 | Data modelling queries | chp4, chp5 | 10 | what-would-change SELECTs for UPDATE/DELETE/UPSERT (see doubt 1), find duplicates, orphan rows, schema/metadata queries | ecommerce |
| 9 | JSONB and arrays | chp17, chp23 | 12 | extract/aggregate JSON, `->` vs `->>`, jsonb_array_elements, unnest, array_agg, ranges | events, ecommerce |
| 10 | Performance reasoning | chp13, chp21 | 14 | read a plan, pick the right index, sargable rewrites, `NOT IN` vs `NOT EXISTS`, covering index (see doubt 2) | ecommerce (large) |
| 11 | **Mock interviews** | all | 25 sets | 3 chained scenario questions in 45 minutes, one business domain per set | all |

Total ≈ 220 questions + 25 mock sets. Spend most of your time on stages 4, 7 and 11: these are what interviewers actually ask.

## How to work through it

1. Read the stage's notes chapter once (not the whole thing, only the parts it lists).
2. Do the stage's questions **in id order**. Timebox: 20 min easy/medium, 30 min hard. Use hints one at a time.
3. Move to the next stage when you solve **80 % of it without the solution** (the tool will track this).
4. Questions you needed the solution for come back after 3 days and again after 10 days (revisit queue).
5. Finish each stage with its 2 "brutal" questions as a test. Stage 11 is the real rehearsal.

## Datasets to add (2 exist)

| Dataset | Tables (main) | Why |
|---|---|---|
| `ecommerce` ✅ | customers, orders, order_items, payments, reviews, categories tree | joins, aggregation, windows |
| `hr` ✅ | employees (manager tree), departments, salary_history, projects | self-join, recursion, windows |
| `school` | students, courses, enrollments, scores, teachers | ranking, division ("all courses"), Nth highest |
| `bank` | customers, accounts, transactions, loans | running balance, fraud-style patterns |
| `events` | users, sessions, events, subscriptions | sessionization, funnel, retention |
| `hotel` | rooms, guests, bookings (date ranges) | overlapping intervals, availability |
| `logistics` | trips, drivers, riders, locations, payments | recursion (routes), time series, percentiles |

## Build plan — small steps, one at a time

Rule: **I build ONE step, you test it, I fix what you found, and only then the next step starts.** Nothing is built "all in one".
Every question of a step is checked by `/validate` (runs, returns rows, same rows twice) and gets a trap review (is it really tricky?).

| Step | What | Qs | New dataset | Status |
|---|---|---|---|---|
| 1 | The tool: Check with DataDiff, ✓ marks, hide completed, keep order, sample output, solution + trap after completing | 6 samples | — | ✅ done |
| 2 | Stage 0 — select basics (NULLs, BETWEEN, LIKE, CASE, DISTINCT ON) | 12 | — | ✅ done |
| 3 | Stage 1 — joins and set operations | 20 | `school` | ✅ done |
| 4 | Stage 2 — aggregation | 20 | `bank` | ✅ done |
| 5 | Stage 3 — subqueries (correlated, EXISTS, relational division) | 16 | — | ✅ done |
| 6 | Stage 4a — window functions I: ranking, top-N per group, dedupe | 15 | — | ✅ done |
| 7 | Stage 4b — window functions II: running totals, LAG/LEAD, frames | 15 | — | ✅ done |
| 8 | Tool: revisit queue (3-day / 10-day) + a "weak topics" view | — | — | next |
| 9 | Stage 5 — CTEs and recursion | 18 | `logistics` | |
| 10 | Stage 6 — dates and strings | 16 | `events` | |
| 11 | Stage 7a — interview patterns I: gaps and islands, streaks, sessionization | 15 | — | |
| 12 | Stage 7b — interview patterns II: funnels, retention, overlapping intervals | 15 | `hotel` | |
| 13 | Stages 8 + 9 — data-modelling queries, JSONB and arrays | 22 | — | |
| 14 | Stage 10 — performance reasoning (+ a plan-based check) | 14 | — | |
| 15 | Stage 11a — mock interviews 1-12 (+ a 45-minute timer mode) | 12 sets | — | |
| 16 | Stage 11b — mock interviews 13-25 | 13 sets | — | |

About 16 small steps. Step 8 is next (the revisit queue), then step 9. The warm-up (step 2) is there so you can judge the style (scenario, trap, follow-up) before the rest is written.

## Adding or changing questions

Read `AUTHORING.md` first. Every question needs a tempting wrong answer and a differently written correct answer in `tools/traps*.yaml`;
`python3 tools/check_traps.py` runs them all against the running tool (it also runs the validator) and never touches your own progress.
