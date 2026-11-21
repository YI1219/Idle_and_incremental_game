# Cliff presence attempt (2026-11-20)

Written on 2026-11-21 by the following session, from this package's files and the patch scripts the 2026-11-20 session left behind. That session ran out of quota after capturing and did not review its own stills. Not art-accepted.

## What it changed (all uncommitted)

- `shaders/terrain_editor/stone_surface.gdshaderinc`: new `stone_cliff_character()` and `cliff_character` uniform. On steep faces it adds long mineral plates (the mineral map stretched about 3:1 along gravity), fissures (the same map stretched about 7:1, dark tail only) and a mossy brow running down from the grass lip, all world anchored, with a broad "voice" field that lets parts of each face rest. Four taps of an already bound map and two value noises.
- `shaders/terrain_editor/cliff_column.gdshader`, `cliff.gdshader`: call the character layer.
- `scripts/terrain_editor/procedural_shard.gd`: slab archetypes end in one short blunt foot chamfer; fold, tilt and pitch values reduced so foot lines stay close to level.
- `scripts/terrain_editor/terrain_decoration.gd`: `tier1_frac = 1.0`, so outer slabs end at the local hull foot instead of plunging up to 42% below it.

`checks/source_before/` and `checks/start_sha256.txt` are that session's starting point.

## Checks it left

- `checks/suite_try3.json`: 40 tests, 0 failed.
- `checks/character_cost_3840x2160.json`, `character_cost_1920x1080.json`: character layer about 0.5 ms at 4K and about 0.74 ms at 1080p, both inside run-to-run noise.
- `final/`, `final_held2104/`, `final_held4242/`, `final_held913/`, `final_night/`: 24 frames each, `valid=true`.

## Review (2026-11-21)

Against `../20261119_rock_shapes/` on the same cameras:

- Bottoms improved but still read as a stepped dark skirting: each slab ends in a dark chamfer, at depths between -4.9 m and -7.1 m.
- Faces read well in sun; on the shaded reverse wall the streaks read as weathered concrete rather than painted rock.

The follow-up is `../20261121_cliff_water/` (root veil, pond and waterfall), which keeps everything above and builds on it.
