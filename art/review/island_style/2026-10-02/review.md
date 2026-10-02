# Island style capture · 2026-10-02

Rock-kit underside after the grass-cloth fix. The courtyard concept image remains look/mood reference only. Organic coast, 息壤 volume cost, and sloped pond banks are unchanged.

Reproduce:

```sh
godot --path . --script tests/capture_island_style.gd --resolution 1280x720 --fixed-fps 60
godot --headless --path . --script tests/rockkit_bench.gd
```

| File | View |
| --- | --- |
| `overview_play.png` | Default distance, play mode |
| `closeup_play.png` | Near distance, play mode |
| `overview_build.png` | Build mode |
| `closeup_build.png` | Near build mode |
| `grass_edge.png` | Close rim: grass / soil lip / rock cut |
| `underside_low.png` | Low side: baked rock-kit cliffs |
| `large_island.png` | Expanded ~4× courtyard |
| `large_island_underside.png` | Expanded island, low side |
| `multi_island.png` | Main island plus seven satellites |
| `rockkit_bench.txt` | Piece / triangle / draw / bake / hitch sample |

PNG binaries stay local (`art/**` gitignore). Copies used for review are in the agent artifacts folder.

## What this pass does

Shore rocks sit above the grass plane, then the shared rock shader discards `world_y > 0`. The grass top is expanded to the shore-rock XZ silhouette so the cut is covered. A 0.46 m inset ring carries a short grass→soil→rock lip. After paint settles (80 ms), `WorkerThreadPool` bakes a per-island union: clip to the grass plane, drop faces whose centroid sits inside two inset instance hulls, drop near-ground lids/undersides, no occlusion core. MultiMesh stays up while painting and if the bake fails.

## VM sample (Godot 4.7.2, llvmpipe, not a target laptop)

| Scene | Pieces | Tris | Draw | Bake / island | Hitch (swap) |
| --- | --- | --- | --- | --- | --- |
| Playable ~130 cells, 1 island | 95 | 4856 | 1 | 624 ms | 3.1 ms |
| 4× area, 528 cells, 1 island | 180 | 5428 | 1 | 1770 ms | 3.7 ms |
| Coast edit on the 4× island | — | — | — | respace 79 ms | full rebuild 152 ms |
| 4× + 7 satellites | 440 | 48133 | 8 | 1787 ms (max) | 4.7 ms |

Bake work is already split into 8 m XZ sectors inside the job; the number above is the whole-island total. `flush_bakes()` used by the bench runs the bake on the calling thread, so `process_ms` tracks bake time, not gameplay frame time. Headless `TIME_PROCESS` / GPU counters stay unreliable.

This is not target-device performance evidence. Software-renderer captures are paler than a discrete GPU.

## Honest remainders

- Grass is still a flat cut. The soil lip helps, but it does not look like weathered turf grown into the rock.
- The bake is not a manifold CSG union. Overlap interiors are a two-hull proxy. The playable underside still shows gaps and large kit faces; intersection curves are not sealed.
- Small satellite islands keep more triangles because they overlap less, so eight islands can exceed the 4× island’s triangle count.
- Rocks break the coastline in XZ only. Nothing sticks above the grass, so the “cliff top” read is the jagged grass outline, not protruding stones.
- llvmpipe washout. Target-laptop 60 FPS is unmeasured.
