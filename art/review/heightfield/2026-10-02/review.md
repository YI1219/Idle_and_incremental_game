# Heightfield islands — 2026-10-02

Replaces the rock-kit CSG / profile-extruded underside with one procedural heightfield per island. Cloud sea, AgX, height fog, damped telephoto (`near` 1.2 m), and 息壤 ledger stay from `cursor/island-volume-atmosphere-c7ad`.

Base the PR on that branch (not `main`) so the diff is the heightfield swap, not the whole cloud-sea stack.

## How to reproduce

```
godot --headless --path . --script tests/heightfield_test.gd
godot --path . --script tests/capture_heightfield.gd --resolution 1280x720 --fixed-fps 30
```

## Tests

| Suite | Result | Notes |
| --- | --- | --- |
| `heightfield_test.gd` | 21/21 | volume, cracks, dig-through closed mesh, water spill, flatten, determinism |
| `island_volume_test.gd` | 24/24 | rewritten for heightfield volume / LOD; CSG presence checks removed |
| `xirang_test.gd` | 16/16 | includes `quote_volume` / `quote_remove_volume` |
| `camera_test.gd` | 9/9 | added raised near-plane check |
| `terrain_test.gd` | 794/794 | play-grid authority unchanged |
| `rockkit_test.gd` | 23/23 | kit/baker unit tests still run; they no longer drive the live island |
| `sandbox_land` / `layout` / `runtime` | 60 / 17 / 35 | checks passed; Godot still aborts 134 on two headless exits |

`island_presence.gd` / `rock_baker.gd` / `rock_underside.gd` remain in tree for kit tests only. Live courtyard uses `IslandHeightfield`.

## Perf (llvmpipe, Godot 4.7, this VM — not target hardware)

| Scene | Islands | Chunks | Tris | Draw calls | Top stroke | Full rebuild |
| --- | --- | --- | --- | --- | --- | --- |
| Playable courtyard | 1 | 6 | 2552 | 23 | 4.8–5.2 ms | 38–40 ms |
| 4× island | 1 | 12 | 9432 | 15 | — | 101–106 ms |
| 4× + 7 satellites | 8 | 26 | 12224 | 22 | — | 101–106 ms |

Stroke is a main-thread top-only `16×16` rebuild of the dirty field. Full rebuild includes walls, bottom, water, and rock scatter. Far islands pause (`PROCESS_MODE_DISABLED`) and emit a 2-step LOD mesh. Do not treat these numbers as a Windows thin-laptop or MacBook Air result.

## Views

- `overview.png` — playable courtyard, organic coast, river still a cut
- `closeup_slope.png` — faceted ground / kit rocks (capture often lands under the cottage eaves)
- `lake.png` — pit water on the heightfield
- `hole_waterfall.png` — dig-through shaft; waterfall is a thin teal ribbon
- `placed_building.png` — trees seated on the field (flatten ramp is subtle on already-flat land)
- `underside.png` — flat bottom, vertical hole, grass rim, wall rocks
- `large_island.png` / `multi_island.png` — 4× and seven satellites

## Honest leftovers

Not art acceptance. Software GL (llvmpipe) + the play HUD are in every frame.

- Grass reads gray-olive from above; the lime rim only pops in the underside view. Slope → soil → rock is in the shader and vertex colors, but a flat courtyard barely exercises it. Steep faces no longer get per-triangle Voronoi push (that split rim edges and failed the closed-mesh test); chunky rock is shader-side only.
- Cloud sea from PR #1 is present as low-poly puff hexagons in a fogged gray void. The billow sheet does not read as a sea on this renderer.
- Waterfall v1 is a single ribbon plus a few particles. Easy to miss. Drain sites are capped at 8.
- Kit rocks on steep faces are too large; several hang under the slab instead of sitting 30–50% in the wall.
- Default islands are almost flat boxes. Satellites look like Minecraft cubes until someone sculpts them.
- Capture cameras fight `DongtianSpace` / the play rig. Several “close” shots still clip the cottage or look down a hole from the eaves. Underside / overview / multi are the trustworthy ones.
- `skip_top` on river cells keeps the old jade-water mesh; interior river is not a heightfield lake.
- 4× full rebuild sits around 100 ms on this VM. Fine for stroke-end, not for every paint tick; drag already updates tops only.
