# Base demo verification record

Made 2026-09-19, last verified 2026-09-20. This record only describes checks already run. It is not equivalent to final art approval.

- Godot 4.7.2 full scene start, no script load errors.
- demo_test.gd: 20/20. 5 actions exist; doorway center and ±0.45 lateral capsule actually pass, walls block; each of two attacks hits once; pause during startup does not settle an attack; normal walk across the bridge to the east bank; river water blocks walk and dodge; cross-space return is not pulled back to the old landing.
- space_test.gd: 21/21. Actual key movement triggers courtyard → interior → courtyard → exploration → courtyard, full-fade transitions, same character instance, camera does not fly across.
- camera_test.gd: 8/8.
- sim_kernel_test.gd: 6252/6252; sim_loop_test.gd: 17/17; sim_research_test.gd: 32/32; sim_explore_test.gd: 30/30.
- terrain_test.gd: 794/794, including all 256 raw masks collapsed to 47, corner conditions, both bridge banks, world-cell mapping, isolated water centers with no grass overlay, river blocking restored after bridge removal, bridge surface height matching character feet.
- combat_test.gd: all asserts passed, covering startup / hit-time cross-frame / single hit / two-stage / dodge window / front-back range / transition cancel.
- Qinglan GLB round-trip: 10 skinned meshes, 28 bones, 5 actions, no unweighted vertices, 25 pose spot-checks of limited coordinates; report at ../qinglan/roundtrip_report.json.
- Building Blender generation: size asserts passed, door width 1.6, height 1.8.

Actual renders were taken with tests/capture_demo.gd on Godot's Metal renderer, not concept images.

## Still prototype

Character cuffs, collar, and foot contact still need refinement; no cloth sim. Official river upkeep economy is not integrated. Ground outside the starting island is for traversal and picture checks; original economy zone and formulas remain. The dummy is a practice prototype; facilities still have placeholder looks.
