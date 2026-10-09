# Round 5: rock-crowned island rim, and decoration that follows terrain edits

2026-10-08. Scope: the owner's round-5 points on stones and the island edge only.

1. The edge should read as the tops of rock forms, not a polyline where lawn is cut onto a cliff.
2. Expanding or sculpting must keep that rock-top edge.
3. Confirm that lookdev decoration (rim columns, underside boulders, shore stones, vines) rebuilds when terrain is edited, fix any static bake, and document it.

The cottage/layout proportion pass, a full edge vegetation system, the waterfall and the grass tone are not touched. Shore stones keep the round-4 0.62 scale. The result is a review candidate, **not aesthetic acceptance**.

Captures are actual Godot 4.7.2 Forward+ renders of `scenes/terrain_editor.tscn` on a cloud VM using Mesa lavapipe (software Vulkan), 1671 × 941, MSAA 4×. PNGs are kept locally (gitignored) and attached to the PR; the JSON files record poses and submission counters.

- `tests/capture_lighting_round.gd -- after out=2026-10-08/round5` gives the default pose and the left/right/back orbits (`after_*`, `after.json`). "Round 4" is `../round4/after_*`.
- `tests/capture_rim_round.gd -- after` (new) gives three close rim views at the gameplay pitch (upper front, lower right, terrace step) and an edit sequence: before, expand at the lower terrace's dry right edge, raise part of the new land twice, then three undos (`after_rim_*`, `after_edit_*`, `after_rim.json`). The edit goes through `TerrainData`'s brush/undo API and is published by the scene's own `TerrainRenderer`, as an editor stroke would be.
- `round4_rim_*` and `round4_edit_*` are the same script run on the round-4 commit (`e8d3e92`) in a separate worktree, for a like-for-like before.

## Rim: rock crowns instead of a cut lip

**Rim blocks** (`TerrainDecoration._column_layout`). The round-4 columns stood 0.03–0.13 m *below* the turf behind a hard lawn lip. They are now rim blocks whose crowns form the edge.

- **Crown height:** each block's crown rises 0.03–0.15 m above the turf at its own edge point.
- **Plan:** blocks step 0.06–0.58 m outward from the contour and have thickness 0.95–1.30 m (plus the step-out), so the silhouette is a run of rock heads that step in and out.
- **Joints:** 0.10–0.22 m. Spacing is about 2.1 m, and a block can span two nearly straight segments (join chance 0.65), so widths vary from about 0.3 to 3 m.
- **Height:** outer blocks hang 35–80% of the wall depth.
- **Pose:** slight yaw and lean. A random quarter turn of the source stone (applied before scaling) shows a different face per block.
- **Coverage:** broad dry outer walls (supporting shell, inset ≥ 0.9, no lake, more than 1 cell from a fall) and, new this round, broad dry **terrace steps** (`ContourTerrain` profile flag `step`: dry on both sides, at least 0.9 m tall, inset ≥ 0.9). Step blocks stand on the lower terrace.
- **Step or outer:** each block decides from its own profile, so a segment that turns from a step onto an outer wall stays clad.
- **Shared edges:** an outer wall appears in the outline of every elevation, so only the outline at the wall's own top owns its blocks. There are no duplicates; round 4's 98 included repeats on shared edges. The default island has 57 blocks (19 on the lower terrace), and the layout takes 14 ms per contour revision on this host.

**Four shapes.** These are all existing CC0 stones, stood upright and baked into unit boxes: Kenney `stone_smallFlatA` (flat-faced prisms), `stone_largeD` (tapered), and, new this round, Kenney `stone_largeB` and Quaternius `Rock_Medium_2` (rounder, lumpier heads). They form four instanced kinds, `cliff_column`, `_b`, `_c` and `_d`. No model was downloaded and no source geometry was authored.

**Crown keeps its bevel** (`cliff_column.gdshader`, mirrored on the CPU by `TerrainDecoration.crown_remap`).

- Stretching a stone to 2–4 m used to turn its rounded top into a vertical smear. The vertex shader now keeps the source stone's top fifth at about 0.30 m of real height and stretches only the body. Vine draping uses the same remap.
- Normals are flat facet normals from screen-space derivatives.
- Crowns facing up get the island's lawn (shared function, below), with the lawn normal. Just under the crown is a moss fringe, then the stone tone, streaks and darker foot from round 4.

