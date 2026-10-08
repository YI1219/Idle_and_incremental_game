# Current project consensus and handoff entry
Updated: 2026-10-06. Latest explicit user instructions take precedence. Read this before code and related design. Source assets and review reports are evidence, not automatic todos.

## Current priority and approved scope

The project remains an ancient-style xianxia idle incremental game. The active demo is a freely editable floating-island workshop. The latest user image guides its two terraces, two lakes, waterfall sequence, modest cottage, faceted cliffs and vegetation. This reference composition does not prescribe every future courtyard layout. Tiny Glade guides coherence of editing and adaptive detail; its internal terrain representation has not been inferred.

The latest explicit request is to match the supplied CURRENT/TARGET images in the actual running Godot scene, using an iterative screenshot loop. Preserve both editable terraces, connected ponds/falls, the small cottage/garden, common tree heights and shallow rock support. Reshape local geometry and revise rendering as needed; avoid a global yellow/desaturation filter, background buildings and foreground framing objects. This overrides earlier fixed-camera and narrowly color-only constraints. The user authorized direct implementation, with no repeated design approval. Original assets and unrelated work remain intact.

Camera now supports **right-drag orbit (yaw and bounded pitch), Q/E horizontal orbit, middle-drag/WASD horizontal pan, wheel height/zoom**. Orbit pivots around the current ground focus and preserves wheel-selected height. Home/reset/presets preserve zoom and orientation. Focus loss releases both pan and orbit. Default composition remains pitch −27°, yaw 16°, FOV 31°, height 21.

## Current workshop revision

Work remains on `codex/terrain-fidelity` in the primary checkout. [Target-match runtime review](art/review/terrain_fidelity/2026-10-06/target_match/review.md) is the latest implementation and screenshot evidence, **not aesthetic acceptance**. The [homestead pass](art/review/terrain_fidelity/2026-10-06/homestead/review.md), [shape checkpoint](art/review/terrain_fidelity/2026-10-06/shape_checkpoint/review.md) and [previous rework](art/review/terrain_fidelity/2026-10-06/rework/review.md) are historical. Candidates `4d891bd` and `3a73663` were not accepted.

The sparse XZ height grid, shared contours, presets, two terraces and lake boundaries/elevations remain unchanged. Complete terrain/detail/prop/picking snapshots still publish together at two chunks per frame; idle frames do not rebuild. Editing, undo/redo and layout save/load remain. Local rock relief now uses smaller, less oblique cells and reduced protrusion; the supporting shell still uses 60% depth. Picking uses the same modified mesh. External falls end beneath the local shell and fade; connected receiving falls retain their terrain-derived endpoints.

The retained cottage stays at the prior 0.65 scale, with light plaster and timber posts. Five supported kitchen-garden rows remain, with short terrain-supported fence additions. The four original tree anchors remain; canopy proportions and facet colors changed while mature height normalization remains approximately 4.1 m. Shore stones retain real shoulders instead of flattened slab tops. Reused curved grass forms reeds, and small procedural floating leaves and beveled stepping stones replace unsuitable local shapes. Flowers, shrubs and cliff sprays remain terrain-supported and instanced.

Rendering (lighting round 1, branch `cursor/lighting-atmosphere-round1-ad0c`; see [lighting round 1 review](art/review/terrain_fidelity/2026-10-08/lighting_round1/review.md)) uses a lower warm back-right sun with fully opaque soft shadows, a faint neutral shadowless fill and warm-grey ambient. Linear tonemapping is kept, since Filmic/AgX grey out the warm palette. Stronger SSAO adds contact darkening, and glow blooms only HDR values (the sun core and water glints). A thin exponential fog leaves the sky unaffected. Water has stronger moving slopes, restrained pale wavelets, sky radiance and supported concentric receiving ripples. Falls have fine descending filaments and local scattering fill. No colour-grade LUT, lightmaps, volumetric fog, generated replacement artwork or offline render is used.

The background is three shared mountain meshes split into cullable angular MultiMesh sectors with ridge foliage, plus the existing cloud texture recolored in an angular sky shader with a haloed HDR sun. Mountains and three world-anchored flat cloud decks between the rings share the sky gradient (`sky_palette.gdshaderinc`) for aerial perspective, so farther layers dissolve into a warm cloud sea. Mountains sit 400–800 m away and follow navigation focus translation to stay distant while retaining orbital perspective. Camera far plane is 1800 m. No buildings, collision, playable/decorative ground or foreground props were added to the background.

Fresh verification: 28/28 headless terrain test scripts plus 2/2 actual-render suites pass (22 runtime assertions and 7 cottage material assertions). Fresh visual evidence includes the 1671 × 941 default composition, left/right/back orbit, garden/water close views, wider zoom and gameplay UI. Eight intermediate image candidates and the baseline remain for audit. Remaining gaps versus TARGET: mountains/clouds and foliage are simpler; cliff relief is still procedural and some shore rhythms repeat; target's richer, softer indirect-light finish is not fully achieved; water reflects sky, not cottage/trees. Performance acceptance is separate: current-host render counters are recorded, but target-laptop FPS and long-idle power/stability remain unmeasured.

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

The owner reviews lighting round 1 screenshots before the next small round; later rounds cover geometry, cliffs, vegetation and props. Review the actual screenshots against the supplied TARGET. Do not treat passing geometry/runtime checks as visual acceptance. Further art work should focus on the remaining mountain/cloud softness, vegetation silhouettes and rock/shore variation, while preserving the editable data and current camera. Target-device editing latency, GPU cost and idle power/stability need separate measurement.
