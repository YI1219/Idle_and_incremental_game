# Local editable volume — first implementation gate

Started2026-10-19, verification continued2026-10-20. **Art is not accepted; do not expand this shape to the whole island.** This is a local native study, not a replacement for the original complete scene or a completed game-art goal.

2026-10-20 update: [continuous contact correction](../../2026-10-20/volume_diagnosis/README.md) supersedes this initial vertex-contact display. Counts and pictures below remain the initialc8c558f evidence; current source is21/21document and12/12native. No user art acceptance.

## Delivered

- Native scene `res://scenes/volume_patch_study.tscn`: real subtract/add/plane/smooth brushes, orbit/zoom, stroke undo/redo, separate study save/load.
- Existing Tripo land master v2, rigid front alignment, uniform8.5mwidth and translation only. Its5028triangles become the source of an immutable0.25m field preset; all displayed rock is the editable volume, not a fixed decorative wall.
- Newly exposed surfaces use the same world-space material. Existing mineral/packed-relief maps reused; **no high-poly normal bake, new Tripo task or texture charge**.
- Lake carved from that solid, clipped against the same tetrahedral field at its sample-plane water level. Three-dimensional lattice-edge connectivity detects side/bottom leaks, including diagonal passages. Invalid water hides without deleting the lake definition; undo repairs it. A small center pillar no longer incorrectly drains the surrounding basin.
- Complete erasure publishes empty display/collision/water and remains undoable. Display/collision update together. Study saves bind to the complete posed/sampled preset hash, reject mismatches atomically and never use old sandbox save paths.

## Actual pictures and conclusions

`captures.json` records11native1671×941frames, camera positions, source-preset identity, actual adapter and per-state build cost. PNGs remain local per repository art policy. No webpage was made.

- `source_neutral.png` / `converted_neutral.png`: same source pose, camera, light and neutral material; source uses imported normals, conversion uses42degree creases. Conversion control has no lake cut. This comparison includes normal changes; do not describe it as geometry-only isolation.
- `initial_play.png`, `initial_close.png`, `initial_reverse.png`, `initial_low.png`: coated source with an actual small lake. Grass boundaries visibly interpolate as triangles; pond shape reads as an excavation; lower rock still puffy. Rear wall is too broad and quiet. These are observed art defects, not approved stylization.
- `simple_material.png` / `initial_close.png`: exact same geometry/camera/light, maps off/on. Relief improves local surface response but does not fix silhouette, vegetation contact or the crater-like bank.
- `tunnel_play.png`, `tunnel_low.png`: real through-cut with retained roof and material on new interior faces. `lake_breach.png`: real upper-bank cut invalidates water. `restored.png`: undo restores identical authored data.

Original full-scene baseline remains at `../authored_island/baseline/`. It has a different layout, scale and populated environment. It is historical evidence, not a matched single-variable full-scene improvement claim for this isolated patch.

## Verification and limits

Fresh headless document checks19/19; native1280×720public mouse/keyboard, collision, Chinese font, water clipping and total-erasure/undo checks11/11. Legacy sculpt29/29; legacy base check result recorded in verification.json. Native capture exits0; final log checked separately for shader/script/font errors.

One bounded independent code review found twoP2issues: empty mesh publication and center-pillar water invalidity. Both reproduced RED, fixed in one pass and reverified GREEN. No art acceptance inferred from review.

This patch is synchronous and bounded to X[-8,8],Y[-4,7],Z[-6,6] for validation. Source terrain after pond carve16,980triangles; tunnel17,756; breach17,552. M4Pro observations are roughly0.34–0.36sec per small-patch build, not a robust benchmark or target-device result. Terrain triangle count grew relative to the5028triangle source. This is not yet low-cost production editing.

Stage2 chunk scheduling/async publication, freely painted cover, arbitrary lake networks/split reservoirs/outlets, whole-island composition, new cottage, release export, target-device FPS and long-idle measurements remain unimplemented/unverified. Current water is an opaque study shader, not the final refraction/waterfall solution. Arbitrary structural-collapse physics is outside scope.

## Reproduce

Run the scene directly in the current Godot project. Left mouse sculpts; right drag orbits; wheel zooms; brackets resize;Ctrl+Z/Yundo/redo. HUD saves only to `user://volume_patch_study/layout.json`.

Rebuild preset only if needed: run `tools/art/prepare_volume_patch.gd`; run Blender with `tools/art/sample_volume_patch.py`; run the prepare script with `--pack`. Source originals are required only for authoring/capture controls; runtime uses the embedded preset. Source/sampling reports live under `art/work/volume_patch/2026-10-19/` and record actual hashes, original topology and independent float64 ray checks.

Separate OFL subset font is packed in a FontFile resource; no system-font lookup is required. Rebuild with `tools/art/build_volume_patch_font.py` (fontTools4.60.2 and preserved Noto source), then prepare script `--font`. Existing UI font unchanged.

## Next art decision

Recommended: keep the sculpt/data verification, refine the existing source's main planes and bottom, replace the spherical pond cut with a designed bank profile, and move the grass/soil boundary away from coarse triangle interpolation. Compare again locally before extending the island. A concrete direction question with current screenshot has been sent to the user; no approval has been received at this point.
