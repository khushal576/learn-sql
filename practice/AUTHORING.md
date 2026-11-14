# Authoring guide — how a question is written (read this before adding any)

Questions are YAML files: `questions/<topic>/<id>-<slug>.yaml`. The tool (SQL Practice, Toolbox) loads them live; datasets are
`datasets/<name>/{schema.sql,seed.sql}` (read `schema.sql` of the dataset you use; **never edit a dataset** — if a trap cannot
bite on the existing data, change the question, not the data).

## Fields
```yaml
id: ag-002                      # prefix per topic, 3 digits; ids sort = the order the learner meets them (easy -> hard)
title: Short scenario title
topic: aggregation              # must be a folder name listed in questions/_path.yaml
tags: [group-by, "null"]        # QUOTE tags YAML would turn into values: "null", "yes", "no"
difficulty: easy                # easy | medium | hard | brutal
dataset: ecommerce              # ecommerce | hr | school | bank
prompt: |                       # markdown (**bold**, `code`, lists). A SCENARIO: a role + a business ask + the exact output spec
  ...Return `col_a`, `col_b`, ordered by ...
solution_sql: |                 # the reference answer: ONE read-only statement, deterministic, <= 500 rows
  SELECT ...
compare: {order_matters: true}  # true only if the prompt asks for an order (then ORDER BY must fully determine the order: add a tie-breaker)
                                # optional: decimals: 2 (numbers are compared after rounding to this many decimals; default 2)
hints:                          # 1-3 progressive hints, never the answer
  - "..."
trap: |                         # shown AFTER completion: the ONE mistake this question is built to catch, and why
followup: |                     # shown after completion: the interviewer's next question + a one-line answer
alternatives:                   # optional: 1-2 other correct ways to write it (SQL strings)
  - "SELECT ..."
```

## Rules (what makes a question good here)
1. **Scenario, not syntax.** "Marketing wants ..." / "Finance needs ..." — never "write a query that uses LEFT JOIN".
2. **One trap per question**, from medium up (easy ones may have none, but still need a plausible wrong answer). The trap must be a mistake
   people REALLY make and it must **bite on the actual data**: the tempting wrong query must return a *different* result. Prove it.
3. **Exact output spec**: name every output column (`AS total_pay`) and say the order. Columns must match by name AND order.
4. **Rounding**: numbers are compared after rounding to 2 decimals. If you ask for `round(x, 1)` the prompt must say "rounded to 1 decimal".
   Percentages: say whether 0-100 or 0-1. Avoid money columns that depend on float noise.
5. **Deterministic**: no `now()`, no `random()`; use a fixed "today" stated in the prompt (e.g. 2024-06-30). Ties -> explicit tie-breaker.
6. **Small results** (1-500 rows). Restrict scope in the prompt ("customers 1 to 30", "course 3") when the full answer would be large.
7. **Every claim in `trap`/`followup` with a number must be true** (e.g. "7 payments are lost") — check it with a real query.
8. Difficulty mix per batch roughly 25 % easy, 45 % medium, 30 % hard; ids ascend with difficulty.
9. Postgres 18 dialect. Learner SQL runs read-only as a restricted role, one statement, 10 s timeout.

## Testing (do all of this for every question)
Database for ad-hoc queries (set search_path to the dataset schema):
`docker exec -i toolbox-postgres-1 psql -U toolbox -d practice -At -c "SET search_path=ecommerce; SELECT ..."`

1. Reference check — the tool validates every solution (runs, returns rows, deterministic, <= 500 rows):
   `curl -s localhost:8000/tools/sql-practice/validate | python3 -m json.tool | head -50`
2. Trap check — add an entry per question to YOUR OWN file `tools/traps_<batch>.yaml`:
   ```yaml
   ag-002:
     wrong: |      # the tempting mistake; must FAIL Check
       SELECT ...
     right: |      # a DIFFERENTLY written correct answer (not a copy of solution_sql); must PASS Check
       SELECT ...
   ```
   then run `python3 tools/check_traps.py <id> <id> ...` (from learn-sql/practice). It must print "wrong answer rejected: True / alternative correct answer accepted: True".
   The runner resets the questions it tests. It skips any question that already has progress — **never reset or edit the progress of other questions**.
3. Do NOT touch: datasets, other batches' questions/trap files, `_path.yaml`, the Toolbox code.
