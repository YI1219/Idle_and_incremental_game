# Studies S3 and S4: look and island generation

Throwaway code. One tool that builds an island from cells with a new generator and draws it with a new look, so both can be judged on pictures against the frozen Godot project and on a few numbers. Its checkpoint G1 is `art/lookdev/20261122_g1/` (`README.md`, `compare.html`); the natural-look rounds that followed are under `art/lookdev/20261123_natural/`.

Nothing here is the start of the real crates. What carries forward is the design, the measurements and the list of defects.

## Run it

```
cd runtime && cargo build --release -p s34_study
cd .. && tools/perf/gpu_run.sh 600 runtime/spikes/s34_study/tools/shot.sh OUT_DIR \
    --layout=runtime/data/reference/layout_7301_0.json --seed=7301 --views=whole,game \
    --tag=NAME --metrics=OUT_DIR/metrics.json > OUT_DIR.log 2>&1
```

Run from the repository root (data paths are relative to it). `shot.sh` writes the frames (3024x1964) to `OUT_DIR` and reduced copies (1300 px wide) to `OUT_DIR/small/`; with `CROP="Y X"` set it also writes a 1300x850 crop at native pixels. Send `gpu_run.sh` output to a file; do not pipe it.

## Options

| Option | Meaning |
|---|---|
| `--layout=FILE` | A layout exported by `tools/export/export_layouts.gd` (`runtime/data/reference/layout_*.json`). |
| `--synthetic=N` | A generated terraced island of about N cells with two ponds, for sizes the exports do not cover. |
| `--seed=S` | Seed for the body, the stand-ins and the scatter (default 7301). |
| `--body=karst\|hull` | Hanging rock columns on a hidden liner (default), or the bare liner. |
| `--hour=day\|dusk\|night` | Light, palette and backdrop of the frozen project's three captures. |
| `--scene=single\|trio` | One island, or three (layouts 7301, 4242 and 913) for the wallpaper view. |
| `--views=a,b\|all\|wallpaper` | Cameras from `runtime/data/reference/cameras.json` (`all` is the twelve review views), plus `wallpaper` and `below`. A synthetic island gets its own `whole` and `game`. |
| `--size=WxH` | Output size (default 3024x1964). |
| `--scale=2\|1` | Internal samples per output pixel per axis: 2 is the resting-camera mode (review stills), 1 the moving-camera mode. |
| `--fxaa` | FXAA 3.11 on the display values; `--scale=1 --fxaa` is the moving-camera mode. |
| `--props=auto\|none\|DIR` | Exported Godot props: `auto` takes the scene beside the layout (`layout_7301_0.json` -> `scene_7301_0`), and for a synthetic island scatters `scene_7301_0`; `none` gives the procedural stand-ins. |
| `--grass=on\|off`, `--ssr=on\|off`, `--ssao=on\|off\|noblur`, `--debug=ao` | Switches for measuring what a pass costs or does. |
| `--metrics=FILE`, `--tag=NAME`, `--out=DIR` | Metrics JSON, frame name prefix, output folder. |
| `--bench` | After each still, 120 frames with the camera orbiting (shadow map cached) and a `BENCH` line in milliseconds. |
| `--edit-test` | The locality test: three strokes at the rim (add a 3x3 patch, remove one, raise one) and how far the rim plan changes (`EDIT` lines). |

Printed lines: `island:` (cells, faces, columns, triangles per part, build time per stage), `form:` (rim plan metrics), `PROPS`, `GRASS`, `STATS` (picture statistics), `BENCH`, `EDIT`, `FRAME`.

## How an island is built

Cells (1 m, heights in 0.5 m steps, an optional water level) are the only input. Every derived value depends only on cells within a few metres, which is what keeps an edit local (`--edit-test`: no rim face changes beyond 12 m on the four layouts and the 4,096-cell island).

- `src/field.rs`
  - Fields on a 0.25 m grid: a blurred occupancy whose 0.5 contour is the island's outline (sigma 0.45 m), two wider blurs for how deep inside the rim a point is, a blurred water mask for banks.
  - Terrace steps: every cell edge between two land cells of different heights is a step. The steps form a graph on the cell corners; its chains (between junctions of three or more steps and the rim) are subdivided at 0.5 m, relaxed (20 passes) and held within 0.6 m of the cell edges, so a stair of cells becomes one straight or gently curved run. Each piece keeps the two levels of the cell edge it came from, so a 2 m drop stays one wall. Pieces sit in a 1 m bucket index.
  - Height: from which side of the nearest relaxed step a point lies on. A rise under 0.75 m is a soft lawn slope (0.44 m wide); 0.75 m or more is a wall, a hard step. A step in a pond bed is soft. A pond is held where a wall or the outline would spill it: a narrow bank 0.10 m above its surface, except in a fall's notch, where a sill lies just under the surface.
  - Top surface: one mesh over the grid, clipped at the outline. A grid cell crossed by a wall is cut along the relaxed contour, each part at its own level, and the cut is filled by a ribbon: the upper lawn rolls 3.5 cm over the edge, then cut rock goes straight down (in the bed's colour under a pond's surface). Lip plants are set along the outline and along the walls' brows.
