# Editable terrain workshop

The active demo uses `TerrainData`: a sparse dictionary of land cells, height and optional water elevation. All visible terrain is generated from this data. Missing cells are off-island or holes. The retained legacy gameplay scene has separate historical terrain rules.

Raise/lower move an existing cell by 0.5 units per stroke; height is bounded from -4 to 12. Expand fills absent cells at the selected height. Contract removes cells, water and automatic decoration. Drag strokes interpolate their path and change each visited cell once. Undo/redo retain the latest 64 strokes.

Snapping aligns the brush center to the picked cell center, including the owning cell on cliff boundaries. With snapping off, circular coverage follows the cursor continuously; underlying terrain still uses cells and 0.5 height increments. The construction grid is optional and does not define ground materials.

Water painting selects one of exactly eight absolute elevations: 0, 0.5, 1, 1.5, 2, 2.5, 3 or 3.5. Only lower floors accept water; raising the floor through its water surface removes that water. Equal-elevation neighbors join using all 47 normalized eight-neighbor blob states; a diagonal needs both adjacent orthogonal neighbors. Banks distinguish convex corners, straight edges and concave corners. Bank boundary walls connect the selected water elevation to neighboring ground, including deep floors. This is editable pond geometry, not fluid simulation. Higher water adjacent to lower water or missing land generates a waterfall.

8×8 chunks merge grass, bank, cliff, water and waterfall surfaces. Changed cells invalidate their chunk and affected neighboring boundary chunks. Rebuilds are bounded to two chunks per frame; idle frames do not rebuild terrain. Picking follows the same authoritative cell heights and sides.

Existing CC0 Quaternius grass, bush, tree and rock meshes use chunk-local MultiMeshes. Coordinate/seed hashing places independent kinds deterministically. Surface grass follows ground height; surface rocks partly embed; cliff rocks anchor inside exposed faces. Submerged cells suppress surface vegetation and rocks. Original sources are unmodified. Runtime foliage materials adapt the pack to the scene palette.

Layout JSON under `user://terrain_editor/layout.json` preserves terrain and seed separately from legacy gameplay saves. Loading validates the complete candidate before replacement, rejecting corrupt data, nonfinite values, coordinates beyond ±1024, more than 65536 cells, duplicate cells and invalid water levels.

Verification commands:

```sh
python3 tests/run_preview.py tests/terrain_editor_data_test.gd --headless
python3 tests/run_preview.py tests/terrain_editor_render_test.gd --headless
python3 tests/run_preview.py tests/terrain_editor_decoration_test.gd --headless
python3 tests/run_preview.py tests/terrain_editor_runtime_test.gd --headless
```
