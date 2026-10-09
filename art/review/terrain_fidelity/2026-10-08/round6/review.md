# Round 6 — rock mass, footprint, edit growth

Captured 2026-10-09 from the running terrain editor (Forward+, llvmpipe, 1671×941 unless noted). Concept reference is the owner's island schematic. Round 5 is `../round5/`. This is not visual acceptance.

## What changed

- **Edge.** Outer walls and dry terrace steps are a chain of overlapping retained CC0 stones (`cliff_column`, `_b`, `_c`, `_d`: Kenney `stone_largeB`, `stone_largeD`, `stone_smallFlatA`, Quaternius `Rock_Medium_2`). Heads are chunky (about 2.2–2.8 m wide, 1.6–2.4 m tall), rise 0.06–0.14 m above the turf, and stand 0.32–0.68 m proud. Runs follow the contour, including short corners, and stop only across a waterfall mouth.
- **Wall and underside.** The same stones continue down the outer wall. The foot is a wide Quaternius boulder (`underside_rock` / `underside_rock_b`) stepped inward and overlapped with its neighbours, so the underside hangs as part of that mass. The procedural shell stays 0.28 m behind the contour as joint fill. Shore stones stay at the round-4 scale (0.62). Waterfall and grass tone are unchanged.
- **Footprint.** Homestead preset only: a smooth union of the two lobes plus a front bridge closes the old waist notches. Both terraces, both lakes, the connecting fall, and editable height data stay. Cottage, path and garden are not moved.
- **Growth.** A published height edit eases in over 0.55 s (`shaders/terrain_editor/terrain_morph.gdshaderinc`). New land rises about 2.4 m; a raise lifts the column that is already on screen. Terrain, water, falls, rim stones and instanced decoration move together. A full rebuild snaps. The cottage does not take part in the ease.

Decoration is still derived from the current heights on every revision, including undo, redo and load.

## Screenshots

- `compare_default.png` — concept, round 5, round 6, default camera.
- `after_default.png`, `after_orbit_left.png`, `after_orbit_right.png`, `after_orbit_back.png` — round 6 orbits (`after.json`).
- `compare_rim_front.png`, `compare_rim_right.png` — round 5 beside round 6. Also `after_rim_upper_front.png`, `after_rim_lower_right.png`, `after_rim_terrace_step.png`.
- `after_edit_0_before.png` through `after_edit_3_undone.png` — expand at the lower terrace's dry right edge, raise part of the new land twice, then undo, published by the scene renderer (`after_rim.json`).
- `compare_growth.png` and `growth_expand_*.png` / `growth_raise_*.png` — same expand, then the raise, with the renderer clock paused. Progress 0, 0.12, 0.25, 0.40, 0.60, 1 over the 0.55 s ease (`growth.json`). At 0 the new tongue is below the clouds; by 0.25 it has mostly arrived; 0.60 settles slightly past the target and 1 rests on it. The raise lifts that ground instead of popping.

## Tests

- Headless: 29/29 `tests/terrain*_test.gd` (every terrain script except decoration regen and cottage material, which need a display). Includes editor runtime.
- Display: decoration regeneration 41/41; cottage material 7 checks, 0 failures.
- `terrain_shrub_support_test` is unchanged in what it requires (every shrub base vertex on the turf). Shrubs whose base would sit on a rim head are not placed, so they are not lifted off the ground beside the stone.

## Remaining gaps

- The concept's edge is a course of large, sunlit, cut stone blocks with grass spilling over a clean lip. These are retained organic boulders. From gameplay distance the wall still reads as a faceted cliff, and some joints open as dark pockets onto the shell instead of tight seams.
- The underside is overlapping rounded boulders stepped in from the heads. It is one mass with the rim in the layout, and it is not one carved volume. A few bulbs still read as separate stones, and the shell shows in the deeper pockets.
- The footprint is one elongated island instead of the round-5 pinch. It is not the concept's straighter, more architectural plan, and the cottage, path and garden were left where they were.
- Crown grass is the existing tufts. The concept's flowers and vines hanging over every lip are still the deferred vegetation pass.
- Growth eases height only. Land that is removed disappears when the revision publishes, rather than sinking away. The cottage stays put during the ease.
- Falls are still shaded sheets plus mist puffs. Water does not reflect the cottage or trees. Mountains and clouds are simpler than the concept.

## Performance (this host only)

`tests/benchmark_lighting_round.gd -- after out=2026-10-08/round6` (`feature_cost_after.json`) is 1280×720 on llvmpipe. One run. Round 5's saved all-on medians were 484 ms and 462 ms, and that review treated about ±20 ms as noise. This run is 494 ms all-on and 477 ms all-on-again, inside that noise of round 5. Hiding the rim stones and the underside boulders together drops this run to 450 ms, about 40 ms, which is a real slice on this host but not resolved past the noise. Default-view submission counts at 1671×941: 763 draw calls and about 2.02M primitives, against 749 draws and about 2.05M primitives in round 5. Target-laptop frame time and idle power are not measured.
