# Island style capture · 2026-10-02

Convex-hull CSG union after the shredded two-hull proxy was rejected. MultiMesh (shader clip, raised shore rocks, expanded grass, soil lip) is the default. A bake swaps in only when validation says it is closed except the grass cut.

Reproduce:

```sh
godot --path . --script tests/capture_island_style.gd --resolution 1280x720 --fixed-fps 60
godot --headless --path . --script tests/rockkit_bench.gd
```

| File | View |
| --- | --- |
| `grass_edge.png` | Close rim: grass / soil / solid rock cut |
| `underside_low.png` | Low side of the playable island |
| `large_island.png` | Expanded ~4× courtyard |
| `large_island_underside.png` | Expanded island, low side |
| `multi_island.png` | Main island plus seven satellites |
| `rockkit_bench.txt` | Piece / triangle / draw / bake / hitch |

PNG binaries stay local (`art/**` gitignore). Copies used for review are in the agent artifacts folder.

## What this pass does

Each kit piece is replaced by its convex hull (closed by construction). After paint settles, Godot CSG unions those hulls off-tree and subtracts a box above `y = 0`. CSG deadlocks on `WorkerThreadPool`, so the bake runs on the calling thread. The result is accepted only if `max_y ≤ 0` and every odd boundary edge sits on the grass cut (or the mesh is fully closed). Otherwise MultiMesh stays.

## VM sample (Godot 4.7.2, llvmpipe, not a target laptop)

| Scene | Pieces | Tris | Draw | Bake | Hitch (main-thread CSG + swap) |
| --- | --- | --- | --- | --- | --- |
| Playable ~130 cells, 1 island | 95 | 11344 | 1 | 422 ms | 428 ms |
| 4× area, 528 cells, 1 island | 180 | 21300 | 1 | 837 ms | 848 ms |
| Coast edit on the 4× island | — | — | — | respace 78 ms | full rebuild 150 ms |
| 4× + 7 satellites | 440 | 62098 | 8 | 829 ms (max) | 840 ms |

Hitch ≈ bake because Manifold CSG cannot run in a worker here. `flush_bakes()` used by the bench is synchronous. Headless GPU counters stay 0. This is not target-device evidence.

## Versus run #3 MultiMesh

Run #3 kept stacked kit instances (about 32k–129k tris, 10–64 rock draws, no bake hitch). It read as separate rocks, including interiors. This union is one closed shell per island, fewer tris/draws, and no sky holes. Hulls puff out concavities, so the mass is smoother and less “stacked kit” than run #3. Run #4’s two-hull proxy shredded the mesh and is not shipped.

## Honest remainders

- Convex hulls lose kit concavities. The underside is a faceted boulder, not the original overlapping stones.
- CSG reports some even-count coincident faces under a coarse edge key; those are not side holes. Validation rejects only an odd edge that is not on the grass cut.
- Bake hitch is 0.4–0.85 s on this VM after a settle. Painting still shows MultiMesh.
- Grass is still a flat cut with a short soil lip.
- Target-laptop 60 FPS is unmeasured. Software render is washed out.