- `src/body.rs`: the rim plan (outline points anchored to a world lattice, breaks chosen within their own window, long faces split and paired) and two bodies: `Hull`, a low-polygon inverted terrain, and `Karst`, that hull as a hidden liner with a rim block per face (folds, shelves, shoulders) and a second tier of deeper columns. Blocks reach back only as far as the ground over them stays at their top.
- `src/water.rs`: pond surfaces from the water cells and the cells round them, clipped where a wall or the outline holds the pond. Each junction (pond edges spilling into lower water or off the island) pours through one notch, a sheet `min(junction width, 1.6 m)` wide centred on it and placed on the relaxed wall or the outline. The sheet starts on the pond just behind the lip and rolls over it, falls on an arc, and lands in a soft foam patch with a low veil; an outer fall frays into the cloud sea.
- `src/props.rs`: the frozen Godot scene's props from `runtime/data/reference/scene_<seed>_<preset>/` (exported by `tools/export/export_scene_props.gd`), baked into static world-space vertices and drawn by ports of three Godot shaders (`cliff_rock`, `decor_vertex_color`, `foliage_cards`).
  - On an exported layout each instance is refitted to this tool's ground (its height above its Godot cell kept; lilies and reeds keep their height above the water). Instances off the island are dropped and counted.
  - On a synthetic island the scene's trees, bushes, bamboo, garden and shore stones, flowers, tufts, reeds and lilies are scattered by seed at the source layout's count per square metre of dry land (or of water for the shore and pond kinds). A tree's trunk and crown, two objects in the export, stay one instance. Trees stand in loose groups off water, walls and the rim, bushes gather round them, shore stones line the ponds, lilies take open water. The scholar's rock, bench, lantern and the stepping-stone path are not scattered.
  - Props keep the grass clear round them. In the terms pass they are drawn per 8 m chunk, culled to the view, nearest first.
- `src/decor.rs`: procedural stand-ins (pines, broad-leaved trees, rocks, stepping stones, bamboo, lily pads) for `--props=none`.
- `src/grass.rs`: the frozen project's rosette grass, instanced: one clump mesh per detail level and one 32-byte record per root, 28 roots a square metre, colour relative to the ground, levels per 8 m chunk from the projected leaf width.

## How a frame is drawn

`src/render.rs` and `src/shader.wgsl` (wgpu 30; see `runtime/README.md`):

1. Shadow map (4096, 16-tap soft lookups; 6 taps for grass and leaf cards), cached while the sun does not move.
2. Terms pass: island, props, grass write a display albedo, sun visibility, baked occlusion and a normal. Island stone is painted here (gouache wash, brush planes, dry strokes, mossy brow under the lawn lip, after Godot's `stone_surface` and `stone_cliff_character`).
3. Occlusion at half the internal resolution with a depth-aware blur; far taps read a view-distance pyramid.
4. Resolve in linear light: sun, sky and ground hemisphere, fill; the far field; near air. The far field is ported from the frozen project: its painted sky, six cloud decks and three rings of distant mountains placed as Godot placed them (`data/mountain_poses.json`). The near air (fog and far haze) is scaled by the camera's distance to its orbit centre over the review set's whole view, so a larger island seen whole is not washed out. Below the island the rock dissolves into a root mist in the shaded cloud sea's tone of the hour.
5. Water pass, premultiplied into its own target: ponds (Godot's ripples, light lines, shallow band, a screen-space reflection march), falls (Godot's waterfall threads and ropes, a per-hour tint calibrated to the reference), spray and foam.
6. Down pass: the water composited, the internal samples averaged in linear, Godot's filmic curve, one sRGB encode, contrast and saturation, dither. Then FXAA if asked.

Colours are authored as display values and decoded to linear in the shader; backdrop colours are pre-inverted through the tone curve so they appear as written. The hour's palette shifts come from the frozen project's blended style presets (`tools/blend_preset.py`).

## Known limits

- Where three steps meet, the cut follows one wall per grid cell; pieces that bridge two levels there are drawn as rock, and a thin slit can remain at some junctions.
- Props stand where the cells put them; where a relaxed wall moved past a prop's cell edge, the prop keeps its cell's height offset on the new ground and can sit against the wall face.
- The three-island wallpaper view (`--scene=trio`) still uses the older mound far field and cloud sea, because the ported decks vanish toward the horizon at its low camera.
- The 4,096-cell island at `--scale=1 --fxaa` with scattered real props runs close to its 11 ms limit; grass and the cut-out leaf cards are most of the cost.
- The tool renders off screen only; frame times are wall-clock over 120 frames with the shadow map cached.

## Findings worth keeping

- Authoring colours as display values and then writing them through an sRGB target made every frame about 0.09 brighter and half as saturated. The pipeline must be one or the other throughout.
- Spacing outline points by arc length makes the whole rim plan slide when the outline changes anywhere. Points have to be anchored to the world, lattice lines must not coincide with cell edges, and ties have to be broken by something that does not depend on order.
- Blurring raw heights, or blurred level sets, gives terrace edges that follow the cell stairs on shallow diagonals. Relaxing the step chains themselves (with every level that steps at one cell edge kept on one piece) and cutting the surface along them gives straight runs and true walls.
- A material family interpolated across a triangle passes through values that match no family; snap it per pixel.
- Soft noise used as brushwork reads as dirt. Thin, hard-edged strokes in sparse clusters read as drawing.
- Blocks that pass through each other at shallow angles leave thin slivers. A real construction needs blocks that are cut against each other or kept apart.
