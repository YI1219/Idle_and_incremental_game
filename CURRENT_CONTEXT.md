# Current project consensus and handoff entry
Updated: 2026-10-06. Latest explicit user instructions take precedence. Read this before code and related design. Source assets and review reports are evidence, not automatic todos.

## Current priority and approved scope

The project remains an ancient-style xianxia idle incremental game. The active demo is a freely editable floating-island workshop. The latest user image guides its two terraces, two lakes, waterfall sequence, modest cottage, faceted cliffs and vegetation. This reference composition does not prescribe every future courtyard layout. Tiny Glade guides coherence of editing and adaptive detail; its internal terrain representation has not been inferred.

The latest explicit request is a direct in-engine environment art pass: preserve the existing workshop layout and camera, use a restrained sage/jade/gray palette with soft baked-style real-time lighting, shrink the cottage to 65%, add five small kitchen-garden rows, normalize mature tree heights, shorten only the rock underside by 40%, and add a simple mountain/cloud background with no buildings or foreground framing. This supersedes the previous instruction against global art parameter changes. The user authorized direct implementation; no repeated design approval is required. Original assets and unrelated local work must be preserved. No purchases or custom-model generation are authorized.

Camera orientation remains fixed under the user's explicit navigation instruction. Keyboard and middle-drag pan horizontally at constant height; only the wheel changes height/zoom. Vertical movement and orbit are disabled. Recenter, reset and presets preserve height. Rotated poses in the review harness are inspection-only and do not change gameplay controls.

## Current workshop revision

Work remains on `codex/terrain-fidelity` in the primary checkout. [Quiet homestead review](art/review/terrain_fidelity/2026-10-06/homestead/review.md) records the current implementation and real rendered captures. It is not final user aesthetic acceptance. The [shape checkpoint](art/review/terrain_fidelity/2026-10-06/shape_checkpoint/review.md) and [previous rework](art/review/terrain_fidelity/2026-10-06/rework/review.md) are historical evidence; candidates `4d891bd` and `3a73663` were not accepted.

The same sparse XZ height grid, shared contours, terrain presets, two terraces and two ponds remain. Complete immutable terrain/detail/prop/picking snapshots still publish together at two chunks per frame; idle frames do not rebuild. Editable operations, undo/redo and layout save/load remain unchanged. Camera navigation contracts remain intact.

The cottage and attached details/colliders uniformly multiply the prior scale by 0.65. Five kitchen-garden rows reuse retained foliage as low crops in MultiMeshes, beside the reconnected and vegetation-cleared entrance path. They use authoritative terrain support and hide/restore with terrain removal/undo. No new farming system exists. The four original tree anchors have measured mature heights of 4.067–4.233 m, with restrained width/yaw variation.

Outer rock support below its local terrace is reduced to 60% depth; terraces, ponds and inter-terrace height differences are preserved, with minimum-height support retained. Shared picking follows the geometry. Coherent warm-gray cliff colors and softer lighting reduce facet contrast. The lower outlet has a small clearance correction for its new shell. Existing oblique cliff geometry and connected flow infrastructure remain.

Workshop materials now use restrained sage/olive foliage and ground, jade-blue water, weathered timber and charcoal roofs. Ground/shore/turf share palette controls; water exposes shallow/deep colors. The scene exposes sunlight, ambient and haze controls. Soft directional light, cool fill, shadow opacity and SSAO approximate baked lighting on editable terrain. Renderer stays Forward+; no lightmaps, backend changes, heavy volumetrics or global color filter were introduced.

A lightweight camera-aligned sky adds layered mountain silhouettes, recolored existing cloud-only texture and an upper-right pale sun. No background buildings or foreground framing. Waterfall shading uses interrupted descending streaks instead of outlined cells. Shore stones vary more, with existing reeds/lilies and sparse pale path flowers. Known visual limits include angular cliff recesses, some repetitive shoreline stones, simplified crops and lack of background parallax. Water reflects sky only. Fresh verification: 29/29 terrain test scripts pass, including 28 homestead assertions and 22/22 actual Metal runtime checks. The exact-size 1671 × 941 composition and closer garden captures were visually inspected. New target-hardware and long-idle performance have not been measured.

## Scene and asset boundaries

The Sea of Consciousness Courtyard is a sandbox with combinable modules. Village scope remains undecided and separate; exploration is intended for procedural layouts. Do not merge these three scene types. Nature kinds remain independent; no bundled tree/rock placement tool or locked decorative ground.

Use 3D modular scenes and non-pixel ancient-Chinese stylization. The new floating-island picture is the workshop target; 尘之回声 remains a presentation reference, and 墨境 / Realm of Ink remains a character-motion/combat/art reference without expanding gameplay scope. Character, garment and combat-animation work is deferred; existing Qinglan v06 is visually unaccepted and need not appear in the workshop. Preserve originals and existing playable sources; do not restart 2D directional/Spine production.

The cottage and starter sword already use refined Tripo assets; do not ask to regenerate them. Existing CC0 Quaternius and Kenney sources are available; first validate pairing in a small rendered scene before increasing density. Asset details remain in [art/README.md](art/README.md), and module acceptance in [scene art spec](docs/art/scene_art_and_module_spec.md).

Custom selected assets retain concept → four independent consistent front/left/right/back views → user-operated Tripo → user-led Blender inspection/refinement → textures/baking → engine acceptance. Do not operate Tripo or build replacement original model geometry in code. User account feedback about retries/texturing is account-specific; unknown parameters remain unknown. No currently submittable generation task exists. Do not purchase assets without authorization.

## Confirmed combat principles (kept, not the current expansion focus)

Early game uses a held sword; later, sword flight may be considered. One-on-one fights can be handled calmly through observation and parry; multiple enemies are dangerous because direction and timing are hard to cover at once. Hostile characters' close-range spiritual pressure can stack and drain ward. Movement arts have charges and a short invulnerability window; advanced arts and realms may affect abilities.

Any positive ward before a hit grants full damage reduction determined by realm relation, envisioned as 60%–95%. The reduced portion is paid by ward, floored at zero; any reduction ward cannot cover is not transferred to vitality. If ward is zero on the next hit, there is no reduction. Active qi damage drains ward first and overflows to vitality; passive close-range spiritual pressure drains ward only. Exact numbers, recovery times, and skill parameters are tunable prototype values, not all locked. Details: [Combat rules and trial values](docs/combat.md).

## Performance and acceptance

Accept function, art and performance separately. Concepts are not engine screenshots; historical tests are not current verification. About 60 FPS on a Windows thin-and-light laptop and a MacBook Air remains a target needing actual device measurement. Current-host isolated cost comparison cannot prove it. Existing idle/large-map evidence belongs to earlier renderers.

## Next actions

Review the actual homestead capture against the latest explicit brief before expanding scope. Preserve the layout, restrained colors, smaller cottage/garden, common tree heights and thinner shell. User aesthetic acceptance remains separate from geometry/runtime checks. Additional art refinement should focus only on visible local issues, and target-device editing latency and idle power/stability need separate measurement.
