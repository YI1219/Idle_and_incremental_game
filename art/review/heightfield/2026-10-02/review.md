# Heightfield islands — visual quality overhaul (run 4) 2026-10-02

Same branch / PR #2. Gameplay and brush math stayed frozen. This pass is lighting, materials, coastline read, walls, grass dressing, water, waterfall/shaft, and facility stand-ins. Cloud sea, damped telephoto (`near` 1.2 m), and 息壤 stay.

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

- Warm low-angle sun, weak cool fill, FILMIC (ACES blew the sky to white on llvmpipe), saturation, light height fog. Vertex AO on the mesh because software GL often drops SSAO.
- Coast tops stay grass to the lip. The run-3 brown corner squares were rock-flagged coast quads (`vcol.b = 1 - inland`). Rim verts snap fully to the smoothed loop; rim jitter is damped.
- Walls are offset faceted rings with a warm→cool grade and a keel that tapers toward a point. Shaft rims flare open. A few hanging roots sit under the island.
- Grass gets hue/value patches, darker rims and tree contact, sparse MultiMesh tufts/pebbles/flowers, and shore rocks. Dirt paths are a soft worn mix.
- Lakes use a depth/foam shader with back-face cull so they are not a cyan box.
- Waterfall keeps the ribbon; still-frame mist puffs sit at the plunge.
- Neon facility cubes are a planter, a crate/jar, and stone lanterns.

## Tests

| Suite | Result | Notes |
| --- | --- | --- |
| `heightfield_test.gd` | 38/38 | closed mesh / winding still hold with the keel |
| `island_volume_test.gd` | 24/24 | cache key is land only |
| `terrain_test.gd` | 795/795 | earlier this pass; brush math unchanged |
| `sandbox_land_test.gd` | 59 checks, 0 failures | process aborted on Godot quit (llvmpipe); no failed asserts |

## Perf (llvmpipe, Godot 4.7, this VM — not target hardware)

| Scene | Islands | Chunks | Tris | Draw calls | Top stroke | Full rebuild |
| --- | --- | --- | --- | --- | --- | --- |
| Playable courtyard | 1 | 6 | 3144 | 26 | 16.7 ms | 171 ms |
| 4× island | 1 | 12 | 4232 | 11 | — | 432 ms |
| 4× + 7 satellites | 8 | 40 | 12032 | 75 | — | 428 ms |

Run 3 playable was 2900 / 20 / 10.7 / 65. Dressing MultiMeshes and one extra wall ring add draws and a modest rebuild hitch. Triangle count stayed in the same band. Do not treat these numbers as a Windows thin-laptop or MacBook Air result.

## Views (inspected before reporting)

- `overview.png` — play camera. Oval pebble, no brown corner squares, muted stand-ins instead of neon cubes, pale pond, a few tufts/pebbles. Sky is a cool wash, not the old grey — still not a dressed diorama.
- `low_side.png` — east wall from a lower play pitch. Brown faceted rock with a visible keel point. Not seed7 stacked blocks.
- `lake.png` — closed basin under the bridge, shore pebbles, ice-teal water. No lily pads readable. Triangle edges still show.
- `shaft_waterfall.png` — lake kept (lakes=1, falls=3). A thin fall leaves the east lip. The punched shaft does not read as a clear well of clouds from this angle.
- `multi_island.png` — 4× oval plus two satellites inside the 34° telephoto.
- `overview_compare_run3_run4.png` — same framing. Run 4 removes the cyan/purple/orange cubes and brown corners; grass is slightly yellower; pond is paler teal; sky is cooler.

## Honest leftovers

Not art acceptance. Software GL (llvmpipe) + the play HUD are in every frame.

- The farming-diorama target is a hand-dressed Godot scene: warm low sun, long soft shadows, strong AO, saturated teal water, lily pads, dense hero props. This island is still a procedural heightfield with cheap stand-ins. Lighting on llvmpipe stays flat; SSAO/PCSS/bloom do not sell the shot.
- seed7 walls are sculpted stacked blocks. Ours are noise-offset rings with a keel. Closer than the run-3 slab, not a match.
- Water is a flat ice-teal disc. Depth/foam exist in the shader; they do not read as translucent teal with shore fade from the play camera.
- The shaft is a depression, not a window onto the cloud sea. Clouds are pale discs in a pale sky.
- Grass color variation is subtle at telephoto. Tufts are short cards, not Quaternius clumps.
- Kit rocks stay off the walls.
- Only two of seven satellites fit the play telephoto unless `max_distance` is raised.
- Target-device 60 FPS is unmeasured.
