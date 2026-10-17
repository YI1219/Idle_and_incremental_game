# Feature-preserving reconstruction: rejected local prototype

2026-10-17. This is the authorized next open-source-informed experiment, not a new island-art candidate or integration of an upstream kernel. Default `spall_finish1`, runtime terrain/editor, original models, trees, buildings and layout remain unchanged. [Local gallery](http://127.0.0.1:18771/cliff_dual.html).

The result is useful diagnostically but **all four new DC meshes are rejected**. Independent review found actual triangle self-intersections despite closed, oriented, one-component topology. Parent reran the strict detector and reproduced the counts. Do not call these geometrically valid meshes, promote the clearer screenshots, or infer editor readiness from the record roundtrip.

## What was tested

Reuse exactly the previous closed native-Manifold union of existing crown36/37/38 and its .25m signed node records. An independently implemented uniform Dual Contouring probe uses mass-centered, box-constrained QEF placement. Face-connected crossing patches receive separate vertices: the initial one-vertex-per-cell attempt produced a four-use edge/two bad vertex links and is retained separately under `art/work/cliff_dual/2026-10-17/rejected_first_topology`. Sign-based winding and patch separation repair those **topological** failures, not the later geometric self-intersections.

Two inputs are compared at identical spacing/signs: existing density plus central-difference gradients; or extra exact source segment intersections and original face normals. The second input is augmented data, not information automatically recoverable from old density-only saves. No adaptive octree, published Manifold Dual Contouring implementation, or libfive kernel is integrated. No upstream source code is vendored.

One actual public `rock_plane` brush at (-15,3.25,3), radius4, upward normal changes1236nodes. Exact standalone field undo, redo and record reload pass. The source-aware edited control derives intersections from the same original union plus bounded half-ball subtraction, including its cut plane and spherical boundary. This does not validate TerrainData history/publication, ground-cap coupling, picking, collision, props or arbitrary edit sequences.

## Fresh evidence and decision

| Reconstruction | Triangles | Non-two-use / inconsistent edges / bad vertex links | Confirmed crossing pairs, at least |
| --- | ---: | --- | ---: |
| DC, density only | 6,556 | 0 / 0 / 0 | 120 |
| DC, source Hermite | 6,556 | 0 / 0 / 0 | 79 |
| DC, density only, brush edited | 6,428 | 0 / 0 / 0 | 108 |
| DC, source Hermite, brush edited | 6,428 | 0 / 0 / 0 | 77 |

All four have one positive-volume connected component. These facts do not make them embedded valid surfaces. The deterministic crossing check uses zero-epsilon Blender BVH candidates, then independent float64 segment/triangle interior equations with1e-7 strict parameter margin. It excludes pairs sharing a position rounded to1e-5, coplanar and near-touch cases, so the counts are lower bounds rather than exhaustive exact-predicate validation. The source union and old sampled controls, including sampled-after-brush, have zero candidates under the same detector. See the hashed [intersection report](../../../../work/cliff_dual/2026-10-17/intersections.json). A global diagonal flip was independently explored and did not repair intersections; no diagonal-only fix is established.

Five numerical tests pass: corner, planar rank deficiency, constrained solution, sphere orientation, diagonal-pocket edge topology. They test specific properties; they do not guarantee arbitrary geometric validity. The additional crossing rejection gate is essential. [Validation](validation.json) explicitly asserts rejection, not acceptance.

The sampled vertex implicit residual is lower on average with extra source Hermite information (~2mm versus ~5mm), but its worst sampled residual is **worse** (~11cm versus ~5.4cm before editing). This is neither Euclidean surface distance nor an area-weighted/global error bound. Hermite crossing selection encounters1ambiguous edge before editing and4after; no source crossing is missing. Do not use average residual as a beauty or correctness score.

There are53successfully written new native Godot images:45isolated (five stages × three normal/material controls × three views) and8actual-scene images (two unedited DC stages × close/grass/reverse/far). The gallery reuses26previous controls with matching camera position/rotation and lab orthographic size. Same material,65degree normal algorithm and lighting are used. Scene rendering replaces exactly three draw instances, omits covered horizontal lids within1mm ofY3.5, and preserves authoritative data hash; full closed meshes remain used for measurement. Existing backing, lawn and props remain, so this is not a whole-island geometry replacement. Water phase is fixed; clouds/mist remain live. No edited DC is shown beneath unchanged scene lawn. All logs are clean; successful capture is distinct from valid geometry.

Parent visual inspection: source-Hermite reconstruction makes some shoulder turns cleaner and reduces old staircase facets. Density-only DC introduces several narrow scars. Both still inherit broad rounded source masses; actual grass contact remains a hard cut, side-to-bottom layers remain visible, and far appearance changes little. **No art promotion.** No target-device cost, runtime latency or overall goal completion claim.

## What the other projects contribute

| Primary source | Useful idea and actual status |
| --- | --- |
| [libfive](https://github.com/libfive/libfive), [QEF explanation](https://www.mattkeeter.com/projects/qef/), [DualContouringSample](https://github.com/nickgildea/DualContouringSample) | Feature constraints and mass-centered QEF informed this experiment. libfive's full hierarchical, feature-preserving manifold mesher is **not** reproduced by this small prototype. A robust meshing/triangulation solution still needs a bounded feasibility test before backend migration. |
| [SUSMA](https://github.com/jaaamesey/SUSMA) | Analytic subtract/union sculpt representation is an architectural reference. Here the brush equations/source constraints remain available during reconstruction, rather than pretending old node records retain them. No code integration or player workflow replacement. |
| [Terrain3D](https://github.com/TokisanGames/Terrain3D), [texture painting documentation](https://terrain3d.readthedocs.io/en/stable/docs/texture_painting.html) | Base/overlay material control, height-bearing texture sets, varied painted grass/earth edges and wetness controls are relevant to material finish. Prior true-height contact probe still looked painted and was rejected; this turn does not claim a material improvement. Its terrain backend is not automatically suitable for a floating underside. |
| [Waterways](https://github.com/Arnklit/Waterways) | Flow/foam maps can guide calmer pond and connected waterfall motion. Not implemented or validated this round; retain authored pond data rather than blindly import spline rivers. |
| [Godot Manifold PR94321](https://github.com/godotengine/godot/pull/94321) | The previously measured native union already uses the installed engine capability. No custom engine fork is needed for that control, and it does not alone solve player-sculpt reconstruction. |

Next geometry work must address geometric intersections and feature-data persistence through real editing before promotion. Avoid another unvalidated QEF/diagonal tuning sweep. Material-contact and water experiments can remain independent of the backend decision. New model generation remains deferred; no task submitted or credits spent.

## Reproduction

From repository root, run the public edit helper; Blender bake; Blender strict intersection verifier; numerical tests; native lab capture; native scene capture; review builder, in that order. Helpers are in `tools/art/`: `edit_cliff_dual_probe.gd`, `bake_cliff_dual_probe.py`, `check_cliff_dual_intersections.py`, `build_cliff_dual_review.py`. Capture helpers accept `--input=res://art/work/cliff_dual/2026-10-17/`, `--output=res://art/review/terrain_fidelity/2026-10-17/cliff_dual/`, and comma-separated `--shapes`. Lab uses all four DC stages plus `sampled_edited` and `--geometry-only`; scene uses only `dc_field,dc_hermite`. The detector runs with Blender `--factory-startup` and Python; tests use unittest discovery for `test_cliff_dual_probe.py`.

Binary meshes and PNGs remain local under project art policy; JSON, review, tool source and verification logs are tracked. Regeneration needs the preserved previous local binary source and maps.
