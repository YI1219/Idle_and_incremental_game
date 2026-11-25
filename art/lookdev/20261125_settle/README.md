# Round k1 and k2: rounded rock edges, appear-and-settle after edits (2026-11-25)

The owner's instruction of 2026-11-25, after the second review package (`art/lookdev/20261123_natural/`): exactly two things, still no full art accept and no phase 2.

1. Soften and chamfer the rock-wall edges so they feel closer to Godot: rounder slab edges and face junctions, softer transitions, no hard cut along slab tops.
2. A short Tiny Glade-like appear-and-settle when terrain or items are edited. Not a growth simulation: ground rises and settles, grass and props emerge and ease in with a slight overshoot, and the interaction stays immediate.

Open `compare.html` (it plays the sequences; the slider scrubs, **Slow** plays at a quarter speed). Pictures are not in git; `checks/render_settle.sh` renders all of them again and `checks/build_compare.py` rebuilds the page.

## 1. Rounded rock edges (round k1, commit `f0a77fe`)

Done in commit `f0a77fe` and not changed this round. Buttress slabs and rim blocks have real rounded edges (arcs of three pieces with smooth normals, 0.18 to 0.30 m on slabs, 0.12 to 0.22 m on rim blocks); slab tops are a slightly crowned surface shaded by its own normals, so the diagonal crease is gone; junctions between rim blocks get a concave fillet where one stands proud and a softened shading turn where they are nearly flush; terrace-wall corners ease their shading over 0.13 m; hanging columns have rounds of two pieces. The compare page shows five views before (81d1f12) and after.

Still visible, small, and left as they are (they were listed in the k1 notes): a short shelf where a rim skirt's end meets a forward block's corner (`outer_hull`, above the middle block), and a thin soft joint line where two rim blocks meet nearly flush.

## 2. Appear and settle (round k2)

Five sequences on layout 7301, each from its own camera: **raise** a 3 x 3 lawn patch by 1 m, **lower** one by 1 m, **expand** the island by 4 x 3 cells at the rim, **place** a tree, two bushes, two stones and a flower, and draw a **ramp** across a 1 m terrace wall.

What moves (my calls on timing and amounts):

- Ground: where the height changed, the new surface starts at the old height and eases to the new one over 0.55 s, overshooting by about 6 % of the change before it settles. A raised patch grows out of the lawn as a walled plinth; a lowered one sinks; a ramp leans out of the wall it cuts. New land rises whole from 0.6 m below, rim blocks included. The motion ripples out from the stroke (0.045 s a metre).
- Grass on changed ground regrows: it starts 0.10 s after the ground under it (plus a little per-root jitter), grows to full height in 0.42 s with about 10 % overshoot, its width following from a third. Round a placed item the grass parts in a ring half a metre wide and regrows the same way.
- Placed items grow from nothing about their base: height over 0.5 s with about 12 % overshoot, width a moment behind with about 7 %, one item every 0.09 s in the order placed. Existing items ride the ground under them.
- After about 1.2 s nothing moves; with no edit running, the picture is the same as before this round (see the checks).

How it stays immediate: when an edit lands the island is rebuilt once, as before, and a small settle table is made for the edit's dirty rectangle only (the touched cells plus 4 m, 2,000 to 3,200 cells of 0.25 m, made in 0.2 to 0.4 ms). The whole motion then runs in the vertex shaders from one clock value: no mesh is touched while it plays. Edit to first frame of motion, measured in this tool on layout 7301:

| sequence | rebuild (ms) | settle table (ms) | upload (ms) | total (ms) |
|---|---|---|---|---|
| raise | 70.2 | 0.17 | 18.4 | 88.7 |
| lower | 87.0 (fields 50.5, an outlier; 68.8 and 77.8 in the other two runs) | 0.22 | 18.9 | 106.2 |
| expand | 70.1 | 0.33 | 19.1 | 89.6 |
| place | 67.9 | 0.33 | 19.5 | 87.8 |
| ramp | 71.1 | 0.41 | 18.5 | 90.0 |

The rebuild is still the whole island (fields about 34 ms, top surface 17 to 20, props 6 to 7, grass 8). Rebuilding only the touched chunks belongs to the edit pipeline of phase 3 and was not started; an item placement would not need the terrain rebuilt at all. At about 90 ms the motion begins five or six frames after the stroke ends; on a larger island the rebuild grows with it, which is the reason for that pipeline.

Frame cost at 3024 x 1964 in the moving-camera mode (scale 1, FXAA), each sequence's camera orbiting, two runs:

| sequence | settled, shadow map cached (ms) | settled, shadow map redrawn (ms) | during the motion (ms) |
|---|---|---|---|
| raise | 9.60 / 9.59 | 9.97 / 10.08 | 10.00 / 10.13 |
| lower | 8.24 / 8.29 | 8.56 / 8.68 | 8.69 / 8.67 |
| expand | 7.70 / 7.96 | 8.24 / 8.32 | 8.18 / 8.33 |
| place | 9.03 / 9.45 | 9.38 / 9.64 | 9.40 / 9.59 |
| ramp | 8.55 / 8.39 | 8.95 / 8.68 | 8.96 / 8.73 |

The motion costs 0.2 to 0.5 ms a frame for about 1.2 s after an edit, almost all of it redrawing the sun's shadow map (moving geometry needs it); the settle lookups themselves are within noise. The Mac was busy throughout (load averages 9.1 to 11.1, as in the 2026-11-24 benches, which then read about 25 % high), so all of these are high.

Known limits of the motion:

- Ramp: for about 0.1 s at the start, the pressed-down step where the old wall stood is painted as lawn, not stone (it is the stretched lawn surface).
- Expand: where new land meets a lower old terrace, thin slivers of that terrace wall's top stand up for about the first 0.1 s.
- Water does not move; the sequences keep away from ponds.
- Separately, not part of the motion: after the expand edit the island generator leaves a short grey stone shelf on the lawn where the new land meets the lower terrace (visible in the settled frame). That is the generator's handling of this edited outline and outside this round's scope.

## Checks

- With no edit running, this build against the stills of commit `f0a77fe` (`regress.txt`): 145 to 1,745 isolated pixels differ out of 5.9 million (at grass-leaf and leaf-card edges, at most 46/255 on a single pixel), no visible change. The `f0a77fe` binary reproduces its own stills exactly, so this is floating-point rounding in the restructured vertex shaders.
- Edit locality (`edit.log`): all five strokes change nothing beyond 12 m (rim plan farthest 11.19 m, top surface 2.48 m).

## Files

- `compare.html`, `web/` (reduced copies for the page), `regress.txt`.
- `flip/` (the sequences at 1512 x 982, 30 frames a second), `keys/` (3024 x 1964 key frames at 0, 0.1, 0.2, 0.35, 0.6 and 1.5 s and before), `bench_a/`, `bench_b/` (logs and metrics, `*.load` the load averages), `regress/`, `rocks/`, `rocks_before/`, `edit/`.
- `checks/render_settle.sh` (renders everything, detached and restartable), `checks/build_compare.py`.
- Code: `runtime/spikes/s34_study/src/settle.rs` and the `settle_*` functions in `shader.wgsl`; the study's README, section "Appear and settle (round k2)".
- `questions.md`: two short questions for the owner, each with the default I used.
