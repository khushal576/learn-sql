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


## PLAN-BASED CHECK (`check: {type: plan}`) — for performance-reasoning questions
Use when the point of a question is HOW the database answers, not only what it returns (index vs full scan, sargable predicates, anti joins).
```yaml
check:
  type: plan
  must_use: ["Index Scan|Index Only Scan|Bitmap Index Scan"]   # each entry satisfied if ANY '|' alternative matches; ALL entries needed
  must_not_use: ["Seq Scan on orders"]                           # none of these may appear in the plan
  note: "must be answered through an index"                      # optional: what the page tells the learner (default: generic words)
```
**How it is evaluated.** Check still compares the RESULT with the reference (unchanged). Additionally the learner's query goes through `EXPLAIN (FORMAT JSON)` (NO ANALYZE: planned, never executed) as the same restricted read-only role, in the same rolled-back transaction with the dataset's search_path. Every node of the whole tree (Plans recursively, SubPlans, nodes under Gather) is collected. An entry alternative matches a node when
- `X` : the node's `Node Type` equals X (case-insensitive), e.g. `Index Scan`, `Hash Join`, `Bitmap Index Scan`;
- `X on rel` : Node Type is X and `Relation Name` is rel, e.g. `Seq Scan on orders`;
- `Anti Join` / `Semi Join` : any join node whose `Join Type` contains Anti / Semi (Postgres may print "Right Anti").
Answer is correct only if the result matches AND all rules hold. The verdict shows which rule failed ("Your plan scans orders sequentially ...") and the plan tree (node, relation, index, estimated rows) for pass and fail. The reference SQL is NOT subject to the rules (but should satisfy them: test it). A syntax/EXPLAIN error is not an attempt. The page shows only a general line ("This question also checks your query plan: ..."), never your node names; write `note:` to control it. Every question (plan or not) has an **Explain** button.
**Authoring tips.** Test plans with `curl -s -XPOST localhost:8000/tools/sql-practice/explain -H 'content-type: application/json' -d '{"dataset":"perf","sql":"SELECT ..."}'` (returns `node_types` and `text`). Postgres picks plans from statistics: on selective lookups it often prints `Bitmap Heap Scan` + `Bitmap Index Scan` instead of `Index Scan`, so list all index alternatives. Seq Scan can sit under a Gather. Only use rules that hold with a wide margin (an index lookup of ~10 rows in 300k, not 15 % of the table); datasets end with `VACUUM ANALYZE` so Index Only Scan is possible.
**Trap tests (`tools/traps_<batch>.yaml`)** use the same `wrong`/`right` pair: `wrong` = a result-correct query with a bad plan (e.g. `WHERE customer_id + 0 = 42`, `lower(col)` without a matching expression index, a leading-wildcard LIKE) OR a plan-correct query with the wrong result; `right` = a differently written query with the right result AND a good plan. `python3 tools/check_traps.py <id>` verifies both.


---

# MOCK INTERVIEW SETS

A mock interview is a **45-minute timed set of 3 chained questions** told as one business story. The tool (🎯 Mock interviews) keeps the clock on the server; no "give up" button; solutions open when a question is solved, and all of them when the run ends.

## Files
* Questions: ordinary question YAML in `questions/mock-interviews/mk-NNN-<slug>.yaml` — ids `mk-001`, `mk-002`, ... , **`topic: mock-interviews`**, all the usual fields (`prompt`, `solution_sql`, `compare`, `hints`, `trap`, `followup`, `dataset`, `difficulty`, `check`...). They never appear in the normal list / path / progress counts. `_path.yaml` needs no change.
* Sets: `questions/_mocks.yaml` (not a question file):

```yaml
sets:
  - id: mock-01                     # lowercase letters, digits, dashes; unique
    title: "Marketplace analyst — loyalty programme"
    domain: ecommerce               # free text: the business domain
    minutes: 45                     # whole number > 0
    intro: |                        # markdown: the interviewer's framing — the story that chains the 3 questions
      ...
    questions: [mk-001, mk-002, mk-003]   # EXACTLY 3 existing ids, in the order they are asked; a question belongs to one set only
```
`GET /validate` (and `tools/check_traps.py`) report problems per set: unknown/duplicate ids, minutes <= 0, missing title/intro, mock questions that are in no set.

## Rules for a good set
1. **One story, three steps of rising difficulty**: easy (~10 min) -> medium (~15 min) -> hard (~20 min). Set `difficulty` on each question accordingly.
2. The `intro` is the interviewer talking: who you are, what the business wants, and why the three asks follow from each other. Each question's `prompt` may refer to the story ("Following up on the loyalty tiers...") but must be **independently solvable and checkable** — never depend on the learner's answer to an earlier question.
3. **Mixed topics** across the three (e.g. a join/filter, an aggregation or window function, then a harder pattern such as gaps-and-islands, recursive CTE or a tricky NULL/anti-join); one dataset per question, usually the same dataset for the whole set.
4. Same quality rules as every question: deterministic reference (full ORDER BY or `compare` unordered), expected columns obvious from the prompt, a real `trap`, an interviewer `followup`, 2-3 `hints` (hints ARE available during the run; they are the learner's choice).
5. **Trap pairs are mandatory** exactly as for normal questions: `tools/traps_mocks*.yaml` (your own file per batch, never someone else's), one entry per mock question id with a tempting `wrong` and a differently written `right`. `tools/check_traps.py` tests mock questions by starting the set's clock, checking, resetting and discarding that test run (it skips a set that someone is currently taking).
6. Check your work: `python3 tools/check_traps.py mk-001 mk-002 mk-003` (PROBLEMS: 0) and `curl localhost:8000/tools/sql-practice/validate` (the `mocks` entry for your set must be ok).
