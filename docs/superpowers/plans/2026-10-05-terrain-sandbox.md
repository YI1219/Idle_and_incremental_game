# Floating-island Terrain Sandbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking. Native execution was selected and approved by the user.

**Goal:** Replace the active demo with freely editable floating-island terrain, automatic vegetation and embedded rocks, eight water elevations, 47 connection states and smooth horizontal camera navigation.

**Architecture:** A sparse authoritative height grid drives 8×8 terrain chunks and chunk-local decoration MultiMeshes. A dedicated editor scene owns camera, stroke input, UI and isolated persistence. Reuse Blob47 and existing free asset sources; preserve unrelated working-tree changes.

**Tech Stack:** Godot 4.7.2, GDScript, ArrayMesh, MultiMesh, shared spatial shaders, existing CC0 Quaternius glTF assets.

**Spec:** `docs/superpowers/specs/2026-10-05-terrain-sandbox-design.md` (approved with revised camera and preservation requirements).

## Global Constraints

- The old terrain and placed scene objects may be removed or replaced; they are not preservation requirements.
- Original asset source files and economy sources remain available.
- Terrain heights use bounded increments of 0.5 world units, from -4 to 12.
- Water has exactly eight elevations, 0 through 7, spaced by 0.5 world units.
- Camera orientation stays fixed; horizontal movement preserves height; only the scroll wheel adjusts camera height and zoom.
- No purchases, custom original geometry generation, character/combat changes or village/exploration expansion.
- Benchmark 4096 cells at 1280×720 low quality over three runs of at least 60 seconds, median frame time ≤16.7 ms and p95 ≤25 ms; separately run 30-minute stability. Target-device acceptance remains pending actual measurements.

## Review Focus

- Dragging from the UI onto terrain must not begin an accidental edit (Task 4).
- Negative coordinates and chunk corners must invalidate every affected boundary (Task 1/2).
- Removing all land must leave a usable editor and preserve camera height (Task 4).
- Corrupt or oversized layout input must leave the current layout intact (Task 1/4).
- Rapid edits and undo while rebuilds are queued must converge to current data without stale decoration (Task 2/3).

### Task 1: Authoritative terrain data and strokes

**Files:** Create `scripts/terrain_editor/terrain_data.gd`; test `tests/terrain_editor_data_test.gd`. Consume `scripts/world/blob47.gd` unchanged.

**Interfaces:** `TerrainData extends RefCounted`; `cells: Dictionary[Vector2i, Dictionary]` stores `height: float`, `water: int` (-1 means dry). `seed: int`; `dirty_chunks: Dictionary`; `begin_stroke()`, `apply_brush(center: Vector2, radius: float, tool: String, snap: bool, height: float, water: int) -> int`, `end_stroke()`, `undo() -> bool`, `redo() -> bool`, `water_mask(cell: Vector2i) -> int`, `serialize() -> Dictionary`, `deserialize(payload: Dictionary) -> bool`, `make_preset(kind: int)`. Dirty chunks use floor division by 8 and include neighboring affected cells.

- [x] Write failing data tests: expand absent land, raise/lower by 0.5, contract removes water, repeated visit changes once per stroke, height clamps to [-4,12], dry land raised through water removes it. Assert snapped and continuous brush centers select different coverage at a cell boundary.
- [x] Run `python3 tests/run_preview.py tests/terrain_editor_data_test.gd --headless`; require failure due to missing implementation.
- [x] Implement interfaces, three presets, bounded stroke history, atomic validated load (maximum 65536 cells, finite heights, coordinate bounds ±1024, water -1..7), and neighbor invalidation.
- [x] Extend tests: each water level 0..7 survives serialization; 256 neighbor configurations yield exactly 47 masks; differing elevations do not join. Negative-coordinate/corner edits dirty all relevant chunks. Undo/redo restores cells/water exactly; malformed/oversized input leaves state unchanged.
- [x] Re-run the data tests; require zero failures, then commit only task files.

### Task 2: Chunk terrain, water and waterfall geometry

**Files:** Create `scripts/terrain_editor/terrain_renderer.gd`, `scripts/terrain_editor/chunk_geometry.gd`, `shaders/terrain_editor/ground.gdshader`, `shaders/terrain_editor/water.gdshader`; test `tests/terrain_editor_render_test.gd`.

**Interfaces:** Consume TerrainData. `TerrainRenderer extends Node3D`: `configure(data: TerrainData)`, `flush_dirty(max_chunks: int = 2) -> int`, `rebuild_all()`, `pick(ray_origin: Vector3, ray_direction: Vector3) -> Dictionary` returns hit position/cell or empty result; `chunks: Dictionary`. `ChunkGeometry.build(data: TerrainData, chunk: Vector2i) -> Dictionary` returns shared-material grass, cliff, bank, water and waterfall meshes. Picker uses authoritative cell top and side intersection, including holes.

- [x] Write failing render tests for stepped faces, missing-cell cliffs, isolated water, equal-height joins, all 47 masks and higher-to-lower waterfall generation; run `python3 tests/run_preview.py tests/terrain_editor_render_test.gd --headless` and confirm expected missing implementation failure.
- [x] Implement merged chunk surfaces with faceted cliff variation, matching ground cuts/water banks using Blob47, shared world-space materials, and bounded waterfall strips. Dirty work is processed only after changes and uses latest state.
- [x] Assert an interior edit rebuilds only its affected chunk set; an edge/corner edit refreshes neighbors; rapid edit/undo before flush produces geometry matching current cells. Pick hits land/water and avoids holes; no nodes per terrain cell.
- [x] Run render and data tests with zero failures; commit task files.

