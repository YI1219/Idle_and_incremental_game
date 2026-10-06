# Quiet cultivation homestead — 2026-10-06

Actual Godot 4.7.2 Forward+ / Metal render, Apple M4 Pro. This is an implemented art pass, not concept art or final user aesthetic acceptance.

## Delivered scene

The existing `scenes/terrain_editor.tscn` entry point still constructs the same editable island. Its two terraces, both lake outlines/elevations, connected waterfall and off-island waterfall, cottage location, tree anchors, bench and lantern remain. The camera script and data preset are unchanged. `updated.png` is rendered at **1671 × 941**, matching the supplied attachment's dimensions, from the existing camera (pitch −27°, yaw 16°, FOV 31°, height 21). The attachment itself was not treated as the target palette; the before render is `--baseline.png` (the native macOS window rounded that capture to 1670 × 940). `garden_detail.png` is an additional closer inspection with the same orientation.

- Cottage and its existing door details/colliders multiply their previous scale by **0.65**, retaining the original Tripo asset. The path starts at the new doorway; procedural vegetation leaves its route clear.
- Five short brown soil rows / 35 retained-source faceted vegetable crowns, batched into five MultiMeshes. The plot occupies dry land beside the entrance path. Rows follow terrain publication and hide if support is removed, restoring after undo. No farm gameplay is added.
- Four trees retain their original anchors. Actual vertex ground-to-top heights are **4.233, 4.067, 4.150, 4.191 m** (roughly 4% spread). Widths and yaw vary modestly.
- Outer supporting rock depth is **60%** of the previous depth, anchored below its local supporting terrace. The minimum legal terrain height keeps a 0.5 m supporting body. Terrace walls and playable elevations remain. Picking derives from the changed mesh. A small outer waterfall clearance adjustment prevents a lip overlap introduced by the shorter shell.
- Sage/olive ground and foliage, subdued jade-blue water, coherent warm-gray cliffs, weathered timber, charcoal tiles, ivory clouds. Material-level changes are scoped to workshop resources; retained source assets and other scenes' materials are untouched.
- Softer warm directional light from the right, cool ambient fill, reduced shadow opacity and restrained SSAO approximate baked softness. No lightmaps were baked because terrain remains editable. No backend change, new volumetrics, particles, bloom, depth of field or fullscreen color grade.
- Lightweight sky shader uses layered simplified mountain silhouettes and recolors broad density from the existing cloud-only texture. Pale sun is upper right. No background buildings and no foreground framing assets.
- Calm broad water motion; descending interrupted waterfall streaks replace outlined cellular rings. Reused reeds/lilies, varied shoreline stone sizes, sparse pale flowers at path margins and existing restrained hanging vines retain open space.

## Controls and changed files

| File / location | Controls or responsibility |
| --- | --- |
| `scripts/terrain_editor/terrain_props.gd` | `COTTAGE_SCALE`; existing architecture; supported kitchen garden |
| `scripts/terrain_editor/terrain_decoration.gd` | `COMMON_TREE_HEIGHT`; path clearance; shore variation / flowers |
| `scripts/terrain_editor/terrain_models.gd` | Per-role vegetation, stone and timber palette; retained model reuse |
| `scripts/terrain_editor/contour_terrain.gd` | `UNDERSIDE_THICKNESS`; outer stream clearance; shared shell / picking |
| `scripts/terrain_editor/editor.gd` | Exported sunlight / ambient energy and background haze; shadow/contact balance |
| `shaders/terrain_editor/land_palette.gdshaderinc` | Inspector-editable sRGB ground color endpoints shared by ground, turf and shore |
| `shaders/terrain_editor/water.gdshader` | Inspector-editable shallow/deep sRGB water endpoints; broad normal movement |
| Other `shaders/terrain_editor/` changes | Sky, waterfall, foam, foliage, cottage, cliff palette and matching shore/turf |
| `tests/capture_homestead.gd` | Real rendered composition and detail captures, exact-size SubViewport and metadata |
| `tests/terrain_homestead_test.gd` | Proportions, actual vertex heights, support/removal/undo and camera assertions |
| `tests/terrain_boundary_wall_test.gd` | Probe inside local supporting shell instead of obsolete fixed world Y = −2 |

## Verification and limits

**29/29 terrain test scripts passed in the final run.** Final test results are recorded in `checks.json` and per-script logs. Actual renderer tests include cottage materials and the 22-check editor runtime suite; the other tests exercise geometry and data headlessly. `terrain_homestead_test.gd` covers 28 assertions. Screenshots were opened and inspected, including entrance/garden contact, tree bases, the terrace waterfall and shell.

Visual acceptance remains the user's. The existing cliff geometry still has angular recesses, the shoreline retains some repetitive stone rhythm, and the small crops deliberately reuse simple faceted foliage. Background silhouettes are camera-aligned infinite-distance sky artwork and provide no 3D parallax. Water has sky reflections, not reflected cottage/tree geometry. No new target-laptop FPS, GPU timing, long-idle power/stability or animation-playback acceptance is claimed. Existing unrelated local work, project settings and original assets are preserved.