**Grass over the crowns.**

- 55% of blocks get a grass tuft spilling over the outer edge of the crown.
- Ground modules (grass, clumps, shrubs, flowers, surface rocks, fence, path) whose point falls on a crown are lifted onto it (`_rim_lift`), so they are never buried in the stone. Trees are excluded: a trunk sinking at most 0.11 m into a crown is invisible, and tree height stays measured from terrain contact.
- Hanging-vine roots seat on the crown.

**Procedural rim** (`ContourTerrain._profile_point`, `cliff.gdshader`).

- Where no block stands (joints, short pieces, corners), the old lip notch is removed. Broad dry walls and terrace steps now round over in a convex shoulder (`SHOULDER_DEPTH` 0.45 m, bulge 0.10 m), then recess behind the block plane (`COLUMN_RECESS` 0.30 → 0.40 m), so joints read as crevices.
- Cliff vertices now carry the cap height and whether that cap is dry land (cliff UV). The cliff shader rolls the same lawn over the shoulder, followed by a ragged moss fringe, so the turf turns down onto rock instead of stopping on a line.
- Both terrace contours stay exact.

**Shared lawn.** The ground cap's colour logic moved unchanged into `ground_cover.gdshaderinc`. The cap, block crowns and the cliff shoulder all call it, so the lawn continues onto rock without a seam in tone or tuft pattern. The grass tone itself is unchanged from round 4.

**Stone tone.** `cliff_palette.gdshaderinc` grey moves from (.38, .36, .32)–(.52, .49, .42) to (.43, .42, .39)–(.58, .56, .51), about 10–15% lighter and cooler, matching sampled concept rock. Cliff, blocks, shore and underside stones share it.

Underside boulders are kept as they were (rounded mass at the shell foot). Shore stones are unchanged at 0.62 scale.

## Does decoration follow edits? Audit and result

**Before this round, everything already regenerated; nothing was a static bake.** Trace through the code:

- `TerrainRenderer.flush_dirty` copies the cells and calls `contours.refresh` whenever `data.revision` changes; `ContourTerrain.revision` increments on every refresh. It then rebuilds every chunk that has or had geometry, plus every chunk the shared cap triangulation touches.
- Each chunk rebuild calls `TerrainDecoration.populate`, which calls `placements(data, chunk)` on the refreshed contours. Each pass:
  - rebuilds the outline-wide rim-block layout, cached only by `(contour revision, seed)`;
  - places underside boulders, shore stones, reeds and lilies from the current outlines and lake regions;
  - places vines from the current outline and cliff profile, draping them onto the current blocks;
  - places grass, clumps, shrubs, flowers and surface rocks from the current surface.
- Chunks publish as one complete revision, and `_publish` then re-syncs the support-checked homestead props (`TerrainProps.sync`) and the waterfall mist (`splash_points`, `fall_veils`).
- The homestead layout anchors (cottage, four tree spots, fences, path, three flower groups, house clearing) are fixed positions by design. They are layout, not lookdev: each is support-checked against the current surface and disappears when its land is removed. This is unchanged and belongs to the deferred layout pass.
- Plant cover is shader-only and samples the current mesh.
- Distant mountains and cloud decks do not depend on the island.

**What was fixed or added this round:**

- **Duplicate blocks on shared outline edges** are removed. Previously an edit near a shared edge rebuilt two overlapping copies.
- **Rim lift and crown remap** read the same per-revision layout, so ground modules and vines re-seat on the current crowns after every edit, not on round-4 crown positions.
- **Per-block step or outer decision:** an edit that turns a step into an outer wall, or the reverse, re-clads correctly.
- **New test, `tests/terrain_decoration_regen_test.gd`** (41 checks; run with a display). It edits the homestead island through the brush/undo API and publishes with the real renderer. After every step it checks that each published decoration instance, of every kind in every chunk, equals a placement computed from scratch: copied cells, new contours, and a decoration object that has never seen an earlier revision. The steps are:
  1. the initial island;
  2. expand;
  3. raise twice;
  4. save → load;
  5. preset reset;
  6. contract of a clad upper-terrace wall;
  7. undo, redo and undo again;
  8. expand and raise, then undo both.

  It also checks:
  - every rim-block crown sits 0.02–0.16 m above the current turf at its edge;
  - expanded land carries at least 3 new blocks on its new edge, more underside boulders and re-seated vines;
  - raised land carries blocks at the raised height;
  - no block remains on contracted cells, and the new edge is clad again;
  - undo restores the initial decoration exactly, transform for transform.

  As a check that the test can fail, freezing the block layout after the first build gives 17 failures out of 41.
