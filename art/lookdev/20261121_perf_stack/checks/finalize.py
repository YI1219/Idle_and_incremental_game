"""Tidy the 2026-11-21 perf-stack package. Run from the project root. Safe to run again."""
import hashlib, subprocess
from pathlib import Path
ROOT = Path(".")
PKG = ROOT / "art/lookdev/20261121_perf_stack"
BEFORE = PKG / "checks/source_before"
FILES = {"preview_quality.gd": "scripts/terrain_editor/preview_quality.gd", "editor.gd": "scripts/terrain_editor/editor.gd",
         "shihai_hud.gd": "scripts/gameplay/ui/shihai_hud.gd", "preview_quality_test.gd": "tests/preview_quality_test.gd"}
stale = BEFORE / "water_renderer.gd"
if stale.exists():
    assert stale.read_bytes() == (ROOT / "scripts/terrain_editor/water_renderer.gd").read_bytes()
    stale.unlink()  # copied as a precaution, never changed
patch, lines = [], []
for name, rel in FILES.items():
    out = subprocess.run(["diff", "-u", str(BEFORE / name), rel], capture_output=True, text=True).stdout
    assert out, rel
    patch.append(out)
    lines.append(f"{hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()}  {rel}")
new = "tools/perf/bench_presets.gd"
lines.append(f"{hashlib.sha256((ROOT / new).read_bytes()).hexdigest()}  {new}  (new file)")
(PKG / "checks/production.patch").write_text("".join(patch))
(PKG / "checks/final_sha256.txt").write_text("\n".join(lines) + "\n")
text = "".join(patch)
print("patch: +%d -%d lines over %d files" % (sum(1 for l in text.splitlines() if l.startswith("+") and not l.startswith("+++")), sum(1 for l in text.splitlines() if l.startswith("-") and not l.startswith("---")), len(FILES)))
# The stagger package's file must be untouched by this slice.
want = (ROOT / "art/lookdev/20261121_reverse_stagger/checks/final_sha256.txt").read_text().split()[0]
assert hashlib.sha256((ROOT / "scripts/terrain_editor/terrain_decoration.gd").read_bytes()).hexdigest() == want
print("terrain_decoration.gd unchanged since the stagger package")
