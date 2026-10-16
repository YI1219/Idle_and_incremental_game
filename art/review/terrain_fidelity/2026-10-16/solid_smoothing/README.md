# Direct solid shaping: smoothing, geological cuts and dry-prop support

2026-10-16. **Retain the shared tools and unified-terrain support correction. Recess2 is a local authoring study; it does not replace the default island art. Full goal remains active/incomplete.**

## Result and scope

The player and prefab author directly edit the same volume. New `rock_smooth` uses simultaneous six-neighbor averaging within a compact radial falloff; `rock_cleave` subtracts the existing unequal geological shoulder volume. They append public workshop tools10/11, preserving previous indices, and use the existing world/radius/sample guards, ordinary stroke history, samples, snapshots and version4 local-profile persistence. No separate model assembly stage, custom-source replacement or new base-profile reinterpretation.

[Sculpt comparison](../../2026-10-14/courtyard_finish/solid_sculpt.html) has42actual Godot images: six stages, seven matched cameras (whole/far/edge/grass/shore/reverse/bottom). `solid_matched_views.json` independently compares the recorded camera poses and phase1.25; four principal water clocks are fixed by capture code, clouds/mist live. This is a prototype comparison, not a replacement of the current `cover_finish1_*` default gallery.

- Rough chisel2 and6-pass smoothing remain rejected: thin remnants become excessively rounded broad walls. The six-pass author is preserved as `polish1_author.gd.txt`.
- Two passes preserve firmer turns but retain a downward pointed fin. `author_unified_cliff_smooth.gd` retains those exact two-pass strokes for reproduction with the `chisel smooth` capture arguments.
- Recess2 uses one public geological cut and two public smoothing stamps. It replaces the local hanging fin with a connected inset and leaves the calm common bottom. Parent inspected all seven final views; independent review inspected all seven final pairs. Broad flat walls, uniform lower-body proportions, underside banding and hard grass contact still prevent default acceptance. More perimeter stamps are not an adequate answer to those major forms.
- Source island cells, tree/building sources and original assets remain unchanged. Sculpting changes support, so some shrubs/flowers move or disappear. Do not claim identical final prop layouts.

## Floating cap-rock correction

Recess1 exposes a dark unsupported-looking underside beneath a retained lawn stone. Independent actual source-triangle probes confirm raised/missing lower-third support:60sample failures across300probes/default,raise,contract. These are sample counts, not60stones.

The new helper checks the real source mesh lower-third section against unified terrain. Small required drops lower its pose with3cm burial; absent/wet support or a drop greater than45%of model height suppresses the small dry prop. This differs from shore stones, where the wet flank may deliberately overhang. It affects only unified `surface_rock` placement; the default model-based path is unchanged. It does not weld a prop into the terrain or prove every visible underside is buried.

Final actual checks: recess0/120probes, stones2/2/2; unshaped unified base0/160probes, stones3/3/2. Both include real flat-volume/BoxMesh fixtures proving small lowering, exact retention and unsupported/excessive-drop removal. Recess2 visibly removes the flagged cap rock; no replacement floating prop is introduced. Recess_before2 applies the same fix, so the final shape pair does not mix support implementations. Earlier screenshots preserve the problem as stage evidence.

## Fresh verification

- Smoothing real red11/15→green15/15; expanded final21/21. Flat planes, needle removal, symmetry, untouched outside, empty air, real shoulder/base meshes, exact undo/redo/JSON, unchanged cells/local profile and atomic nonfinite/world/capacity guards. Final meshes11,364/25,620vertices, zero open edges/inward faces. Initial parse typo was fixed before obtaining the recorded real red; it is not counted as a feature failure.
- Geological cutter real red8/10→green10/10; expanded final12/12. Actual subtraction/outside retention/orientation, exact history/persistence, empty air, world/orientation/capacity guards;26,016vertices/zero open edges/inward faces. Independent reviewer reran12/12.
- `final_checks.json`: all10named headless scripts clean (smooth21,cleave12,original volume29,plane10,shoulder15,published9,base23,profile15,data301,runtime22). The separate final support report follows the prop correction.
- Native public pointer route25/25 and general editor339/339 clean. New tools use actual HUD selection, pointer stroke, publication, changed-surface picking, exact undo and repicking. Existing shoulder fixture separately verifies30,704published triangles/zero bad shared edges; new-tool source-mesh tests separately verify their closure.
- The initial cutter pointer assertion wrongly assumed an oblique ray reaches the cut bottom; diagnostic hit is its front face atY3.151299. `pointer_initial_assumption.json` records24/25. Corrected assertion requires the original cap point to be empty, pickedY<3.4 and absolute picked density<.002, plus unchanged exact undo/repick checks. This is an oracle correction, not a production fix or a relaxed closure/support threshold.
- Whole recess source skin:696,744vertices/one connected component/zero invalid edges or nonfinite vertices;5,451overrides; original cells unchanged. This whole source proof is distinct from the native small-fixture chunk publication check.
- `final_support_checks.json`: rooted grass241anchors/zero unsupported or invalid/102,924uploaded values. Shore83/68/84/67stones across four edits, zero failures/3,526probes. Vines375/375/384/386/405centroids across five states, zero missing or separated over.10m. Recess is authored before these cell edits; these are finite fixtures, not arbitrary sculpture or every leaf tip. Default decoration23/23 passes separately.
- Final capture report has two clean seven-view native runs after the support correction. Earlier rough/polish/recess captures are retained as stage evidence. The support test's added fixture briefly had a duplicate local-variable parse error; corrected final runs are clean.
- Independent final review finds no remaining actionable correctness issue, independently passes both final dry contact fixtures, and recommends retaining tools/contact fix/local study without default art promotion. No GPU work by reviewer.

Dynamic water routing through arbitrary carving, large-edit speed, arbitrary player volumes, moving-camera stability and target-laptop performance remain unaccepted. This round changes neither water shaders nor default source geometry, so previous water/performance results are not new verification. No Tripo operation, purchase or user model handoff is pending. PNGs remain local review evidence under the repository binary policy; capture/author code, reports and source hashes are tracked.
