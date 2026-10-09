# Round 3 — stone underside, soft plant cover, waterfall material

2026-10-08. Scope: the owner's three round-2 notes. The jagged, hard-cornered underside becomes rounded stone masses, the clean island top gets a light simulated plant cover, and the jelly-like falls read as falling water. Lake water, mist, lighting, edge vegetation, vines and cliff columns are not touched. The result is a review candidate, **not aesthetic acceptance**.

Captures are actual Godot 4.7.2 Forward+ renders of `scenes/terrain_editor.tscn` on a cloud VM using Mesa lavapipe (software Vulkan), 1671 × 941, MSAA 4×. `tests/capture_lighting_round.gd -- after out=2026-10-08/round3` reproduces the round-1/2 default pose and the left/right/back orbits. "Before" is `../round2/after_*`. `after.json` records poses and submission counters. PNGs are kept locally (gitignored) and attached to the PR.

## Underside and corners

- Existing CC0 Quaternius rocks `Rock_Medium_1` and `Rock_Medium_2` (`assets/nature/quaternius/`, with their `Rocks_Diffuse.png`) are loaded as two new decoration kinds, `underside_rock` and `underside_rock_b`. They are not merged into the batched static mesh. Each is normalised to unit width with its top centre at the origin. No new geometry was authored.
- `terrain_decoration._underside_rocks` walks the broad outer shell walls. Placement is deterministic, with world-anchored 1.45 m dedupe cells. It skips walls beside lakes and within two cells of a fall, so curtain clearance is unchanged. Each anchor places:
  - a large rock (2.6–3.5 m) hanging crown-down from the shell foot and tilted outward, so the bottom reads as a cluster of rounded boulders;
  - at turns of the outline, a larger corner rock at about 30% depth, so corners become one rounded mass instead of a miter;
  - often, a smaller mid-wall rock at 38–58% depth, which breaks the face into stacked lobes.
- `underside_rock.gdshader` uses the shared `cliff_gray` palette, the rock texture's value only, a per-instance tone (same scheme as shore stones) and slight darkening on downward faces. Rocks cast shadows.
- `contour_terrain._step_field` now eases across the whole cell (smoothstep) instead of short ramps. The keel and buttress fields therefore swell into rounded lobes instead of hard steps. The keel limit, the 80% shell depth, the lip notch and narrow-neck behaviour are unchanged.

## Surface plant cover

`ground.gdshader` only. No new instances or draw calls.

- Broad mottling between drier, paler and lusher olive patches, shifted by a three-octave cover height.
- Two overlapping layers of cellular tufts (about 0.43 m and 0.22 m) with irregular rims. Each tuft is darker olive or lighter dry grass, and has dome-shaped normals so it catches the sun like low clumps.
- Sparse pale seed-head specks and fine grain.
- `cover_relief` (0.55) sets the lighting relief. All tuft detail fades with screen-space footprint, so distant terraces don't shimmer.
- Grid overlay, paths, fields and the existing grass, flower and shrub instances are unchanged. The base grass hue was not rewritten; lusher patches only pull it toward olive.

## Waterfall

`waterfall.gdshader` fragment only. Geometry, the vertex metadata, plunge foam, mist and lake water are unchanged.

- Water starts as a glassy, darker lip band and aerates to white over the first metre or so of drop.
- Two constant-speed strand layers (slow near the lip, fast lower down) are blended by drop. This gives the effect of acceleration without the old stretching-and-sliding filaments. A finer, faster strand layer and descending packets break up the regular stripes.
- The edges are ragged, uneven insets that widen with drop. Thin translucent gaps open between strands in the lower fall; the core stays near opaque.
- Groove normals come from the strand relief. Roughness and specular differ between glassy water and white water, and there is a little emission on white water so shaded falls don't go grey. External falls still fade before the shell end.

## Tests

- All 28 headless `tests/terrain*_test.gd` scripts exit 0. Decoration has 63/63 checks; the shape diagnostic finds 0 wedges among 713 substantial cliff triangles.
- The two rendered suites pass on lavapipe: editor runtime 22/22, and cottage material 7 checks with 0 failures.
- No assertion changed this round. No existing test encoded the jagged underside.

## Performance (current host only)

`tests/benchmark_lighting_round.gd -- after out=2026-10-08/round3` runs at 1280 × 720 on a 4-core lavapipe rasterizer, so the numbers are relative only (`feature_cost_after.json`). Median viewport GPU time with everything on is 465–475 ms, against 425 ms in round 2, which is about +10%. Likely causes are the heavier ground fragment shader (two 9-cell tuft loops plus noise) and the shadow-casting underside rocks (two extra instanced kinds, 244–342 tris per instance). Turning the sun shadow off saves about 85 ms, and SSAO off about 65 ms. Target-laptop FPS and idle power remain unmeasured. If the tuft loops prove costly on target hardware, the second tuft layer can be dropped at low quality.

## Remaining gaps vs concept

- The upper cliff wall between the lip and the hanging boulders is still the faceted procedural face. The concept's tall columnar blocks and deep vertical shadows were out of scope.
- The rocks are low-poly Quaternius forms with only texture value detail. From some orbits the repeated two shapes are recognisable, and where boulders overlap a vine the vine can be partly hidden.
- Plant cover is a surface shader. It has no real fuzz on silhouettes or at the turf lip, which edge vegetation (next round) should supply. Sunlit grass is still more yellow than the concept's olive.
- The falls are still a single sheet: no separate spray veil, side mist strands or volume. The lower fall shows a faint seam where the rock behind it ends.
- Lit cliffs in the back orbit read slightly sandy. Mountains, clouds and the lake are unchanged from round 2.
