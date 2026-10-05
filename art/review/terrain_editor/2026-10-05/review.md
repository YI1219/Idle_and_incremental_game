# Terrain workshop verification — 2026-10-05

Function, visuals and performance are separate acceptance dimensions. This report is current stage evidence; all required development-device checks are complete.

## Functional evidence

Fresh editor checks: data 301/301, geometry 339/339, decoration 164/164 and runtime/camera 20/20. The full 26-script suite passes cleanly with headless fixed-step timing. The legacy running-turn test fixture needed its missing `build_mode` field; no character production behavior changed.

Coverage includes raise/lower/expand/contract, stroke deduplication, snap coverage differences, 8 water elevations, all 47 bank contours, exact joined-edge matching, dirty neighbors, diagonal corner picking, deterministic terrain-adapting decoration, viewport GUI routing, horizontal pan height invariance, wheel-only height/zoom, undo/redo and validated isolated layout save/load. Tests were written and observed failing before the new modules; seam/corner regressions reproduced 17 failures before correction. Independent review found two additional boundary defects; actual cliff clicks and 8-level deep-water support tests reproduced 34 failures before correction. Direct rebuilt mesh/MultiMesh state now verifies queued edit/undo. See independent_review.md.

## Actual engine views

`editor_ui.png` and `edited_layout_0.png` through `edited_layout_2.png` are rendered Godot views at 1280×720. The capture script applies actual edits to terraces/ponds, a long island and an island with holes/new water. `captures.json` records 19, 26 and 76 changed cells; corresponding layouts are saved as JSON. These are engine screenshots, not concept art.

Observed: the same module rules generate layered grass, water banks, waterfalls, faceted cliffs, terrain-following grass/rocks and trees across different outlines and heights. The image guides scene hierarchy and palette; foliage detail, grid-shaped shore silhouettes and exposed cliff rhythm remain less polished than the reference. This is a functioning demo, not a claim of exact visual reproduction or user art acceptance.

## Development-device benchmark

Apple M4 Pro, Godot 4.7.2, Metal/Forward+, 1280×720, low quality with shadows disabled and instanced CC0 nature. Exactly 4096 terrain cells. Five-second warmup, three separate real-time 60-second runs with vsync disabled; no fixed-FPS or headless-render substitutes. The benchmark includes periodic edits/undo and records complete frame-time samples. Edit response is measured from data mutation to completion of dirty chunk rebuilds; it includes frame scheduling and mesh population, but not physical display latency.

| Run | Seconds | Median ms | p95 ms | Edit response p95 ms | Draw calls | End static memory MiB |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 60.0 | 5.564 | 16.685 | 7.770 | 503 | 60.80 |
| 2 | 60.0 | 5.452 | 16.302 | 9.078 | 503 | 60.80 |
| 3 | 60.0 | 5.820 | 16.708 | 9.842 | 503 | 60.79 |

All three final runs meet median ≤16.7 ms and p95 ≤25 ms. Godot static allocator and video-memory monitors are the recorded memory methods; they are not total process RSS. Earlier runs were superseded after the final review fixes. This development device does not prove Windows thin-laptop or MacBook Air performance, or long-idle power acceptance.

## Completed stability and delivery

The protected real-time run completed 1800.004 seconds with 4096 cells, a 60 FPS cap, horizontal camera movement and 359 periodic edit/undo/redo cycles. It recorded 107,473 frame samples. Median frame time was 16.686 ms; p95 was 18.429 ms; edit-response p95 was 17.944 ms. The layout returned to its initial data and the dirty queue was empty. Scene nodes began and ended at 604; the transient peak was 605. No runtime errors or crash were logged.

Godot static allocator usage was 60.39 MiB after warmup, peaked at 62.50 MiB during measurement and was 64.94 MiB while constructing the result. The last value includes the additional Array copy of 107,473 frame samples made by finish(); bounded stroke history and continuous sample recording are included throughout. This is a 30-minute observation with no accumulating scene nodes, not a claim of zero future memory growth or long-idle power acceptance. Video memory at the end was 226.84 MiB.

The earlier attempt exited cleanly before its deadline without a final result and is excluded (stability_interrupted.txt); its cause was not established. Ordinary window-close requests are now ignored by the measurement harness. The completed result and log are stability_30min.json and stability_completed.txt.

Final independent review is complete; both important findings were corrected using failing-then-passing regressions. The corrected demo is delivered to the primary checkout, preserving unrelated local file contents and original asset/gameplay sources. Actual engine PNGs and the user reference are also preserved there. Target-laptop performance, subjective final art acceptance and long-idle power remain separate future measurements.
