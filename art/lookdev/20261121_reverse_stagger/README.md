# Reverse wall: from a regimented row to a staggered cliff (2026-11-21)

Owner call (2026-11-21): the back of the island (`reverse`, `foot_reverse`, clearest on seed 7301 at day and dusk) is a row of like-width, like-height vertical faces with no stagger, like a palisade. This is a form and arrangement problem of the generated cliff, not a texture or mist problem. Earlier form locks stay in force: heightmap is the authority for the base shell, visible cliffs are modular multi-face groups, organised main-face width and depth, one primary and one secondary face, natural local protrusions, no guard wall, no pillar arrays.

Scope: one production file, `scripts/terrain_editor/terrain_decoration.gd` (placement only). No shader, material, light, palette, mesh-kit or scene change. Single entry `scenes/terrain_editor.tscn`. Not art-accepted.

## Cause

Measured on the layout data (`checks/plan_dump.gd`, `checks/plan_metric.py`), not guessed from stills:

1. Every outer slab stood at nearly the same distance in front of the heightmap contour (0.66 to 0.89 m), so in plan the whole rim was one smooth line. The front-back step between neighbouring faces was 0.0 to 0.1 m all the way round (`diag/before/plan_7301.png`).
2. Slab width follows contour-run length, and a gently bowed rim is cut into near-equal chords, so the back got widths of 4.7 to 6.3 m in a row.
3. All relief elsewhere came from the lowered rock groups ("shoulders"). Whether a run may carry one was decided by three gates tuned to the default island: a chance weighted by five fixed compass lobes around the island centre (the back-left falls in a gap between two lobes), a hard exclusion of both ends of the island by x coordinate, and a land probe that the stair-stepped contour of a gently bowed wall also fails. On seed 7301 the back-left wall and the west end, 38 m of rim, could not get a group.

Result before: the longest chain of neighbouring outer slabs with no group and every joint flush was 9 slabs, 38.1 m, wrapping the back and the west end. That is the row in the owner's stills.

## What changed

Two additions in `terrain_decoration.gd`. The existing gates and their results are untouched, so the groups the front already had stay where they were.

1. Stagger of the main faces (`_stagger_outer_faces`, runs after the narrow-pillar merge). Each outer slab takes a role from its own width plus a fixed per-slab number:
   - primary (broad): steps 0.80 to 1.25 m forward, turns 3 to 6 degrees, and takes over a plain neighbour that continues its plane, so one broad face replaces two alike ones;
   - secondary (narrow): steps back toward the contour (never closer than 0.46 m, so the base shell stays covered), turns, and the slabs beside it stop at its ends, so it shows as a recessed face and not as a slot;
   - the rest shift by up to 0.12 m either way.
   Slabs that offer a rock group hold their place, and the faces beside them do not step forward as well: the group is the protrusion of its stretch of wall.
2. Rock groups offered by the rim itself (`sh_filler` in `_rim_run`, selection in `_prune_overlapping_buttresses`). A share (37%) of the broad outer runs that the old gates left bare offer a group, with a land probe that reaches further in so only a real nose fails it. One is kept only where no group of the first kind was offered within 5.25 m and it outranks every other offered group within that radius. Their tops come from 1.0 m to about a third of the wall height below the lip (3.6 m at most), so groups differ in height without turning into pedestals.

Both additions decide from the slab itself and one neighbour to either side. Nothing depends on island-wide coordinates.

## What was tried and dropped

- Front-back steps of about half a metre only (first version): invisible on a shaded wall at the review cameras. A step has to be about a metre, or come with a change of facing, to read.
- A group on every eligible bare run within 8.5 m spacing: fixed the row, but gave eight groups on the default island and five similar blocks in one view. That broke the existing check for the owner's 2026-11-16 "Option A" restraint (2 to 6 groups), and it did look busy. Kept the restraint: six groups now.
- Groups set low on the wall (tops 30 to 48% down): read as a pedestal with a wide flat top from above. Capped the drop.
- Roles by ranking each slab against its neighbours, and groups chosen with a 9.5 m radius: both chained through neighbours, so an edit could change cliff pieces more than 10.5 m away (two locality checks failed). Roles are now intrinsic and every interaction is one hop.

