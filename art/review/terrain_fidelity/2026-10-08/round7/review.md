# Round 7 — procedural cut-block rim

Captured 2026-10-09 from the running terrain editor (Forward+, llvmpipe, 1671×941 unless noted). The concept is the owner's island schematic. Round 6 is `../round6/`. This is not visual acceptance.

## Approach

Round 6 stretched retained Kenney and Quaternius stones into the rim. Those meshes stay available for shore stones, surface rocks and plants. They no longer define the silhouette.

The rim and the underside are six baked block meshes, instanced with MultiMesh. Each mesh is a unit box: x/z in [−0.5, 0.5], y in [−1, 0], top centre at the origin. A placement scales that box to width, height and thickness.

The footprint is a squarish clipped rectangle, not a circle. Four corner cuts, each 4.5–8% of the edge, plus a skew of about ±0.012, then the ring is fitted back into the unit box. Consecutive rings share that shape, so each side is a flat facet. `ChunkGeometry.Surface` stores one normal per triangle.

Straight blocks (`cliff_column`, `_b`, `_c`, `_d`, seeds 11, 23, 37, 41) use six rings. The top ring is at scale 0.93. The ring at y = −0.17 is full width. The body stays at scale 1.0 down to the foot. The chamfer sits in the top fifth of the box. `cliff_column.gdshader` keeps that fifth at about 0.30 m however tall the block is, so the rock head stays the edge and the sides stay near vertical. Upward crown faces use the same lawn function as the cap. Moss is limited to that crown, so lower courses do not grow a green lip.

Foot blocks (`underside_rock`, `underside_rock_b`, seeds 53 and 67) keep a full-width top, then narrow to scales 0.92, 0.84, 0.76 and 0.70. They use the same shader and the same unit-box scale as the wall, so the foot is the bottom of the wall rather than a separate boulder.

A straight block is 96 triangles. A foot block is 112. Per-face vertex colors sit around 0.58–0.74, which is the grey the shader already treats as an untinted facet. Instance color still tints each stone.

Layout is unchanged in structure. Contour runs place overlapping heads (width = run span + 0.95 m, spacing about 2.15 m). Heads rise 0.06–0.14 m above the turf and stand 0.36–0.58 m proud. On the homestead they are 1.70–2.62 m tall (average about 2.18 m). Courses under an outer head use the same blocks, overlapped 0.62 m vertically, with the outer face within a few centimetres of the head. The last course is the tapered foot. Waterfall mouths still split a run. Shore stones stay at scale 0.62 and do not set the rim.

The shell behind the blocks is recessed 0.40 m (was 0.28 m), so a joint is a crevice against rock rather than the shell standing proud of the courses. The homestead footprint, both terraces, both lakes, the connecting fall, and the 0.55 s height ease are unchanged. Cottage, path and garden are not moved.

## Local regeneration

`TerrainDecoration` keeps each contour run. The key is the chord, the land height, the height cells within 3.5 m, and any fall veil that can shorten that run, plus the world seed. The next revision copies a run whose key still matches and rebuilds the rest. Keys that the new outline does not use are dropped. Restored poses are the poses a cold layout produced for that same key, and the decoration test compares the published island to a placement whose cache was cleared.

On this host, one measurement of the homestead outline:

| Pass | Hits | Misses | Layout |
| --- | --- | --- | --- |
| First build | 0 | 86 | 14.0 ms |
| Expand at (19.2, 4.6), radius 2.8 | 79 | 13 | 9.7 ms |
| Raise on that new land | 79 | 61 | 16.5 ms |

The expand reuses most of the rim. The raise moves enough nearby contour to rebuild a large share of the lower terrace, so that pass is not cheaper than the first build. Building the signature still walks the nearby cells on a hit; the saving is the skipped placement. Baking the six meshes measured 4.6 ms. The first time the running scene compiled the rim shader, that same span was about 25 ms; a later load was 4.8 ms.

## Screenshots

- `compare_default.png` — concept, round 6, round 7, default camera.
- `after_default.png`, `after_orbit_left.png`, `after_orbit_right.png`, `after_orbit_back.png` — round 7 orbits (`after.json`).
- `compare_rim_front.png`, `compare_rim_right.png` — round 6 beside round 7. Also `after_rim_upper_front.png`, `after_rim_lower_right.png`, `after_rim_terrace_step.png`.
- `compare_underside.png` and `after_underside.png` — the lower lobe from the side, and a low camera looking back at the wall.
- `after_edit_0_before.png` through `after_edit_3_undone.png` — expand, two raises, undo (`after_rim.json`).

A pixel scan across the front rim (425 samples on one row through the wall) found 6 sky-bright pixels and 13 pixels darker than luminance 50. The rest is mid grey, with seams around 50 against faces around 90–100. Those seams are shade, not openings onto the sky. From underneath, the closed bottom of each course is visible where the next course steps in, so the low camera reads more ledges than the side view does.

## Tests

- Headless: 29/29 `tests/terrain*_test.gd` (every terrain script except decoration regen and cottage material, which need a display). Includes editor runtime.
- Display: decoration regeneration 42/42, including the check that an expand reuses more rim runs than it rebuilds; cottage material 7 checks, 0 failures.
- Shrub bases stay on turf: 43608 points, 0 unsupported. Shrubs that would sit on a rim head are still left off the crown.

## Remaining gaps

- The blocks are a repeated cut octagon, not the concept's hand-fitted masonry. At gameplay distance the wall still reads as a faceted cliff. Close in, the courses and the corner cuts are visible, and SSAO darkens the joints.
- The foot narrows to 70% of the course width. It continues the wall, and it is not one carved taper. The low underside view shows the bottoms of the upper courses.
- Grass on the crown is the existing lawn function plus a few tufts. Flowers and vines over the lip stay deferred.
- The footprint is still the round 6 elongated island. The cottage, path and garden were not moved.
- The 0.55 s height ease was not recaptured. Its shader path was not changed; round 6 still has the paused-clock sequence. Removed land still disappears when the revision publishes, and the cottage still does not ease.

## Performance (this host only)

Default view at 1671×941: 763 draw calls and 1,998,773 primitives. Host frame time on that capture was about 1035 ms. Round 6 at the same resolution was 763 draws and about 2.02M primitives. The 720p feature-cost benchmark was not rerun. Target-laptop frame time and idle power are not measured.
