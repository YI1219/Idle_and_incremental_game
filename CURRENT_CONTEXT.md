# Current project consensus and handoff entry
Updated: 2026-09-21. This file is the current goals, production priority, and handoff entry. Later explicit user requests take precedence. Obsolete notes, plans, and concept drafts have been deleted. Valid review reports remain as implementation evidence only. Implementation status must still be judged from code, runtime assets, and actual inspection.

## Product and current priority

This is an ancient-style xianxia idle incremental game with sandbox building. Resource production, management, long-term growth, and exploration are the core; combat serves exploration and must not expand the project into an action-combat game. Keep the existing economy kernel and playable demo; do not rebuild from scratch.

The user has returned to a 3D production pipeline, referencing 尘之回声 (DustEcho) for the desired presentation but explicitly rejecting pixelated rendering in favor of a non-pixel ancient-Chinese palette and stylized finish. Stop 2D directional-character and Spine production. Current priority is SANDBOX BUILDING FUNCTIONALITY, ahead of further static scene/art refinement. The first placement/move/remove/save/load loop is now integrated into the playable courtyard. Character modeling, garment and combat-animation work remain deferred; keep existing characters for traversal and scale. Preserve the independent art study as a secondary reference; do not resume expensive garment refinement or rebuild all assets. Preserve gameplay, modular courtyard requirements and performance validation. See [3D art direction](docs/art/three_d_art_direction.md).

## Three scene types and sandbox premises

The user explicitly distinguishes three scene types: the Sea of Consciousness Courtyard, the village, and exploration scenes. They share a unified art style and reusable assets, but must not be mixed into a single courtyard map.

| Scene | Confirmed direction | Current design boundary |
| --- | --- | --- |
| Sea of Consciousness Courtyard | Sandbox building; terrain, buildings, facilities, and landscape are designed for placement and combination | Art must not depend on preset coordinates, specific neighbors, or a unique camera |
| Village | A scene type independent of the courtyard, keeping an ancient-style settlement look | Player remodeling scope and village generation are not yet decided; do not assume it is fully editable or fully fixed |
| Exploration scenes | Designed toward procedural generation, using combinable terrain, vegetation, resource, and event modules | Exact algorithm, map scale, and whether a visit resets are not yet decided; the existing exploration demo is not completed procedural generation |

Sandbox placement is not unconstrained: existing footprint, traversal, and resource rules still apply. Whether every type may be freely rotated, scaled, or stacked is not confirmed; do not add those abilities automatically. Art should first stay coherent when objects are placed independently, rotated in allowed directions, and given new neighbors.

## Art judgment baseline

