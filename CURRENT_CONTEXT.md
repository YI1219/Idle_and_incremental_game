# Current project consensus and handoff entry
Updated: 2026-10-14. Latest explicit user instructions take precedence. Read this before code and related design. Source assets and review reports are evidence, not automatic todos.

## Current priority and approved scope

The project remains an ancient-style xianxia idle incremental game. The active demo is a freely editable floating-island workshop. The latest user reference (2026-10-14) is an intimate classical Chinese courtyard with warm sunlight, cool cloud-sea atmosphere, cream plaster, blue-grey roofing, layered foliage and natural grass/earth transitions. It guides the finish, not a fixed layout, character/UI replacement, or a merger of courtyard and village scenes. The user explicitly delegates art direction.

The latest pass reuses retained textured CC0 trees, bushes, flowers and fine grass. It keeps bark/leaf surfaces and UVs distinct, grounds the combined source mesh and preserves source-relative geometry. Warm front-right sun and cool ambient/background replace the uniform golden haze. The existing cottage now displays at 0.85 scale (previously 0.65); the five garden rows move 0.75 m forward to clear its facade. Grass-to-soil wear follows the same route as the more widely spaced textured stepping stones. Fine terrestrial grass is separate from pond reeds and accepts the existing compression mask. Authoritative island/pond data and original model files are unchanged.

Previous rim/bottom constraints remain: physical green turf clusters with local stone exposure, no continuous grey/beveled lip or painted green shoulder, varied stone clefts, side stones easing into one calm bottom, no orphan shore props. This round changes lighting/material response, not the retained island closure geometry. Extreme low-angle root intersections and angular joins remain visible; do not claim concept parity.

## Current workshop revision

Work is on `cursor/lighting-atmosphere-round1-ad0c` in `/Users/yi/Projects/games/yunlu-pr9-astra`. Current evidence is the [October 14 courtyard review](art/review/terrain_fidelity/2026-10-14/courtyard_finish/review.md), based on `696fe31`. The October 12 underside/material review and earlier studies are historical evidence, not current todos.

Camera controls and the full-island starting composition remain unchanged: right-drag and Q/E orbit, middle-drag/WASD pan, wheel zoom, default pitch −27°, yaw 16°, FOV 31°, height 21. The new gallery adds close courtyard framing and matched before/after views without baking that framing into navigation or terrain data. Home/reset/presets retain wheel-selected zoom/orientation.

All visible land still comes from authoritative terrain data. Crown/root solids, continuous lower envelope, affine grid closure, connected bank geometry, snapshot publication, edit animation, undo/redo and save/load remain. Trees retain four terrain-supported anchors and approximately 4.15 m mature height. Individual foliage kinds remain independent, instanced and terrain-supported; there is no bundled placement tool. Six existing nature texture imports now include mip chains; original image/model bytes are retained.

The two existing packed stone/ground maps remain active. Stone response is quieter under the new frontal light; paving uses the same mineral material. Physical turf and shader cover retain their world-space grass compression path, now also applied to the new fine meadow clumps. A gameplay system does not yet paint this mask. Pond/fall shaders use cooler clear-water tones, a damp shallow bed and less emission. Existing shore stones and reeds remain attached to supported banks.

Distant instanced mountain geometry, cloud decks and the existing cloud texture remain orbitable. Their shared palette is now cool blue-grey with a warm sun area. No new decorative land or background buildings are added. Existing Tripo cottage geometry is retained; no custom model generation or purchase occurred.

Verification details and exact current commands/results belong to the October 14 review. Art approval, functional checks and target-device performance remain separate. Two old tests of closed convex leaf lobes were retired because the new source has textured leaf cards; independent source-to-runtime triangle preservation now checks that bark and canopy stay in their original relation.

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

Review the [current courtyard comparison](art/review/terrain_fidelity/2026-10-14/courtyard_finish/comparison.html). The retained result improves lighting, architecture presence and material/foliage layering, but is not concept-equivalent. Main remaining asset gaps are the reference's sculptural pine, richer distant mountain silhouettes and finer local shore/cliff forms. Do not turn these observations into automatic generation tasks; any selected custom asset still follows the user-operated pipeline.
