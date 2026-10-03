# Island rock prototype — stacked underside (2026-10-03)

Standalone scene only. Screenshots are the clean courtyard island (435 land cells) before the bench strokes.

## Perf (Godot 4.7.2, llvmpipe, this VM — not a laptop)

Previous build on this VM: full 94.53 ms, raise/lower 46.59 / 45.84 ms, rocks 187, rock tris 69878, draws 8. Mac numbers the user reported for that build: stroke 25 ms, full 42 ms. Do not read this VM as that machine.

| Measure | This VM |
| --- | --- |
| Full rebuild | 57.01 ms |
| Stroke raise / lower / rim | 22.97 / 19.26 / 16.29 ms |
| Add-land inside the grid | 25.38 ms (435 → 438 cells) |
| Add-land that resizes the grid | 51.31 ms (438 → 461 cells) |
| Deferred dress | about 6–11 ms |
| Tris top / core / rocks | 4599 / 279 / 39408 (after the strokes) |
| Rocks / draws | 129 / 6 |

Height strokes and an in-grid land stroke stay under 30 ms. A stroke that grows the allocated grid still remeshes the whole top, about 51 ms. Full rebuild stays under 80 ms. Rock tris stay under 40k. Draw calls are one top, one core, and the kit MultiMeshes.

## What changed

- Underside is a seeded stack: full yaw, overlap spacing, inward tilt, per-slot scale. Slot hash is the island seed plus ring and index.
- No tip stalk. The bottom is a squat cluster plus four short hangers. The core ends in a flat cap inside that cluster.
- Lip rocks snap their highest vertex just under the grass. If that top crosses a lower terrace, the rock slides outward instead of dropping the whole piece and opening the lip.
- Coast skirt is 0.36 m so a small tilt still meets the earth band.
- Rocks are one MultiMesh per kit piece. A brush restamps only the coast segment it touches. A mask edit that stays inside the grid reblurs that neighbourhood and patches those cells.
- `add_land` stamps a disk of the brush radius. The old cutoff (`weight * strength >= 0.35`) left coast strokes at 435 cells.

## Honest read versus seed 7

The side reads as a warm, faceted rock mass that narrows downward, not as a colonnade. The pieces are packed tighter than the Eevee study, so individual boulders fuse more, and this VM's lighting is softer than that render.

The long pointed stalk is gone. The bottom is a short grey cluster, still more tapered than a round knob, with a dark core notch on the lower left and a small crevice in the middle when viewed straight up.

The south close-up still has a thin gap between the earth band and the rock tops. From a three-quarter view the rocks meet the lip. A few rocks still break the grass rim, mostly around the shaft and one spike on the east terrace. The grass surface itself stays the terraced top.
