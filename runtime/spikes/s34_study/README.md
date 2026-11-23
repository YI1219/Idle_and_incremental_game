# Studies S3 and S4: look and island generation

Throwaway code. One tool that builds an island from cells with a new generator and draws it with a new look, so both can be judged on pictures against the frozen Godot project and on a few numbers. Its checkpoint G1 is `art/lookdev/20261122_g1/` (`README.md`, `compare.html`); the owner rejected its look B on 2026-11-23, and the tool now draws the natural look of the Godot baseline; the package for the owner's review is `art/lookdev/20261123_natural/` (`README.md`, `compare.html`).

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
| `--layout=FILE` | A layout exported by `tools/export/export_layouts.gd` (`runtime/data/reference/layout_*.json`, version 1), or a version-2 layout written by `--save-layout`. |
| `--synthetic=N` | A generated terraced island of about N cells with two ponds, for sizes the exports do not cover. |
| `--ramp=ax,az,bx,bz,width` | The ramp stroke (repeatable, applied in order after loading or synthesising): see "Slopes and ramps" below. Prints `RAMP a=(..) b=(..) width .. : .. cells, rise .. m over .. m, gradient ..` or `RAMP refused: reason`. |
| `--save-layout=FILE` | Writes the resulting cells as a version-2 layout. |
| `--synthetic-ramps` | With `--synthetic`: one ramp of width 2 across each long terrace wall (8 or more cell edges between the same two levels), near its middle, deterministic. Off by default so earlier pictures and benches stay comparable. |
| `--seed=S` | Seed for the body, the stand-ins and the scatter (default 7301). |
| `--body=karst\|hull` | Hanging rock columns on a hidden liner (default), or the bare liner. |
| `--hour=day\|dusk\|night` | Light, palette and backdrop of the frozen project's three captures. |
| `--scene=single\|trio` | One island, or three (layouts 7301, 4242 and 913) for the wallpaper view. |
| `--views=a,b\|all\|wallpaper` | Cameras from `runtime/data/reference/cameras.json` (`all` is the twelve review views), plus `wallpaper` and `below`. A synthetic island gets its own `whole` and `game`. |
| `--size=WxH` | Output size (default 3024x1964). |
| `--scale=2\|1` | Internal samples per output pixel per axis: 2 is the resting-camera mode (review stills), 1 the moving-camera mode. |
| `--fxaa` | FXAA 3.11 on the display values; `--scale=1 --fxaa` is the moving-camera mode. |
| `--props=auto\|none\|DIR` | Exported Godot props: `auto` takes the scene beside the layout (`layout_7301_0.json` -> `scene_7301_0`; an edited layout such as `layout_7301_0_ramps.json` drops trailing `_name` parts until a scene folder exists), and for a synthetic island scatters `scene_7301_0`; `none` gives the procedural stand-ins; `DIR` names the scene folder. |
| `--grass=on\|off`, `--ssr=on\|off`, `--ssao=on\|off\|noblur`, `--debug=ao\|ssao\|parts` | Switches for measuring what a pass costs or does. `parts` paints each part of the island in a flat colour by paint id (lawn, walls, liner, rim blocks, deeper columns, skirt, wall backing) and island stone that faces away from the camera in magenta, for finding holes. |
| `--metrics=FILE`, `--tag=NAME`, `--out=DIR` | Metrics JSON, frame name prefix, output folder. |
| `--bench` | After each still, 120 frames with the camera orbiting (shadow map cached) and a `BENCH` line in milliseconds. |
| `--edit-test` | The locality test: three strokes at the rim (add a 3x3 patch, remove one, raise one) and how far the rim plan changes, and a ramp stroke of width 2 across a terrace wall (the wall edge a third of the way through the sorted list that takes a valid ramp), for which the top surface (lawn, banks, walls) is also compared vertex by vertex (changed: no vertex of the other build within 1 cm) (`EDIT` lines). |

Printed lines: `island:` (cells, faces, columns, triangles per part, build time per stage), `form:` (rim plan metrics), `RAMP`, `LAYOUT`, `PROPS`, `GRASS`, `STATS` (picture statistics), `BENCH`, `EDIT`, `FRAME`.

Measuring switches (environment): `S34_LEAF_PREPASS=0` (no leaf depth pre-pass), `S34_PROP_CHUNK=8` (prop culling chunk size in metres, default 4), `S34_SKIP=leaf,grass` (leave parts out of the terms pass).

