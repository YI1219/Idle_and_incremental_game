# Heightfield islands — 2026-10-02

Replaces the rock-kit CSG / profile-extruded underside with one procedural heightfield per island. Cloud sea, AgX, height fog, damped telephoto, and 息壤 ledger stay from `cursor/island-volume-atmosphere-c7ad`.

## How to reproduce

```
godot --headless --path . --script tests/heightfield_test.gd
godot --path . --script tests/capture_heightfield.gd --resolution 1280x720 --fixed-fps 60
```

## Views

- `overview.png` — playable courtyard
- `closeup_slope.png` — raised grass / soil / rock
- `lake.png` — pit lake
- `hole_waterfall.png` — dig-through + fall
- `placed_building.png` — auto-flattened footprint
- `underside.png` — flat bottom in the cloud sea
- `large_island.png` / `multi_island.png` — 4x and satellites

## Honest leftovers

Recorded after the capture run. Do not treat these images as art acceptance.
