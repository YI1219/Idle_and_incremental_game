# Current project consensus and handoff entry
Updated: 2026-10-06. Latest explicit user instructions take precedence. Read this before code and related design. Source assets and review reports are evidence, not automatic todos.

## Current priority and approved scope

The project remains an ancient-style xianxia idle incremental game. The active demo is a freely editable floating-island workshop. The latest user image guides its two terraces, two lakes, waterfall sequence, modest cottage, faceted cliffs and vegetation. This reference composition does not prescribe every future courtyard layout. Tiny Glade guides coherence of editing and adaptive detail; its internal terrain representation has not been inferred.

Visual fidelity takes priority over the earlier function/performance-first direction. The ongoing task follows the latest shape-language checkpoint request and the user-supplied `FLOATING_ISLAND_LOOKDEV_BRIEF.md`: continue visual rework with matched runtime views, motion and performance evidence. This is an intermediate checkpoint, not overall goal completion. User aesthetic approval remains separate. The user approved execution and requested native plans; no repeated approval loop is required. Original assets and unrelated local work must be preserved. No purchases or custom-model generation are authorized.

Camera orientation remains fixed under the user's explicit navigation instruction. Keyboard and middle-drag pan horizontally at constant height; only the wheel changes height/zoom. Vertical movement and orbit are disabled. Recenter, reset and presets preserve height. Rotated poses in the review harness are inspection-only and do not change gameplay controls.

## Current workshop revision

Work is on `codex/terrain-fidelity` in the primary checkout. Candidates `4d891bd` and `3a73663` were **NOT ACCEPTED**. The latest user recognizes substantive progress in quieter vegetation, restrained tree scale, calmer lakes and curved waterfall lips; preserve those gains. [Current shape checkpoint](art/review/terrain_fidelity/2026-10-06/shape_checkpoint/review.md) is the current evidence. The [previous rework](art/review/terrain_fidelity/2026-10-06/rework/review.md) and earlier reports remain historical evidence.

Terrain is a sparse 2D XZ height grid, not a 3D voxel volume. Shared smoothed contours generate connected land, tapered cliffs, lakes and waterfalls. All visible land shares authoritative build data. Raise/lower/expand/contract, optional snapping (off by default), eight water elevations, 47 neighbor states, undo/redo and separate layout save/load remain. Complete immutable terrain, detail, supported props and picking snapshots publish together at two chunks per frame; idle frames do not rebuild.

Simple gray material, controlled white light, no shadows/AO and geometric-flat versus production-normal comparisons separated the cliff causes: aligned slab geometry made horizontal shelves, while all-face averaging and whole-triangle crease fallback contributed soft/pinched shading. Oblique unequal volume relief, feature-following profile knots, shorter triangle diagonals and per-corner plane-group normals now interrupt the shelf rhythm. Overall thickness and legal minimum-height support remain. There is no additional all-around rock layer. Canonical shared edges, picking and immutable publication remain. Some local pointed facets/recess slits and flatter terrace walls still fall short of the reference.

The calmer lake shader, contour-derived bank/depth field, curved waterfall lip and daylight are retained. Broader unequal fall folds, intermittent downward cellular aeration and a supported receiving roll now connect the curtain foot to fuller foam. The core is nearly opaque with irregular fading edges; a small terminal-only light contribution supports froth. Cellular highlights can still read as a net/outlined bubbles, especially around edited holes. This is unresolved rework, not optional polish. No new reflection feature was added.

Selected tapered banks blend grass into exposed earth and shallow water; stone gaps use the same support and bank selection. Small turf lips use actual dry-cap proximity. Quiet ground is retained. Four retained-source crown masses now have a broader primary and unequal secondary lobes with branch space, without another uniform instance scale reduction. Source assets/cottage remain intact. Shore stones are still repetitive and some exposed banks remain visibly polygonal.

Fresh final verification: 26 scripts pass, plus actual Metal runtime 22/22. Four edit fixtures, minimum legal height, irregular boundaries, regeneration and fresh-editor reopening have actual captures. Two 300-frame clips cover full-scene inspection and the connected flow sample; six sampled frames were visually inspected, uninterrupted playback remains unverified. An invariant geometry-site cache preserves byte-identical vertices/normals/colors in the default and four independent edit fixtures. Full acceptance remains separate from these finite checks.

Fresh matched comparison against `3a73663` uses actual 1280×720 SubViewport rendering, 4x MSAA/shadows/SSAO and three serial 12-second runs on an M4 Pro. Median submission intervals stay near 6.9 ms; p95 changes from 8.095–8.160 to 7.437–7.485 ms. Edit publication changes from 220.342–275.777 to 222.628–285.950 ms; maximum intervals from 146.988–148.326 to 171.626–175.851 ms. These are process/submission intervals, not presentation FPS or GPU frame time. Target laptops, larger maps and long-idle power/stability remain unmeasured.

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

Continue from the shape checkpoint, preserving its gains and existing gameplay/data/camera contracts. Resolve localized pointed cliff facets and flatter terrace walls, the waterfall's outlined-cell appearance, and remaining polygon-tracing shoreline rhythm through representative connected samples. Do not restart with global parameter changes or refill quiet ground with vegetation. No new user decision is required to recognize these mismatches; user aesthetic acceptance remains separate. Target-device editing latency and idle power/stability need separate measurement.
