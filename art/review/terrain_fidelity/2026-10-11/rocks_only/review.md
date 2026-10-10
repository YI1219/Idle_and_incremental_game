# Step 1: rocks only — review

2026-10-11 · branch `cursor/lighting-atmosphere-round1-ad0c` · baseline `131bbcc` (Round 8).

The local checkout and remote branch were reset to Round 8 as requested. The later Astra commits are no longer on this branch, and their three later review directories were removed. There were no additional Git worktrees or attached worktree artifacts to discard.

[Concept | after screenshots](comparison.html) show the whole scene, upper/lower rims, terrace step, side bodies, underside and expand → raise → undo → shrink → restore. The supplied concept is artwork; the after images are actual Godot Forward+ captures. The baseline composition is unchanged. PNG and HTML files remain local under the repository's existing art ignore policy; this report, test outputs and capture metadata are versioned.

## Rock changes

- Four crown meshes and two root meshes are generated from unequal intersecting fracture planes, with physical face relief. Every mesh is a closed solid with outward winding. The old full-height body is replaced by broad crowns and independently placed, staggered, inward-tapering roots.
- Crowns project beyond the underlying contour. Their unequal clipped plans and corner gaps form the rim silhouette. Roots sit behind crown joints with varying vertical overlap and orientation; there are no repeated horizontal masonry courses.
- Corner-bounded contour spans resize before dividing at 3.8 m of arc length. Shrinking recombines them deterministically. Outer and terrace crowns both use bounded span-derived widths; complete reconstruction, undo and load produce the same placements. This is geometry-derived subdivision rather than persistent hand-authored stone identities.
- Existing smaller shore-stone families now follow the pond bank continuously except for natural placement gaps and spill openings. They remain separate from the large crowns and roots. Shifted root meshes are fitted around the actual waterfall opening.
- Root faces participate in the existing vine contact calculation; spatial queries use actual mesh bounds, including fracture protrusions. The existing foliage system and layout are retained.

## Scope preserved

The terrain data/presets, contour terrain, cottage/prop placement and scene files are byte-identical to `131bbcc`. No cottage/layout, lake/terrace, camera, atmosphere or vegetation-system change was made. Original assets remain intact. Stone color was adjusted locally in the body shader. The ring uses retained small shore assets, not those assets enlarged into the rim.

## Fresh verification

- **32/32 headless terrain suites passed:** [full outputs](checks.json). Contact tests were refreshed after the actual-bounds correction.
- **27/27 rim-system checks:** span growth/splitting/merging, bounded spans, separate roots, outward-facing instances, broad crowns, actual terrace-crown growth, and contact lookup at protruding fracture vertices.
- **40/40 volume checks:** closed edges, positive volume and inward root taper across eight seeds for both families.
- **140 waterfall samples clear** in default, expanded and contracted terrain; no sampled point lies inside a crown or root.
- **Rendered regeneration 42/42; cottage checks 7/7:** [rendered outputs](rendered_checks.json).
- **15 successful final screenshots:** [default/orbit metadata](after.json), [rim/underside/edit metadata](after_rim.json). Godot 4.7.2, Forward+ / Metal, 1671 × 941. Capture timing is development-host evidence only; target-device performance remains unmeasured.

Fresh review found terrace crowns still using fixed width and an accidental flower-offset change. The width issue was reproduced on actual placed meshes and fixed; the flower change was reverted. Visual feedback led to less regular crown outlines and roots staggered farther beneath the crown joints. The resulting waterfall collision was reproduced (11 blocked samples), fixed and extended to the three terrain states above. The final default, close rim, underside and shrink views were inspected after these corrections.

## Review boundary

This is the requested rocks-only review candidate. The concept's full landscape is not being copied: the Round 8 layout and cottage were explicitly frozen. The painted reference has finer incidental chips and vegetation; this pass keeps the existing scene detail. Function checks do not constitute owner art approval. Stop here for review before any further scene work.

## Reproduce

```sh
godot --path . -s res://tests/capture_lighting_round.gd -- after out=2026-10-11/rocks_only
godot --path . -s res://tests/capture_rim_round.gd -- after out=2026-10-11/rocks_only
godot --headless --path . -s res://tests/terrain_rim_systems_test.gd
godot --headless --path . -s res://tests/terrain_stone_volume_test.gd
godot --headless --path . -s res://tests/terrain_rock_fall_clearance_test.gd
godot --path . -s res://tests/terrain_decoration_regen_test.gd
```
