#!/usr/bin/env python3
"""Re-run the regression list recorded by the previous cliff round.

Reads art/lookdev/20261114_cliff_optimization/checks/cases.json for the test
paths and their headless/native mode, runs each with the same mode, and writes
OUT (default: suite.json beside this script).
Usage: python3 run_suite.py [--out FILE] [--only substring]
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path("/Users/yi/Projects/games/the-scroll-within")
GODOT = "/opt/homebrew/bin/godot"
CASES = ROOT / "art/lookdev/20261114_cliff_optimization/checks/cases.json"


def main() -> int:
    out = Path(__file__).with_name("suite.json")
    only = ""
    args = sys.argv[1:]
    while args:
        flag = args.pop(0)
        if flag == "--out":
            out = Path(args.pop(0))
        elif flag == "--only":
            only = args.pop(0)
    power = subprocess.run(["pmset", "-g", "batt"], capture_output=True, text=True).stdout
    if "AC Power" not in power:
        print("NOT ON AC POWER - refusing to run")
        return 2
    cases = json.loads(CASES.read_text())
    results = []
    failed = 0
    for case in cases:
        test = case["test"]
        if only and only not in test:
            continue
        command = [GODOT, "--path", str(ROOT)] + (["--headless"] if case["headless"] else []) + ["--script", "res://" + test]
        started = time.time()
        try:
            run = subprocess.run(command, capture_output=True, text=True, timeout=240)
            rc = run.returncode
            text = (run.stdout + run.stderr).strip()
        except subprocess.TimeoutExpired as error:
            rc = -9
            text = ((error.stdout or b"").decode(errors="replace") if isinstance(error.stdout, bytes) else (error.stdout or "")) + "\nTIMEOUT"
        lines = [line for line in text.splitlines() if line.strip()]
        errors = [line for line in lines if "SCRIPT ERROR" in line or line.startswith("ERROR")]
        tail = lines[-1] if lines else ""
        ok = rc == 0
        failed += 0 if ok else 1
        results.append({"test": test, "headless": case["headless"], "rc": rc, "duration_s": round(time.time() - started, 2), "tail": tail[-300:], "error_lines": errors[:12], "previous_rc": case.get("rc")})
        print(("PASS " if ok else "FAIL ") + f"{test} rc={rc} {tail[-150:]}")
        if not ok:
            for line in errors[:10]:
                print("    " + line[:220])
    out.write_text(json.dumps({"ran": len(results), "failed": failed, "results": results}, indent=1) + "\n")
    print(f"SUITE ran={len(results)} failed={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
