# Quaternius Standard comparison

Date: 2026-09-20. **Production recommendation: retain this five-model Quaternius sample for targeted material and ground-cover refinement.** It is a better visual starting point than the sampled Kenney models. It is not approved final art, a completed sandbox, or a target-hardware performance pass.

## Source and actual contents

Access was restored after the user adjusted connectivity. The free Standard archive was downloaded through the official itch.io free-download flow. No purchase, account registration, or paid Source edition was used.

- [Official pack page](https://quaternius.com/packs/stylizednaturemegakit.html) and [download page](https://quaternius.itch.io/stylized-nature-megakit).
- [Original archive manifest](../../../../source/third_party/quaternius_stylized_nature/2026-09-20/manifest.json): archive SHA-256, byte count, upload ID, edition, retrieval date, and selected files.
- [Enclosed license](../../../../source/third_party/quaternius_stylized_nature/2026-09-20/original/License_Standard.txt): Standard, CC0 1.0, 68/116 models. Counted **68 glTF files** in the actual archive. Promotional counts vary; they do not override the downloaded contents.
- The download page identifies upload 11055123, dated 2024-07-30 20:36 UTC. No semantic version is supplied in the enclosed license; do not invent one.
- The complete original archive and extraction remain in art/source. Five glTF files and their unmodified buffer/texture dependencies are copied into art/work/module_probe/quaternius. The paid engine projects and stylized shaders are not part of this trial.

## Sample

| Asset | Triangles | Materials | Purpose |
| --- | ---: | ---: | --- |
| CommonTree_1 | 6265 | 2 | Broadleaf tree variant |
| CommonTree_3 | 3505 | 2 | Narrower tree variant |
| Grass_Common_Short | 155 | 1 | Ground-cover sample |
| Rock_Medium_1 | 342 | 1 | Rock variant |
| Rock_Medium_2 | 244 | 1 | Rock variant |

[Model statistics and dependency hashes](assets.json). Textures include 2048px bark/normal/rock maps, a 1024px foliage map, and a 512px grass map. These are source dimensions, not a finalized runtime texture budget. Materials are imported as supplied; no custom foliage shader, wind, mesh reduction, or manual LOD was added.

## Same-layout comparison

The existing trial script now accepts a kit argument. Both packs use the same deterministic placements, equal target heights, cottage poses, prototype terrain/facilities, light, cameras, and 1280x720 viewport. Target heights remain trial parameters: trees 3.1/2.6m, grass 0.35m, rocks 0.65/0.45m. The model shapes and resulting crown widths differ.

| Layout | Quaternius overview | Quaternius near | Quaternius rotated | Kenney overview |
| --- | --- | --- | --- | --- |
| Sparse, with water | [image](sparse_overview.png) | [image](sparse_near.png) | [image](sparse_rotated.png) | [image](../kenney_comparison/sparse_overview.png) |
| Dense, with water | [image](dense_overview.png) | [image](dense_near.png) | [image](dense_rotated.png) | [image](../kenney_comparison/dense_overview.png) |
| Cottage relocated/rotated, dry | [image](relocated_dry_overview.png) | [image](relocated_dry_near.png) | [image](relocated_dry_rotated.png) | [image](../kenney_comparison/relocated_dry_overview.png) |

Nine Quaternius views were visually inspected. The natural branching and irregular tree crowns fit the cottage better than Kenney's spherical/block crowns. The muted green-gray rocks also fit better than the sampled Kenney orange rocks. Both packs still leave the prototype ground visibly empty.

Remaining issues:

- Fine leaf geometry and strong leaf-to-leaf shading produce noisy foliage at overview distance. Inspect material shading, silhouette preservation, filtering, and LOD before expanding the batch; do not assume the paid promotional shader is included.
- Grass is too sparse to establish convincing ground cover in this fixture. Evaluate small coherent clusters and terrain contact without filling every open area.
- The dense fixture still causes overlapping crowns, tree/rock intersections, and character/bridge occlusion. The current sampler only reserves broad house/path/bridge areas; it has no asset-to-asset footprint solver. These are layout-system limitations as well as art concerns.
- Static cottage relocation does not update the gameplay entrance. Trees/rocks have no new gameplay collision. The fixture pauses simulation and actor movement. Static images therefore do not prove placement usability, traversal, clicking, moving-camera stability, or procedural exploration.
- Existing cottage, Qinglan, sword, production markers, and ground were retained. The existing main scene was not replaced. The reference image does not prescribe any of these fixture positions or require water.

## Short rendering sample

Apple M4 Pro, macOS, Godot 4.7.2, Metal/Forward+, 1280x720, existing project shadow/MSAA settings. Vsync disabled for the trial window, no fixed-fps simulation. Each static overview warms up for 30 frames and records 180 chronological wall-clock process-frame intervals.

| Pack | Layout | Nature instances | Mean ms | P95 ms | Draw calls | Rendered primitives |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| kenney | sparse | 20 | 10.88 | 17.10 | 124 | 41820 |
| kenney | dense | 100 | 9.53 | 17.01 | 130 | 78780 |
| kenney | relocated_dry | 20 | 10.56 | 17.21 | 116 | 40485 |
| quaternius | sparse | 20 | 10.83 | 17.43 | 114 | 158712 |
| quaternius | dense | 100 | 11.11 | 17.22 | 118 | 663240 |
| quaternius | relocated_dry | 20 | 10.56 | 17.32 | 106 | 157377 |

[Quaternius summary](render_probe.json), [raw intervals](frame_intervals_ms.json), [successful run log](run.log); [Kenney summary](../kenney_comparison/render_probe.json), [raw intervals](../kenney_comparison/frame_intervals_ms.json), [successful run log](../kenney_comparison/run.log).

The Quaternius sample has 10511 source triangles per five-model set versus 770 for Kenney (about 13.7x). Whole-scene rendered primitive counts include more than this source sum, including render passes. Draw-call counts do not establish GPU cost. The short timing samples show strong approximately 8.3/16.7ms pacing and system variance; the dense Kenney run even averages less than sparse. Do not infer that denser scenes are faster, or that either pack is performance-equivalent. These are wall-clock intervals, not GPU timings. Low quality, MacBook Air, Windows thin laptops, live economy load, and long-session heat/power remain untested.

## Reproduction and next action

Run from the project root:

```sh
godot --path . --script art/work/module_probe/probe.gd --resolution 1280x720 -- --kit=quaternius
godot --path . --script art/work/module_probe/probe.gd --resolution 1280x720 -- --kit=kenney
```

The original Kenney evidence in the parent directory is preserved. New pack runs write to separate folders. The probe reads original assets through GLTFDocument because art/ is intentionally excluded from editor import. It does not write player saves.

Next: refine Quaternius foliage readability and small ground-cover clusters in this same module set, then validate moved-building entrances and natural-object footprints in a playable fixture. Keep functional, visual, and performance acceptance separate. No new Tripo submission is needed at this stage.
