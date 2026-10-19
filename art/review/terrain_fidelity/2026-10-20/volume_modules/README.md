# Three existing rock modules — local candidate, art gate still open

The user selected existing-mother shape/contact/bank correction. Overall source squeezing had not produced an attractive main form. This checkpoint instead hand-organizes three preserved existing rock assets, unions their posed surfaces into one closed body and converts that body to the same editable density system. **The result is not art accepted and is not a new default.** No paid asset, custom model from scratch, house task, display website or whole-island expansion occurred.

## Actual comparison and judgment

`lower_patch_{play,close,reverse,low}.png` and `module_patch_{play,close,reverse,low}.png` use identical world cameras, lights, shader settings, grass helper and shallow-pond profile. Only the derived source and its planting metadata differ. The old source is the prior lower-return local mother, not the original full game scene. The new shape has the same8.5m width and3.25m top/−1.147m minimum, but a broader5.914m depth/87.058m³ volume; this is not a same-footprint comparison. Water animation time remains live.

Fewer main planes and a central recess read more clearly than the prior puff-like mass. However, the source still makes large ledges, the rear remains a broad wall, the turf boundary is angular and the bottom reads as separate flat-ended feet. Source-neutral and converted-neutral views retain those problems. Merely adding texture or increasing sampling resolution cannot fix the authored composition. Close, reverse, low, tunnel, breach and restoration frames were inspected. Do not use a successful tunnel or clean topology as a beauty judgment. A concrete optional direction question with old/new actual images is pending; no user art acceptance has been received.

`catalog_front/back.png` inspect the three original sources uniformly fitted to2.8m maximum dimension. `lower_source_*` / `assembled_source_*` compare actual reimported GLBs in one neutral material/42°crease rig, before any editable conversion. `module_converted_neutral.png` shows the unedited converted assembly without water/grass. These are native Godot captures, not generated concepts.

## Preserved sources and derived geometry

Sources: existing Quaternius `Rock_Medium_1.gltf`342triangles, refined `cliff_main_v4.glb`634 and `cliff_tall_v2.glb`816. The retained Quaternius license is CC0 1.0. Source paths and original file/triangle hashes are in `art/work/volume_modules/2026-10-20/sources.json`; `source_preservation.json` freshly compares them, all three older presets and the study scene against HEAD. All are unchanged.

`tools/art/author_volume_modules.py` uses explicit unequal poses, inverted source orientation, exact Boolean unions and a3.25m top trim. The work `.blend` retains posed originals alongside the union. It exports one1816triangle/910welded-vertex connected body with positive signed volume and zero finite edge/link/strict-crossing defects. The strict crossing check excludes shared-position and coplanar cases; it is not a universal intersection proof. Canonical files remain under `art/work/volume_modules/2026-10-20/`:

- `assembled.bin`: SHA256 `1f1e6026d6892dab61a2c6ee81c7be3c30e73f1e3088334a18072f94a978ad4b`.
- `three_rock_assembly_v1.glb`: `d15fa27f6f0f5910dd60ea50126a230474262e7049ecdafbc5f6cc0a814e0289`.
- Runtime `assets/terrain/volume_patch/source_rock_modules_v1.res`: `0b9010ab398d5157c0b7338440d656091e07e19119c63522e953eedef357e7e7`.

Godot GLB reimport has a finite vertex discrepancy≤.226mm. Three-ray.25m density conversion produces17556unedited triangles; the shallow-pond fixture has17684terrain+504grass+79water triangles. The low-poly source count is therefore **not** the displayed terrain cost. Finite source vertices+centroids→converted surface: mean2.24cm/p95 8.27cm/max20.57cm. Reverse: mean.63cm/p95 3.03cm/max11.36cm. These are finite probes, not continuous Hausdorff bounds. Conversion softens shallow corners; complete values are in `conversion_distance.json`.

## Planting and actual basin correction

The first capture reused the old2.85m planting minimum and incorrectly left broad lower upperland bare. Those12actual frames/report and the prior preset are preserved under `before_planting_metadata/` and the work directory. The new source explicitly supplies `planting_min_y=2.4`; older sources default to2.85 and their preset bytes remain unchanged. The converted geometry SHA is identical before/after this metadata correction.

Physical grass previously excluded all ground below the pond level, even dry land outside the basin. It now uses actual validated basin columns with a one-cell shore margin. Current module fixture:24fans/504triangles/144actual roots. Independent retrieved root positions stay within.078mm and maximum density−.002097; grass is derived from the same solid. The matched lower fixture now has51fans/1071triangles/306roots because this same basin correction also applies there. Older grass reports describe their earlier historical capture, not these counts.

This does not solve source-depth soil stratification on freshly cut upward faces. The stone wet shader still uses its earlier radial lake approximation; actual basin awareness here applies to physical grass placement only.

## Function, checks and remaining scope

Independent bounded review found no actionable Critical/Important delta defect. It separately verified six atomic cross-source rejections, packed density/provenance hashes and default planting thresholds. It also found1192collapsed triangles in the existing mesher’s captured17556triangle unedited output. Excluding those, the skin is one component with zero bad edge usage. This is not a claim of fully nondegenerate production geometry; the mesher was not changed in this local assembly delta.

Module source7/7: source-bound JSON roundtrip, mutual atomic rejection against prior mother, closed pond, real tunnel/roof and exact undo. Module grass9/9 includes dry lower land outside the pond, actual emitted roots, local cut, total erasure and exact restoration. Fresh original21/21, refined8/8, prior source matrix15/15, default grass8/8 and native original-study runtime12/12 all pass. The native mouse/font/GPU-contact check covers the original study scene; module captures separately assert displayed mesh/collision equality. Module capture12frames succeeds, breach hides invalid water and undo restores source-bound data exactly.

Synchronous capture builds take roughly342–398ms on the M4 Pro for new-source states. They are diagnostic fixture timings, not interactive frame time, target-laptop performance or stage2 asynchronous architecture. User saves are not written by capture injection. The tools-only candidate document has a distinct source family; it is not a separately shipped interactive study with a new save path.

Reproduction order: `inspect_volume_modules.gd` → Blender `author_volume_modules.py` → inspect `capture_module_form.gd` → Blender author tool with `-- --sample` → `pack_volume_modules.gd` → `capture_volume_module_patch.gd`. Run Blender with `--python-exit-code 1`; inspect Godot output for script errors as well as exit status. Final logs are clean. An intermediate duplicate local variable caused a parse failure and was corrected before the successful captures/regressions. No failing log is claimed as final evidence.

The full goal remains active. Stage1 local art remains incomplete; stage2–5 and house/whole-scene/target-device gates have not started here. Preserve this candidate and discuss whether its large-mass direction is useful before another composition pass.