## Result

Longest plain row (neighbouring outer slabs, none with a group, every joint under 0.30 m of step), from `diag/before` and `diag/after`:

| Layout | Before | After | Groups |
| --- | --- | --- | --- |
| seed 7301 preset 0 | 9 slabs, 38.1 m | 4 slabs, 21.8 m | 5 → 6 |
| seed 2104 preset 0 | 8 slabs, 34.8 m | 4 slabs, 21.7 m | 5 → 6 |
| seed 4242 preset 1 | 4 slabs, 22.4 m | 2 slabs, 13.1 m | 4 → 5 |
| seed 913 preset 2 | 12 slabs, 47.2 m | 5 slabs, 22.7 m | 6 → 7 |

On seed 7301 the back now reads, right to left in `foot_reverse`: a rock group at the corner, a plain face, a broad primary face standing about a metre forward with the lawn following it out, two plain faces, then the existing group. The remaining longest row is on the front-right, where the fall and the terraces already break it up.

## Evidence

- `compare.html`: before (2026-11-21 cliff-water set) and after, native 2560×1440, 12 cameras × default, dusk and three held layouts, flip in place; plan drawings before and after; the table above.
- `final/`, `final_night/`, `final_held2104/`, `final_held4242/`, `final_held913/`: 24 frames each, same script and arguments as the earlier sets (`../20261114_cliff_optimization/checks/capture.gd -- --suite=full`), run by `checks/capture_set.sh`.
- `diag/before/`, `diag/after/`: plan drawing, layout JSON and metric JSON per layout (`checks/plan_all.sh`).
- `checks/suite.json`: the 40-case regression list of the earlier cliff rounds, unchanged, rerun on the final file: 40 ran, 0 failed. This includes the two locality checks and the Option A restraint check that earlier versions of this change failed.
- `checks/normal_entry.log`: the normal scene entry run for 150 frames (`godot --path . --quit-after 150`), no error or shader message.
- `checks/production.patch`, `checks/final_sha256.txt`, `checks/source_before/`, `checks/start_sha256.txt`, `checks/tree_at_start.patch` (the whole uncommitted tree as it stood when this task began).

## Still there

- A primary face carries its lawn out with it, so the grass edge stands up to about 2.1 m outside the heightmap cells there (it was up to 0.9 m everywhere before). Nothing can be placed on that strip. A bare rock crown on those faces would be the next step if the strip reads as a lawn tab.
- The share and the per-slab numbers decide where groups land. On the default island the one new group stands at the back-left corner. Other seeds get one to three; no upper bound is enforced beyond the spacing rule.
- The older note that the large reverse faces lack texture and presence is only helped by the new planes and returns; the stone shader is unchanged.
- The veil, the shaded-wall streaks, the hard dusk junction between wall and veil, the pale far pond and the slab feet from below are as they were in the 2026-11-21 cliff-water package.
- Cost: none measurable. Cold cliff layout of the default island, headless, five builds, twice each way: 271.4 ms after against 271.5 to 272.5 ms before (`checks/layout_time.gd`); the placement stage alone goes from about 55 to 59 ms. No shader or draw-call change, so frame time was not re-measured.

## Roll back

Restore `scripts/terrain_editor/terrain_decoration.gd` from `checks/source_before/scripts/terrain_decoration.gd`, or apply `checks/production.patch` in reverse. Setting `STAGGER_FILL_SHARE` to 0 removes the new groups only; returning early from `_stagger_outer_faces` removes the face stagger only. Do not reset other uncommitted work.

`art_accepted: false`; `target_hardware_performance_measured: false`.
