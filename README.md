# Floating Garden · Terrain Workshop

Current playable demo for an ancient-style xianxia idle incremental project. Freely edit a floating island with layered grass, rock cliffs, ponds, waterfalls and automatic vegetation. Read [current project context](CURRENT_CONTEXT.md) for scope and acceptance status.

## Launch

Double-click **Play Demo.command** or **打开沙盒营造.command**. Requires Godot 4.7 or newer; the launcher imports resources before running the workshop. Opening `project.godot` and pressing Run launches the same scene.

| Action | Control |
| --- | --- |
| Raise / lower / expand / contract | Select tool, then left-drag |
| Add / remove water | Select tool and one of eight water elevations |
| Brush size and expansion height | Left panel |
| Snap brush to cell centers | Snap toggle; off allows continuous cursor placement |
| Horizontal panning | WASD / arrows / middle-mouse drag |
| Camera height and zoom | Scroll wheel only |
| Horizontal recenter | Home |
| Undo / redo | Buttons or Ctrl/Cmd+Z / Shift+Ctrl/Cmd+Z |
| Save / load layout | Buttons; isolated workshop layout file |
| Reset / change layout | Preset selector and Reset |

Camera orientation is fixed. Vertical movement, fly navigation and orbit are disabled. Terrain edits automatically regenerate nearby vegetation and embedded rock models. Every visible land cell is editable, including outer edges and holes. Terrain remains cell-based even with snapping off. See [terrain rules](docs/terrain.md) and [camera rules](docs/camera.md).

## Current limits

This is a terrain demo. Water is an eight-level editing system, not a fluid simulation. Free Kenney model parts and adapted runtime materials provide solid surface objects; shared organic contours and cliff geometry are generated in code. The refined cottage is reused; bench and lantern use placeholders. Original source models are preserved. Economy, character and combat sources remain available but are not part of the active workshop. The legacy scene can be opened directly as `scenes/play.tscn`; `Play Indoor Transition.command` remains its launcher.

The active revision prioritizes visual fidelity to the supplied floating-island image and coherent editing. Actual reference comparisons and user art acceptance are pending. Current-renderer performance is reported separately from previous benchmarks; Windows thin-laptop and MacBook Air results remain unmeasured.

## Verification

```sh
python3 tests/run_preview.py tests/terrain_contour_test.gd --headless
python3 tests/run_preview.py tests/terrain_editor_data_test.gd --headless
python3 tests/run_preview.py tests/terrain_editor_render_test.gd --headless
python3 tests/run_preview.py tests/terrain_editor_decoration_test.gd --headless
python3 tests/run_preview.py tests/terrain_editor_runtime_test.gd --headless
```

Original asset status: [art/README.md](art/README.md). Existing economy and exploration design: [docs/README.md](docs/README.md). Approved workshop [design](docs/superpowers/specs/2026-10-05-terrain-sandbox-design.md) and [implementation plan](docs/superpowers/plans/2026-10-05-terrain-sandbox.md).
