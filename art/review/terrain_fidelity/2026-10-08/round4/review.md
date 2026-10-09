# Round 4: standing stone columns, grass tone, waterfall volume, smaller shore stones

2026-10-08. Scope: the owner's three round-3 pushes, plus a shore-stone size tweak.

1. Replace the faceted procedural band between the turf lip and the hanging boulders with tall standing stone columns.
2. Shift the grass toward the concept's lighter, greyer olive.
3. Make the falls read thick and frothy instead of a streaked plane, and remove the lower-fall seam.

Lake water, edge vegetation, the vine design and the lighting are not touched. The result is a review candidate, **not aesthetic acceptance**.

Captures are actual Godot 4.7.2 Forward+ renders of `scenes/terrain_editor.tscn` on a cloud VM using Mesa lavapipe (software Vulkan), 1671 × 941, MSAA 4×. `tests/capture_lighting_round.gd -- after out=2026-10-08/round4` reproduces the default pose and the left/right/back orbits. "Before" is `../round3/after_*`. `after.json` records poses and submission counters. PNGs are kept locally (gitignored) and attached to the PR.

## Cliff columns

- Two existing CC0 Kenney stones, `stone_smallFlatA` (20 tris) and `stone_largeD` (80 tris), are stood upright and baked into unit boxes. They form two instanced kinds, `cliff_column` and `cliff_column_b` (about 68% and 32%). Upright `smallFlatA` gives flat-faced prism blocks; `largeD` gives tapered, more weathered blocks. No model was downloaded and no new source geometry was authored.
- `TerrainDecoration._column_layout` covers broad, dry outer walls along every outline segment. These are walls with a supporting shell, not beside a lake or fall, and with inset ≥ 0.9.
  - **Width:** a block can span two nearly straight segments. That choice belongs to the shared vertex, and two consecutive vertices never both join, so block width varies from about 0.35 to 2.3 m. The default island gets 98 blocks, 1.7–4.8 m tall. Segment ends are world-anchored lattice crossings, so an edit only moves nearby blocks.
  - **Joints:** 0.07–0.17 m.
  - **Top:** 0.03–0.13 m below the turf. The block front sits from 0.03 m behind to 0.09 m in front of the lip line.
  - **Height:** 45–86% of the local wall depth, so block feet are stepped.
  - **Variation:** thickness 0.85–1.1 m, slight yaw and lean, a random 180° flip, and the per-stone tone used by the shore and underside stones.
  - The layout is computed once per contour revision. `ContourTerrain.revision` is new and increments on each refresh.
- `cliff_column.gdshader` uses the shared cliff palette and softened source facet shade. It adds vertical weathering streaks, a darker foot, darker downward faces, and moss on block tops plus a ragged fringe just under the turf.
- `ContourTerrain._profile_point`: from just under the lip to about 3 m down, the broad dry outer wall is kept at least `COLUMN_RECESS` (0.30 m) behind the lip line. Joints therefore show recessed rock, and SSAO darkens them into deep crevices. Buttresses and relief no longer poke through the blocks. Below that band, and on narrow necks, walls beside falls, terrace joins and the cap contour, nothing changes.
- The round-3 hanging Quaternius boulders at the shell foot are kept and give the underside its rounded stone-mass silhouette. The round-3 corner and mid-wall boulders are removed because they cut through the columns. Underside depth is unchanged.
- Hanging vines that fall in front of a column now drape onto its actual mesh, using a ray against the world triangles of nearby columns. Before this, they would have been hidden behind it. The vine design itself is unchanged.

## Grass tone

Measured over the same three grass regions as the concept, as mean rendered colour:

| | Left terrace | Right terrace | Lower terrace |
| --- | --- | --- | --- |
| Concept | (151, 138, 96) L .48 S .22 | (148, 136, 94) L .47 S .22 | (143, 139, 100) L .48 S .18 |
| Round 3 | (150, 137, 74) L .44 S .34 | (123, 118, 69) L .38 S .28 | (117, 110, 66) L .36 S .28 |
| Round 4 | (155, 142, 95) L .49 S .24 | (125, 119, 79) L .40 S .23 | (129, 122, 82) L .41 S .22 |

- `land_palette.gdshaderinc`: `grass_base` (.43, .49, .30) → (.46, .51, .42), and `grass_highlight` (.66, .65, .40) → (.64, .65, .54). This lowers saturation, raises blue and removes the yellow cast. The cliff turf lips and shore transitions share the palette and follow.
- `ground.gdshader`: the dry, lush, dark-tuft and light-tuft multipliers are lifted and desaturated, so shaded and lush patches stay lighter grey-olive instead of dark saturated green. The tuft layers, mottling, seed heads, grain and relief are unchanged.
- The curved grass blades and grass clumps move from dark (.15, .19, .10) / light (.35, .38, .22) to (.17, .19, .12) / (.38, .39, .27).

