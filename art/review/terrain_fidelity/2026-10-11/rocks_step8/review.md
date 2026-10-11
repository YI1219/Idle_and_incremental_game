# Step 8 — calmer fractured stone masses

2026-10-11 · `cursor/lighting-atmosphere-round1-ad0c` · baseline `bcfc583`, no reset. Stop for owner review.

[Concept + before | after gallery](comparison.html) · [Default](after_default.png) · [Rim](after_rim_upper_front.png) · [Underside](after_underside.png) · [Bottom](after_underside_bottom.png) · [Pond shore](after_pond_shore.png). Additional lip, joint and former loose-prop views are included. Before images are unchanged Step 7 captures; cameras and lighting match. Water animation phases differ. PNG/HTML remain local artifacts under repository ignore policy; metadata and reports are tracked.

## What I tried and retained

- Replaced the dense raised-center mantle pattern with fewer, larger closed masses. Broad faces meet along selected off-center fractures; most joints are tight, with occasional deeper openings. Removing concentric shoulders reduces the repeated button/honeycomb read. The side-envelope fixture drops from 112 bodies / 5,352 triangles to 64 / 2,212.
- The first large-block study looked like a heavy skirt. Recessing the central bottom and varying its height with asymmetric world-space waves lets the separate roots contribute more to the lower outline. A second flat-face study still looked like plates; the retained fracture study adds tilted planes and uneven projection. No center-directed keel or smooth exposed shell was added.
- Reduced moss density and crest height, using two broad low lobes instead of three spiky ones. Softer shading keeps the physical flaps quieter against the grass. Stone tones shift slightly toward cool grey shadows and warmer pale faces under the same lights.
- Made supported bank scallops visible above opaque water. An intermediate study produced detached ribbons; a new join on the authored shoreline fixes the submerged connection. The independent reviewer confirmed that regression is resolved.

## Verified this pass

- [43/43 headless suites](tests.json), [42/42 rendered regeneration checks](regeneration.json), and [rendered moss compression](lip_compression_render.json): 3,397 standing pixels, 0 fully compressed, 2,581 with a local mask.
- [Frozen hashes](frozen_geometry.json): terrain cells, merged crown outline, water vertices and waterfall vertices match baseline exactly. Cottage/layout and lighting code are untouched.
- Default/expand/contract/deep-lower fixtures: zero sampled lawn leaks, open edges, buried vine centers or bottom coverage misses; remote stone vertices remain unchanged. Existing shore-prop support tests pass default/dry/contract.
- [Shore regression](shore_regression.json): baseline exposes only 42/555 wet crest samples; final exposes 1,824/1,824. The detached-ribbon study fails with 351 submerged boundary crossings; final passes 1,357 connection checks.
- Inspected final five views plus lip close-up with `view_image` against concept/earlier studies. Independent bounded review has no remaining actionable finding.

The main visual improvement is a quieter hierarchy of broad rock masses rather than packed little cells. Some underside intersections still read as slabs at close range, and the frozen crown corners remain angular. Owner preference and target-device performance are not established by these checks. No gameplay, vegetation system, pond-layout, waterfall-route or lighting expansion.
