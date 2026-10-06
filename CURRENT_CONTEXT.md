# Current project consensus and handoff entry
Updated: 2026-10-06. Latest explicit user instructions take precedence. Read this before code and related design. Source assets and review reports are evidence, not automatic todos.

## Current priority and approved scope

The project remains an ancient-style xianxia idle incremental game. The active demo is a freely editable floating-island workshop. The latest user image guides its two terraces, two lakes, waterfall sequence, modest cottage, faceted cliffs and vegetation. This reference composition does not prescribe every future courtyard layout. Tiny Glade guides coherence of editing and adaptive detail; its internal terrain representation has not been inferred.

Visual fidelity takes priority over the earlier function/performance-first direction. The current native goal follows the latest pasted rejection/rework request and the user-supplied `FLOATING_ISLAND_LOOKDEV_BRIEF.md`: deliver a review-ready improved candidate with matched runtime views, motion and performance evidence. User aesthetic approval remains separate. The user approved execution and requested native plans; no repeated approval loop is required. Original assets and unrelated local work must be preserved. No purchases or custom-model generation are authorized.

Camera orientation remains fixed under the user's explicit navigation instruction. Keyboard and middle-drag pan horizontally at constant height; only the wheel changes height/zoom. Vertical movement and orbit are disabled. Recenter, reset and presets preserve height. Rotated poses in the review harness are inspection-only and do not change gameplay controls.

## Current workshop revision

Work is on `codex/terrain-fidelity` in the primary checkout. The 2026-10-06 candidate at `4d891bd` was submitted for review and is now **NOT ACCEPTED — SUBSTANTIVE VISUAL REWORK REQUIRED**. [Current evidence and limitations](art/review/terrain_fidelity/2026-10-06/review.md) supersede historical round status. Earlier geometry, vegetation and rejected trials remain [revision-specific evidence](art/review/terrain_fidelity/2026-10-05/review.md).

Terrain is a sparse 2D XZ height grid, not a 3D voxel volume. Shared smoothed contours generate connected land, tapered cliffs, lakes and waterfalls. All visible land shares authoritative build data. Raise/lower/expand/contract, optional snapping (off by default), eight water elevations, 47 neighbor states, undo/redo and separate layout save/load remain. Complete immutable terrain, detail, supported props and picking snapshots publish together at two chunks per frame; idle frames do not rebuild.

The current rework changes shared cliff geometry to shallow blunt feet and bevelled masses with irregular ledges/recesses; playable caps stay flat. Minimum legal land retains a supporting half-unit shell. Outer corner classification and broad/narrow shared-edge knots were corrected after fresh edited views exposed a deep spike and cracks. There is no separate embedded cliff-model layer. Canonical shared edges, picking and immutable two-chunk publication remain.

Regular lake bands were traced to directional wave slopes; continuous 2D height gradients replace them. Actual contour bank distance and bed depth shape the margin response. New supported graded shore shelves replace abrupt grassy gaps. Rounded sampled fall lips, physical folds/sway, downward aeration and local supported receiving foam connect the flow. Closed wet rings retain local landing foam. Falls still read somewhat like translucent ribbons and foam remains thin lace; shores have blunt patch ends and stones are repetitive. Static sky radiance does not reflect scene geometry.

Four derived crown masses expose branch space; tree scales vary. Low common grass clusters and shorter sparse vines leave quiet ground. Original assets and cottage remain intact. Integrated warm daylight/blue fill and blended shadow splits improve separation without changing renderer, tone mapping or SSAO.

Current evidence is [the substantive rework review](art/review/terrain_fidelity/2026-10-06/rework/review.md). Matched runtime output includes default/close/rotated views, four edits, minimum height, irregular boundaries, regeneration and fresh-editor reopening; plain-material views verify real rock geometry. Fresh checks, motion sampling and measured costs are recorded there with their scope. User artistic acceptance remains pending; previous candidate results are historical, not this revision's verification.

The matched current-host comparison preserves actual 1280×720 SubViewport rendering/4x MSAA/shadows/SSAO and sequential three-run conditions. Median submission intervals remain near 6.9 ms; p95 increases from 7.428–7.496 to 8.082–8.178 ms. Edit publication rises from 195.318–242.376 to 222.978–300.847 ms; maximum intervals rise from 100.726–107.884 to 141.669–151.332 ms. This is a measured geometry/editing trade-off, not unchanged cost or presented FPS. GPU timing, target-laptop support, larger maps and long-idle stability remain unmeasured. Long horizontal rock ledges remain an art refinement issue.

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

Review the integrated rework against the latest daytime target and concrete user feedback. Preserve its coherent terrain/data/camera contracts and original assets. Aesthetic acceptance is the user's decision, independent of passing finite checks. If further rework is requested, use the current rework evidence as the new revision baseline; do not describe historical captures or timing as fresh results. Target-device editing latency and idle power/stability need separate measurement.