## Slopes and ramps (round r9)

- Layout version 2: a cell may carry `"slope": [gx, gz]`, the rise in metres per metre toward +x and +z (gradient length at most 0.6, about 31 degrees; no water). Its `height` is the surface height at the cell's centre, a free real number; the surface over the cell is that plane. Cells without `slope` are flat; version-1 files load unchanged. Water levels keep the export's encoding (half metres, -1 for none).
- The ramp stroke `ramp(a, b, width)` (`field::ramp`): `a` and `b` on land; refused when either end is water or off the island, the length is under 2 m, the gradient `|hb - ha| / length` exceeds 0.6, the two ends stand at the same height, or the strip would cover water. Otherwise every cell whose centre lies within `width / 2` of the segment (inclusive) and between its ends becomes a slope cell with `height = ha + (hb - ha) t` and `slope = (hb - ha) / length * direction`. A centre line on a cell edge gives `width` rows; on a row of cell centres it gives one more. Ends on cell edges of an axis-aligned ramp meet the flat lawn exactly; elsewhere the end may be off by up to half a cell times the gradient, which the 0.08 m rule below absorbs or turns into a small soft bank.
- Steps with slopes: each side of a cell edge is its cell's plane. Two neighbours (slope or flat, neither holding water) whose surfaces agree along the shared edge within 0.08 m at both ends are continuous: no step; the crease is rounded over 0.3 m either side (`Field::cell_ground`). Otherwise the edge is a step whose rise varies along it; each half edge is labelled by which side is higher at its middle, so a step whose sides swap over along an edge is handled. A chain of steps beside a slope cell is a wall as a whole when its rise reaches 0.75 m anywhere (a ramp's cheek is one wedge of cut rock that tapers to nothing where the rise runs out); under that it is the soft bank. Chains of flat cells keep the per-piece rule, so islands without slopes build exactly as before (and take the flat-only code path).
- The wall ribbon (`field::ribbon`) takes its two grounds per end, so its height follows the varying rise; the roll over the brow drops at most half the rise; where the sides swap within a piece it is split at the crossing.
- Lawn: the rosette grass on a slope cell grows as on flat ground (no lip thinning), each root turned to the slope. The ground painting follows the plane.
- Props: heights above Godot's own cell come from the scene's layout, so an edited layout does not move them. On a slope a tree, bamboo, bush, bench, lantern or the scholar's rock stays upright and sinks its base to the lowest ground under its footprint; stones, path stones, flowers and tufts tilt with the ground. The synthetic scatter puts no tree within 1.2 m of a slope cell.
- Rim: the rim plan, the lip and the rim skirt read the field's height, so where a ramp reaches the outline the skirt closes the sloped lip down to the blocks.
- Junctions (F1): where three or more steps meet at a cell corner with a wall among them, the grid cells within 0.45 m of the corner are cut into the sectors between the steps' first pieces; each sector takes the ground of the bounding step nearer to the point (a wall's side, a pond's held rim, or a soft step's blend), and every wall ray's ribbon runs to the corner itself without overlap or roll, so the walls share the corner's vertical edge and turn it as one piece of stone. The slim posts of round r8 are gone.

## How an island is built

Cells (1 m, heights in 0.5 m steps, an optional water level) are the only input. Every derived value depends only on cells within a few metres, which is what keeps an edit local (`--edit-test`: no rim face changes beyond 12 m on the four layouts and the 4,096-cell island).

- `src/field.rs`
  - Fields on a 0.25 m grid: a blurred occupancy whose 0.5 contour is the island's outline (sigma 0.45 m), two wider blurs for how deep inside the rim a point is, a blurred water mask for banks.
  - Terrace steps: every cell edge between two land cells of different heights is a step. The steps form a graph on the cell corners; its chains (between junctions of three or more steps and the rim) are subdivided at 0.5 m, relaxed (20 passes) and held within 0.6 m of the cell edges, so a stair of cells becomes one straight or gently curved run. Each piece keeps the two levels of the cell edge it came from, so a 2 m drop stays one wall. Pieces sit in a 1 m bucket index.
  - Height: from which side of the nearest relaxed step a point lies on. A rise under 0.75 m is a soft lawn slope (0.44 m wide); 0.75 m or more is a wall, a hard step. A step in a pond bed is soft. A pond is held where a wall or the outline would spill it: a narrow bank 0.10 m above its surface, except in a fall's notch, where a sill lies just under the surface.
  - Top surface: one mesh over the grid, clipped at the outline. A grid cell crossed by a wall is cut along the relaxed contour, each part at its own level, and the cut is filled by a ribbon: the upper lawn rolls 3.5 cm over the edge, then cut rock goes straight down (in the bed's colour under a pond's surface). Behind each piece of wall a backing face (5 cm behind the cut, 0.2 m past its ends) shows rock through the slits where pieces meet. A piece of surface that bridges two levels faces the way it tilts; a flat piece is lawn even where the field's slope is steep. Lip plants are set along the outline and along the walls' brows.
