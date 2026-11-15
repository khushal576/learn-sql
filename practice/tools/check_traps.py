#!/usr/bin/env python3
"""Regression test for the question bank: for every question listed in tools/traps*.yaml,
  * the TEMPTING WRONG answer (`wrong`) must FAIL Check, and
  * a differently written CORRECT answer (`right`) must PASS Check.
It talks to the running SQL Practice tool over HTTP and never touches progress you have already made: a question whose
status is not "new" is skipped (and every question it tests is reset to "new" afterwards).

    python3 tools/check_traps.py                 # all questions
    python3 tools/check_traps.py ag-003 wf-019   # only these
    TOOLBOX_URL=http://localhost:8000 python3 tools/check_traps.py
Mock-interview questions (questions/mock-interviews/) are tested the same way: the checker starts the set, checks, resets, and discards its test run.
Also runs the authoring validator (GET /validate): every reference answer must run, return rows, be deterministic.
"""
import json, os, sys, urllib.request
from pathlib import Path

import yaml

BASE = os.environ.get("TOOLBOX_URL", "http://localhost:8000").rstrip("/") + "/tools/sql-practice/"


def call(path, body=None, post=False):
    data = json.dumps(body if body is not None else {}).encode() if (post or body is not None) else None
    req = urllib.request.Request(BASE + path, data=data, method="POST" if data is not None else "GET", headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        return json.load(e)


def main(only):
    traps = {}
    for f in sorted(Path(__file__).parent.glob("traps*.yaml")):      # traps.yaml + one traps_<batch>.yaml per authoring batch
        traps.update(yaml.safe_load(f.read_text()) or {})
    known = {q["id"]: q for q in call("questions")["questions"]}
    mock_of = {}                                    # mock questions are not in /questions: they live in sets (need a running clock to Check)
    for q in call("mocks/questions")["questions"]:
        known[q["id"]] = q; mock_of[q["id"]] = q["set_id"]
    in_progress = {s["id"] for s in call("mocks")["sets"] if s["status"] == "in_progress"}
    problems = 0
    v = call("validate")
    for q in v["questions"]:
        if not q["ok"]:
            problems += 1
            print(f"VALIDATE  {q['id']}: {q['problems']}")
    for m in v.get("mocks", []):
        if not m["ok"]:
            problems += 1
            print(f"VALIDATE  mock set {m['id']}: {m['problems']}")
    print(f"validate: {'all reference answers OK' if v['ok'] else 'PROBLEMS above'}  ({len(v['questions'])} questions)")
    missing = sorted(set(known) - set(traps))
    if missing and not only:
        print(f"note: no trap test yet for: {', '.join(missing)}")
    for qid, t in traps.items():
        if only and qid not in only:
            continue
        if qid not in known:
            print(f"{qid}: not found in the tool (stale entry?)"); problems += 1; continue
        if qid in mock_of and mock_of[qid] in in_progress:
            print(f"{qid}: skipped (its mock interview is running)"); continue
        if qid not in mock_of and known[qid]["status"] != "new":
            print(f"{qid}: skipped (you have progress on it)"); continue
        run_id = None
        try:
            if qid in mock_of:                       # start the set's clock for the test, throw the run away afterwards
                run_id = call(f"mocks/{mock_of[qid]}/start", post=True)["run"]["id"]
            w = call("check", {"id": qid, "sql": t["wrong"]}); r = call("check", {"id": qid, "sql": t["right"]})
        finally:
            call(f"questions/{qid}/reset", post=True)
            if run_id is not None:
                call(f"mocks/runs/{run_id}/discard", post=True)
        w_ok, r_ok = w.get("correct") is False, r.get("correct") is True
        if not (w_ok and r_ok):
            problems += 1
        print(f"{qid:8} wrong answer rejected: {w_ok!s:5}  alternative correct answer accepted: {r_ok!s:5}"
              + ("" if w_ok else "  <- WRONG ANSWER WAS ACCEPTED")
              + ("" if r_ok else f"  <- {r.get('error') or r.get('reason') or ('missing', r.get('missing_total'), 'extra', r.get('unexpected_total'), 'cells', r.get('cell_diffs_total'))}"))
    print("PROBLEMS:", problems)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(set(sys.argv[1:])))