## Waterfall: analysis and what was tried

The concept fall is a thick, bright white, aerated body with soft edges that dissolve into spray, and the lower fall ends in mist. The round-3 fall was one flat sheet with painted vertical streaks. It was blue-grey and translucent in shade, and the change of backdrop from rock to sky showed through as a seam on the lower fall.

- **Offset spray shell (rejected):** a second, offset pass over the same mesh. Waterfall vertex normals are not consistently outward (262 outward-facing triangles against 106 inward on the default island), so an offset along the normal would bulge into the cliff on part of the curtain. I didn't pursue it.
- **Thicker core sheet (implemented, `waterfall.gdshader`):**
  - The core turns white within about 0.8 m of the lip. Glassy, light blue-grey water stays only at the lip.
  - Below the lip the core is nearly opaque (0.985 in white water), which removes the rock-end seam.
  - Shading uses a two-tone white (soft grey-blue in grooves, bright white on ridges) and stronger self-illumination, so the shaded side stays white.
  - Normals wrap across the width (from the run's across coordinate), so the body shades as a rounded column of water with a lit side and a shaded side.
  - Edges are feathered and widen with drop. The motion keeps the same two steady layers of falling streaks, with less fine-noise contrast to avoid flicker.
- **Spray veil (implemented, `waterfall_mist.gd`):** `ContourTerrain.fall_veils` publishes each connected curtain's lip, foot, width, outward direction and whether it falls off the island. The existing camera-facing mist MultiMesh now also emits 4–16 puffs per curtain.
  - Most puffs gather at the ragged sides, and the rest veil the face; they drift down with the water.
  - Falls that drop off the island get 4 larger cloud puffs where the sheet fades, so they dissolve into mist like the concept.
  - Plunge puffs are unchanged. The cost is the same single mist draw, with 15 extra puffs on the default island (22 instead of 7).
- Plunge foam geometry, ripples and lake water are unchanged.

## Shore stones (owner add-on)

`SHORE_STONE_SCALE` 0.62 scales size and sink together for boulders, medium stones and pebble clusters. Their relative size spread, free yaw, tilt, partial submersion, group pattern and plunge-zone clearance are unchanged. More short grassy bank shows between stones.

## Tests

- All 28 headless `tests/terrain*_test.gd` scripts exit 0. Decoration passes 65/65 (the extra checks come from the new MultiMeshes, still ≤ 20 per chunk), and the shape diagnostic finds 0 wedges in 907 substantial cliff triangles.
- The two rendered suites pass on lavapipe: editor runtime 22/22, and cottage material 7 checks with 0 failures.
- **Intentional test change:** `terrain_vine_contact_test.gd` required every hanging vine centroid to touch the procedural cliff mesh, which encoded the old cliff face. Vines over a column now hang on the column. The test now also accepts the columns' actual world triangles as support; the 0.10 m limit is unchanged. All five fixtures (default plus four edits) report 0 missing and 0 separated, with a maximum gap of 0.025 m.

## Performance (current host only)

`tests/benchmark_lighting_round.gd -- after out=2026-10-08/round4` runs at 1280 × 720 on a 4-core lavapipe rasterizer, so the numbers are relative only (`feature_cost_after.json`). Median viewport GPU time with everything on is 463–466 ms, against 465–475 ms in round 3, so the change is within noise. Turning the waterfall mist and veil off saves about 6 ms. Draw calls rise by about 50–57 per view, from the two column kinds and their shadow pass. Primitives fall by about 40k, because the corner and mid-wall boulders are gone. Target-laptop FPS and idle power remain unmeasured.

## Remaining gaps vs concept

- The columns are two stretched low-poly shapes with flat-shaded facets. Large blocks show their source triangulation as faint diagonal shading. They have no carved horizontal fractures or chipped edges, and the concept's blocks are crisper and lighter on their sunlit faces.
- The inner step wall between the two terraces and the walls beside falls and lakes keep the procedural face; columns cover only broad outer walls. Below the column feet some procedural rock still shows above the hanging boulders.
- Sunlit cliffs and column faces in the back orbit still read sandy under the warm sun.
- Grass now matches the concept tone in sunlit areas, but shaded areas are still darker (L .40 against .47). Next to the greyer grass, the yellow-green lily pads and some shrubs now read more saturated than the concept.
- The falls are still a single shaded sheet. Volume comes from shading and the veil puffs, not geometry, and the puffs can read as soft beige blobs against dark rock. The concept's fall is wider and brighter, with a clearer spray cloud at the bottom.
- Edge shrubs, hanging vines over the column faces and cliff-face greenery are still the deferred next round.
