# Step 7 — underside naturalism, softer edges, shore cleanup

2026-10-11 · `cursor/lighting-atmosphere-round1-ad0c` · baseline `db027e8`, no reset. One lookdev pass; stop for owner review.

[Before | after gallery](comparison.html): default, upper-front rim, underside, bottom, pond shore and former loose-prop area. Before is genuine baseline rendering; two new diagnostic cameras were recaptured from an isolated baseline source snapshot. After uses the same cameras and lighting. PNG/HTML are local artifacts under repository ignore policy.

## Changed

- Unequal weighted mantle cells, wider seed variation, stronger bottom tilt, independently varied depth and off-centre fracture shoulders. Closed stone masses now project/recess instead of ending in tidy flat plates; internal backing and separate tapered roots remain.
- Local upper-side normal softening and small irregular moss crests weaken the lawn/cliff edge. Crown plans are untouched; no geometric bevel or continuous grey strip. Anchors remain buried, with physical green clusters rather than face paint.
- Existing supported banks have lower crests, small scallops and varied shallow reach; their material uses the same lawn cover at the dry join and mottles toward wet earth. Pond data, water mesh and waterfall shader are unchanged.
- Removed flattened dry-lawn grass instances and horizontal vine sprays at obsolete rim anchors (the loose green discs). Reed-like clumps require nearby water and dry support. Every retained lily mesh vertex must sit over water at the matching level. Existing flowers, shrubs and hanging vines remain.

## Verified

- [43/43 headless terrain suites](tests.json), [42/42 rendered regeneration checks](regeneration.json). Adaptive runs, edit/undo/redo and save/load pass.
- [Exact matching baseline/current hashes](frozen_geometry.json) for terrain data, merged rim, water vertices and waterfall vertices. Finish probes retain 28,068 leak-free lawn samples and 291 hole-free cap samples.
- Default/expand/contract/deep-lower mantle fixtures: no sampled lawn intrusion, open stone edges, buried vine centers or bottom-ray misses; remote stone vertices remain unchanged. Independent body test: 112 closed positive-volume solids, 5,352 triangles in the side-envelope fixture.
- Shore-prop regression reproduced baseline clutter, then passes default/dry/contract with zero invalid placements. Default retains 23 supported reeds and 16 fully wet lily groups. Shore continuity and water field tests pass.
- [Rendered moss compression](lip_compression_render.json): 6,392 standing pixels, 0 fully compressed, 5,104 with a localized mask. Review caught the shore material's missing compression binding; the binding test failed before the fix and passes after it.
- Viewed all six final images with `view_image`. Bottom masses and removal of loose lawn props are clearly visible. Rim/pond softening is restrained; exposed broad crown corners remain angular. Owner should judge the amount of softening and current moss facet read.

## Deferred

Cottage, layout, pond layout, waterfall mesh/shader and lighting are unchanged. No footstep gameplay or vegetation-system expansion. Performance on target hardware remains unmeasured; functional locality is not a regeneration-time or FPS guarantee. This pass is ready for review, not owner art acceptance.