Current presentation reference: [DustEcho developer rendering/combat demo](https://www.bilibili.com/video/BV1XuorB2E1P/). Its public description identifies a top-down 3D game with pixelated rendering. Only that description has been verified here, not a frame-by-frame visual analysis or its shader implementation. The user wants comparable overall presentation with non-pixel guofeng rendering; do not infer adoption of its ARPG scope.

The user also approves [墨境 / Realm of Ink](https://store.steampowered.com/app/2597080/Realm_of_Ink/?l=schinese) as a reference for combat presentation, character motion, and art style. Future observation should cover pose transitions, attack movement, timing and feedback, and ink-inspired color/readability. This records the user’s preference, not completed footage analysis or a decision to copy its rendering pipeline. Sandbox building remains the priority; character/combat production stays deferred.

Keep lessons from the 2D concept exploration: small head, slender adult silhouette, graceful and dashing demeanor, minimal facial detail and restrained blue-gray/ivory/cyan palette. The user liked the poetic style but rejected cute proportions, grounded repetitive martial poses and unnatural hovering. These images remain references, not new sprite/Spine production tasks. Footwear permission was specific to the 2D trial; do not silently change existing 3D knee-trouser/barefoot sources.

The user finds the look of the [courtyard concept image](art/source/visual_targets/2026-09-20/courtyard_user_target.png) usable. It is a reference for color, materials, atmosphere, and finish only — not a layout, asset list, terrain, or landscape reproduction requirement, and not the only style source.

Additional art references from the user: Spark in the Dark: Automated Adventure, Craftopia, Wildmender, V Rising, The Magistrate, and Mountain Gate & Illusion. Distill a unified ancient-style look from these references; do not paste together each game's different scale, materials, and subject matter. Official links and observation notes are in [Scene art and module spec](docs/art/scene_art_and_module_spec.md).

- Ancient-style pairing, natural space, flowing silhouettes, and overall finish matter most; pine trees are not required assets.
- Large color masses, abstraction, and beauty mean summarized silhouettes, coordinated palettes, and clear hierarchy. Moderate material variation, leaf clusters, moss, and ground detail are allowed; do not reduce this to empty lots, flat color planes, and scattered primitives.
- Vegetation, rocks, paths, water, bridges, and distant views are optional combinable elements; not every courtyard must have all of them. Sparse, open layouts must also work. Unify module scale, palette, materials, and lighting so both player layouts and procedural layouts look natural. Default top-down readability is required; near-zoom should still hold together.
- GRIS, Journey, and Sky are atmosphere and finish references; keep this project's ancient-style language and do not copy desert forms.
- The character has black hair, a natural warm skin tone, white knee-length trousers, and simple cloth shoes allowed for the new 2D version (preserved 3D sources retain bare feet); blue-gray outer robe, ivory inner lining, and a restrained cyan sash and ribbons. Cuffs, hems, and motion must stay flexible and flowing; check intersections.
- The cottage keeps a blue-gray curved dual-pitch roof, ivory walls, simplified timber, and a small window, with no door curtain. The character must actually pass through the doorway.

## Asset pipeline

Use 3D characters, skeletal animation and spatial scene modules as the main pipeline. Rendering targets non-pixel stylization with a unified ancient-Chinese palette; this is not a return to realistic material detail. Conventional 2D textures, particles, UI and concept art remain useful. Stop the mandatory camera-facing 2D/four-direction character and Spine approach.

Preserve existing Tripo/Quaternius/CMU sources, ten original tracks, runtime assets and playable systems. First reuse them for style and camera studies; v06 remains visually unaccepted and is not automatically the final character. Choose whether to repair or replace individual sources only after inspection.

Custom 3D workflow: approved design → four separate consistent front/left/right/back references when generation is needed → user-operated Tripo → user-led model/rig refinement → texturing and Godot acceptance. Reuse qualified assets rather than regenerate them. Codex handles art direction, reference images, parameters and agreed engine/rendering work; the user's earlier ownership of 3D modeling and animation design is not silently reassigned. Never operate Tripo or purchase assets without authorization.

User account feedback: retries with the same parameters are free; changing parameters may cost credits; texturing costs 10 credits and cannot be retried afterward. Inspect the untextured model first and finish retries before deciding to texture. This is account feedback, not a universal price guarantee. Keep originals. Do not write suggested settings as known actual settings.

There are currently no generation tasks for the user to submit. The unsuitable nature-asset four-view batch has been deleted; do not generate from that list. See [Generation tasks](art/generation_tasks.md).

## Current implementation and boundaries

| Item | Current status |
| --- | --- |
| Qinglan | Retained as an unaccepted playable reference for the restored 3D pipeline; no new refinement or replacement selected yet. Runtime still uses `qinglan_garment_v06.glb`: v05 textile finish retained; knee-length trousers and v03 calf surfaces restored without a new body mask. Ten garment-only sleeve/cuff/hem controls add damped acceleration, stride and turn response, retaining ribbon chains. All ten original clip time/value data, original rest transforms and bind matrices are preserved; contextual gaits and CMU step turns remain. Fresh functional tests pass, but residual garment/leg intersections, folded hems and broad angular cuffs remain; visual acceptance is incomplete. No cloth solver or target-device performance claim. |
| Starter sword | The Tripo original has been refined and bound to the right hand, 1068 triangles. Basic swing, directional parry, and movement-art practice are integrated. |
| Cottage | The running asset is the refined Tripo version, 2966 triangles, doorway about 1.608 × 1.829 m. The old direct-modeled version remains as history only. |
| River tiles | 47-state connection logic exists; visible terrain, bridge, and facilities still include prototype looks. 47 states does not mean 47 independent models must be generated. |
| Sandbox and scene coverage | Main play scene now supports B-key building: footprint selection, real green/red previews, nature placement/move/remove, unique cottage relocation with updated entrance/return, guarded land edits and manual layout save/load without resource rollback. See [sandbox review](art/review/sandbox/2026-09-21/review.md). Production facilities remain fixed; no object rotation, river editing, full routing, undo or full construction economy. All 130 visible starting cells now share authoritative build/render data; empty land can be erased and all outer edges expanded, with a 256-cell playable cap and drag painting. Nature objects are independent; no tree/rock bundle tool. v2 layout files preserve outer holes, and v1 files migrate implicit land and split bundles on read. See [land refinement](art/review/sandbox_land/2026-09-21/review.md). Original doorway/facility coordinate overlap remains grandfathered only at the initial house site. Bridge remains fixed. Runtime spaces remain courtyard, interior and a fixed exploration fork; no village scene. |
| Combat | Single dummy practice, vitality/ward, and close-range spiritual pressure. Three enemy attack types, multi-enemy, growth, and sword flight are not a complete playable system. |
| Overall look | Heightfield islands (2026-10-02): gameplay stays a per-island height grid and land mask. The visible grass edge is a smoothed marching-squares contour. Below that lip the wall is procedural flat-shaded rock blocks in the terrain mesh, warm brown near the top and cooler grey lower. Render cells are 2× gameplay (distant LOD 1×). Run 5 olive grass, tufts, lake shader, and cloud sea stay. Brushes, volume cost, dig-through, lakes, and auto-flatten are unchanged. See [heightfield review](art/review/heightfield/2026-10-02/review.md). Art acceptance and target-device performance remain open. |
| Free assets | Kenney Nature Kit 2.1 and Quaternius Standard originals are downloaded and CC0 checked. Earlier five-model samples were compared across three layouts. Eight unchanged Quaternius models now dress the runtime courtyard. A separate KayKit + Quaternius rock-kit (10 hanging pieces) is committed under `assets/rockkit/` for island undersides. Final art, placement acceptance, and target-device performance remain open. |

Detailed sources, work files, and runtime paths are in [Asset status](art/README.md). The original systems-doc entry is [Design index](docs/README.md); keep its economy, exploration, and other rules. Do not infer completed features from historical plans.

The 2026-09-20 [handoff inspection](art/review/handoff/2026-09-20/review.md) records runtime-asset hashes, functional checks, current engine screenshots, and the high-frame-rate transition-test sampling limitation. The [Quaternius comparison](art/review/module_probe/2026-09-20/quaternius/review.md) records source contents, nine views, and short development-machine render samples. The earlier [visual and motion pass](art/review/animation_refinement/review.md) records rejected procedural body motion and retained scene dressing. The current [human-template replacement](art/review/animation_template/review.md) includes source/target previews and actual traversal, with fresh functional and source-preservation checks. The earlier [running and clothing pass](art/review/running_cloth/review.md) records v04 tailoring and steering. The [gait, turn and fabric pass](art/review/gait_v05/review.md) adds actual stepping transitions, contextual gaits and textile refinement. The current [garment v06 pass](art/review/garment_v06/review.md) restores the intended knee hems/calves and adds garment-only secondary motion, with fresh source-preservation checks and actual before/after engine captures; residual intersections and cloth finish remain open. Original files remain preserved.

## Confirmed combat principles (kept, not the current expansion focus)

Early game uses a held sword; later, sword flight may be considered. One-on-one fights can be handled calmly through observation and parry; multiple enemies are dangerous because direction and timing are hard to cover at once. Hostile characters' close-range spiritual pressure can stack and drain ward. Movement arts have charges and a short invulnerability window; advanced arts and realms may affect abilities.

Any positive ward before a hit grants full damage reduction determined by realm relation, envisioned as 60%–95%. The reduced portion is paid by ward, floored at zero; any reduction ward cannot cover is not transferred to vitality. If ward is zero on the next hit, there is no reduction. Active qi damage drains ward first and overflows to vitality; passive close-range spiritual pressure drains ward only. Exact numbers, recovery times, and skill parameters are tunable prototype values, not all locked. Details: [Combat rules and trial values](docs/combat.md).

## Performance goals and acceptance

Low quality on a Windows thin-and-light laptop and a MacBook Air should aim for about 60 FPS. Minimum hardware is unspecified and target devices have not been measured; do not claim the target is met. An idle game also cares about long-session power, heat, and stability.

Optimization should first inspect instance reuse, LOD, culling, material count, shadows, water, and transparent stacking, then decide renderer and quality tiers. Low quality still keeps composition, main vegetation silhouettes, the ancient-style palette, and spatial layers. Record device, resolution, backend, quality, frame time, and variance. Do not substitute development-machine results for thin-laptop results.

## Next steps

1. Prioritize the sandbox building loop over further static art. Run `打开沙盒营造.command` or press B in the main demo; review actual placement, move/cancel/remove, terrain feedback and layout save/load.
2. Ground/build data are now unified and tree/rock bundles removed. Next resolve legacy facility coordinates, then scope production-facility relocation and traversal/connectivity validation. Do not assume unconfirmed rotation, scaling or stacking permissions.
3. Keep management, production and economy constraints as the basis for later building costs and placement effects. Current nature trial is free and yield-neutral; layout saves do not replace a full game save.
4. Use the independent art study for later tree crown, terrain boundary and paving refinement, after the build workflow is usable. Character work remains deferred.
5. Preserve scene separation and existing movement. Accept function, art and target-device performance independently. No current generation submission task.

Ask only when information is truly missing, user action is required, or a key direction conflicts. Continue reversible daily work autonomously. Do not purchase assets automatically. Do not restore old plans item by item, and do not substitute “continue progressing” language for actual work.

## Maintenance

Sync new explicit decisions into this file and related current entries. Replace old status; do not keep appending contradictory “latest status” notes. Delete obsolete, misleading content outright. Do not keep wrong requirements under history labels or backups. Keep generation inputs, originals, and review reports for valid assets as evidence.
