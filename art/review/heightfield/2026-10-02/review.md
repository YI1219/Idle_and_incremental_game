# Heightfield islands — smooth coast and procedural wall rock (2026-10-02)

Same branch / PR #2. Brushes, volume cost, dig-through, lakes, and auto-flatten are unchanged. The shell pass below is still the mesh. A later lighting pass only retuned materials: foliage no longer adds emission, and grass mottling is two world-space brightness scales of about ±10% on the existing grey-olive pair, with a small normal bump added on the geometric normal. Ambient 0.12, key light 1.85, AgX exposure 1.24, saturation 1.08, and SSAO radius 0.18 / intensity 2.4 were already in range. No reference-repo code or assets were copied. Clumped tufts, the lake water shader, and prop contact blends are unchanged.

## How to reproduce

```
godot --headless --path . --script tests/heightfield_test.gd
godot --headless --path . --script tests/island_volume_test.gd
godot --headless --path . --script tests/terrain_test.gd
godot --path . --rendering-driver opengl3 --script tests/sandbox_land_test.gd --resolution 1280x720 --fixed-fps 30
godot --path . --rendering-driver opengl3 --script tests/capture_heightfield.gd --resolution 1280x720 --fixed-fps 30
```

## What changed

- Grass coastline is a marching-squares contour of a blurred land mask (iso 0.5, linear edge hits, five Laplacian passes). The top outline is that curve. It is not the gameplay grid and it is not a rocky silhouette.
- Full islands subdivide render cells 2× (0.25 m). Distant LOD uses 1×. Lake banks and slopes use that finer grid with gradient normals.
- Top undulation is render-only (neighbor blur plus a few centimetres of value noise), and it is suppressed on flat pads and building/device footprints. It does not write H.
- The outer lip dips 3–6 cm over the last 0.32 m and hangs 0.10–0.30 m into a thin earth band. That hem vertex is the top of the rock column, so grass, earth, and wall share one edge.
- Rock courses are one column per lip vertex. The face steps out over the first two courses, stays near-vertical, and tucks under only in the bottom 30%. There is no horizontal shelf between rows. The merged chunk mesh has no open edges at 1 mm. Warm brown grades to grey down the wall; rock lighting is wrapped so a shadowed vertical face stays readable.
- Shore stones are five procedural chunks (no kit meshes), one MultiMesh per variant, placed from a position hash along the coast and lake loops. They sit inland of the lip and are partly buried.

## Tests

| Suite | Result |
| --- | --- |
| `heightfield_test.gd` | 38/38 |
| `island_volume_test.gd` | 24/24 |
| `terrain_test.gd` | 795/795 |
| `sandbox_land_test.gd` | 59 checks, 0 failures |

## Perf (llvmpipe, Godot 4.7, this VM — not target hardware)

| Scene | Islands | Chunks | Tris | Draws | Top stroke | Full rebuild |
| --- | --- | --- | --- | --- | --- | --- |
| Playable courtyard | 1 | 6 | 7412 | 19 | 216 ms | 353 ms |
| 4× island | 1 | 12 | 9674 | 14 | — | 966 ms |
| 4× + 7 satellites | 8 | 40 | 28208 | 95 | — | 385 ms |

Run 5 on this same capture path was 3340 tris, stroke about 57 ms, playable rebuild about 269 ms. The new shell is heavier. The 16 ms stroke aim was not met here (65 ms for the whole playable top). Do not read these numbers as a Mac or Windows laptop result.

## Views

- `overview.png` — play camera.
- `low_side.png` — low east view, cottage hidden, walls in frame.
- `lake.png` — basin close-up.
- `shaft_waterfall.png` — sculpted shaft, lakes=1, falls=3.
- `multi_island.png` — 4× island plus satellites.
- `overview_compare_run5_new.png` — run 5 on the left, this pass on the right, same framing.

## Honest leftovers

Not art acceptance.

- From the high play camera the wall is a warm rim. The low side shows vertical facets, warmer at the top. The underside keel still faces down, so it stays darker than the wall.
- Shore stones read as small buried chunks in the overview. A few near the camera still look large because the coast shot is a few metres from the lip.
- Distant islands use the coarser LOD contour.
- Stroke cost on this VM is 216 ms for the playable shell, above the 16 ms aim. A 4× full rebuild is 966 ms.
- Water is still the run 5 lake surface. Tuft density and flowers are unchanged from that pass.
- Grass mottling is intentionally mild. The shoulder is a few centimetres of dip plus a thin earth band; it will not read as a thick soil roll from the high camera.
- Tree cards no longer self-light. The rest of the lighting stack was already low ambient, AgX, and small-radius SSAO, so the frame stays close to the previous shot.
- Target-device frame rate was not measured. Playable stroke on this VM after the shader change was 75 ms.