### Task 3: Instanced terrain-adapting vegetation and rocks

**Files:** Create `scripts/terrain_editor/terrain_decoration.gd`; test `tests/terrain_editor_decoration_test.gd`. Reuse existing `assets/nature/quaternius/` meshes and license.

**Interfaces:** `TerrainDecoration extends RefCounted`: `load_assets()`, `placements(data: TerrainData, chunk: Vector2i) -> Dictionary`, `populate(parent: Node3D, data: TerrainData, chunk: Vector2i)`. Placements group grass, bush, tree, surface rock and embedded cliff rock transforms by mesh/material surface; consume Task 2's chunks through TerrainRenderer.

- [x] Write failing tests: same cells/seed produce identical transforms; water removes vegetation; raise updates surface transform heights; cliff rocks partially intersect exposed faces; remove/undo returns original deterministic placements. Run `python3 tests/run_preview.py tests/terrain_editor_decoration_test.gd --headless` and confirm missing implementation failure.
- [x] Extract glTF mesh surfaces and transforms once; instantiate per-kind MultiMeshes with shared materials and deterministic coordinate hashes. Avoid model node instances per decoration. Anchor rocks to ground/side faces; regenerate affected chunks during geometry flush. Document any missing-model placeholder.
- [x] Test rapid data changes before flush leave no stale population; inspect a rendered small scene for scale, embedding and texture pairing before expanding decoration density.
- [x] Require data/render/decoration tests passing; commit task files.

### Task 4: Camera and interactive editor

**Files:** Create `scripts/terrain_editor/editor_camera.gd`, `scripts/terrain_editor/editor.gd`, `scripts/terrain_editor/editor_hud.gd`, `scenes/terrain_editor.tscn`; test `tests/terrain_editor_runtime_test.gd`.

**Interfaces:** `EditorCamera extends Camera3D`: `pan(horizontal: Vector2, delta: float)`, `pan_pixels(relative: Vector2)`, `wheel(steps: float)`, `advance(delta: float)`, `recenter(center: Vector2)`. Fixed yaw/pitch; independent horizontal target and wheel-controlled height target. `TerrainEditor extends Node3D`: `data`, `renderer`, `camera`, `select_preset(kind: int)`, `save_layout(path: String) -> Error`, `load_layout(path: String) -> Error`. HUD forwards tool/radius/snap/water/grid/history/save/load actions, never direct terrain mutation.

- [x] Write failing camera tests: keyboard/drag pan preserves Y; Q/E, orbit gestures and terrain elevation cannot change height; wheel alone changes bounded height/zoom smoothly; recenter/preset/reset preserves height. Run `python3 tests/run_preview.py tests/terrain_editor_runtime_test.gd --headless` for expected missing implementation failure.
- [x] Implement fixed-orientation WASD/arrows and middle-drag navigation, wheel dolly and time-based easing. Disable vertical/fly/orbit actions. Focus loss ends strokes; GUI-origin drags cannot paint. Picker supports expanding into absent cells through a selected-height fallback plane.
- [x] Implement brush indicator, tool panel, eight-level water selector, snap explanation, optional grid, undo/redo and isolated JSON save/load under `user://terrain_editor/`. Add sunny sky/light composition and three presets using the same editable module rules.
- [x] Test UI drag capture, empty-island recovery, interrupted strokes, corrupted load rollback, save/load and wheel height preservation across reset. Run all editor tests, require zero failures, then commit task files.

### Task 5: Active entry, launchers and current documentation

**Files:** Modify `project.godot` only at active scene/description settings; update `Play Demo.command`, `打开沙盒营造.command`, `README.md`, `CURRENT_CONTEXT.md`, `docs/camera.md`, `docs/terrain.md`. Preserve unrelated project settings and working-tree edits.

- [x] Switch `run/main_scene` to `res://scenes/terrain_editor.tscn`; update launchers to run it. Original asset sources/economy remain available; old scene objects are not carried into the new demo.
- [x] Replace stale current-priority/camera statements with the approved sandbox scope and actual implemented status. Record controls, water elevation semantics, snapping behavior, free-asset reuse and verification commands.
- [x] Launch actual active scene at 1280×720; require no parse/runtime errors and functional controls. Verify original source files are intact and diff excludes unrelated changes; commit task files.

### Task 6: Engine visual inspection, benchmarks and stability

**Files:** Create `tests/capture_terrain_editor.gd`, `tests/benchmark_terrain_editor.gd`; save evidence under `art/review/terrain_editor/2026-10-05/` and update current status with measured results.

- [x] Capture actual rendered views of three substantially different edited layouts: terraces/spill, elongated island and holes/sparse land. Inspect images for silhouette, grass/cliff transitions, water banks, waterfalls, embedded rocks, vegetation scale and reference-consistent lighting. Correct defects and rerun affected checks before performance measurement.
- [x] Run visible, real-time (no fixed FPS) 4096-cell low-quality benchmark at 1280×720 for 3×60 seconds after warmup. Save frame distributions, median/p95, device/backend, draw calls, memory and stroke-to-render latency. Require median ≤16.7 ms and p95 ≤25 ms for each run; unresolved misses stay open.
- [ ] Run a visible 30-minute stability session with periodic terrain edits, undo/redo and camera movement. Compare memory after warmup versus end; require no crash/runtime errors, no accumulating nodes and valid data/renderer agreement.
- [ ] Run all editor checks fresh and compare evidence to every goal requirement. Keep thin-laptop/MacBook Air acceptance pending separate device measurements. Commit verified work and evidence; mark goal complete only when all required gates pass.
