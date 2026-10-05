# Current project consensus and handoff entry
Updated: 2026-10-05. Latest explicit user instructions take precedence. Read this before code and related design. Source assets and review reports are evidence, not automatic todos.

## Current priority and approved scope

The project remains an ancient-style xianxia idle incremental game, with management, production, growth and exploration as its core. The active demo is a freely editable floating-island terrain workshop. The latest user image guides layered grassy land, faceted rock cliffs, blue ponds, waterfalls and coherent stylized vegetation; it does not lock every future courtyard to one layout.

The user approved the [design](docs/superpowers/specs/2026-10-05-terrain-sandbox-design.md) and [implementation plan](docs/superpowers/plans/2026-10-05-terrain-sandbox.md), choosing native execution in this chat. The old terrain and placed scene objects need not be preserved. Original asset sources and economy code remain available. No paid assets, custom original model generation, character/combat expansion or village/exploration expansion is included.

Camera orientation is fixed. Keyboard and middle-drag movement pan horizontally, preserving height. Only the scroll wheel changes height and zoom. Vertical movement, fly navigation and orbit are disabled. Recenter, reset and preset changes preserve camera height.

## Implemented workshop

The primary project and branch `codex/terrain-sandbox` now contain TerrainData, chunk geometry, automatic decoration, camera and editor UI. The workshop is the default scene and both demo/workshop launchers run it. The workshop has raise/lower/expand/contract drag brushes, snap toggle, eight water elevations, 47 normalized neighbor states, water painting/removal, undo/redo, isolated layout save/load, three presets and optional grid. Grass and surface rocks follow the terrain; cliff rocks are procedurally embedded using existing free models. 8×8 chunk meshes and chunk-local MultiMeshes rebuild only dirty regions. Every visible terrain cell is authoritative and editable.

Fresh tests currently pass: data 301/301, geometry 339/339, decoration 164/164 and runtime/camera 20/20. These prove their specific functional coverage, not visual acceptance or performance. Three corrected edited-layout engine captures have been inspected. They demonstrate the terrain, water, vegetation and cliffs across different layouts; foliage detail and cliff/shore rhythm remain less polished than the reference, so final user art acceptance is separate. The full 26-script functional suite passed after a fixture-only correction to the legacy running-turn test. Three corrected real-time 4096-cell benchmarks pass (median 5.452–5.820 ms; p95 16.302–16.708 ms) on the M4 Pro development device. Final independent review is complete: snapped cliff ownership and deep-water supporting walls were fixed with regression coverage. The corrected demo is delivered to the primary checkout; unrelated local file contents are preserved. The protected 1800.004-second stability run passed: 359 edit/undo/redo cycles, no runtime errors, no pending rebuilds, restored layout and 604 nodes at both start/end. Its capped median/p95 were 16.686/18.429 ms. Static memory rose from 60.39 MiB to a 62.50 MiB measurement peak; final report construction used 64.94 MiB including sample-array conversion.

Workshop terrain and camera behavior are specified in [terrain](docs/terrain.md) and [camera](docs/camera.md). Native execution continues through verification without extra task-by-task approval.

## Scene and asset boundaries

The Sea of Consciousness Courtyard is a sandbox with combinable modules. Village scope remains undecided and separate; exploration is intended for procedural layouts. Do not merge these three scene types. Nature kinds remain independent; no bundled tree/rock placement tool or locked decorative ground.

Use 3D modular scenes and non-pixel ancient-Chinese stylization. The new floating-island picture is the workshop target; 尘之回声 remains a presentation reference, and 墨境 / Realm of Ink remains a character-motion/combat/art reference without expanding gameplay scope. Character, garment and combat-animation work is deferred; existing Qinglan v06 is visually unaccepted and need not appear in the workshop. Preserve originals and existing playable sources; do not restart 2D directional/Spine production.

The cottage and starter sword already use refined Tripo assets; do not ask to regenerate them. Existing CC0 Quaternius and Kenney sources are available; first validate pairing in a small rendered scene before increasing density. Asset details remain in [art/README.md](art/README.md), and module acceptance in [scene art spec](docs/art/scene_art_and_module_spec.md).

Custom selected assets retain concept → four independent consistent front/left/right/back views → user-operated Tripo → user-led Blender inspection/refinement → textures/baking → engine acceptance. Do not operate Tripo or build replacement original model geometry in code. User account feedback about retries/texturing is account-specific; unknown parameters remain unknown. No currently submittable generation task exists. Do not purchase assets without authorization.

## Confirmed combat principles (kept, not the current expansion focus)

Early game uses a held sword; later, sword flight may be considered. One-on-one fights can be handled calmly through observation and parry; multiple enemies are dangerous because direction and timing are hard to cover at once. Hostile characters' close-range spiritual pressure can stack and drain ward. Movement arts have charges and a short invulnerability window; advanced arts and realms may affect abilities.

Any positive ward before a hit grants full damage reduction determined by realm relation, envisioned as 60%–95%. The reduced portion is paid by ward, floored at zero; any reduction ward cannot cover is not transferred to vitality. If ward is zero on the next hit, there is no reduction. Active qi damage drains ward first and overflows to vitality; passive close-range spiritual pressure drains ward only. Exact numbers, recovery times, and skill parameters are tunable prototype values, not all locked. Details: [Combat rules and trial values](docs/combat.md).

## Performance and acceptance

Accept function, art and performance separately. Concepts are not engine screenshots; historical tests are not current-round verification. About 60 FPS on a Windows thin-and-light laptop and a MacBook Air remains a target that needs actual device measurements. Development-device results cannot prove it.

Measure the workshop at 4096 cells, 1280×720 low quality, with three runs of at least 60 seconds: median ≤16.7 ms and p95 ≤25 ms. Record hardware/backend, draw calls, memory and edit-response latency, and run 30-minute stability. Low quality retains composition and style. Consider long-idle heat/power; do not claim power acceptance from short frame benchmarks.

## Next actions

The approved terrain-workshop implementation and development-device verification are complete. Three edited engine views, three corrected benchmarks, 30-minute stability, all 26 functional scripts and independent review are recorded under art/review/terrain_editor/2026-10-05/. Future visual polish and actual Windows thin-laptop/MacBook Air and long-idle power measurements are separately pending. Preserve unrelated primary-checkout changes in further work. Replace stale status in current docs instead of appending conflicting versions. Do not restore obsolete collaboration folders, claims or messaging.
