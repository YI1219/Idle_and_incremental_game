# Terrain workshop verification — 2026-10-05

Function, visuals and performance are separate acceptance dimensions. This report is current stage evidence; the fresh 30-minute stability session remains pending.

## Functional evidence

Fresh editor checks: data 301/301, geometry 339/339, decoration 164/164 and runtime/camera 20/20. The full 26-script suite passes cleanly with headless fixed-step timing. The legacy running-turn test fixture needed its missing `build_mode` field; no character production behavior changed.

Coverage includes raise/lower/expand/contract, stroke deduplication, snap coverage differences, 8 water elevations, all 47 bank contours, exact joined-edge matching, dirty neighbors, diagonal corner picking, deterministic terrain-adapting decoration, viewport GUI routing, horizontal pan height invariance, wheel-only height/zoom, undo/redo and validated isolated layout save/load. Tests were written and observed failing before the new modules; seam/corner regressions reproduced 17 failures before correction. Independent review found two additional boundary defects; actual cliff clicks and 8-level deep-water support tests reproduced 34 failures before correction. Direct rebuilt mesh/MultiMesh state now verifies queued edit/undo. See independent_review.md.

## Actual engine views

`editor_ui.png` and `edited_layout_0.png` through `edited_layout_2.png` are rendered Godot views at 1280×720. The capture script applies actual edits to terraces/ponds, a long island and an island with holes/new water. `captures.json` records 19, 26 and 76 changed cells; corresponding layouts are saved as JSON. These are engine screenshots, not concept art.

Observed: the same module rules generate layered grass, water banks, waterfalls, faceted cliffs, terrain-following grass/rocks and trees across different outlines and heights. The image guides scene hierarchy and palette; foliage detail, grid-shaped shore silhouettes and exposed cliff rhythm remain less polished than the reference. This is a functioning demo, not a claim of exact visual reproduction or user art acceptance.

## Development-device benchmark

Apple M4 Pro, Godot 4.7.2, Metal/Forward+, 1280×720, low quality with shadows disabled and instanced CC0 nature. Exactly 4096 terrain cells. Five-second warmup, three separate real-time 60-second runs with vsync disabled; no fixed-FPS or headless-render substitutes. The benchmark includes periodic edits/undo and records complete frame-time samples.

| Run | Seconds | Median ms | p95 ms | Edit response p95 ms | Draw calls | End static memory MiB |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 60.0 | 5.564 | 16.685 | 7.770 | 503 | 60.80 |
| 2 | 60.0 | 5.452 | 16.302 | 9.078 | 503 | 60.80 |
| 3 | 60.0 | 5.820 | 16.708 | 9.842 | 503 | 60.79 |

All three final runs meet median ≤16.7 ms and p95 ≤25 ms. Godot static allocator and video-memory monitors are the recorded memory methods; they are not total process RSS. Earlier runs were superseded after the final review fixes. This development device does not prove Windows thin-laptop or MacBook Air performance, or long-idle power acceptance.

## Pending stability and delivery

The protected 1800-second real-time session is active with FPS capped to 60, periodic edit/undo/redo cycles and horizontal camera movement. The earlier attempt exited cleanly before the deadline without a final result and is excluded from acceptance (stability_interrupted.txt); the cause was not established. The harness now ignores ordinary window-close requests so only a completed duration produces the required evidence. Its result must establish no runtime errors/crash, no accumulating scene nodes, bounded memory and restored terrain data before completion is claimed. Final independent review is complete; both important findings are fixed with failing-then-passing regressions. The corrected demo has been delivered to the primary checkout, preserving all unrelated local file contents; actual PNG evidence and the original user reference were copied there. Source models and legacy economy code remain intact.
