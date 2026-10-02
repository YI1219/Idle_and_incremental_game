# Heightfield islands — seed7 kit underside (run 6) 2026-10-02

Same branch / PR #2. Five shader/scatter patches did not converge, so this run replaces the visible island shape and underside. Gameplay brushes, volume cost, dig-through, lakes, and auto-flatten stay frozen. No CSG/boolean (PR #1 hitch). Primary style bible is the KayKit Forest + Quaternius MegaKit kit in `assets/rockkit/` and the Blender seed7 prototype. Ideas only from 《我有一片田》 — no code copied.

## How to reproduce

```
godot --headless --path . --script tests/heightfield_test.gd
godot --headless --path . --script tests/island_volume_test.gd
godot --headless --path . --script tests/terrain_test.gd
godot --headless --path . --script tests/rockkit_test.gd
godot --path . --rendering-driver opengl3 --script tests/sandbox_land_test.gd --resolution 1280x720 --fixed-fps 30
godot --path . --rendering-driver opengl3 --script tests/capture_heightfield.gd --resolution 1280x720 --fixed-fps 30
```

Capture locks `DongtianSpace`. Lake / low-side / 3/4 hide the cottage.

## What changed

- Coast is a blurred land-mask SDF → interpolated marching squares → Chaikin/Catmull → low-frequency wobble only. Rim verts snap to that contour and grow a little so the grass plate covers rock tops. Gameplay H/M stay on the grid.
- Rounded grass shoulder + brown earth lip along the contour (`build_slab`). Hidden inward core + grid walls stay behind the kit so gaps do not show sky.
- Underside is seed7 rule-based MultiMesh kit rocks (`rock_underside.gd` ring table from `rockkit_island.py`): overlapping rim, tapering mid rings, tip cluster, hanging roots. Slot identity `(ring, slot)`. Shrink respaces; floating leftovers are dropped. No CSG.
- Palette reset to seed7: grass `#9cbf7a` / `#9db985`, earth `#9a7656`, rock warm→cool, sky `#dde8ee`. No emission. Ambient 0.26, sun 1.35 with soft angular shadows.
- Lake uses the same SDF path, sloped earth bank, fan-tessellated teal water, a few sitting kit rocks.
- Fewer clumpier grass tufts (284 on the courtyard). Sparse flowers.

Out of scope: waterfall/shaft visuals, new props.

## Tests

| Suite | Result | Notes |
| --- | --- | --- |
| `heightfield_test.gd` | 38/38 | closed mesh / winding hold after SDF rim snap |
| `island_volume_test.gd` | 24/24 | cache key is land only; H unchanged |
| `terrain_test.gd` | 795/795 | brush math unchanged |
| `rockkit_test.gd` | 24/24 | seed7 snap, no-float-after-shrink, grow keeps sculpt |
| `sandbox_land_test.gd` | 59 checks, 0 failures | process aborted on Godot quit (llvmpipe); no failed asserts |

## Perf (llvmpipe, Godot 4.7, this VM — not target hardware)

| Scene | Islands | Chunks | Tris | Draws | Stroke | Rebuild | Kit instances | Kit tris | Tufts |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Playable courtyard | 1 | 6 | 29321 | 27 | 45.0 ms | 122 ms | 78 | 27097 | 284 |
| 4× island | 1 | 12 | 54703 | 29 | — | 301 ms | 139 | 48527 | 749 |
| 4× + 7 satellites | 8 | 40 | 150632 | 142 | — | 298 ms | 411 | 139768 | 1310 |

Seed7 Blender prototype is ~74 instances / ~22k tris. Playable is in that band (78 / 27k). Stroke stays ~45 ms on this software GL box. Rebuild is faster than run 5 (122 vs 210 ms) even with kit MultiMeshes. User Mac (M4 Pro, Metal Forward+) measured ~155 fps uncapped on run 4 — do not treat these llvmpipe numbers as a thin-laptop result.

## Views (inspected before reporting)

- `overview.png` — play camera. Fresh soft green, organic blob, teal pond, sparse tufts. A chunky dark rock crust still reads around the grass disc (seed7 overview hides that under the lip).
- `low_side.png` — kit underside. Faceted KayKit/Quaternius blocks, overlapping, warm tan. This is the first shot that actually looks like seed7_side. Mid/tip rings and the cool-grey keel do not read; the rim is a cliff wall over a dark void.
- `seed7_three_quarter.png` — whole-island side from slightly below. Same kit wall. Cloud sea shows as a pale disc behind the core.
- `lake.png` — rounded teal basin, thin earth edge, a few bank stones. Fan triangles still facet a little. Not neon, not run-5 grey-green.
- `multi_island.png` — organic blobs, kit rims on every island, fresh green tops.
- `overview_compare_run5_run6.png` — left olive rectangle + stubble; right fresher green blob + kit crust + teal water.

## Honest leftovers vs seed7

Not art acceptance. Software GL + play HUD are in every frame.

- **Play-camera halo.** seed7 overview is a clean green plate with a thin brown lip. Ours still shows a dark rocky crust from 50°. Grass grow-out helps but 2 m kit tops still peek.
- **No stacked taper.** seed7_side shows four interleaved rings plus a tip, warm brown → cool grey. We place those rings; from the side the rim wall hides them. The keel is a dark hole, not a cool-grey stalactite cluster. The KayKit column tip can still read as a drill bit when it does show.
- **Rock colour is flat tan.** The world-Y gradient exists in `island_rock.gdshader` and does not read on the upper 2 m that the camera sees. seed7's toon ramp is also stronger.
- **Earth lip is thin.** Visible on the lake; easy to miss on the outer coast from the play camera.
- **Grass is still card clumps**, not a dense meadow. 284 tufts on the courtyard is "fewer/nicer" as asked, not seed7's bare plate and not yipiantian's 30/m².
- **Water is calmer teal** but still a polygonal fan, not a shader disc with a wet sand shelf.
- **Clouds from below** are a hard pale plate. Radial fade was built for the play camera looking down.
- Boxy KayKit trapezoids (Rock_2_*) repeat on the near cliff — seed7's README already calls this out.
- Target-device 60 FPS is unmeasured here.
