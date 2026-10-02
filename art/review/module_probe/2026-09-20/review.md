# Kenney minimal-module physical trial

Date: 2026-09-20. **Production judgment: these five models, under current import and lighting, are not selected as official nature art.** This is candidate screening, not user aesthetic acceptance, and not full sandbox-function or performance acceptance.

## Source and version

The [official asset page](https://kenney.nl/assets/nature-kit) and the pack's License.txt both mark CC0, usable for personal, educational, and commercial projects. The page changelog says 1.0; the pack license says Nature Kit 2.1. Record that difference; do not guess a release date. Original archive and full extract are kept in `art/source/third_party/kenney_nature_kit/2026-09-20/`, [source manifest and summary](../../../source/third_party/kenney_nature_kit/2026-09-20/manifest.json). No payment.

From the same pack: tree_oak, tree_detailed, grass, rock_smallA, rock_smallB, at 196, 402, 132, 16, 24 triangles. No image textures; original materials used. See [physical stats](assets.json). Originals and trial copies match; meshes were not edited. Trial instances only uniform-scaled to target height, grounded, and rotated. Do not automatically add that scaling ability to the game.

## Trial and observations

Reused the main scene's cottage, character, sword, ground, facilities, and lights; paused gameplay and transition updates; added an independent camera. Nature assets used the same PackedScene source, instanced repeatedly. No hand MultiMesh/LOD optimization. A fixed seed only makes the trial repeatable; **it does not mean exploration procedural generation is implemented**.

| Layout | Nature instances | Top-down | Near | Rotated |
| --- | ---: | --- | --- | --- |
| Sparse with water | 20 | [image](sparse_overview.png) | [image](sparse_near.png) | [image](sparse_rotated.png) |
| Dense with water | 100 | [image](dense_overview.png) | [image](dense_near.png) | [image](dense_rotated.png) |
| House relocated and rotated 90°, no water | 20 | [image](relocated_dry_overview.png) | [image](relocated_dry_near.png) | [image](relocated_dry_rotated.png) |

Nine images inspected:

- Both broadleaf crowns read as ball/block masses, lacking soft leaf-cluster layers, still clearly apart from the cottage's curved eaves and flowing direction. Simply adding count does not improve this.
- Default trunks and rocks lean orange; green crowns lean bright cyan; the assets outshine the cottage. Palette can be corrected later, but this round's geometric silhouettes already should not pass directly.
- Grass clusters are too weak in top-down to improve large flat ground; rock forms are very simplified. Character and facilities are occluded in near views by crowns in front.
- Dense images show obvious repetition, overlapping crowns, and some tree–rock intersections. Trial placement only avoided house bounds, the central path, and the bridge; it did not implement footprint checks between assets. Problems include placement, not all model quality.
- After rotation, the cottage and main modules still read, but some backlit faces show dotted shadows that need import and shadow-setting investigation; this round did not fix them. A no-water layout rendering does not mean ground art is done.

The cottage, when moved in the trial, did not update doorway state; nature objects had no collision. This round does not treat static empty space as actual traversal acceptance, and did not complete player movement, clicking, continuous camera orbit, or full seam coverage. Traversal of the current main play is rechecked by the original tests separately.

## Render-sampling boundary

Dev machine Apple M4 Pro, macOS, Godot 4.7.2, Metal/Forward+, 1280×720, project's existing shadow and MSAA settings; only the trial window disabled vsync. Same lights and render config. Static top-down: 30 warmup frames, then 180 actual display-loop intervals. **Did not use fixed-fps simulated performance.**

| Layout | Mean interval ms | P95 ms | Max ms | Draw calls | Render primitives (engine count) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Sparse | 11.44 | 17.37 | 17.95 | 124 | 41820 |
| Dense | 11.48 | 17.50 | 18.03 | 130 | 78780 |
| Relocated dry | 11.67 | 17.46 | 19.11 | 116 | 40485 |

[Raw summary](render_probe.json). These are main-loop wall-clock intervals, including OS scheduling/present effects, not GPU render time. Sampling is short; do not set budgets from this or claim stable 60 FPS. Raw per-frame sequences were not saved, so other percentiles cannot be recomputed. Did not test low-quality tier, normal economy load, target Windows thin laptop / MacBook Air, or long-session power/heat. This only establishes a candidate render baseline in the same environment.

Reproduce: from the project root, run `godot --path . --script art/work/module_probe/probe.gd --resolution 1280x720`. Trial code is in art/work, not wired to the main entry, and does not write player saves. Rerunning updates this directory's screenshots and render summary. Official screenshots/data only take the last zero-error run; see [run log](../../handoff/2026-09-20/module_probe.log).

The Quaternius Standard follow-up is now complete: see the [same-layout comparison](quaternius/review.md). It is the preferred refinement candidate; this Kenney sample remains unselected. No new tree, grass, or rock Tripo task is needed.
