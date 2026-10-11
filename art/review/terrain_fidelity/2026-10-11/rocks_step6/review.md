# Step 6 — rim and underside lookdev

2026-10-11 · branch `cursor/lighting-atmosphere-round1-ad0c` · baseline `3d7bad7`. No reset. One lookdev pass, ready for owner review.

[Concept | before | after gallery](comparison.html). Required views: [default](after_default.png), [upper front](after_rim_upper_front.png), [underside](after_underside.png), [moss lip](after_grass_lip.png), [tight joints](after_tight_joint.png). Extra diagnostic: [directly beneath](after_underside_bottom.png). Before images are the saved Step 5 captures at the same cameras. References A/B and the full concept are included locally. Images are genuine Godot captures; PNG/HTML remain local review artifacts under the repository's ignore policy.

## Changed

- Removed the distance-only grey top stripe and green material spill down crown/cliff faces. Lawn reaches the frozen crown outline, with only rare small exposed stone patches.
- Replaced flat ragged flaps with sparse, closed three-lobed moss clusters. They sit on the actual stone, cast shadows and retain the world-space compression hook.
- Broadened root fracture planes while keeping separate tapered roots. Added independent closed lower stone bodies with irregular cells, varied projection/depth, tight/open clefts and mild warm/cool tint. Recessed backing remains inside the masses for watertight coverage.
- Closed the previously open bottom and broke it into offset stone bodies. Floor tessellation and height sampling are world-local, so distant blocks remain unchanged during edits.
- Existing hanging vegetation re-seats against the new stone faces; a hidden cluster is omitted if bounded contact resolution cannot expose it. This is a contact correction, not a vine-system redesign.

## Verified this round

- [42/42 headless terrain suites](tests.json); [42/42 rendered regeneration checks](regeneration.json), including adaptive runs, expand/raise/contract, undo/redo and save/load.
- Exact top footprint unchanged; 28,068 lawn tint probes have no leaks, 291 cap probes have no holes. Crown/root volume checks pass 40/40.
- Default, expand, contract and seven-stroke deep-lower integration fixtures: no unpaired stone edges, sampled lawn intrusion, buried vine centers or missed bottom rays (96/98/95/96 probes). Remote mantle vertex movement is **0 m**, with unchanged counts.
- Mixed existing crown rhythm retained: recessed sections have 27 tight pairs and 4 open gaps; projecting fronts have 12 tight pairs and 18 wider gaps. These are different sections, not a claim that every front joint nearly touches.
- Rendered [grass compression](grass_compression_render.json) and [lip compression](lip_compression_render.json) pass. Current round's final moss geometry supports full and localized flattening.
- Inspected concept/A/B against fresh default, upper-front, underside and close-ups with `view_image`. The continuous rim stroke and painted drips are gone; the bottom is now stone-covered. Independent review found and reverified fixes for lawn intrusion, buried vine contact and nonlocal floor movement.

## Deferred / limits

Cottage, layout, ponds, waterfall geometry/shader, shore-ring density and lighting were left unchanged. Lawn micro-relief and compression API are retained; no footstep gameplay. Crown top geometry remains fixed, so some upper corners are still quite angular. The directly-beneath view reads as broad fractured plates, with thicker roots at the perimeter; owner review should judge that balance and moss-cluster softness. This is not a claim of exact concept matching or owner art approval.

The mantle is rebuilt with the contour snapshot; crown/root run caching remains local. Functional locality does not prove cheap CPU regeneration. Added geometry and draw calls have not been accepted on MacBook Air or Windows thin-and-light hardware. No target FPS claim.

Stop here for owner review.
