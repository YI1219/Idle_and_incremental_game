"""Tidy the 2026-11-21 reverse-stagger package. Run from the project root. Safe to run again."""
import hashlib, json, shutil, subprocess
from pathlib import Path
ROOT = Path(".")
PKG = ROOT / "art/lookdev/20261121_reverse_stagger"
BEFORE = PKG / "checks/source_before"
changed = []
for before in sorted(BEFORE.rglob("*")):
    if not before.is_file():
        continue
    rel = before.relative_to(BEFORE)
    if rel.parts[0] == "scripts":
        now = ROOT / "scripts/terrain_editor" / rel.name
    elif rel.parts[0] == "shaders":
        now = ROOT / "shaders/terrain_editor" / rel.name
    else:
        now = ROOT / rel.name
    if not now.exists() or now.read_bytes() != before.read_bytes():
        changed.append(str(now))
print("changed since task start:", changed)
assert changed == ["scripts/terrain_editor/terrain_decoration.gd"], changed
rel = "scripts/terrain_editor/terrain_decoration.gd"
patch = subprocess.run(["diff", "-u", str(BEFORE / "scripts/terrain_decoration.gd"), rel], capture_output=True, text=True).stdout
(PKG / "checks/production.patch").write_text(patch)
(PKG / "checks/final_sha256.txt").write_text(f"{hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()}  {rel}\n")
print("patch lines", patch.count("\n"), "added", sum(1 for l in patch.splitlines() if l.startswith("+") and not l.startswith("+++")), "removed", sum(1 for l in patch.splitlines() if l.startswith("-") and not l.startswith("---")))
trials = PKG / "checks/trial_logs"
trials.mkdir(exist_ok=True)
for name in ("suite_v4.json", "suite_v4.log"):
    f = PKG / "checks" / name
    if f.exists():
        f.rename(trials / name)
for folder in sorted((PKG / "diag").iterdir()):
    if folder.is_dir() and folder.name not in ("before", "after"):
        shutil.rmtree(folder)
rows = []
labels = {"7301": "seed 7301 preset 0", "2104": "seed 2104 preset 0", "4242": "seed 4242 preset 1", "913": "seed 913 preset 2"}
for seed, label in labels.items():
    b = json.loads((PKG / f"diag/before/metric_{seed}.json").read_text())
    a = json.loads((PKG / f"diag/after/metric_{seed}.json").read_text())
    rows.append([label, "%d slabs, %.1f m" % (b["longest_plain_row"]["slabs"], b["longest_plain_row"]["length_m"]),
                 "%d slabs, %.1f m" % (a["longest_plain_row"]["slabs"], a["longest_plain_row"]["length_m"]), "%d → %d" % (b["masses"], a["masses"])])
page = (PKG / "compare.html").read_text()
start = page.index("/*METRIC*/")
end = page.index("/*END*/")
page = page[:start] + "/*METRIC*/" + json.dumps(rows, ensure_ascii=False) + page[end:]
(PKG / "compare.html").write_text(page)
print(rows)
suite = json.loads((PKG / "checks/suite.json").read_text())
print("suite", suite["ran"], suite["failed"])
missing = [f"{s}/{c}.png" for s in ("final", "final_night", "final_held2104", "final_held4242", "final_held913") for c in ("foot_reverse", "reverse", "side_286", "side_106", "whole", "game", "close", "cliff_close", "foot_front", "overview", "terrace_close", "outer_hull") if not (PKG / s / f"{c}.png").exists() or not (ROOT / "art/lookdev/20261121_cliff_water" / s / f"{c}.png").exists()]
print("missing images for compare page:", missing)
