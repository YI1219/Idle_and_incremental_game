# Terrain workshop verification — 2026-10-05

Function, visuals and performance are separate acceptance dimensions. This report is current stage evidence; stability and final independent review remain pending.

## Functional evidence

Fresh editor checks: data 301/301, geometry 306/306, decoration 164/164 and runtime/camera 16/16. The full 26-script suite passes cleanly with headless fixed-step timing. The legacy running-turn test fixture needed its missing `build_mode` field; no character production behavior changed.

Coverage includes raise/lower/expand/contract, stroke deduplication, snap coverage differences, 8 water elevations, all 47 bank contours, exact joined-edge matching, dirty neighbors, diagonal corner picking, deterministic terrain-adapting decoration, viewport GUI routing, horizontal pan height invariance, wheel-only height/zoom, undo/redo and validated isolated layout save/load. Tests were written and observed failing before the new modules; seam/corner regressions reproduced 17 failures before correction.

## Actual engine views

`editor_ui.png` and `edited_layout_0.png` through `edited_layout_2.png` are rendered Godot views at 1280×720. The capture script applies actual edits to terraces/ponds, a long island and an island with holes/new water. `captures.json` records 19, 26 and 76 changed cells; corresponding layouts are saved as JSON. These are engine screenshots, not concept art.

Observed: the same module rules generate layered grass, water banks, waterfalls, faceted cliffs, terrain-following grass/rocks and trees across different outlines and heights. The image guides scene hierarchy and palette; foliage detail, grid-shaped shore silhouettes and exposed cliff rhythm remain less polished than the reference. This is a functioning demo, not a claim of exact visual reproduction or user art acceptance.

## Development-device benchmark

Apple M4 Pro, Godot 4.7.2, Metal/Forward+, 1280×720, low quality with shadows disabled and instanced CC0 nature. Exactly 4096 terrain cells. Five-second warmup, three separate real-time 60-second runs with vsync disabled; no fixed-FPS or headless-render substitutes. The benchmark includes periodic edits/undo and records complete frame-time samples.

| Run | Seconds | Median ms | p95 ms | Edit response p95 ms | Draw calls | End static memory MiB |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 60.0 | 5.441 | 16.902 | 17.731 | 505 | 60.81 |
| 2 | 60.0 | 5.420 | 16.517 | 9.313 | 505 | 60.81 |
| 3 | 60.0 | 5.693 | 16.534 | 18.306 | 505 | 60.81 |

All three final runs meet median ≤16.7 ms and p95 ≤25 ms. Godot static allocator and video-memory monitors are the recorded memory methods; they are not total process RSS. Earlier runs were superseded after bank/picking corrections. This development device does not prove Windows thin-laptop or MacBook Air performance, or long-idle power acceptance.

## Pending stability and delivery

The 1800-second real-time session is active with FPS capped to 60, periodic edit/undo cycles and horizontal camera movement. Its result must establish no runtime errors/crash, no accumulating scene nodes, bounded memory and restored terrain data before completion is claimed. Final independent review and transfer to the primary checkout are still pending. Source models and legacy economy code remain intact.
