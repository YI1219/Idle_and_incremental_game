# Heightfield islands — courtyard seating and rock walls 2026-10-02

Follow-up on PR #2 after the opaque-grass / 4×-oval pass. Same branch. Cloud sea, AgX, height fog, damped telephoto (`near` 1.2 m), and 息壤 stay.

## How to reproduce

```
godot --headless --path . --script tests/heightfield_test.gd
godot --headless --path . --script tests/island_volume_test.gd
godot --headless --path . --script tests/terrain_test.gd
godot --path . --rendering-driver opengl3 --script tests/sandbox_land_test.gd --resolution 1280x720 --fixed-fps 30
godot --path . --rendering-driver opengl3 --script tests/capture_heightfield.gd --resolution 1280x720 --fixed-fps 30
```

Capture locks `DongtianSpace`. Lake and wall close-ups hide the cottage so the roof does not eat the frame.

## Tests

| Suite | Result | Notes |
| --- | --- | --- |
| `heightfield_test.gd` | 38/38 | pebble footprint, ribbon waterfall, punch_shaft |
| `island_volume_test.gd` | 24/24 | cache key is land only |
| `terrain_test.gd` | 795/795 | jade river hidden; heightfield lake + bridge |
| `sandbox_land_test.gd` | 60/60 | oval keeps erasable rim cells and expansion edges |

## Perf (llvmpipe, Godot 4.7, this VM — not target hardware)

| Scene | Islands | Chunks | Tris | Draw calls | Top stroke | Full rebuild |
| --- | --- | --- | --- | --- | --- | --- |
| Playable courtyard | 1 | 6 | 2900 | 20 | 10.7 ms | 65 ms |
| 4× island | 1 | 12 | 3988 | 9 | — | 98 ms |
| 4× + 7 satellites | 8 | 40 | 10826 | 23 | — | 93 ms |

Do not treat these numbers as a Windows thin-laptop or MacBook Air result.

## Views (inspected before reporting)

- `overview.png` — play camera. All trees/rocks/facilities sit on the pebble. No floaters over the cloud sea. East heightfield lake + bridge. A thin waterfall leaves the east lip. Coast is an oval/pebble, not a rounded rectangle.
- `low_side.png` — play rig, pitched at the east wall. Solid brown rock, flat-shaded planes, no pastel stripes, no shard spikes. Palette is warm earth under the grass, cooler/darker below. Not as chunky as the Blender seed7 block wall.
- `lake.png` — closed teal basin under the bridge. Shore is grass. Props stay on land.
- `shaft_waterfall.png` — after a punch-shaft + east spill. Curved waterfall ribbon is visible beside the bridge from the side. The hole reads as a dark pit more than a clear well of clouds.
- `multi_island.png` — 4× oval plus two satellites inside the 34° telephoto. Other pads sit outside the lens.

## Honest leftovers

Not art acceptance. Software GL (llvmpipe) + the play HUD are in every frame.

- Walls are faceted and use the seed7 brown→grey intent, but they are still a tapered cliff, not the Blender prototype's stacked rock blocks.
- Dig-through from the play camera is a dark pit; clouds below are hard to read at 28–50° pitch.
- Waterfall ribbon is visible from the side; foam/mist do not show on a still. Five spill sites fire after the shaft cut and can empty the east lake — lake/wall frames are taken before that cut.
- Kit rocks stay off until they embed.
- Only two of seven satellites fit the play telephoto unless `max_distance` is raised.
- Target-device 60 FPS is unmeasured.
