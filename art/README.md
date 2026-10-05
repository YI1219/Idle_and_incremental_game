# Current asset status
Updated: 2026-10-06. The user has returned to the [3D pipeline with non-pixel guofeng rendering](../docs/art/three_d_art_direction.md), using 尘之回声 as a presentation reference. Directional 2D character and Spine production are stopped; concept images remain reference evidence. Overall art is unaccepted.

The active priority is the editable floating-island workshop, with fidelity to the latest user image taking precedence over the earlier function/performance-first acceptance. [Current terrain renders and evidence](review/terrain_fidelity/2026-10-05/review.md) are actual Godot screenshots and remain visually unaccepted. The workshop reuses the refined cottage and selected Kenney CC0 sources, with derived runtime materials, 17-part irregular canopies with unequal core/rim clusters, contour-generated terrain and automatic surface detail. Broad cliff spans now have closer physical samples and stronger faceted rock shoulders, with a shared palette for retained embedded stones. Wet mouth-side rock relief stays behind the waterfalls. Deep scallops and pointed lower projections still differ from the reference. Waterfalls now have shallow physical folds, softer translucent streams and quieter veins, with separate opaque pond shading. The latest cottage shading uses its retained material roles for warm wall/gable panels and stable object-space post projection; originals and model geometry remain unchanged. Bench and lantern remain placeholders. The workshop sky now uses a generated cloud-only bitmap, with [prompt and source record](source/skies/2026-10-05/cloud_backdrop_v01.json); runtime mipmaps and gentler cloud/cyan shading soften its sharp detail while preserving the original bitmap/import and neutral lighting. Terrain and props remain interactive 3D geometry. This does not lock future courtyard layouts to the reference composition.

Existing Qinglan v06, its sources and ten animations remain intact; character/garment/animation refinement is deferred. Earlier courtyard, sandbox and land studies are historical evidence for the retained legacy scene. The active terrain workshop replaces that scene as the demo entry point without deleting original assets or the legacy playable scenes.

## Integrated candidates

| Asset | Runtime file | Source and status | Remaining |
| --- | --- | --- | --- |
| Qinglan | [qinglan_garment_v06.glb](../assets/characters/qinglan/qinglan_garment_v06.glb) | Preserved Tripo/Quaternius sources and ten original clips; v05 textiles, restored knee trousers/calves, controlled sleeve/cuff/hem/ribbon secondary motion. Gentle jog and CMU turns retained; fresh functional/preservation checks pass | Residual robe/leg/inner-layer intersections, angular cuff faces and folded hems; visual acceptance incomplete. Grip, shoulder/toe articulation and final expression remain open |
| Starter sword | [starter_jian.glb](../assets/weapons/sword/starter_jian.glb) | User Tripo original 993 triangles, refined 1068; three-color materials; right-hand bound, runtime length about 0.72 m | Finger grip and full-action review; not final animation acceptance |
| Cottage | [cottage_tripo.glb](../assets/buildings/cottage/cottage_tripo.glb) | Both untextured and textured originals received; refined 2966 triangles, doorway about 1.608 × 1.829 m; traversal and indoor transition integrated | Open wall shells and non-manifold edges remain; overall materials and scene pairing await acceptance |

Sword and cottage now do not need the user to generate again. Runtime assets existing and function integration do not mean final art passed.

## Source and refinement records

- Qinglan: [original manifest](source/qinglan/manifest.json), [preserved Blender source](work/qinglan/qinglan_candidate.blend), [preserved template work file](work/qinglan/qinglan_template_v03.blend), [clothing v04](work/qinglan/qinglan_clothed_v04.blend), [running/clothing review](review/running_cloth/review.md), [fabric v05 work file](work/qinglan/qinglan_fabric_v05.blend), [gait/turn review](review/gait_v05/review.md), [v06 work file](work/qinglan/qinglan_garment_v06.blend), [current garment/secondary-motion review](review/garment_v06/review.md), [CMU turn provenance and exact terms](source/third_party/cmu_turns/README.md).
- Sword: [originals and input manifest](source/sword/2026-09-20/manifest.json), [refinement file](work/sword/sword_candidate.blend), [refinement report](review/sword/refinement_report.json), [action review](review/sword/runtime/review.md).
- Cottage: [input and original manifest](source/cottage/2026-09-20/manifest.json), [refinement file](work/cottage/cottage_tripo_candidate.blend), [refinement report](review/cottage/tripo_v01/refinement.json).
- `source` keeps inputs and originals, `work` keeps editable files, `review` keeps stage evidence, the game uses `../assets`. Reports describe the version at that time and do not automatically represent current status.

## Prototypes and next steps

Rivers have 47-state connection logic. Existing procedural terrain, bridge, facilities, and the practice dummy are still gameplay-prototype looks. Runtime capability may be kept, but they are not the final look. 47 states does not mean 47 independent models must be generated.

Old `cottage_demo.blend` / `cottage_demo.glb` and direct-modeling scripts are history only. The running scene uses `cottage_tripo.glb`. Old Cursor scripts and `work/demo` backups are not new tasks or official production entries.

Unsuitable nature-asset four-views and their generation lists have been deleted. Pines are not a prerequisite for the next stage. Evaluate [complete free packs](../docs/art/free_asset_candidates.md) across multiple layouts; do not copy the concept-image landscape.

Kenney Nature Kit (enclosed version 2.1) and Quaternius Stylized Nature MegaKit Standard (68 glTF models) have now been downloaded, with enclosed CC0 licenses checked and originals retained. Five models from each were tested in three static layouts and three camera views. [Quaternius comparison and source links](review/module_probe/2026-09-20/quaternius/review.md). Eight unchanged Quaternius models are now integrated in the default courtyard with grouped planting, shared foliage/wind, ground contact, water, cottage and sky material refinement. [Environment review](review/visual_refinement/2026-09-20/review.md) includes two layouts at three cameras and source provenance. The earlier comparison samples remain in art/work/module_probe. Final foliage detail, placement acceptance, and target-device performance are still pending.

## Acceptance boundary

The current [human-template replacement](review/animation_template/review.md) records fresh animation, demo, sword and fixed-step space checks, 90 re-imported poses, and byte-identical retained geometry/skinning. The previous procedural body-motion pass was rejected. The later [running/clothing pass](review/running_cloth/review.md) preserves those animation tracks while refining garment deformation and running turns. The [gait/turn/fabric pass](review/gait_v05/review.md) adds separate contextual gaits and captured stepping transitions, with fabric/waist refinement. The current [garment v06 pass](review/garment_v06/review.md) restores knee-length trousers and original calf surfaces, adds garment-only secondary motion and preserves the human tracks. All ten functional test scripts pass, but visual cloth/intersection acceptance remains incomplete. The result remains a visual candidate; target-device performance has not been measured.

The 2026-09-20 [handoff inspection](review/handoff/2026-09-20/review.md) records newly run functional checks and the high-frame-rate transition-test sampling boundary. Later changes still require relevant reruns. The character is not intersection-free in every pose. The cottage is not a closed solid. Short development-machine static render samples do not establish target thin-laptop performance.

Later tasks and manual-operation notes are only in [Generation tasks](generation_tasks.md). There are currently no tasks to submit.
