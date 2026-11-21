# Water scaling implementation plan

Goal: reduce persistent CPU work and dry-area scaling without changing water numerics or cliff appearance.
Spec: user's approved 2026-11-13 discussion; CURRENT_CONTEXT.md cliff protection and single-version constraints.
Architecture: preserve authoritative sparse editor data and existing conservative solver/public dictionaries. Use dense indexed scratch buffers and sorted wet work lists for flux, reuse immutable worker snapshots between explicit authoring syncs, and cache terrain-only image input. Sleep only after an exactly motionless solve; no volume threshold or changed timestep.
Execution: inline under writing-plans/executing-plans/TDD; user already approved proceeding. Work in the existing dirty project as required, no new project/worktree, blanket revert, automatic commit or unrelated edits. Review against two-file task-start snapshots rather than HEAD, which includes other work.

## Tasks

- [x] 1. Baseline and contracts: snapshot water_flow/water_renderer; add solver scaling probe and regression coverage. Prove stable pools stop solving and routine updates reuse immutable snapshots with edit/reset invalidation (RED).
- [x] 2. Solver: indexed Float64 buffers, precomputed neighbors, sorted wet traversal, reusable flux scratch; retain arithmetic/transfer order, basin behavior, tiny positives and public state. Exact sleep wakes on authored edits. Run water tests and compare old/new trajectories.
- [x] 3. Publication: snapshot cache keyed by reconciled authoring version/seed; version-aware result rejection; persist only changed volumes while keeping explicit write reconciliation; cache dry image input and patch wet/outgoing pixels. Test edits in flight, direct explicit sync, flush/reset and drying donor flow pixels.
- [x] 4. Evidence: old/new 1x/4x/16x solver + renderer CPU probes, native runtime FPS/frame-tail measurement, matched actual Godot views for several seeds/angles/day/night, current-stage suite, independent review, process cleanup and concise context record.

## Review focus

- Direct edits without revision increments remain supported by explicit sync/flush; no worker reads mutable editor records.
- Mid-worker height/removal edits discard stale visual results without losing conserved water.
- Last positive outgoing flux on a newly dry cell remains in the field texture.
- Float64 arithmetic, cell/direction traversal and transfer ordering match baseline; no epsilon drying.
- Reused images and snapshot records are immutable; time advances while exact sleeping solver does no repeated flux work.

## Progress / rulings

- Baseline snapshots saved under source_before/. Godot 4.7.2 verified.
- Scope ruling: no broad terrain contour refactor or GPU lighting redesign in this water-focused change. Measure their remaining costs separately; do not claim total island cost is now independent of area.

- Solver regression ruling: initial GDScript wet-list comparator caused +13% small-island solver time; replaced with native sorting of precomputed row-major indices. Final ABBA 100-tick solver 874.8→833.3ms at623 cells,2062.0→822.2ms at9968 cells. Full40-update pipeline807.4→720.2ms /3397.7→1064.6ms; all mass/discharge exact.
- Review fixes: positive hydraulic head prevents sleep even if tiny time/volume underflows; explicit persistence canonicalizes invalid raw volumes. Both RED→GREEN. TypedDictionary membership merge caught by byte comparison, replaced with bool set. Independent final review: no Important findings.
- Verification: final4560 exact checks across12cases/30steps;32 current-stage groups pass(28headless+4native). Historical gameplay_m1_m2_test excluded for removed stage-two actor assumption, not a pass.28 actual native2K captures/14pairs,11exact;3pairs each9pixels differ(max5/255), visually inspected. Runtime ABBA complete: native2K56.83→56.85,4K28.25→28.25,scaled4K68.03→67.91FPS, within run variation. No overall FPS, temperature or target-device improvement claim.