- `src/body.rs`: the rim plan (outline points anchored to a world lattice, breaks chosen within their own window, long faces split and paired) and two bodies: `Hull`, a low-polygon inverted terrain, and `Karst`, that hull as a hidden liner with a rim block per face (folds, shelves, shoulders) and a second tier of deeper columns. Blocks reach back only as far as the ground over them stays at their top, and every block is capped. Where the rim steps down (a terrace wall or a pond reaching the outline), a rock skirt at the outline closes the gap between the higher lip and the block top; the liner's rim takes the lowest ground within 0.7 of its grid so it never stands above a lower lawn.
- `src/water.rs`: pond surfaces from the water cells and the cells round them, clipped where a wall or the outline holds the pond. Each junction (pond edges spilling into lower water or off the island) pours through one notch, a sheet `min(junction width, 1.6 m)` wide centred on it and placed on the relaxed wall or the outline. The sheet starts on the pond just behind the lip and rolls over it, falls on an arc, and lands in a soft foam patch with a low veil; an outer fall frays into the cloud sea.
- `src/props.rs`: the frozen Godot scene's props from `runtime/data/reference/scene_<seed>_<preset>/` (exported by `tools/export/export_scene_props.gd`), baked into static world-space vertices and drawn by ports of three Godot shaders (`cliff_rock`, `decor_vertex_color`, `foliage_cards`).
  - On an exported layout each instance is refitted to this tool's ground (its height above its Godot cell kept; lilies and reeds keep their height above the water). Instances off the island are dropped and counted. Round r9 (F2): a stone (garden, cliff and shore stones, path stones) whose footprint is over a pond and whose underside stands clear of the bed is lowered onto the bed, partly under water, or moved to the nearest dry shore point within 2.5 m when the water is deeper than 60% of its height (`PROPS ... stones set on a pond bed, ... moved to the shore`). A prop whose footprint (the part within 0.4 m of its base) touches a terrace wall or a fall's notch is moved to the nearest clear lawn or shore point within 1 m, or dropped (`PROPS ... moved off walls`).
  - On a synthetic island the scene's trees, bushes, bamboo, garden and shore stones, flowers, tufts, reeds and lilies are scattered by seed at the source layout's count per square metre of dry land (or of water for the shore and pond kinds). A tree's trunk and crown, two objects in the export, stay one instance. Trees stand in loose groups off water, walls and the rim, bushes gather round them, shore stones line the ponds, lilies take open water. Garden stones come in clusters of two to five of mixed sizes, started mostly on pond banks, at the feet of terrace walls and beside trees, now and then on open lawn. The scholar's rock, bench, lantern and the stepping-stone path are not scattered.
  - Props keep the grass clear round them. In the terms pass they are drawn per 8 m chunk, culled to the view, nearest first.
- `src/decor.rs`: procedural stand-ins (pines, broad-leaved trees, rocks, stepping stones, bamboo, lily pads) for `--props=none`.
- `src/grass.rs`: the frozen project's rosette grass, instanced: one clump mesh per detail level and one 32-byte record per root, 28 roots a square metre, colour relative to the ground, levels per 8 m chunk from the projected leaf width.

## How a frame is drawn

`src/render.rs` and `src/shader.wgsl` (wgpu 30; see `runtime/README.md`):

