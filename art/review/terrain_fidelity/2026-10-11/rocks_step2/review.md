# Step 2 — rim crown polish

2026-10-11 · `cursor/lighting-atmosphere-round1-ad0c` · baseline `c14a9a2` (Step 1 retained; no reset).

Changed:
- Broad planar crown caps with a shallow continuous shoulder; narrow corner cuts blunt the outer silhouette. Neighbor heights still come from the existing placement system.
- Exposed stone-colored lip around the grass interior. Its tint and width were reduced after reviewing the first render to avoid a bright outline.
- Lightweight warm/cool triangle colors, soft mineral tint and mild lower-face AO. No texture assets, additional grass meshes or lighting changes.

Preserved/deferred: separate tapered roots, adaptive grow/split/shrink/merge and local MultiMesh regeneration; cottage/layout, pond shapes, waterfall mesh/shader, shore-ring density, vines, vegetation, lighting and edit UX. Existing contact queries naturally reseat vines against the revised crowns. Both root mesh arrays are byte-identical to Step 1 (seeds 53 and 67).

Evidence: [concept | before | after](comparison.html), [after_default](after_default.png), [after_rim_upper_front](after_rim_upper_front.png), [after_underside](after_underside.png). Inspected all three against the concept with `view_image`. Before images are retained Step 1 captures; after images are actual Godot 4.7.2 Metal / Forward+ renders at the same camera poses and lighting. The rim capture now forces drawing so native-window occlusion cannot stall readback.

Verification: **33/33 headless terrain suites**, including **24/24 crown-polish**, **40/40 closed-volume/taper**, **25/25 adaptive rim** and **140 waterfall-clearance samples with no intersections**; **42/42 rendered local-regeneration checks**. See [test output](tests.json) and [capture metadata](after_rim.json). A fresh independent review found no actionable defects. Target-device performance remains unmeasured.

The three polish criteria are ready for owner visual review. Stopped here; no further scene work included.
