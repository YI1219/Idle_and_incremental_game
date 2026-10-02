# Courtyard sandbox implementation

Goal: prioritize a working building loop in the existing play scene over further static art.

Scope: retain sparse land/economy rules. Add grid-aligned nature placement, selection by footprint, move/cancel/remove, movable unique cottage at its existing facing, green/red previews with reasons, manual layout save/load. Keep production/spring/gate fixed, no scaling/stacking/rotation or new costs. Existing support terrain remains locked, explicitly distinguished from editable economy cells. No village/exploration editing or character asset changes.

Architecture: `scripts/build/layout.gd` stores entity records and validates support, water, reserved cells, overlap, cottage approach and player exclusion. `builder.gd` coordinates live nodes and atomic layout save/load; `build_panel.gd` owns compact paper/jade controls. `island_shell.gd` delegates building input and retains economy authority. Moving the cottage updates SpaceState.house_door, existing entrance and exit logic, collisions and path material. Preview UI consumes clicks before world edits. Ordinary movement resumes on leaving Build.

- [x] Pure placement tests: overlap, water/void, occupied cells, move rollback, protected house, invalid schema/roundtrip.
- [x] Implement layout model and scene controller; avoid changes to assets. Record original source hashes.
- [x] Integrate UI, feedback, footprint grid, real model ghost, collision and moved cottage doorway. Keep Q/E, wheel and middle-pan.
- [x] Save layout + editable land only with temporary-file rename. Load validates into scratch state before committing; does not rewind resources or production time. Manual load, no automatic overwrite of player saves.
- [x] Verify main-scene placement/move/remove, input isolation, door relocation, persistence roundtrip and invalid-load rollback. Run related existing tests; capture actual engine valid/invalid previews and rearranged scene.
- [x] Update current scope and handoff docs. Explicit limits: no full production placement, river editing, full connectivity routing, multiplayer or art/performance acceptance.

Results: layout 17/17, runtime 34/34; existing related regressions and engine captures recorded in `art/review/sandbox/2026-09-21/review.md`. No dependencies installed, no Git repository available, no assets regenerated.
