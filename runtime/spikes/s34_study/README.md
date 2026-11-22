# Studies S3 and S4: look and island generation

Throwaway code. One tool that builds an island from cells with a new generator and draws it with a new look, so both can be judged on pictures against the frozen Godot project and on a few numbers. Its results are checkpoint G1: `art/lookdev/20261122_g1/README.md` and `compare.html` there.

Nothing here is the start of the real crates. What carries forward is the design, the measurements and the list of defects.

## What it does

- `src/field.rs`: cells (1 m, heights in 0.5 m steps) are the only input. From them: a blurred occupancy whose 0.5 contour is the island's smooth outline; two wider blurs that say how far inside the rim a point is; terrace heights built from smoothed level sets, so steps are smooth in plan and near-vertical in section. The top surface is one height field clipped at the outline, with a rolled lawn lip. Every value depends only on cells within a few metres.
- `src/body.rs`: the rim plan and two bodies.
  - Rim plan: outline points anchored to a world lattice; a point is a break if its score (corners, changes of rim height, a world-anchored hash) beats every other point within its own window; long faces are split where they sag from the rim and then paired into one broad and one narrow.
  - `Hull`: a low-polygon inverted terrain under the island, shallow at the rim and deep under the middle of wide parts.
  - `Karst`: that hull as a hidden liner, plus rim blocks (one per face, with folds, shelves, shoulders and a bedding step) and a second tier of deeper columns on a jittered lattice.
- `src/decor.rs`: stand-ins for content: pruned pines as tiers of flat pads, broad-leaved trees as rings of leaf masses, rocks, stepping stones, bamboo, lily pads (the rim tufts were replaced by the grass field).
- `src/props.rs` (since 2026-11-23): the frozen Godot scene's real props from `runtime/data/reference/scene_<seed>_<preset>/` (`--props=DIR`, default from the layout name, `--props=none` for the stand-ins; synthetic islands keep the stand-ins). Every `on_top` object and instance is refitted to this tool's ground (its height above the Godot cell under its origin is kept; lilies and reeds over water keep their height above the water) and baked into static world-space vertices. Instances outside this tool's outline or over no cell are dropped and counted (`PROPS` line). With props loaded, the procedural trees, bamboo, rocks, stones and lily pads are not made.
- `src/grass.rs`: the grass field (round r3 blades, replaced in round r4, see below).
- `src/water.rs`: pond surfaces and falls from the cells' water flags (standing in for basins filled by a spring).
- `src/shader.wgsl`, `src/render.rs` (look N, since 2026-11-23): terms (soft 16-tap sun shadow), screen-space occlusion and a depth-aware blur, a resolve in linear light (sun, sky and ground hemisphere, fill; sky and cloud sea backdrop; haze and root mist), water, then a filter down from four samples per pixel in linear, the filmic curve of Godot and one sRGB encode. Vertex colours are display values decoded to linear in the shader; backdrop colours are authored as displayed and pre-inverted through the tone curve. Looks A, B and C (line, flat wash, paper) were removed; they are in git at `6be0388`.
  - Occlusion, its blur and a small linear-depth buffer they read run at the output resolution whatever `--scale` is; the resolve upsamples the occlusion with depth weights.
  - Round r3: island stone is painted in the terms pass from `assets/terrain_editor/gouache_stone_sol61.png` (triplanar wash, brush planes and dry streaks pulled along gravity, after Godot's `stone_cliff_character`), with a mossy brow under the lawn lip and darker joins and lip band baked from per-vertex lip height and front position; ground and grass use Godot's wrapped `meadow_diffuse`; the far mounds are a ring of soft ridges about 480 m out whose upper band shows and whose lower slopes dissolve into the two-toned cloud sea; ponds get a 16-step screen-space reflection (`--ssr=off`), so water draws into its own target and the down pass composites it; internal holes in a layout get a stone-lined pit.
  - `--fxaa`: FXAA 3.11 (quality, 12 steps) on the display values after the tone curve. `--scale=1 --fxaa` is the moving-camera mode; `--scale=2` is the resting-camera mode for review stills.
  - Props are drawn in the terms and shadow passes by ports of the Godot shaders' colour logic: `fs_prop_stone` (`cliff_rock`), `fs_prop_decor` (`decor_vertex_color`), `fs_prop_leaf` (`foliage_cards`, atlas cut-out at 0.23 in both passes, lighting normal out of the crown blended with up).
- Round r4 (2026-11-23):
  - Grass (`src/grass.rs`) is the frozen project's rosette, drawn instanced: one clump mesh per level (seven leaves, Godot's `clump_mesh()` numbers, no centre ridge) and one 32-byte record per root (place, turn, size, ground colour, tuft volume, tone patch, cushion slope). Placement follows `grass_field.gd` `build()`: 28 roots a square metre, Godot's `tuft_patch` drift field for scale and height, lip plants on the outline roll and on terrace brows aligned to the surface and raised (fans over the edge). Colour is relative to the ground under the root (`grass_blades.gdshader` vertex function). The ground follows `ground_cover()`'s soft patches round the authored lawn colour. Levels per 8 m chunk from the projected leaf width in output pixels: two bends above 5 px, one bend above 1.5 px, half the roots with leaves 1.6x wider above 0.75 px, a quarter with 2.3x wider flat leaves below. Chunks drawn near first, after the props.
  - The lawn lip rolls over the outline by about 6 cm in the lawn's own colour; under it a short band of rock (with the mossy brow) reaches down to the blocks.
  - Stone paint ports `stone_surface` (the gouache wash against its mean, at 2x Godot's strength and without its extra mip bias, so the brush dabs show at native pixels; mineral cloud and chalk) and `stone_cliff_character` (brush planes and dry strokes at 0.4 and 0.55 of Godot's strength, mossy brow reaching 0.25 to 2.4 m).
  - Ponds port `water.gdshader`'s ripple fields, its drifting light lines (fewer and weaker than Godot's), shore light lines, a paler shallow band, and its reflection march (24 geometric steps, 6-step binary search, rejection of thick gaps and hits near the water line, distance and edge fade, a light filter growing with distance).
  - Falls: the fall edges of a junction become one straight sheet with the upper pond filled out to its lip; shading ports `waterfall.gdshader` (jade body, threads and ropes, frayed sides, `params.x` time).
  - Occlusion runs at half the internal resolution (the output resolution at `--scale=2`, half of it at `--scale=1`); in the moving mode far taps read a view-distance pyramid (SAO).
