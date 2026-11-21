# Cliff root veil, brushed faces, pond sheen and waterfall (2026-11-21)

Wave brief (2026-11-20): keep going on cliff form and material if major faces still read plain or the undersides still read stepped, then water and waterfall, which were judged stiff and paper-like. Performance is first-class; nothing here may depend on the top quality tier.

Scope: five shader files, two scripts and one project setting. No placement, palette, light or environment change. Single entry `scenes/terrain_editor.tscn`. Not art-accepted.

## Review of the 2026-11-20 cliff-presence captures

Compared with `../20261119_rock_shapes/` on the same cameras (default, seeds 2104 / 4242 / 913, dusk):

- Slab bottoms: better, not solved. The long slanted bevels at different depths were gone, but every slab still ended in a short dark chamfer, and neighbours end between -4.9 m and -7.1 m, so the foot read as a stepped dark skirting board under a drum-shaped island. `diag/parts_start/` (tinted generator view) shows the band is the slabs' own foot chamfer, not the core hull.
- Major faces: the character layer read well in sun. On the shaded reverse wall it read as streaked concrete: the grain of the mineral photo, stretched.
- A row of square tone patches sat under the grass lip. Cause: the short band under each slab's collar turns a few degrees against the face below it, and grazing fill light turns that into a visible value step per segment.

## What changed

1. Root veil (`stone_surface.gdshaderinc`, `cliff_column.gdshader`, `cliff.gdshader`). Between about -2.5 m and -5.7 m (with a slow wave along the rim) the stone and its facet shading ease to the palette mist tone (`stone_mist`, unlit, the way the cloud deck and the fall spray are drawn), and below that the rock frays away in tall wisps. The island root stands in the cloud sea at every hour: feet at different depths no longer show, and each tall face carries a value gradient from crisp top to soft root. `root_veil_strength = 0` restores the old look.
2. Brushed faces (`stone_surface.gdshaderinc`). `stone_cliff_character()` now reads the hand-painted wash (`gouache_stone_sol61`, already bound) instead of the mineral photo: the wash pulled about 3:1 along gravity and gathered into a few flat values gives broad brush planes; pulled about 6:1 with only its dark tail kept, it gives a few long dry strokes. Same four taps as before. The mossy brow and the resting "voice" field are unchanged.
3. Calm neck bands (`procedural_shard.gd`). The band under each slab's collar takes the shading normal of the face below it. Vertex positions are untouched, so outlines, joins and the geometry tests are as before; the square patches are gone.
4. Waterfall (`waterfall.gdshader`, rewritten body). The sheet leaves the lip glassy and clear, then loosens with the drop: the pattern is laid along the square root of the drop, so it creeps over the lip, stretches and speeds up; white threads gather into ropes that come in pulses; the sheet thins between ropes so wet rock shows through; the outline frays instead of staying a ruled rectangle; a slow billow moves the loosened sheet in the vertex stage. An outer fall thins into the root veil with the rock behind it. Five noise lookups, down from seven.
5. Pond (`water.gdshader`). The surface carries the engine's own sky radiance through a dielectric fresnel (`sky_sheen`), so the far side of a pond lifts toward the sky tone and follows the hour of the day. It is held at .28: at .50 the lowest camera pitch turned the ponds from jade to pale sky blue. The sheen reads a steeper copy of the existing ripples. Sparse drifting light lines are drawn on the level line of two ripple fields that move in different directions, so they bend, join and part instead of sliding as one pattern; they reuse fields the shader already had. Per-light shading is skipped (black albedo, painted glint).
6. Cheaper stone shading (`stone_surface.gdshaderinc`, `preview_quality.gd`, `project.godot`). Two terms that cost a lot and show almost nothing:
   - The micro-relief (`stone_mineral_normal`: four noises and six taps per cliff fragment) turns a normal by about two degrees. A new global `stone_fine_relief` lets balanced preview quality skip it; "native quality" keeps it.
   - A stone-tooth term cost three taps to move the result by at most 0.2%. Removed for every stone material.
   - Together a balanced-mode cliff fragment goes from 19 taps and 8 noises to 10 taps and 4 noises. Picture change against relief-on stills: mean 0.04 to 0.16 of 255; pixels differing by more than 4/255 stay under 0.03% (`cliff_close`, `reverse`, `game`).

