# Handoff check and first module measurement

Date: 2026-09-20. This round read CURRENT_CONTEXT.md, AGENTS.md, and the scene-art module spec, then checked code, GLBs, and source files, and reran tests. This is stage evidence. Do not promote production suggestions into user decisions.

## Requirements, suggestions, implementation, goals

| Category | Current conclusion |
| --- | --- |
| User-confirmed | Ancient-style xianxia idle incremental; management, production, long-term growth, and exploration as core; Sea of Consciousness Courtyard supports sandbox placement; village is independent; exploration is toward procedural generation; concept image is look-and-finish reference only; keep valid assets |
| Production suggestion | A few assets from the same pack first, compared sparse, dense, relocated, and dry; this round's test heights, counts, and cameras are trial parameters, not official asset specs |
| Implemented | Courtyard/interior/exploration switching; cell laying and deletion; economy/production/research/fixed-fork exploration kernel; basic character actions, sword moves, practice dummy; Tripo cottage and doorway collision; 47-state water-edge logic |
| Not implemented | Independent village runtime scene; full building and nature-module sandbox placement; procedural exploration; river-bridge interfaces that move and turn with layout |
| Unverified goals | Overall art passing; traversal and operations on any legal combination; full-action character intersections; about 60 FPS at low quality on the target thin laptop; long-session power and stability |

Implementation basis: `scenes/play.tscn` → `scripts/play/game.gd`; `autoload/space_state.gd` is only outside/inside/explore; `scripts/sim/explore_trip.gd:reset_map()` is a fixed 14-cell fork. Build in `scripts/world/island_shell.gd` only attaches ground cells; cottage and bridge coordinates are still written in scripts. `river_terrain.gd` bridge display and traversal depend on fixed coordinates; `bridge_cells` is not yet a generic bridge instance definition; terrain rebuild resets the default river. This round did not expand the above.

## Runtime assets, physical

[GLB stats and SHA-256](runtime_assets.json) were read from runtime files this round.

| Model | Triangles | Materials | Notes |
| --- | ---: | --- | --- |
| Qinglan | 12958 | 6 | 28 joints; idle/walk/attack_1/attack_2/dodge five animations |
| Starter sword | 1068 | 3 | player.gd does bind starter_jian.glb to the right hand |
| Cottage | 2966 | 4 | cottage.gd does load cottage_tripo.glb; originals and work files kept |

This round's [courtyard screenshot](courtyard.png), [character near](character.png), [bridge](river_bridge.png), and [interior](interior.png) are from Godot, not concept images. Cottage and character load correctly, but large ground, riverbank, and block facilities are still prototypes. Do not claim the look is accepted.

## Function recheck

After the project and documentation were renamed to English, all 11 existing scripts were rerun again with fixed 60 FPS and exited 0. [Commands and outputs from the English project](english_project/tests.json). Runtime model hashes still match the initial inspection. Development communication and new documentation now use English; player-facing in-game language stays Chinese.

Godot 4.7.2, headless, project previewer style `--fixed-fps 60`. This round's 11 existing test scripts all exited 0; [commands and full output](tests_fixed60.json). Demo 21/21, space 21/21, camera 8/8, terrain 794/794, economy kernel 6252/6252, production 17/17, research 32/32, exploration 30/30; sword rules/sword runtime/combat all failures=0.

First run without a display-frame cap, space test 20/21. That record is not hidden; see [first results](tests.json). Later fixed 60/120 both 21/21; at 240 the original test was 18/21. Evidence: transitions update in `_process`, tests observe on `physics_frame`; higher display frame rates miss a source-space fade peak that lasts only one display frame. [Per-display-frame diagnosis](space_sampling_240.log) records alpha=1 already observed before each of four swaps, still 1 at swap. The diagnostic script is in the same directory. This conclusion only explains peak-sampling false failures; headless diagnosis is not actual-display transition-quality acceptance. This round kept tests and game logic. When expanding frame-rate tests later, observe matching metrics on display frames and physics frames separately.

## Nature-module screening already done

Obtained the Kenney Nature Kit free pack, checked original license, version, and summary, extracted five models, and under existing Godot lighting completed three layouts × three views = nine images plus short render sampling. Details: [module trial report](../../module_probe/2026-09-20/review.md). Current conclusion: do not adopt these five models directly as official nature art. Original pack and trial are kept; do not replace already-valid runtime models.

The initial Quaternius download failure was resolved after the user adjusted connectivity. Standard was subsequently downloaded, its enclosed CC0 license checked, and five models compared in the same three layouts. See the [Quaternius comparison](../../module_probe/2026-09-20/quaternius/review.md). Pro/Source were not purchased, and no Tripo task was started.

Next: refine the Quaternius sample’s foliage readability and ground coverage. Do not expand the rejected Kenney sample. After visual module candidates hold, implement and measure actual placement, doorway/river-bridge traversal, and layout updates.
