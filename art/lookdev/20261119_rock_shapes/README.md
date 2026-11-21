# Rock shapes: fewer narrow pillars (2026-11-19)

User request (2026-11-19): deal with rock shapes first; the overall cliff face is great, but some rocks are too fragmented.

Scope: placement only. One production file changed, `scripts/terrain_editor/terrain_decoration.gd`. No mesh archetype, shader, palette, light, shoulder (primary/secondary mass) or terrain-data change. Single entry `scenes/terrain_editor.tscn`. Not art-accepted.

## What was fragmented

`checks/debug_parts.gd` tints each cliff generator's output (`diagnostic_parts_before/`). The outer face is built from broad `cliff_column_*` slabs 4.4 to 9 m wide. Between them stood pillars 1.2 to 3.3 m wide and about 10 m tall: every contour run shorter than 2.65 m (a corner chamfer, or the end of a terrace level) got its own pillar. Seen from the game camera these read as thin blades and strips, and the small gaps beside them showed chips of the core hull.

## Change

`_merge_narrow_columns()` runs after all rim runs are laid out and before the crown union. A pillar from an outer run shorter than `NARROW_OUTER_RUN` (2.65 m) is dropped when the broad slabs beside it can close over its span:

- a same-level broad slab on each side: both grow to just past the pillar centre;
- a same-level broad slab on one side and any outer pillar on the far side: that slab grows across the whole span.

A growing slab keeps its far end, so only the shared corner changes. A pillar is kept when it stands more than 0.35 m in front of that slab's rim line (an outward bump), when it has less than 2.8 m of land behind it (thin finger or small peninsula), when no broad slab is adjacent, when it carries a shoulder, or when it was trimmed by a waterfall curtain. Passes repeat so two narrow pillars in a row both fold in. Decisions use the pillar and its nearest neighbours only.

Rejected on the way: skipping every narrow run outright. It gave the lowest fragment counts but stripped all pillars from a small player-made peninsula (`cliff_near_consistency_test` caught it) and left see-through slits where slabs taper.

## Measured

`checks/id_render.gd` draws every cliff piece in a flat colour unique to its instance from 12 fixed views (8 orbit, 4 low); `checks/fragment_metric.py` counts connected regions. Strip: at most 1.7 m wide and at least 3 m long. Chip: under 0.9 m2. Sliver: at most 0.55 m wide. Metres are approximate away from the island centre. Sums over the 12 views:

| Layout | Visible pieces | Strips | Chips | Slivers | Core hull visible (m2) |
| --- | --- | --- | --- | --- | --- |
| seed 7301 preset 0 | 436 → 369 | 82 → 68 | 211 → 166 | 12 → 11 | 212 → 214 |
| seed 2104 preset 0 | 453 → 355 | 80 → 57 | 227 → 163 | 11 → 7 | 206 → 209 |
| seed 4242 preset 1 | 419 → 324 | 83 → 60 | 179 → 126 | 29 → 20 | 137 → 137 |
| seed 913 preset 2 | 525 → 503 | 84 → 76 | 281 → 275 | 27 → 23 | 108 → 104 |

Default layout: 30 columns → 24; all six narrow outer pillars merged; the five shoulder masses are unchanged. Seed 913 improves least: most of its narrow pillars stand on thin land or outward bumps and are kept.

## Evidence

- `compare.html`: before (Plan A, 2026-11-16) and after, native 2560×1440, 12 cameras × default, three held layouts and night.
- `ids_before_*`, `ids_after_*`: ID stills, `*_marked.jpg` overlays and `fragment_metric.json`.
- `diagnostic_parts_before/`, `diagnostic_parts_after/`: tinted generator views (diagnostic, not a production look).
- `checks/suite_final.json`: the 40-case regression list of the previous cliff round, rerun unchanged.

## Still there

Stepped slab bottoms on the reverse side, tone patches inside a single slab face, and the small rim notch above the reverse wall are untouched. The strips that remain are mostly slab side faces seen obliquely and interior terrace steps.

## Roll back

`checks/source_before/scripts/terrain_editor/terrain_decoration.gd` is the task start (`checks/start_sha256.txt`). Restore that one file; do not reset other uncommitted work.

`art_accepted: false`; `target_hardware_performance_measured: false`.