## Cost

`checks/probe_ablate.gd` (the 2026-11-20 probe plus `swap:`, which runs the task-start copy of a shader in the same live scene, and `global:`), M4 Pro on AC power, real fixed-pixel target, 4 s samples.

| Measurement | 3840×2160 | 1920×1080 |
| --- | --- | --- |
| Items 1, 4, 5: current vs task-start shaders, 3 rounds (`cost_*.json`) | 29.94 vs 30.13 ms | 12.25 vs 12.32 ms |
| Item 6: relief skipped vs relief on, 6 rounds (`relief_tier_*.json`) | 29.60 vs 30.10 ms | 12.11 vs 12.25 ms |

- Items 1, 4 and 5 are inside round-to-round spread (about 0.3 ms at 4K): cost-neutral here. That probe ran with `sky_sheen` at .50; .28 is the same code path.
- Item 6 saves about 0.5 ms at 4K (1.7%); all six relief-off rounds were faster than all six relief-on rounds. At 1080p the mean saving is 0.15 ms and the ranges overlap.
- Also measured (`tier_*.json`, 4 rounds): `cliff_character = 0` and `reflection_strength = 0` change nothing measurable on this machine, so the brushed layer and the pond's reflection march are free here. Item 2 was not timed separately; it swaps which bound map the same four taps read.
- Target laptops remain unmeasured. A weaker GPU pays more per tap, so the tap counts above are the better guide there.

## Evidence

- `compare.html`: before (2026-11-20 or 2026-11-19) and after, native 2560×1440, 12 cameras × default, three held layouts and dusk; plus a motion loop (eight stills 0.15 s apart) with task-start shaders on the left and current shaders on the right.
- `final/`, `final_held2104/`, `final_held4242/`, `final_held913/`, `final_night/`: 24 frames each, same script and arguments as the two earlier sets (`../20261114_cliff_optimization/checks/capture.gd -- --suite=full`, `--seed/--preset` for held layouts, `--progress=0.83` for dusk). These are balanced-mode shading (relief skipped) at the capture tool's 4× MSAA.
- `motion_before/`, `motion_after/`: 1280-wide stills for the loop (`checks/debug_parts.gd --plain --phases=...`, `--before` for the left side). `motion_before/` was rendered before items 2, 3 and 6 existed, with `--before` swapping the four shaders of items 1, 4 and 5 back, so it is the task-start look.
- `diag/parts_start/`: tinted generator view of the reverse foot at the task start (diagnostic, not a production look).
- `checks/suite.json`: the 40-case regression list of the earlier cliff rounds, rerun unchanged through `checks/run_suite.py` after every change above: 40 ran, 0 failed.
- `checks/normal_entry.log`: the normal scene entry run for 150 frames (`godot --path . --quit-after 150`), no error or shader message.
- `checks/production.patch`, `checks/final_sha256.txt`, `checks/source_before/`, `checks/start_sha256.txt`.

## Still there

- At dusk the dark warm wall meets the bright veil in a fairly strong band.
- At the lowest camera pitch the far pond reads paler and bluer than before. That is the sky on the water; lower `sky_sheen` if the jade should win.
- Seen from directly below, the frayed slab feet are open shells. The game camera never goes there; a low free camera would.
- Pond reflections of bright walls show as pale shapes.
- A slab whose foot ends above about -5.2 m still shows faintly through the veil (lower left of `final_held4242/foot_reverse.png`).
- The veil heights are constants tied to the current hull depth. If island depth becomes editable, they should follow it.
- The capture tool records its own MSAA and shadow settings but not `stone_fine_relief`; its stills follow whatever preview quality last set (balanced, so 0).

## Roll back

Restore from `checks/source_before/`: five shaders under `shaders/terrain_editor/` (`cliff.gdshader`, `cliff_column.gdshader`, `stone_surface.gdshaderinc`, `water.gdshader`, `waterfall.gdshader`), two scripts under `scripts/terrain_editor/` (`procedural_shard.gd`, `preview_quality.gd`) and `root/project.godot`; or apply `checks/production.patch` in reverse. Each numbered item can also be undone alone from the patch. Do not reset other uncommitted work.

`art_accepted: false`; `target_hardware_performance_measured: false`.