1. Shadow map (4096, 16-tap soft lookups; 6 taps for grass and leaf cards), cached while the sun does not move.
2. Terms pass: island, props, grass write a display albedo, sun visibility, baked occlusion and a normal. Round r9 (F4): the cut-out leaf cards first write depth only (atlas cut-out, a vertex shader with only position and atlas coordinate), then the island, props and grass draw, then the leaf cards are shaded with an equal depth test and no discard, so one fragment per pixel runs the leaf shading. Props are culled in 4 m chunks. Shadow taps turn by a fixed rotation (one cos and sin a pixel); leaf cards facing away from the sun skip their taps where the back-lit term is negligible. Island stone is painted here (gouache wash, brush planes, dry strokes, mossy brow under the lawn lip, after Godot's `stone_surface` and `stone_cliff_character`).
3. Occlusion at half the internal resolution with a depth-aware blur; far taps read a view-distance pyramid.
4. Resolve in linear light: sun, sky and ground hemisphere, fill; the far field; near air. The far field is ported from the frozen project: its painted sky, six cloud decks and three rings of distant mountains placed as Godot placed them (`data/mountain_poses.json`). The near air (fog and far haze) is scaled by the camera's distance to its orbit centre over the review set's whole view, so a larger island seen whole is not washed out. Below the island the rock dissolves into what lies behind it along the same ray (round r9, F3): the sky and cloud decks drawn at a quarter of the output resolution in a pass of their own and read bilinearly, so the root fades into whatever cloud is behind it from any side and at any hour; the level and softness of the dissolve are unchanged. (The water pass, which has no far-field textures, keeps the fixed mist colour for falls that drop into it.)
5. Water pass, premultiplied into its own target: ponds (Godot's ripples, light lines, shallow band, a screen-space reflection march), falls (Godot's waterfall threads and ropes, a per-hour tint calibrated to the reference), spray and foam.
6. Down pass: the water composited, the internal samples averaged in linear, Godot's filmic curve, one sRGB encode, contrast and saturation, dither. Then FXAA if asked.

Colours are authored as display values and decoded to linear in the shader; backdrop colours are pre-inverted through the tone curve so they appear as written. The hour's palette shifts come from the frozen project's blended style presets (`tools/blend_preset.py`).

## Known limits

- Where three steps meet next to a fall's notch, the corner's top can show a small angled step in the lip. Island stone seen from behind is shaded as if it faced the camera.
- Ramps: see the r9 review notes in `art/lookdev/20261123_natural/r9/`; the ramp's own triangles cost little, but an island with slopes builds its top surface 10 to 20% slower (slope-aware lookups near slopes, more junctions).
- Props are moved off wall faces by their footprint only; a tree's crown may still overhang a wall, as in Godot.
- The three-island wallpaper view (`--scene=trio`) still uses the older mound far field and cloud sea, because the ported decks vanish toward the horizon at its low camera.
- The 4,096-cell island at `--scale=1 --fxaa` with scattered real props runs close to the 12 ms budget; grass (about 2.1 ms in `game`), screen-space occlusion (1.7 ms) and the cut-out leaf cards (1.4 ms) are most of the cost. The leaf pre-pass and the r9 culling and shadow-tap changes saved about 0.3 ms; culling grass in 4 m parts drew fewer blades but was 1.5 ms slower (more instanced draws) and was left out.
- The tool renders off screen only; frame times are wall-clock over 120 frames with the shadow map cached.

## Findings worth keeping

- Authoring colours as display values and then writing them through an sRGB target made every frame about 0.09 brighter and half as saturated. The pipeline must be one or the other throughout.
- Spacing outline points by arc length makes the whole rim plan slide when the outline changes anywhere. Points have to be anchored to the world, lattice lines must not coincide with cell edges, and ties have to be broken by something that does not depend on order.
- Blurring raw heights, or blurred level sets, gives terrace edges that follow the cell stairs on shallow diagonals. Relaxing the step chains themselves (with every level that steps at one cell edge kept on one piece) and cutting the surface along them gives straight runs and true walls.
- A material family interpolated across a triangle passes through values that match no family; snap it per pixel.
- Soft noise used as brushwork reads as dirt. Thin, hard-edged strokes in sparse clusters read as drawing.
- Blocks that pass through each other at shallow angles leave thin slivers. A real construction needs blocks that are cut against each other or kept apart.
- Screen-space occlusion was the largest single cost of a frame until it ran at half the internal resolution with a depth-aware blur.
- On a large island the cut-out leaf cards of the exported trees are the largest cost: they are drawn over each other many times. Opaque crown masses or distance levels are needed in the real renderer.
- Holes into an island come from surfaces whose edges are interpolated between different levels (a liner rim, a block top at the lowest ground of its face) and from open block tops. A hole-finding view (`--debug=parts`) over every review camera finds them faster than reading frames.
