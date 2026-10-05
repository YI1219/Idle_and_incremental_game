# Requirement audit — terrain workshop

Audited the primary project at a0f2c30 and corresponding corrected engine evidence. The latest explicit camera restriction supersedes the older goal text requesting orbit/fly movement. The accepted scope permits replacement of the old terrain/scene objects while preserving asset and gameplay sources.

| Requirement | Current authoritative evidence | Result |
| --- | --- | --- |
| Active floating-island workshop in primary project | project.godot main_scene, both launchers; fresh primary import and visible default launch logs | Passed |
| Raise/lower/expand/contract drag brushes and snap toggle | terrain_data.gd, editor.gd, HUD; 301 data checks, 20 runtime checks including actual cliff/world/UI clicks | Passed |
| Smooth horizontal pan; fixed orientation; wheel-only height/zoom | editor_camera.gd and runtime camera invariants, reset/empty-land checks | Passed, following latest user request |
| Exactly 8 selectable water elevations | HUD level selector, serialization/painting tests for levels 0–7; ninth-level rejection | Passed |
| All 47 normalized connection states | Blob47 data sweep of 256 inputs; unique triangulated contours and matching adjacent endpoints | Passed |
| Correct terrain/water/cliff geometry and latest-state rebuilds | 339 geometry checks, including deep-water support on all 8 elevations and 4 sides; direct mesh/MultiMesh comparison after queued edit/undo | Passed |
| Terrain-following free 3D vegetation, surface rocks and embedded cliff rocks | 5 original CC0 Quaternius models; 164 placement/instancing checks; actual engine captures | Passed |
| Three substantially different edited engine layouts | refreshed edited_layout_0/1/2.png and saved authoritative layout JSON; captures metadata counts 19/26/76 changed cells | Passed |
| Reference-consistent demonstration | Inspected sunny floating grassy terraces, faceted rock edges, blue ponds/spill, vegetation and embedded rocks across all three captures | Passed as demo; final art polish/user acceptance separate |
| 4096 cells, 1280×720 low quality, 3 real-time runs ≥60 s | benchmark_1/2/3.json: median 5.564/5.452/5.820 ms; p95 16.685/16.302/16.708 ms; draw calls, memory, edit latency and full samples recorded | Passed on M4 Pro; target laptops unmeasured |
| 30-minute stability with edits, undo/redo and horizontal camera movement | Protected rerun / session 74060; earlier terminal attempt ended before deadline without final JSON and is excluded; final JSON not yet emitted | Pending |
| Existing assets/gameplay and unrelated local work preserved | Branch diff excludes original assets and gameplay production sources; unchanged local file SHA-256 hashes | Passed |
| Fresh verification and independent review | All 26 functional scripts clean in worktree and primary; independent review’s two important issues reproduced then fixed; no second review required | Passed |

Remaining completion gate: inspect the corrected 1800-second stability result and error log, interpret memory growth alongside benchmark-recording allocations, update status/plan, deliver final evidence, and clean up the isolated checkout only after preserving ignored artifacts. Windows thin-laptop/MacBook Air frame rate and long-idle power remain separately unmeasured; these are not inferred from the development device.
