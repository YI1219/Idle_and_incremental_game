# Current project consensus and handoff entry
Updated: 2026-10-06. Latest explicit user instructions take precedence. Read this before code and related design. Source assets and review reports are evidence, not automatic todos.

## Current priority and approved scope

The project remains an ancient-style xianxia idle incremental game. The active demo is a freely editable floating-island workshop. The latest user image guides its two terraces, two lakes, waterfall sequence, modest cottage, faceted cliffs and vegetation. This reference composition does not prescribe every future courtyard layout. Tiny Glade guides coherence of editing and adaptive detail; its internal terrain representation has not been inferred.

Visual fidelity takes priority over the earlier function/performance-first direction. The current native goal follows the user-supplied `FLOATING_ISLAND_LOOKDEV_BRIEF.md`: deliver a review-ready improved candidate with matched runtime views, motion and performance evidence. User aesthetic approval remains separate. The user approved execution and requested native plans; no repeated approval loop is required. Original assets and unrelated local work must be preserved. No purchases or custom-model generation are authorized.

Camera orientation remains fixed under the user's explicit navigation instruction. Keyboard and middle-drag pan horizontally at constant height; only the wheel changes height/zoom. Vertical movement and orbit are disabled. Recenter, reset and presets preserve height. Rotated poses in the review harness are inspection-only and do not change gameplay controls.

## Current workshop revision

Work is on `codex/terrain-fidelity` in the primary checkout. The 2026-10-06 candidate is **READY FOR ART REVIEW**, not aesthetically approved or an exact replica. [Current evidence and limitations](art/review/terrain_fidelity/2026-10-06/review.md) supersede historical round status. Earlier geometry, vegetation and rejected trials remain [revision-specific evidence](art/review/terrain_fidelity/2026-10-05/review.md).

Terrain is a sparse 2D XZ height grid, not a 3D voxel volume. Shared smoothed contours generate connected land, tapered cliffs, lakes and waterfalls. All visible land shares authoritative build data. Raise/lower/expand/contract, optional snapping (off by default), eight water elevations, 47 neighbor states, undo/redo and separate layout save/load remain. Complete immutable terrain, detail, supported props and picking snapshots publish together at two chunks per frame; idle frames do not rebuild.

This pass removes lake color mosaics and painted glints, adds continuous world-space wave normals and a restrained directional sky radiance contribution, and localizes disturbance near receiving drops. Basin depth and bank data remain terrain-derived. The lake is opaque/nonmetallic; static sky reflection is not reflected cottage/tree geometry. Waterfalls use downward continuous streaks without global emission. Gently curved supported bank stretches leave grass gaps while bends/outlets retain stones. Ground flecks and cliff color contrast are quieter. Terrain geometry, layout, product camera, cottage, model sources and non-bank placements retain `a41382f` sources. Quaternius curved/wispy grass and Kenney model assembly remain intact; bench and lantern remain placeholders.

Fresh matched baseline/final actual Godot 1672×940 captures include composition, two rotated inspection views, contact detail, all four edit operations (16/12/14/16 cells) and regeneration. Fresh 5-second 1280×720 runtime clips contain 300 frames at fixed 60 Hz; inspected final frames include rotation/zoom/pan and water motion, with no obvious new detached curtain/sorting defect in those samples. Sampling does not prove smooth entire-clip playback or arbitrary topology/angles. The cloud background remains screen-mapped for the fixed product view; cubemap radiance is directional. Unrestricted rotation and a possible bitmap wrap seam are not globally validated.

Nine fresh functional scripts pass: impact 8, shoreline 9, waterfall 35, contours 1025, data 301, render 339, decoration 89, incremental 20 and runtime 22 checks. Runtime covers camera height rules, save/load and painting routing. These bounded checks do not establish all possible edited layouts or visual acceptance. Eight unrelated local file hashes are unchanged; original assets are preserved.

Matched isolated M4 Pro/Metal Forward+ rendering uses a real 1280×720 SubViewport, 4x MSAA, shadows/SSAO, identical camera path/593 cells/four edits, 2-second warmups and three 12-second runs. Baseline median 6.901–6.904 ms/p95 7.482–7.525 ms; final median 6.898–6.903 ms/p95 7.489–7.523 ms. Final publication response is 195.132–245.166 ms, maxima 91.770–106.922 ms; spikes remain. These are submission/process intervals with the native window minimized, not presented FPS. Draw calls remain 510; video memory 217.891 MiB. GPU timing is unavailable on this backend. No material regression beyond observed repeatability in this method; visible-window attempts with inconsistent focus and a failed harness are explicitly excluded. Target laptops, larger maps and long-idle stability remain unmeasured.

Remaining visual gaps: broad regular wave bands and subtle basin/impact response; smooth striped waterfalls, straight crests and soft foam; simple sharp grass banks; elongated cliff wedges and a smoother contracted underside; bulky similar crowns, thin/wiry grass and simpler cottage details. Do not repeat rejected cliff sampling/profile/probe trials from archived notes as current todos.

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

Present the retained candidate, runtime clip and matched comparison for the user's aesthetic judgment. The agreed review-ready deliverable is complete once its evidence is packaged; do not silently begin another indefinite cosmetic loop. Future art work should respond to concrete user feedback on the remaining water, cliff or vegetation gaps while preserving editing, original assets and camera behavior.
