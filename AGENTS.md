# Project working constraints

Read [CURRENT_CONTEXT.md](CURRENT_CONTEXT.md) first, then read code and related design for the task. That file records current consensus and handoff direction. The user's latest explicit requests take precedence. Obsolete plans and misleading concept drafts have been deleted. Asset generation inputs and review reports are source and stage evidence only, not current todos.

## Required direction

- Ancient-style xianxia idle incremental game. Management, production, long-term growth, and exploration are the core. Scenes split into the Sea of Consciousness Courtyard, the village, and procedurally generated exploration areas. Current priority is playable sandbox building functionality before further static art refinement; keep combinable modules and separate art/performance acceptance. Defer character, garment and combat-animation work; keep the existing actor only as a scale/traversal reference.
- The [courtyard image](art/source/visual_targets/2026-09-20/courtyard_user_target.png) is a look-and-finish reference only; it does not prescribe layout, landscape, or an asset list. Combine the user's game references catalogued in the scene art spec into a unified ancient-style design with flowing silhouettes and readability. Do not copy a fixed landscape, and do not require every courtyard to have a river, bridge, or pine trees.
- Nature props are independently editable; do not reintroduce a bundled tree/rock placement tool. All visible courtyard land must share the authoritative build data; do not add locked decorative ground behind the sandbox.
- The Sea of Consciousness Courtyard is a sandbox; elements are designed for placement and combination. The same module set must work in multiple layouts and neighbor relations. Exploration is designed toward procedural generation. Village remodeling scope is not yet decided. Do not mix the village and the courtyard into one scene.
- Main pipeline is now 3D characters, animation and modular scenes, with non-pixel ancient-Chinese stylized rendering. Reference 尘之回声 for presentation and 墨境 (Realm of Ink) for character motion, combat presentation and art style, without expanding gameplay scope. Stop 2D directional-character/Spine production. Follow [3D art direction](docs/art/three_d_art_direction.md). Preserve concept evidence and original assets; first validate existing models before regeneration.
- The current cottage and starter sword already use refined Tripo assets. Do not repeat replacement from old notes or ask the user to regenerate them. Qinglan v06 remains a visually unaccepted reference; first validate the restored 3D rendering direction, then scope model/animation corrections. Keep the playable implementation and originals.
- The unsuitable nature-asset four-view batch has been deleted. Validate resource pairing in a real small scene first, then expand.
- About 60 FPS at low quality on a Windows thin-and-light laptop and a MacBook Air is a target still to be measured. Also consider long-idle power and stability. Low quality still keeps overall composition and style. Do not claim target hardware is met from development-machine results.

## User-operated Tripo workflow

Do not restore Cursor collaboration folders, claim, or messaging mechanisms, and do not operate the Tripo website on the user's behalf. Codex owns art direction, concept/reference images, generation parameters and agreed rendering/game integration. The user owns 3D creation and refinement, including Blender work, and operates Tripo. The following workflow applies only to explicitly selected custom 3D assets; it is not required for 2D artwork.

- Custom pipeline: concept → four independent, consistent front/left/right/back image files → Tripo multi-view low-poly model → Blender inspection and refinement → textures or baking → game acceptance. Do not replace four views with a collage or perspective concept image.
- Before publishing a generation task, actually inspect the four images and give mode, topology, target polycount, texturing stage, format, and save directory. Do not ask the user to submit until the images are ready.
- Inspect the untextured model first, then decide retry or texturing. User account feedback: same-parameter retries are free; changing parameters may cost credits; texturing is 10 credits and cannot be retried afterward. Necessary parameter changes need a quality reason; do not assume all accounts have the same prices.
- Do not overwrite originals. Save images, any available task identifiers, exported originals, work files, runtime assets, and review records. Keep unknown generation parameters unknown; suggestions are not facts.
- Blender may refine existing sources. Do not build original geometry from scratch to replace a custom official model that still needs to be made. Code may implement module assembly, instancing, materials, animation, LOD, and collision.
- Do not purchase assets without user authorization. If generation or sourcing is actually blocked, state the problem.

## Handoff and verification

[Asset status](art/README.md) records current assets. [Generation tasks](art/generation_tasks.md) lists only currently submittable tasks. [Scene art and module spec](docs/art/scene_art_and_module_spec.md) defines scene acceptance.

Accept function, art, and performance separately. Concept images are not in-engine screenshots. Historical test results are not a new verification of this round. Push reversible work. Do not repeatedly request already-granted authorization. When the user is truly needed, ask in one batch. When updating docs, replace stale status; do not append conflicting versions.
