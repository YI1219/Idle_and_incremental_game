# Heightfield islands — visual quality overhaul (run 4) 2026-10-02

Same branch / PR #2. Gameplay and brush math are frozen. This pass is lighting, materials, coastline read, walls, grass dressing, water, waterfall/shaft, and facility stand-ins. Cloud sea, damped telephoto (`near` 1.2 m), and 息壤 stay.

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

- Warm low-angle sun, weak cool fill, ACES, saturation, height fog into the cloud sea, SSAO/glow on. Vertex AO on the mesh because software GL often drops SSAO.
- Coast tops stay grass to the lip (the run-3 brown corner squares were rock-flagged coast quads). Rim verts snap fully to the smoothed loop; rim jitter is damped.
- Walls are stacked faceted blocks with a warm→cool grade and a keel that tapers toward a point. Shaft rims flare open. A few hanging roots sit under the island.
- Grass gets hue/value patches, darker rims and tree contact, MultiMesh tufts/pebbles/flowers, and shore rocks. Dirt paths are a soft worn mix, not hard decals.
- Lakes use a depth/fresnel/foam shader (cull back so they are not a cyan box). A few lily disks sit on the water.
- Waterfall keeps the ribbon; foam is brighter and still-frame mist puffs sit at the plunge.
- Neon facility cubes are planters, a crate/jar, and stone lanterns.

## Tests

Recorded after this commit.

## Perf (llvmpipe, Godot 4.7, this VM — not target hardware)

Recorded after this commit. Do not treat these numbers as a Windows thin-laptop or MacBook Air result.

## Honest leftovers

Not art acceptance. Software GL (llvmpipe) + the play HUD are in every frame.

- The farming-diorama target is a hand-dressed Godot scene with authored lighting, dense hero props, lily pads, and real AO. This island is still a procedural heightfield with cheap stand-ins.
- seed7 walls are sculpted stacked blocks; ours are noise-offset rings. Closer than the flat slab, not a match.
- SSAO, PCSS-soft shadows, and bloom will read weaker on llvmpipe than on a hardware GPU.
- Lily pads are flat disks. Reeds are not modeled.
- Kit rocks stay off the walls.
- Only two of seven satellites fit the play telephoto unless `max_distance` is raised.
- Target-device 60 FPS is unmeasured.
