# Round 8 — independent rock bodies

Captured 2026-10-10 from the running terrain editor (Forward+, llvmpipe, 1671×941). The concept is the owner's island schematic. Round 7 is `../round7/`. This is not visual acceptance.

## How a body is built, against round 7

Round 7 baked one chamfered octagon and stretched it. The mesh was a unit box: x/z in [−0.5, 0.5], y in [−1, 0]. Placement scaled that box to the contour run (width = span + 0.95 m, thickness about 1.7–2.3 m, height about 1.7–2.6 m), so each instance became a wall panel. Several panels sat along one run. More panels were stacked underneath, overlapped by 0.62 m, and the last course was a second, tapered mesh (`underside_rock`). The shader then squashed the top fifth of every panel to about 0.30 m. The turf polyline stayed the edge. The blocks decorated it.

Round 8 does not place those panels, and it does not reuse the round 6 egg meshes for the silhouette. Each of the six kinds is one closed solid, baked once and instanced.

The plan is 6 or 7 corners (`seed % 4` picks the count; seeds 11, 23, 37, 41, 53, 67). Spans and radii are unequal. The longest edge is a real face: both of its corners are pushed out, and the opposite corner is pinched in. That face is turned toward the outside of the island. Four rings share the plan. Down the body the rings lean, twist by at most about 0.16 rad, and each corner swells at its own height. The crown ring is the widest. Its vertices drop by different amounts, up to about 6% of the mesh height, so the top is not a flat chamfer. The foot stays blunt, about three quarters of the crown, with a small per-corner difference. A uniform fit keeps the long axis inside ±0.5 and leaves the short axis short, so a wide face stays wide. Mesh height is about 1.35–1.72 and is not fitted into the unit box. A body is 144 or 168 vertices (48 or 56 triangles).

Placement puts one body on each contour run. Runs still join until about 2.15 m or a turn past 0.55 rad. The body's width and depth do not follow the run length. On a broad wall the world footprint is about 3.1–4.2 m along the rim and 1.9–2.7 m deep; a real neck (inset under 1.45 m) caps the depth. Height is chosen so the foot reaches that wall's own shell floor, about 4.9 m on the homestead median and up to about 6.6 m. Yaw is about ±0.80 rad, with a small lean and roll. The crown origin sits 0.06–0.14 m above the turf and 0.28–1.05 m proud of the contour. Neighbours overlap because each body is wider than its run. There is no second course. `underside_rock` and `underside_rock_b` are two of the six solids, not a foot mesh. The underside in the low shot is the bottom of the same bodies. The shell behind them is recessed 0.55 m, so it sits inside the mass instead of drawing a second outline. Waterfall mouths still shorten a run. Shore stones stay at scale 0.62 and do not set the rim.

The crown remap is an identity. The authored top is what gets drawn. Growth is still the 0.55 s height ease. An edit still rebuilds only the runs whose outline or nearby heights changed.

## Local regeneration

Same cache as round 7: the chord, the land height, cells within 3.5 m, fall veils, and the world seed. A fresh placement clears that cache; the decoration test still requires the published island to match it.

On this host, one measurement of the homestead outline:

| Pass | Hits | Misses | Layout | Bodies |
| --- | --- | --- | --- | --- |
| First build | 0 | 85 | 12.9 ms | 50 |
| Expand at (19.2, 4.6), radius 2.8 | 79 | 12 | 10.6 ms | 55 |
| Raise on that new land | 79 | 60 | 16.8 ms | 54 |

Baking the six meshes measured 4.1 ms. The first time the running scene compiled the rim shader, that span was about 25 ms.

## Screenshots

- `compare_default.png` — concept, round 7, round 8, default camera.
- `compare_rim_front.png` — the upper rim. Round 7 is stacked courses of the same chamfered box. Round 8 is separate standing masses.
- `compare_underside.png` — round 7's low view, round 8 from the side, and round 8 from below. The low view shows the bottoms of those masses, not another row of panels.
- `after_default.png`, `after_rim_upper_front.png`, `after_rim_lower_right.png`, `after_rim_terrace_step.png`, `after_bodies_side.png`, `after_underside.png`.
- `after_edit_0_before.png` through `after_edit_3_undone.png` — expand, two raises, undo.

A horizontal sample through the upper-front cliff (780 pixels) had a minimum luminance of about 57. The bright pixels on that row are sky beside the wall. The dark joints are shade in the crevices, not openings onto the sky.

## Tests

- Headless: 29/29 `tests/terrain*_test.gd` before the final body proportions, then the suites that read the rim were run again: editor decoration 79/79, vine contact 0 failures, shrub support 42028 base points with 0 unsupported and coverage held.
- Display: decoration regeneration 42/42, including expand reusing more runs than it rebuilds and deep bodies (world height ≥ 3.2 m) increasing on the new edge. Cottage material 7 checks, 0 failures.
- Shell floor and cliff taper were part of the 29. The shell recess is 0.55 m; those tests still passed after that change.

## Remaining gaps

- Six procedural prisms are not the concept's hand-fitted masonry. Close in, the faces are large and flat, and several masses still read as packed columns.
- Crown origins stay within 0.06–0.14 m of the turf, so the skyline is quieter than the concept. The break in the outline is the proud corners and the crevices, not rocks of different heights sticking up through the lawn.
- Grass on the crown is the existing lawn function plus a few tufts. Denser lip vegetation stays deferred. The cottage, path and garden were not moved.
- The 0.55 s height ease was not recaptured. Its shader path was not changed.

## Performance (this host only)

Default view at 1671×941: 705 draw calls, 1,955,504 primitives, host frame about 1009 ms. Round 7 at the same resolution was 763 draws and about 2.00M primitives, host frame about 1035 ms. Target-laptop frame time and idle power are not measured.
