# Step 3 — island rim = stone crown

2026-10-11 · `cursor/lighting-atmosphere-round1-ad0c` · baseline `e007329`; no reset.

Changed:

- Crown footprints now assemble the visible terrain top. The old grass shoulder is clipped away, overlapping caps are drawn once, and the lawn reaches the crown exterior without an inward stone platform. Side bodies remain independent; picking includes their actual geometry.
- Removed Step 2 corner chamfers, bevel planes, raised crown placement and lean. Caps meet the lawn at terrace height. Wider crown overlap closes neighboring joints; clipping uses actual crown coverage to avoid opening seams.
- A narrow outward cap band mixes grass and stone color in the ground material. Vertical faces retain mild warm/cool facet variation. No extra grass geometry or texture assets.

Preserved/deferred: separate tapered roots, adaptive grow/split/shrink/merge, local regeneration and MultiMesh side-body baking. Cottage/layout, pond shapes, waterfall mesh/shader, shore-ring density, vines system, lighting and edit UX are unchanged. Existing contact queries reseat vines against the assembled rim. Root mesh hashes remain identical to Step 2 (53: `496251262`; 67: `3531517669`). Lower lawns remain beneath upper crown overhangs.

Evidence: [concept | before | after](comparison.html), [after_default](after_default.png), [after_rim_upper_front](after_rim_upper_front.png), [after_underside](after_underside.png). Before images are retained Step 2 captures; after images are actual Godot 4.7.2 Metal / Forward+ renders at matching cameras and lighting. All three final views were inspected with `view_image` alongside the concept. The raised ring and inland cap shelves are gone; the grass–stone mix is intentionally subtle under the warm light. Tapered roots remain separately readable. PNGs and the gallery are local evidence under the repository's existing art ignore policy.

Verification: **34/34 headless terrain suites**; **42/42 rendered local-regeneration checks**. The new assembly test passed **21,030 overlap probes, 363 single-top probes and 4 terrain-joint support probes**, and verifies unchanged water/shore geometry. Existing checks include **24/24 crown polish**, **40/40 closed-volume/taper**, **25/25 adaptive rim**, and **140 clear waterfall samples**. See [test output](tests.json) and [capture metadata](after_rim.json); edit captures cover expansion, raising, undo, shrink and restore. Fresh code review identified a small terrace-end slit, which was fixed and rechecked; no remaining actionable finding. Target-device performance is unmeasured.

Ready for owner visual review. Stopped here; no further scene work included.
