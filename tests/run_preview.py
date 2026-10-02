#!/usr/bin/env python3
"""Run a Godot script against this project. Does not touch player saves."""
from pathlib import Path
import argparse
import subprocess

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("script")
parser.add_argument("--headless", action="store_true")
parser.add_argument("--interactive", action="store_true")
parser.add_argument("--resolution", default="1280x720")
parser.add_argument("--script-arg", action="append", default=[])
args = parser.parse_args()

command = [
    "godot", "--path", str(root), "--log-file", str(root / ".godot" / "preview.log"),
    "--resolution", args.resolution, "--script", args.script,
]
if not args.interactive:
    command.extend(["--fixed-fps", "60"])
if args.headless:
    command.append("--headless")
if args.script_arg:
    command.extend(["--", *args.script_arg])
raise SystemExit(subprocess.run(command, timeout=None if args.interactive else 180).returncode)
