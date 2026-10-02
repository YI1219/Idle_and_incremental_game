# Heightfield islands — silhouette and material pass (run 5) 2026-10-02

Same branch / PR #2. Brushes, volume cost, dig-through, lakes, and auto-flatten stayed frozen. This pass is render-only: olive grass, clustered scatter, rim-stone chains, a grass/earth shoulder, quieter lighting, and a faded cloud sea. Ideas from the 《我有一片田》 study only — no code, constants, or assets copied (that repo has no license).

## How to reproduce

```
godot --headless --path . --script tests/heightfield_test.gd
godot --headless --path . --script tests/island_volume_test.gd
godot --headless --path . --script tests/terrain_test.gd
godot --path . --rendering-driver opengl3 --script tests/sandbox_land_test.gd --resolution 1280x720 --fixed-fps 30
godot --path . --rendering-driver opengl3 --script tests/capture_heightfield.gd --resolution 1280x720 --fixed-fps 30
```

Capture locks `DongtianSpace`. Lake and wall close-ups hide the cottage so the roof does not eat the frame.

## What changed (visual only)

- No `EMISSION` on grass/cliff. Ambient 0.12, fill 0.04, sun 1.85, AgX exposure 1.24, SSAO radius 0.18 / intensity 2.4. Vertex AO stays for software GL.
- Cliff `step(fract(y))` stripe banding deleted. Rock color uses skewed xz+y grain.
- Grass is desaturated olive (~#6F7A4D / #7E8B5A), two-tone world-space patches, world-space normal noise. Regular pebble grid is gone.
- Clustered MultiMesh scatter from a low-frequency density field: grass tuft cards, a few flowers, pebble clumps. Island `cells_hash` seeds are wrapped before hashing — feeding the raw seed into `sin()` made density constant and spawned zero tufts on the courtyard.
- Contact darkening under trees / house / props.
- Rim and lake-bank rock chains from `assets/rockkit` via MultiMesh. Hanging bakes are flipped to sitting stones and normalized to ~0.2–0.4 m (source meshes are 2–4 m). ~1.05 m spacing, ~34% gaps, big+small groupings, half-embedded.
- Coast rim uses marching-squares + Chaikin/Catmull + low-frequency sine only (no per-vertex hash jitter). Grass lip, then a dark earth roll, then rock. Waterfall foam-cap tris and still-frame mist spheres removed (they were the white strip / '7').
- Render-only micro-relief (continuous value noise, suppressed on pads) and a render-only bank dip into pits. Does not write H.
- Lake shader: shallow bright band, contact dark seam, more teal than ice-blue. Still a flat disc from the play camera.
- Cloud sea sheet fades out radially; puffs are clustered pale spheres. The hard square and ten-sided disc holes are gone.

Not done: seed7 interleaved MultiMesh cliff blocks (expensive). Shared-normal indexing / soft earth risers only partly there (shader bump + bank dip; tops still facet-shaded).

## Tests

| Suite | Result | Notes |
| --- | --- | --- |
| `heightfield_test.gd` | 38/38 | closed mesh / winding hold |
| `island_volume_test.gd` | 24/24 | cache key is land only; H unchanged |
| `terrain_test.gd` | 795/795 | brush math unchanged |
| `sandbox_land_test.gd` | 59 checks, 0 failures | process aborted on Godot quit (llvmpipe); no failed asserts |

## Perf (llvmpipe, Godot 4.7, this VM — not target hardware)

| Scene | Islands | Chunks | Tris | Draw calls | Top stroke | Full rebuild |
| --- | --- | --- | --- | --- | --- | --- |
| Playable courtyard | 1 | 6 | 3340 | 20 | 43.3 ms | 210 ms |
| 4× island | 1 | 12 | 4476 | 14 | — | 481 ms |
| 4× + 7 satellites | 8 | 40 | 12956 | 100 | — | 477 ms |

Run 4 playable was 3144 / 26 / 16.7 / 171. Extra wall ring and dressing MultiMeshes add tris and draws. Stroke is slower on this software GL box because sitting kit meshes are tessellated. User Mac (M4 Pro, Metal Forward+) already measured ~155 fps uncapped on run 4 for both playable and 4×+7 — do not treat these llvmpipe numbers as a Windows thin-laptop or MacBook Air result.

Playable dressing this capture: 1500 tufts, 155 pebbles, 168 flowers, 64 rim rocks. Density field ranged 0.15–0.63.

## Views (inspected before reporting)

- `overview.png` — play camera. Olive top, visible tuft stipple, small dark rim stones, no pebble grid, no grey cloud discs. Pond is still a faceted grey-green plate.
- `low_side.png` — east wall, cottage hidden. Tufts read as a meadow silhouette. Rim stones are small lumps, not a graveyard. Cliff is still a dark faceted shell; the earth shoulder does not read at this pitch. No white '7'.
- `lake.png` — basin under the bridge, tuft texture, a few bank stones. Water is opaque grey-green, not translucent teal. No lily-pad read.
- `shaft_waterfall.png` — lakes=1, falls=3. The punched shaft is a dark hole, not a window onto the cloud sea. Fall is easy to miss from this angle.
- `multi_island.png` — 4× oval plus two satellites inside the 34° telephoto. Cloud sea is a pale wash (radial fade, no square). Dressing disappears at this distance.
- `overview_compare_run4_run5.png` — same framing. Run 5 is olive instead of toy-green, has tuft speckle and rim stones, and loses the grey disc clouds. Water is greener/murkier, not clearer.

## Honest leftovers

Not art acceptance. Software GL (llvmpipe) + the play HUD are in every frame. Mac Metal already proved lighting is not the main gap; these leftover gaps are still shape and material.

- The reference island is flatter than ours and sells the read with ~30 tufts/m², 0.5–1.2 m shore stones, a rounded grass→earth shoulder, and saturated teal water. We have ~15 tufts/m² of cheap cross-cards, 0.2–0.4 m rim stones, and a shoulder that is too thin/dark to see from the play camera.
- Cliffs are still a smooth curved shell with faceted rings. seed7 stacked blocks were not built.
- Tops are still per-face shaded. Terrace steps can still read as triangle ridges. Shared-normal indexing and soft earth risers are incomplete.
- Water is a flat disc. Depth/seam exist in the shader; they do not read as shallow teal with a wet sand band.
- The shaft is a depression, not a cloud window. Soft puffs sit under the island; they do not show in these shots.
- Contact darkening is subtle. Flowers exist in the MultiMesh counts and do not read as flowers at 22 m.
- Kit rocks stay off the hanging underside (still waiting on embed rules).
- Only two of seven satellites fit the play telephoto unless `max_distance` is raised.
- Target-device 60 FPS is unmeasured here. User Mac ~155 fps is a previous-run measurement, not a new claim for this revision.
