# Round 2 — lighting correction, water, shore stones, island silhouette

2026-10-08. Scope: correct the overdone round-1 lighting, then water, shore stones and the island's cliff silhouette and thickness. Edge vegetation and hanging vines are not touched (next round). The result is a review candidate, **not aesthetic acceptance**.

Captures are actual Godot 4.7.2 Forward+ renders of `scenes/terrain_editor.tscn` on a cloud VM using Mesa lavapipe (software Vulkan), 1671 × 941, MSAA 4×, gameplay camera. `tests/capture_lighting_round.gd -- after out=2026-10-08/round2` reproduces the round-1 default pose and orbits. "Before" is the round-1 result (`../lighting_round1/after_*`). `after.json` records poses and submission counters. PNGs are kept locally (gitignored) and attached to the PR.

## Lighting correction

| Setting | Round 1 | Round 2 |
| --- | --- | --- |
| Fog | exponential 0.0008, `e6cfae` | 0.0004, warm gold `ebc58f` |
| Sky gradient | beige-white horizon, strong sun halo | warmer gold horizon and zenith, softer halo |
| Sun disc | HDR core (2.7, 2.15, 1.4), clips white | (1.0, 0.90, 0.60): warm, unclipped in Linear |
| Glow | HDR threshold 1.0 | 0.92 (keeps a little bloom on the disc and glints) |
| Fill / ambient | 0.20 / 0.50 | 0.16 / 0.40 |
| Grade | none | adjustments: contrast 1.08, saturation 1.06 (no tint, no LUT) |
| Cliff stone albedo | `cliff_gray` 0.34–0.45 | 0.38–0.52, lighter warm grey |
| Mountains / clouds | — | slightly cooler stone base; whiter sunlit cloud tops |

Sun direction, shadows, SSAO and mountain aerial perspective are unchanged. The island keeps clear shadows and darkened crevices but sits under much less haze. The sun reads as a warm disc with a halo.

## Water

- `water.gdshader`: clear teal shallows and deep colours, with a pale bed tint and soft moving caustics showing through the shallow margin. A darker reflection band appears beside the far bank, from the shore-field gradient (4 extra texture taps). Receiving water is paler and aerated. Roughness is 0.20, and specular is lowered in the bank band.
- The sky's radiance cubemap now uses the same warm `sky_gradient`, so reflections are warm gold instead of the old cool blue/ivory.
- Plunge (`contour_terrain._splash` + `foam.gdshader`): the foam mound is taller (peak 0.13 m), with a white, nearly opaque core and slight emission so it stays white on the shaded side. Ripple rings are fainter.
- Mist (new `waterfall_mist.gd` + `waterfall_mist.gdshader`): one MultiMesh of camera-facing puffs, 7 per plunge centre recorded by `ContourTerrain.splash_points`. They are unshaded, rise and swell on per-puff phases, and use a depth-buffer soft contact (no hard card edges). No shadows. The mist rebuilds in the same publish step as the terrain.
- Still opaque: no refraction or screen-space reflection, so the cottage, trees and banks are not actually reflected. The bank band is an approximation.

## Shore stones

- Three Kenney CC0 stone meshes: `shore_boulder` (`stone_largeB`, new), `shore_rock` (`stone_largeD`, kept) and `shore_pebble` (`stone_largeA`, new).
- A world-anchored group field places runs of large shouldered boulders (about 1.4–1.9 m wide, 0.8–1.2 m tall). Elsewhere medium stones mix with 2–3-stone pebble clusters, with occasional gaps. Grassy-bank reed sections are unchanged.
- Stones jitter along and across the edge. Medium stones and pebbles often stand out in the water and sit lower, partly submerged. Boulders and pebbles take any yaw, and all stones get a slight tilt. Stones are not pushed into the lake within about 1.2–2.4 m of a plunge.
- Each stone gets a deterministic tone from its position (warm ochre, cool slate or moss-dark, ±20% value) through MultiMesh instance colour. Per-facet value steps are stronger so facets read under soft light. The shoulder-preserving vertex compression on `stone_largeD` is kept; nothing is flattened into slabs.

## Island silhouette and thickness

- `UNDERSIDE_THICKNESS` 0.60 → 0.80: the shell keeps 80% of the original underside depth. At the default 1.5 m terrace, depth goes from about 2.6 m to 3.4 m.
- `_keel_floor`: broad outer walls hang stepped, world-anchored lobes (cells of about 3 m, up to 1.1 m extra). The bottom edge is uneven but stays one mass. The keel is clamped at −3.0 m, the existing −3.08 m floor test still holds, and narrow necks and low edited land keep their old thin body.
- Buttresses in `_profile_point`, for broad outer walls only: blocky world-anchored in/out steps of ±0.5 m, so faces sit forward or back. Forward masses settle back before the foot. A 0.24 m notch just under the lip lets the turf edge overhang. Walls beside falls and narrow necks are unchanged, so curtain clearance holds.
- The cap contours, the two terraces, both lakes, the connecting fall and the editable height data are unchanged. Picking uses the same mesh.

**Intentional test change:** `terrain_homestead_test.gd` asserted a 55–65% shell-depth ratio, which encoded the superseded thin-underside decision. It now asserts 78–82%, plus a check that the keel stays between the slab and the −3.0 m limit. No other test was changed.

## Tests

- All 28 headless `tests/terrain*_test.gd` scripts exit 0.
- The two rendered suites pass on lavapipe: editor runtime 22/22, and cottage material 7 checks with 0 failures.
- Shape diagnostic: 2 elongated wedges out of 650 substantial cliff triangles (limit 8%).

## Performance (current host only)

`tests/benchmark_lighting_round.gd -- after out=2026-10-08/round2` runs at 1280 × 720 on lavapipe, a 4-core CPU rasterizer, so the numbers are relative only. Median viewport GPU time is 425 ms with everything on, and 429 ms with the waterfall mist off, which is within noise. Glow off saves about 35 ms and SSAO off about 40 ms. The water shader adds 6 texture taps per lake pixel and no extra pass. Target-laptop FPS and idle power remain unmeasured.

## Remaining gaps vs concept

- Water is still an opaque stylised surface. The concept's actual reflection of the near shore, trees and cottage is not reproduced, and the clarity is a painted bed tint, not real depth.
- Cliffs: the outline now steps and the slab is thicker. The concept's tall, near-vertical columnar faces and the deep shadows between them are still softer and lower-contrast here. Hanging vines and edge vegetation (next round) supply much of the concept's cliff texture.
- Shore stones are still Kenney meshes with a limited facet vocabulary. The concept's stones are larger, rounder-shouldered and more densely packed along the whole rim.
- The sky and mountains are still simple compared with the concept's layered, sculpted peaks and cumulus. The grass is more yellow-green than the concept's olive.
