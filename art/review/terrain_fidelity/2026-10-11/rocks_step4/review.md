# Step 4 — procedural rim polish, island shape frozen

2026-10-11 · `cursor/lighting-atmosphere-round1-ad0c` · baseline `4db6025`; no reset.

Changed:

- Removed the old shoulder's detached chip by tucking the continuous cliff core inside the final rim. Short terrain joins have closing faces. The core remains behind the independent crown clefts instead of being cut into fragments.
- Closed an inherited triangular lawn hole where overlapping crown cutout edges crossed between triangulation rows. Rim caps now split their scan at those intersections; other terrain/water cap callers retain their previous behavior.
- Crown-top tint now uses distance to the final island edge, with bounded interpolation near the narrow transition. Internal crown overlaps no longer carry grey bands into the lawn.
- Asymmetric side recesses, off-centre fracture junctions, signed chip relief and unequal lower breaks vary the crown fronts. At 0.45 m below the crowns, the front-section probe finds 9 tight joints and 22 clearer gaps; the overlapping backs preserve one island mass. **Every top-outline vertex matches Step 3 exactly**; no shoreline tracing, re-spacing of terrain or footprint growth.
- Patchy grass/moss color extends a short distance down upper vertical crown faces. No geometric bevel or raised lip. Mild mineral noise and warm/cool face tints remain.
- Sparse tuft/detail relief and blade grain respond to a world-space compression texture. `TerrainRenderer.set_grass_compression(texture, world_rect)` binds the data to ground and cliff-cover materials: red 0 = standing, 1 = flat; null/outside = standing. The caller can update the same texture later. Footstep painting, recovery and gameplay are deferred.

Preserved: separate tapered roots (mesh hashes unchanged: 53 = `496251262`, 67 = `3531517669`), adaptive grow/split/shrink/merge, local placement cache, MultiMesh baking and complete revision publication. Cottage/layout, pond/fall geometry and shaders, shore-ring placement, vines system, lighting and edit UX are unchanged. Existing contact queries naturally reseat vines on changed faces. No new texture asset or vegetation system.

Evidence: [concept | before | after](comparison.html), [default](after_default.png), [upper rim](after_rim_upper_front.png), [underside](after_underside.png), [former chip](after_bug_upper_joint.png), [lawn overlap](after_bug_lawn_overlap.png), [grass lip](after_grass_lip.png). Step 3 before images and Step 4 after images use matching cameras/lighting; additional close-ups isolate the bug locations. Final views were inspected with `view_image` against the concept for feel, not pixel matching. PNGs and gallery stay local under the existing art ignore policy.

Verification: **38/38 headless terrain suites**, **42/42 rendered regeneration checks**, and a **rendered grass-mask test**. The finish regression reproduced the old chip and 49 inland tint probes before the fix; now 28,068 probes find no inland leaks and the chip ray is clear. All 291 downward probes around the reproduced lawn opening hit the cap. The top footprint matches the saved baseline; 4,011 side rays across default, expanded and contracted states all find nearby stone backing. Closed stone volumes, flat caps, waterfall clearance, vine contact, local/fresh rebuild equality and distant unchanged cliffs pass. The half-mask render changes 42,873 sampled pixels on the compressed side and leaves the unpainted half identical. See [tests](tests.json), [mask render](grass_compression_render.json), [capture metadata](after_rim.json) and [baseline geometry](baseline_geometry.json).

Fresh independent code review, including the final cap-hole correction, found no actionable defect. These tests and inspected views cover the listed fixtures; art acceptance remains with the owner and target-device performance is unmeasured. Stopped for review.