- **Headless caveat:** Godot's headless dummy renderer keeps no MultiMesh buffer, so instance transforms read back as identity. The new test refuses to run headless instead of passing vacuously. This also means `terrain_incremental_test`'s MultiMesh comparison only checks instance counts when run headless, as it is in the suite. It still passes 20/20 headless and is unchanged.

The edit captures show the same thing visually. The expanded land on the lower terrace's right edge gets its own rock-crowned rim, an underside boulder and vines; raising it lifts the blocks; three undos return to the original edge. Pixel differences between "before" and "undone" come from animated clouds, water and wind, not geometry.

## Tests

- **Headless:** all 28 `tests/terrain*_test.gd` scripts exit 0 (excluding the three rendered suites). Decoration passes 79/79 and incremental 20/20. The shape diagnostic finds 0 wedges in 809 substantial cliff triangles.
- **Rendered suites (lavapipe):** decoration regeneration 41/41, editor runtime 22/22, and cottage material 7 checks with 0 failures.
- **Intentional test change:** `terrain_editor_decoration_test.gd` required grass and clumps to sit exactly at turf height. Over a rim block they now sit on its crown (turf + 0.0–0.11 m), and crown tufts sit 0.05 m into a crown. The test computes the expected height from the published blocks (`rim_top_at`) and accepts crown tufts. It also checks clumps before the raise step, so it compares against the layout they were placed with. The other assertions are unchanged.
- `terrain_vine_contact_test` is unchanged: 0 missing and 0 separated in all five fixtures, with a maximum gap of 0.025 m.

## Performance (current host only)

`tests/benchmark_lighting_round.gd -- after out=2026-10-08/round5` (`feature_cost_after.json`) runs at 1280 × 720 on a 4-core lavapipe rasterizer, so the numbers are relative only. It now also has a rim-blocks-off toggle.

- **Run-to-run noise** on this host is about ±20 ms. Round 4's two all-on medians were 466 and 463 ms. Over three round-5 runs, the all-on and all-on-again medians were 500/506, then 496/507 (after skipping the lawn function on bare rock), then 484/462 (the saved file).
- **Rim blocks:** in the saved run, hiding them gives 460 ms, so their cost is within noise here. The round-5 cost is at most about 5–8% of host GPU time and may be less; this host cannot resolve it further.
- **Submission counts:** draw calls in the default view are 749, against 733 in round 4 (+16, from two more block kinds and their shadow pass). Primitives rise by about 14k (2.054M against 2.040M).
- Rim blocks remain one MultiMesh per kind per chunk; the sources are 20–244 triangles.
- The shoulder adds no geometry; it reshapes existing cliff vertices.
- The layout is computed once per edit revision (14 ms on this host).
- Target-laptop FPS and idle power remain unmeasured.

## Remaining gaps vs concept

- The concept's rim is a continuous chain of chunky, rounded, sunlit rock heads with lush grass and flowers spilling over. Here, blocks still alternate with stretches where only the rolled lawn shoulder shows: joints, short outline pieces, corners, walls beside falls and lakes, and some of the inner terrace step. Those stretches still read as a soft edge on a cliff rather than rock tops.
- Blocks are stretched low-poly stones with flat facets. Large faces show source triangulation, and there are no carved fractures or chipped edges.
- Crown lawn and tufts are sparse compared with the concept's overhanging grass and flowers. That belongs to the deferred edge-vegetation round.
- Lake banks keep shore stones and the procedural rim. Rim blocks are skipped beside water by design, so wet edges do not get rock heads.