- `src/main.rs`: layouts, the twelve review cameras, light sets for day, dusk and night taken from the Godot captures, a three-island scene, picture statistics, form metrics, the edit-locality test, a bench.

## Run it

```
cd runtime && cargo build --release -p s34_study
cd .. && tools/perf/gpu_run.sh 600 runtime/spikes/s34_study/tools/shot.sh OUT_DIR \
    --layout=runtime/data/reference/layout_7301_0.json --body=karst --look=n \
    --views=whole,game --tag=NAME --metrics=OUT_DIR/metrics.json > OUT_DIR.log 2>&1
```

Options are listed at the top of `src/main.rs`. `shot.sh` writes reduced copies to `OUT_DIR/small/`; with `CROP="Y X"` set it also writes a 1300x850 crop at native pixels.

## Findings worth keeping

- Authoring colours as display values and then writing them through an sRGB target made every frame about 0.09 brighter and half as saturated. The pipeline must be one or the other throughout.
- Spacing outline points by arc length makes the whole rim plan slide when the outline changes anywhere. Points have to be anchored to the world, lattice lines must not coincide with cell edges, and ties have to be broken by something that does not depend on order.
- Blurring raw heights gives terraces that follow the cell stairs. Smoothed level sets fix straight and gently curved edges; shallow diagonals still show cell-long steps, so the real construction should relax each terrace contour the way the outline is relaxed.
- Deciding "cut rock or lawn" per triangle leaves a sawtooth of lines along every step. It has to be decided per cell, with one normal.
- A sensitive normal-break line (folds of about fifteen degrees) is what lets a folded face show its structure; a surface id per block is what separates blocks whose faces are nearly parallel.
- Soft noise used as brushwork reads as dirt. Thin, hard-edged strokes in sparse clusters read as drawing.
- Blocks that pass through each other at shallow angles leave thin slivers. A real construction needs blocks that are cut against each other or kept apart.
