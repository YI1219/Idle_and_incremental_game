# Island rock prototype — look pass (2026-10-02)

Standalone scene only. Same architecture: chunked terraced top, deferred rock dress, `HeightMapShape3D`.

## Perf (Godot 4.7.2, llvmpipe, this VM — not a laptop)

Mac numbers from the user for the previous build: stroke 25 ms, full rebuild 42 ms.

| Measure | This VM |
| --- | --- |
| Full rebuild | 94.53 ms |
| Stroke raise / lower | 46.59 ms / 45.84 ms |
| Deferred dress | 7.89 ms / 8.00 ms |
| Tris top / core / rocks | 4291 / 307 / 69878 |
| Rocks / draws | 187 / 8 |

Both brush strokes stay under 50 ms here. Full rebuild stays under 1 s. Do not read the VM sample as the Mac.

## What changed

- Earth skirt is one ribbon on the smoothed coast (0.14 m), and the top rock row is placed up against it.
- Coast loop is two Chaikin passes, one Catmull step, and a two-lobe wobble. Cells the curve crosses are clipped to that loop.
- Top rocks use the wide kit pieces, scaled short, with the long axis along the wall and only a small yaw.
- Four rings step inward. The core is a narrower cone ending in a short stalk, with a few tip icicles.
- Grass tint is smooth world-space noise, not a floor-hash checker.

## Honest read

The south close-up shows the brown band sitting on the top rocks, not floating in a dark recess. It is still a smooth bar, and from below the rim is broken: sky and grass show between the band and the rock tops. A few small ledges stick out of the upper faces.

The outline is rounder than the raw grid, and it is still faceted. Straight runs of the mask remain visible. It is not the main scene's coast.

The upper row is chunky blocks rather than tall pillars. Spacing is uneven and the rows step in, but the pieces still repeat and do not pile like the seed-7 mass.

The silhouette narrows to a short grey stalk. The lower half is more conical than the old bowl. The smooth core still reads through gaps between the lower rings.

Grass mottle is soft. A few rocks still break the grass edge.
