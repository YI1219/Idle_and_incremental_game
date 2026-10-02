# Island rock prototype (2026-10-02)

Standalone scene `scenes/proto/island_proto.tscn`. The play scene is not rewired. Source of truth is `scripts/world/heightfield.gd` on the courtyard yard cells, with the same starter hills, lake brushes, and one punched shaft.

PNGs in this folder are local review shots. `art/**` binaries are gitignored. The draft PR carries the same four frames.

## Reproduce

```
godot --headless --path . --script tests/island_proto_bench.gd
godot --path . --rendering-driver opengl3 --script tests/capture_island_proto.gd --resolution 1280x720 --fixed-fps 30
```

## Perf (Godot 4.7.2, llvmpipe, this VM — not a laptop)

| Measure | Result |
| --- | --- |
| Full rebuild | 56.40 ms |
| Stroke raise (dirty chunks + heightmap shape) | 37.15 ms |
| Stroke lower | 37.06 ms |
| Deferred rock/core dress | 2.98 ms / 2.92 ms |
| Land cells / chunks | 435 / 4 |
| Tris top / core / rocks / total | 4548 / 324 / 41452 / 46324 |
| Rock instances / draws | 119 / 9 |
| Coast loops | 1 outer (192 pts after one Chaikin), 1 hole (40 pts) |

Stroke stays under 50 ms and the full rebuild stays under 1 s on this machine. These are not Windows thin-laptop or MacBook Air numbers.

## Read of the shots

The grass top is a pale disk with a stepped lake and a dug hole. The wall is warm brown on the upper two-thirds and cool grey underneath. The lower band is irregular faceted rock, with one hanging tip under the belly. There is no wide pale base.

The upper row does not read as stacked chunky boulders. It is a repeating colonnade of upright KayKit blocks. A dark gap sits between the grass lip and that row on the low side. From below the cap, thin brown pieces sit off the silhouette (rock corners and the earth lip clearing the grass). That is not the seed-7 reference.

## Licenses

`scripts/proto/CREDITS.md`. Yūgen and Flylands ideas are reimplemented (MIT). Meshes are the existing CC0 KayKit Forest Nature Pack and Quaternius Stylized Nature MegaKit copies under `assets/rockkit/`. Kenney was not fetched. No second copy of the meshes.
