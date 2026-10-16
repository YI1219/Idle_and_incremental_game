# Calmer fine stone relief

2026-10-16. Retain a modest material improvement, not full art acceptance.

## Retained change

Shared `stone_relief_strength` now defaults to.07 instead of the previous hard-coded.20. It only scales tangent-plane slopes from the existing packed map. Mineral albedo, weathering, roughness, physical face normals, textures, geometry and authored layout are unchanged. The default reaches retained cliff models, shore stones, mantle, continuous backing and unified sculpt terrain. Lake-bed fine normals become quieter through their existing.12 blend. Grass uses its separate normals and is unchanged. No extra texture fetch was introduced; performance is unmeasured.

Seven actual camera-matched pairs (`mineral_control1` versus `mineral_soft1`) freeze four principal water clocks at1.25. Cloud/mist still animate. [Interactive comparison](../../2026-10-14/courtyard_finish/stone_relief.html) has14actual Godot images. Original images/capture reports remain in adjacent sculpt_base. `mineral_quiet1` was an incomplete renderer-material-only override, not the final candidate; final soft1 uses the shared default and includes model materials. Main `stone_soft1` has11fresh actual captures. Parent inspected close/grass/whole/rim/shore/bottom; independent reviewer inspected all seven matched pairs and found a small reduction of pebbly/sandpaper lighting while mineral variation and firm model turns remain. Overview/far changes are slight. No actionable shader correctness finding; reviewer ran no GPU tests.

## Fresh verification

`checks.json` records successful clean native Metal runs for all five entries:

- Main captures11/11, no shader/script error.
- Editor339/339.
- Unified wet material11,236foreground,0underside pond-tag changes,11,236positive wet-bed changes.
- Actual lake-bed light:288shallow/119middle/0deep changed pixels;413moving shallow; production377changed/556moving; morph endpoint0different, unchanged acceptance thresholds.
- Actual compression106,279/107,520changed pixels, zero half-mask mismatches.

Earlier geometry/support/closure tests are previous-stage evidence; no fresh broad claims are made from them. No geometry or placement code changed this round. These checks do not establish arbitrary sculpted water behavior, render stability in motion or target-device cost.

## Rejected shape studies

Public plane operations on the local-height coherent base produced `chisel1` and `chisel2`, seven native views each. Chisel1 left thin overhanging cap fragments, pocket-like faces and visibly removed support under a retained local stone. Chisel2 crossed more of the upper wall and reduced thin caps but still produced isolated pointed fins and broad lower walls. Both are rejected and **never replace default geometry**. Source strokes (`chisel1_author.gd.txt`, `chisel2_author.gd.txt`) and clean capture checks remain in plane_sculpt; default island data, props, trees/buildings and model bytes remain intact. No claim of full support or closure acceptance for those rejected studies.

The shape studies confirm that further overlapping bounded planes are not a reliable substitute for composing the whole cross-section: preserve thick shoulders, avoid residual narrow solids, and review the cap-to-side-to-bottom relationship together. Do not promote sharpened cuts merely for adding detail. Full goal remains active: broad panel proportions, razor-like turf contacts, dark underside/banding and natural water finish still require work.
