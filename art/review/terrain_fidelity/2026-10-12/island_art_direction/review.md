# 云露村 floating-island lookdev — 2026-10-12

Baseline: `ff4db69`; branch `cursor/lighting-atmosphere-round1-ad0c`. Actual Godot 4.7.2 Forward+ runtime captures, Apple M4 Pro, 1671×941. The concept is reference artwork, not an engine screenshot. The latest explicit user checklist governs this pass.

## Retained direction

The island reads as one suspended body with varied upper stones and a quieter lower mass. Crowns meet the grass cap directly, with local mineral exposure and supported turf clusters rather than a continuous grey bevel or painted green shoulder. Unequal spans vary close joints and open clefts; terminal splits are pinned so the jitter cannot create tiny tail stones. Roots bend into the lower body. Separate mantle blocks stop in the upper shoulder region; the lower turning face and bottom are continuous.

Two tileable 1024² linear packed maps provide stone mineral value/normal slopes/roughness and overlapping short grass blades. Mip chains filter close detail at distance. Ground, crown caps, physical turf and pond banks share the ground function and preserve the world-space compression path for later trampling. Existing supported pond-bank geometry gains matching normal detail. Authored land, ponds, props, save/edit data and original assets remain intact.

## Structural studies and stopping judgment

| Capture tag | Judgment |
|---|---|
| before | Fresh baseline at matched cameras. |
| crags | Broad shouldered crags: rejected the continuous bevel-like lip and toothy lower shape. |
| clusters | Denser hanging roots: rejected the packed individual teeth. |
| ledge | Thin rim above broad roots: rejected the artificial ledge belt. |
| sculpted / mass / joined | Inward roots and deeper shared base improved mass; affine closure repaired thin interpolation cracks. |
| atmosphere | Stronger sky/lighting change exposed repetitive cloud bands and cooled stone too far; reverted those parts. |
| rhythm | Unequal spans improve variation; final review caught and fixed terminal jitter slivers. |
| material / mineral | Packed maps introduced useful texture. Initial strong grain was too gritty; reduced strength and generated mipmaps. |
| rootmerge / after | More inward roots improved the front but rear orbit exposed lower plate crowding; not final. |
| eased / quiet | Removing downward and lower independent plates reduced crowding; remaining backing needed a gentler turn. |
| rounded | A quarter-ellipse-like taper and relief fading toward the foot improve the transition into the calm base. |
| softcore | Full backing-normal smoothing made the underside look like plaster; reverted. |
| turf | Denser taller turf patches became a decorative fringe; reverted. |
| retained | Fresh full orbit of the retained geometry and materials before final closure-lighting adjustment. |
| baseblend / final | Retained closure-only downward normal blending quiets the thin bright skirt line. Final adds two material close views. |

This is a local art-direction plateau after three distinct structural starts and multiple follow-ups. Two materially different final experiments (whole-surface smoothing and denser physical turf) did not improve the retained form. A narrowly scoped closure-lighting adjustment subsequently removed the bright underside skirt line without changing that form. It is not a claim of optimal beauty or concept parity. The concept still has richer vegetation, finer composition and more natural hand-shaped forms. Extreme low cameras retain some angular floor joins and visible root intersections; the gallery exposes these rather than hiding them.

## Independent review and fixes

Fresh read-only review by `final_island_review` inspected all 18 then-current images plus source and tests. No Critical findings. Three Important findings were addressed:

1. Terminal jitter created tiny stones: a 6 m section could end with a ~0.36 m sliver. Existing rim-system tests failed before the fix, then passed 24/24 after pinning the last split and preserving bounded internal jitter.
2. Both packed maps lacked mip chains. New `terrain_detail_mipmaps_test` failed both maps, then passed after import configuration and reimport.
3. Rear/low views still had many overlapping lower plates. Restricted independent mantle coverage to upper shoulders and reshaped the underlying turn. `terrain_mantle_transition_test` went from five lower plates to zero with continuous backing retained; `terrain_base_easing_test` went from tangent ratio 1.06 to 3.69. Follow-up orbit inspection, not those tests alone, supports the art judgment.

Earlier real regressions found during development: the new lower silhouette could return a nonexistent pick cell (runtime 18/22 → 22/22); nonlinear floor/skirt interpolation produced T-junction slits (42/54 sample failures → zero). The final floor uses shared piecewise-affine triangles and aligned skirt subdivisions.

Two stale checks were replaced without dropping their functional purpose: the physical crest bound now permits the intentional 7.5 cm patch crest, and the old chip-coordinate ray only calls a hit detached when it belongs to a tiny disconnected fragment. Bottom verification is stronger than the intermediate study: it isolates the tagged closure and requires a single shallow face per interior probe. Mantle validation requires every generated body to be closed with positive volume, without imposing the former >50-body density minimum.

Deferred minor: the old shoulder-lighting normal calculation in `cliff_column.gdshader` is overwritten by the new mapped facet normal. It has no visible effect; cleanup was left out of the review fix pass. Reviewer declined to judge no requested behavior.

## Fresh verification

- `tests-final.json`: 51/51 terrain suites pass, with no script/error output accepted as a pass.
- Rendered `terrain_decoration_regen_test.gd`: 42/42 pass after the geometry/material fix pass. Cached and freshly regenerated props match through editing and undo.
- Mantle default/expand/contract/deep-lower: zero open edges, base misses, lawn leaks, buried vines, remote block movement or remote cap movement.
- Calm tagged bottom: 259 interior probes, zero missing or layered faces; four steep transition probes within the 5% bound.
- Separate tests cover crown closure/union, shore-prop support, waterfall clearance, grass compression, orbit, save/edit runtime and material mipmaps.
- 20 actual final views: six matched overall/distant/detail views, two material close views, six elevated orbit angles and six low orbit angles. Water animates, so frames are not pixel-identical in time.

No target-device FPS or power claim. The development host does not establish the Windows thin-and-light or MacBook Air target. Two uncompressed mipmapped RGBA8 detail maps add about 10.7 MiB of texture data before platform-specific residency.

## Decisions made under delegated art direction

1. The latest checklist supersedes the earlier broad goal wording: restore no-bevel/no-painted-green and calm-bottom requirements. Cost if wrong: further reversible art iteration.
2. Replace obsolete exact generated-footprint/depth/density assertions with data immutability, contact, closure and local regeneration coverage. Cost if wrong: the prior exact generated silhouette is no longer protected; the authored layout remains unchanged.

Reproduce captures: `godot --path . --script tests/capture_island_art_direction.gd -- final orbit`. Rebuild the gallery with `python3 tools/art/build_island_review.py`. PNGs and HTML remain local review artifacts under the repository's existing ignore policy; capture metadata, review, test results and the gallery generator are tracked. Runtime texture maps and their import configuration are tracked under `assets/textures/terrain`.
