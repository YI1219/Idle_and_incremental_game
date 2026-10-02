# Heightfield islands — visual fix 2026-10-02

Replaces the rock-kit CSG / profile-extruded underside with one procedural heightfield per island. This note is the visual pass on PR #2 after the glass-box review. Cloud sea, AgX, height fog, damped telephoto (`near` 1.2 m), and 息壤 stay from `cursor/island-volume-atmosphere-c7ad`.

## Cause of the glass boxes

Godot 4 front faces are clockwise. Tops authored with a right-hand *up* normal were backfaces from the play camera, so the slab was hollow from above and grassy only from below. Writing `ALPHA = 1.0` also put the mesh on the transparent pass, so far walls and interior edges showed through. The dark blue-grey “ground” was the underside / fog, not turf.

Fix: no `ALPHA` write, `cull_back`, clockwise winding (tops face the play camera), PR #1 moss/meadow turf from authored `world_n.y`. Old `_land_mesh` / `_cliff_mesh` stay hidden. Kit rocks stay off.

## How to reproduce

```
godot --headless --path . --script tests/heightfield_test.gd
godot --headless --path . --script tests/island_volume_test.gd
godot --path . --rendering-driver opengl3 --script tests/capture_heightfield.gd --resolution 1280x720 --fixed-fps 30
```

Capture locks `DongtianSpace` so the player does not walk into the explore gate (z ≈ 3.85). Lake / hole / building close-ups hide the cottage roof because it ate those frames.

## Tests

| Suite | Result | Notes |
| --- | --- | --- |
| `heightfield_test.gd` | 27/27 | added clockwise winding + organic mask never grows past play cells |
| `island_volume_test.gd` | 24/24 | hanging-body check allows a carved blob |
| `xirang_test.gd` | 16/16 | unchanged |
| `camera_test.gd` | 9/9 | unchanged |

## Perf (llvmpipe, Godot 4.7, this VM — not target hardware)

| Scene | Islands | Chunks | Tris | Draw calls | Top stroke | Full rebuild |
| --- | --- | --- | --- | --- | --- | --- |
| Playable courtyard | 1 | 6 | 1364 | 31 | 5.9 ms | 81 ms |
| 4× island | 1 | 12 | 4276 | 12 | — | 131 ms |
| 4× + 7 satellites | 8 | 40 | 6622 | 19 | — | 110 ms |

Triangle counts dropped versus the rectangular first pass because the blob carve removes corner cells. Far islands still pause + 2-step LOD. Do not treat these numbers as a Windows thin-laptop or MacBook Air result.

## Views (looked at before reporting)

- `overview.png` — play camera. Opaque green grass, solid strata walls, no see-through box. Coast is a rounded rectangle with a bitten south-east corner, not a hard square. River is still the old jade cut.
- `closeup_slope.png` — faceted hill, grass on flats, soil/rock on steep faces. Cottage roof still crowds the frame.
- `lake.png` — heightfield pit lake, organic teal outline, grass shore. Courtyard props sit in the water (not reseated). Cottage hidden for this frame.
- `hole_waterfall.png` — west rim after a dig-through stroke. Reads as a cliff bite, not a clear shaft. Waterfall is easy to miss from above.
- `placed_building.png` — trees on green land next to the pit. Flatten pad is subtle.
- `low_side.png` — solid rock wall, strata bands, grass lip. Not glass.
- `underside.png` — same solid wall from below; tops no longer show green through the slab. Waterfall is a tall teal quad. No kit rocks hanging under `y_bottom`.
- `large_island.png` — 4× blob is a clear oval of green grass.
- `multi_island.png` — same oval plus two visible satellite pads (the other five sit outside a 34° telephoto). Satellites are small rounded platforms, not dark cubes.

## Honest leftovers

Not art acceptance. Software GL (llvmpipe) + the play HUD are in every frame.

- Default starter is a *rounded rectangle*, not a freeform pebble. The 4× blob is the better organic demo.
- River cells still `skip_top` onto the old jade-water mesh. Interior heightfield lakes work; the courtyard river is a separate cut.
- Waterfall v1 is a single quad + foam/mist particles. From the side it reads as a teal slab. Foam/mist do not show on a still.
- Dig-through from the play camera is a rim notch more than a vertical hole. Underside does not currently frame the shaft.
- Kit rocks are disabled. Previous scatter hung under the slab.
- Flatten-on-place is real but hard to see on already-flat turf.
- Lake / hole / building shots hide the cottage. Overview / large / multi keep it.
- Cloud sea is still low-poly puff hexagons in a fogged gray void.
- 4× full rebuild ~130 ms on this VM. Fine for stroke-end; drag still updates tops only.
