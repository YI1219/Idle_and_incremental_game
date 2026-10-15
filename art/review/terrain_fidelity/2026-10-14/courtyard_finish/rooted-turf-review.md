# Rooted turf — verified progress, art goal remains open

2026-10-15. Current `turf5_*` Godot 4.7.2 Forward+ Metal captures at 1671×941 on Apple M4 Pro. Immediate baseline `water_final_*` at `6699721`. Eleven captures, eight principal matched views inspected; the [gallery](comparison.html) also keeps the earlier water/island baselines. Concepts are not runtime evidence.

## Change and visual decision

The old generated sod front had downward-facing top triangles, and the parallel horizontally offset back remained above ground. A test reproduced 970 inverted exposed top triangles. Correct winding, a back buried below the cap/inside the actual stone, smooth normals and a much shorter root cuff now remove the conspicuous folded hanging sheet.

Two unequal little fans reuse the retained curved `Grass_Common_Short` mesh. Uniform scale and rotation preserve its proportions; roots and compression anchors sit inside the final drawn cap. Existing world-space grass compression and whole-group outcrop trimming remain. The same terrain detail material supplies grass/earth color, so no fixed extra ground or painted green stone shoulder is introduced. Trees, buildings, island/water data, source model and texture files are unchanged.

The actual rim view is a modest improvement: upright irregular blades and shorter roots replace broad dangling flaps. It is not reference parity. The small oval root pads can still look applied up close, and broad stone slabs dominate both close and distant silhouettes. The independent reviewer reached the same assessment.

Rejected trials are preserved only as evidence: `turf1` corrected winding/backs but retained rounded leaf-like sheets; `turf2` fingered margins looked like dripping teeth; `turf3` smaller molded cushions still read as leaves. `turf4` introduced source grass fans but kept too much hanging root. `turf5` shortens that root and makes the unequal source fans readable. An isolated no-cover render confirmed the offending shapes belonged to rim cover, rather than source cliff geometry. Its temporary script was removed.

## Matched views

| View | Current assessment |
| --- | --- |
| Rim | Less hanging paper, thin planted silhouettes; oval cuffs still visible. Stone shape remains the major gap. |
| Overview / distance | Composition and continuous bottom retained; smaller cover does not become a perimeter outline. Fine blades are intentionally secondary at distance. |
| Reverse | Grass fans remain grounded along the opposite edge. Large source rock proportions still repeat. |
| Shore / courtyard | Prior physical-bed water and wet shore remain; rim beside the fall is shorter. No tree/building replacement. |
| Ground | Existing soil route, paving, grass material and level production terrain retained. |
| Bottom | Continuous calm closure and prior root/core intersections unchanged. No new hanging rubble. |

## Fresh verification

Full outputs: [turf5_checks.json](turf5_checks.json). Thirteen affected headless scripts pass: solid cuff orientation/normals, source blade silhouette/support, published chunk metadata/normals, rim detail/finish/polish/union/closure/outcrops/systems, editor decoration, compression binding, vine contact and physical lake bed. These are the named checks; the previous full water suite was not rerun and is not represented as current.

- Isolated cuff: 1,888 exposed top triangles, zero inverted faces or invalid normals. Curved source leaf tips are excluded from this solid-volume winding requirement because they may turn downward legitimately.
- Full rim: 21,024 blade vertices above 8 cm, 3,310 supported anchors, 42,736 triangles. All 128,337 actually uploaded chunk positions/normals/anchors are valid. This is default-fixture evidence, not every possible layout.
- The old detail test's long hanging-depth requirement is deliberately retired: the new acceptance is short rooted cuffs plus raised curved blades, not a minimum dangling tongue length. Its depth bound now includes those blades; anchor upload and multiple depth bands remain checked.
- Rendered editor 339/339; actual decoration edit/regeneration 42/42. Rendered compression: 2,110 standing pixels, zero fully compressed pixels, 1,686 local-mask pixels, passes.
- Fresh reviewer independently reran cuff, tuft and detail tests and inspected baseline/rejected/selected close and whole/reverse views; no actionable technical defect found.
- Capture logs and `git diff --check` have no shader/script/whitespace errors. Eight principal views inspected; no concept-quality or target-laptop performance claim.

## Next decisive input

The user selected existing-model refinement first; only if the actual integrated result is insufficient will a new custom model route be prepared. The main stone's concrete source/refinement pack remains ready. No refined `.blend`/`.glb` has arrived in its output directory. The next useful art step is that real main stone in the same editable rim, then the root-pad/stone composition against its actual silhouette. Do not keep adding decorative density or repeat the rejected molded-turf studies to hide the source-shape limitation. Water still uses screen-space refraction with limited reflections. Overall goal remains active, not achieved.
