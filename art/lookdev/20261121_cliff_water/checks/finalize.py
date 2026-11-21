"""Tidy the 2026-11-21 lookdev package and record the session in CURRENT_CONTEXT.md.

Run from the project root. Touches only files this session created, plus one
section at the top of CURRENT_CONTEXT.md. Safe to run again.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(".")
PKG = ROOT / "art/lookdev/20261121_cliff_water"
BEFORE = PKG / "checks/source_before"
FILES = [
    "scripts/terrain_editor/preview_quality.gd",
    "scripts/terrain_editor/procedural_shard.gd",
    "shaders/terrain_editor/cliff.gdshader",
    "shaders/terrain_editor/cliff_column.gdshader",
    "shaders/terrain_editor/stone_surface.gdshaderinc",
    "shaders/terrain_editor/water.gdshader",
    "shaders/terrain_editor/waterfall.gdshader",
]

# Nothing else under scripts/terrain_editor or shaders/terrain_editor may differ
# from the task start.
changed = []
for before in sorted(BEFORE.rglob("*")):
    if before.is_file() and "root" not in before.relative_to(BEFORE).parts[:1]:
        rel = before.relative_to(BEFORE)
        now = ROOT / rel
        if not now.exists() or now.read_bytes() != before.read_bytes():
            changed.append(str(rel))
assert sorted(changed) == sorted(FILES), changed

lines, patch = [], []
for rel in FILES + ["project.godot"]:
    before = BEFORE / ("root/project.godot" if rel == "project.godot" else rel)
    lines.append(f"{hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()}  {rel}")
    patch.append(subprocess.run(["diff", "-u", str(before), rel], capture_output=True, text=True).stdout)
(PKG / "checks/final_sha256.txt").write_text("\n".join(lines) + "\n")
(PKG / "checks/production.patch").write_text("".join(patch))

# Working probes: keep the tinted generator view, drop the intermediate renders.
for folder in sorted((PKG / "diag").iterdir()):
    if folder.is_dir() and folder.name != "parts_start":
        shutil.rmtree(folder)
trials = PKG / "checks/trial_logs"
trials.mkdir(exist_ok=True)
for pattern in ("veil*.log", "water*.log", "brush*.log", "relief?.log", "trim*.log", "sheen*.log", "suite_pass1.*", "suite_water_recheck.*"):
    for log in (PKG / "checks").glob(pattern):
        log.rename(trials / log.name)
stale = PKG / "checks/patch_veil.py"  # superseded first draft; production.patch is the record
if stale.exists():
    stale.unlink()

suite = json.loads((PKG / "checks/suite.json").read_text())
print("suite", suite["ran"], suite["failed"])
for name in ("final", "final_held2104", "final_held4242", "final_held913", "final_night"):
    report = json.loads((PKG / name / "captures.json").read_text())
    print(name, len(report["captures"]), report["valid"], report["errors"])

context = ROOT / "CURRENT_CONTEXT.md"
text = context.read_text(encoding="utf-8")
marker = "## 2026-11-20 to 21 sessions (English)"
section = marker + """

Wave brief from the user, 2026-11-20 (outranks older notes below): performance is first-class, the world must run cheaply on low-end devices and as a hung wallpaper without giving up the current beauty or the classical Chinese atmosphere; palette stays warm mist / olive grass / soft grey stone; major cliff faces were plain and paper-flat, undersides stepped and shelf-like, water and falls stiff and paper-like. Wrap GPU work in `tools/perf/gpu_run.sh` (send its output to a log file, a pipe waits out the whole timeout). No paid Tripo.

Work landed in the worktree (all uncommitted, none art-accepted, target laptops unmeasured):

- Cliff presence, `art/lookdev/20261120_cliff_presence/` (`README.md`): `stone_cliff_character()` in `stone_surface.gdshaderinc` (plates, fissures, mossy brow on steep faces), blunt level slab feet in `procedural_shard.gd`, and `tier1_frac = 1.0` in `terrain_decoration.gd`. Reviewed 2026-11-21: bottoms calmer but still a stepped dark skirting; shaded faces read as streaked concrete.
- Root veil, brushed faces, pond and waterfall, `art/lookdev/20261121_cliff_water/` (`compare.html`, `README.md`): five shaders, `procedural_shard.gd`, `preview_quality.gd`, one global in `project.godot`.
  - Root veil in `stone_surface.gdshaderinc`, used by `cliff_column.gdshader` and `cliff.gdshader`: from about -2.5 m to -5.7 m the rock eases to the palette `stone_mist` tone and then frays away, so slab feet at different depths no longer show and tall faces carry a top-to-root gradient at every hour. `root_veil_strength = 0` turns it off.
  - `stone_cliff_character()` now reads the hand-painted wash (`gouache_stone_sol61`) instead of the mineral photo: broad brush planes and a few dry strokes. Same four taps.
  - `procedural_shard.gd`: the band under each slab's collar takes the shading normal of the face below it, which removes the square tone patches under the grass lip. Vertex positions unchanged.
  - `waterfall.gdshader` rewritten: glassy lip, pattern laid along the square root of the drop so it stretches and speeds up, pulsed white ropes, thinning sheet, fraying outline, vertex billow, outer fall thinning into the veil. Five noise lookups instead of seven.
  - `water.gdshader`: sky sheen from the engine's sky radiance (`sky_sheen = .28`), sparse drifting light lines from fields the shader already had, per-light shading skipped.
  - Cheaper stone shading: new global `stone_fine_relief`, set by `preview_quality.gd` (0 in balanced, 1 in native), skips the cliff micro-relief; a three-tap stone-tooth term worth under one 8-bit step is removed. Balanced cliff fragments go from 19 taps and 8 noises to 10 and 4; stills change by a mean of 0.04 to 0.16 of 255.
  - Cost on M4 Pro, AC power, one live scene: veil, fall and pond are cost-neutral (4K 29.94 vs 30.13 ms for the task-start shaders); skipping the relief saves about 0.5 ms at 4K (29.60 vs 30.10 ms) and 0.15 ms at 1080p. 40 of 40 regression cases pass (`checks/suite.json`).
- Still open: a strong band where the dark wall meets the veil at dusk; the far pond is paler at the lowest camera pitch; frayed slab feet are open shells from directly below; veil heights are constants tied to the current hull depth; no measurement on target laptops.

"""
if marker in text:
    start = text.index(marker)
    end = text.index("\n## ", start + len(marker))
    text = text[:start] + section.rstrip("\n") + "\n" + text[end:]
    context.write_text(text, encoding="utf-8")
    print("context section replaced")
else:
    head, sep, rest = text.partition("\n## ")
    head = head.replace("更新：2026-11-19（最新一节为英文，见下）", "更新：2026-11-21（最新两节为英文，见下）", 1)
    context.write_text(head + "\n" + section + sep.lstrip("\n") + rest, encoding="utf-8")
    print("context updated")
print("finalized")
