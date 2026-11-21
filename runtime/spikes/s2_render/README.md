# Spike S2: what the cached-island frame costs

Throwaway code. Question: if the island is drawn from a world-space bake into time-independent shading terms, resolved with a palette, line and mist, with water live on top, what does a frame cost at the first gate's resolution on the M4 Pro, with a full 4,096-cell island and two more islands on screen?

Measured 2026-11-22 on the development Mac (MacBook Pro Mac16,8, M4 Pro, mains power), through `tools/perf/gpu_run.sh`. Evidence: `art/lookdev/20261122_runtime_spikes/s2_render/` (result files and the log; frames are there too but pictures are not tracked in git).

## What was built

- `src/scene.rs`: a procedural stand-in, not the island generator. Terraced cell islands with an outer cliff that tapers to a root, inner steps, rocks, trees as opaque crown clumps, tufts along rims and sparsely inside, a few buildings, two ponds. Everything is baked into world space with per-vertex occlusion, bounce and line-importance terms. The bench scene is one 4,096-cell island and two 650-cell islands at other positions and heights: 388,326 triangles in 128 draws (one per 8 m chunk).
- `src/shader.wgsl`, `src/main.rs`: three stages.
  - terms: the islands drawn into three 8-bit targets and depth (base colour and family; sun, sky, bounce and line terms; normal), sampling a 4096 shadow map that was rendered once.
  - resolve: one full-screen pass turning terms into colour: chosen lit and shadow colours per material family, a line from depth and normal breaks, height and distance mist, sky and a three-octave cloud sea.
  - water: pond surfaces blended over the result, depth-tested against the cached depth.
- Moving path = terms + resolve + water every frame with the camera orbiting. Still path = resolve + water over terms left from an earlier frame.
- Timing is off screen: frames are submitted and the clock stops when the GPU has finished them all, so the window compositor cannot clip the result.

## Results at the gate resolution (3024x1964)

| View | Moving path | Still path |
| --- | --- | --- |
| whole (all three islands) | 1.86 ms | 0.55 ms |
| game (close on the full island) | 1.59 ms | 0.48 ms |
| low (lower pitch) | 1.86 ms | 0.53 ms |

The plan's design budgets were 12 ms and 4 ms. Godot at the freeze needs 13.7 to 18.9 ms on its light tier and 22.4 to 29.4 ms on its default tier at this resolution, for one 623-cell island.

Other measurements:

| Variant | Moving | Still | Note |
| --- | --- | --- | --- |
| 3600x2338 (what a full-screen window is asked to fill in the Mac's current display mode) | 1.89 to 2.20 ms | 0.67 to 0.77 ms | |
| 6048x3928 (four times the gate's pixels: brute-force 2x2 supersampling) | 3.77 to 4.08 ms | 1.83 to 2.11 ms | still under a 120 FPS frame |
| Three times the scattered detail (1,054,074 triangles) | 3.00 to 3.61 ms | unchanged | the Moving path is bound by triangles, not pixels |
| One 623-cell island alone (48,712 triangles) | 0.84 to 0.91 ms | 0.45 to 0.53 ms | |
| Waiting for the GPU after every frame (cross-check of the method) | 1.75 to 2.04 ms | 0.63 to 0.69 ms | agrees with the batched timing |
| Shadow map refresh (all islands, 4096 map) | 1.3 to 3.6 ms | | paid on an edit or a light step, not per frame |
| Full rebuild of the 4,096-cell island: mesh, upload, shadow refresh | 20 ms (mesh alone 13 ms) | | the worst case with no incremental rebuild at all, for this stand-in generator |

## What this does and does not show

It shows that the structure of the plan's renderer is far inside the frame budget on this Mac: the static island as a bake drawn into terms, one resolve pass, live layers on top. The margin is about six to nine times at the gate resolution, and the Still path is about a thirtieth of a 60 FPS frame.

It does not show the cost of the final picture. The stand-in has flat colours and no painted texture pages, a four-tap shadow lookup, a one-pixel line, no edge smoothing on the Moving path, no falls, mist sheets, character or HUD, and a simple generator. The real island will cost more on every one of those. The measurements say there is room for them, and that the first things to spend the room on are edge quality while moving (supersampling fits) and richer baked surfaces.

It is not a look. The frames are evidence that the passes run and what is in view; the colours and forms are placeholders.

It says nothing about a thin laptop or about Windows.

## Run it

```
cd runtime && cargo build --release -p s2_render
cd .. && tools/perf/gpu_run.sh 900 runtime/spikes/s2_render/tools/run_bench.sh /tmp/tsw_s2 > /tmp/tsw_s2.log 2>&1
```
