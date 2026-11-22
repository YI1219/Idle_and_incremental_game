# Studies S3 and S4: look and island generation

Throwaway code. One tool that builds an island from cells with a new generator and draws it with a new look, so both can be judged on pictures against the frozen Godot project and on a few numbers. Its results are checkpoint G1: `art/lookdev/20261122_g1/README.md` and `compare.html` there.

Nothing here is the start of the real crates. What carries forward is the design, the measurements and the list of defects.

## What it does

- `src/field.rs`: cells (1 m, heights in 0.5 m steps) are the only input. From them: a blurred occupancy whose 0.5 contour is the island's smooth outline; two wider blurs that say how far inside the rim a point is; terrace heights built from smoothed level sets, so steps are smooth in plan and near-vertical in section. The top surface is one height field clipped at the outline, with a rolled lawn lip. Every value depends only on cells within a few metres.
- `src/body.rs`: the rim plan and two bodies.
  - Rim plan: outline points anchored to a world lattice; a point is a break if its score (corners, changes of rim height, a world-anchored hash) beats every other point within its own window; long faces are split where they sag from the rim and then paired into one broad and one narrow.
  - `Hull`: a low-polygon inverted terrain under the island, shallow at the rim and deep under the middle of wide parts.
  - `Karst`: that hull as a hidden liner, plus rim blocks (one per face, with folds, shelves, shoulders and a bedding step) and a second tier of deeper columns on a jittered lattice.
- `src/decor.rs`: stand-ins for content: pruned pines as tiers of flat pads, broad-leaved trees as rings of leaf masses, rocks, stepping stones, bamboo, lily pads, rim tufts.
- `src/water.rs`: pond surfaces and falls from the cells' water flags (standing in for basins filled by a spring).
- `src/shader.wgsl`, `src/render.rs`: terms, resolve, water, then a filter down from four samples per pixel with paper grain. The resolve gathers light into flat washes, picks one of two shade washes by how a face turns, draws line from depth, normal and surface-id breaks, and applies height and distance mist. Colours are display values, written as authored.
- `src/main.rs`: layouts, the twelve review cameras, palettes for day, dusk and night, looks A, B and C, a three-island scene, picture statistics, form metrics, the edit-locality test, a bench.

## Run it

```
cd runtime && cargo build --release -p s34_study
cd .. && tools/perf/gpu_run.sh 600 runtime/spikes/s34_study/tools/shot.sh OUT_DIR \
    --layout=runtime/data/reference/layout_7301_0.json --body=karst --look=b \
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
