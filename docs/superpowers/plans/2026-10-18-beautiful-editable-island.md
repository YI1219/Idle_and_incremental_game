# Beautiful Editable Island Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. The user explicitly authorizes direct execution and a longer goal; no repeated plan-approval gate.

**Goal:** Deliver a coherent, beautiful, playable stylized island; likeness to the old cliff concept and geological realism are not acceptance requirements.

**Architecture:** First compare three finished native-scene treatments driven by the same editable terrain field and retained props. Carry the strongest visual direction into ordinary editable saved data integration, then verify editing, different layouts and seeds. User art acceptance remains required before goal completion.

**Tech Stack:** Existing Godot density/mesher/terrain renderer, GDScript, shaders, native captures, Python review page.

**Spec:** docs/superpowers/specs/2026-10-18-beautiful-editable-island-design.md

## Global Constraints

- Preserve original assets, old saves/default and unrelated dirty state in existing feature checkout.
- No decorative locked ground, new gameplay/characters/tree/building replacement, blind paid generation or seed/detail sweeps.
- User wants action: choose ordinary art/implementation details and proceed.
- Tests/finite geometry/source investigations never substitute for beauty. Two failures retire that mechanism, not the whole goal.

## Review Focus

- Attractive fixed-view diorama must also hold from reverse/low/play cameras.
- Experimental base object is not portable saved data until profile integration; label it.
- Rounded edge must not remove cottage footprint support or produce floating roots.
- New profile must preserve legacy save geometry and share player/prefab editing.
- Mutated cells, seed regeneration, pond levels and capacity/history must stay coherent.

### Task 1: Reference and visual standard

Files: spec above, CURRENT_CONTEXT.md, docs/art/scene_art_and_module_spec.md, art/review/terrain_fidelity/2026-10-18/beautiful_island/reference_sources.json and README.md.
- [x] Inspect official screenshots; separate visual observations from unknown algorithms.
- [x] Replace old target-likeness priority with current user beauty-first intent; preserve factual past failures as history.
- [x] Preserve baseline before changes; compare using full scene, props and actual cameras.

### Task 2: Three finished native alternatives

Files: tools/art/storybook_island_field.gd, tools/art/storybook_island_finish.gdshader, tools/art/capture_storybook_island.gd, art/review/terrain_fidelity/2026-10-18/beautiful_island/.
Consumes: ordinary cells and shared RockSculpt node values; existing renderer and assets.
Produces: soft/graphic/terraced style native captures, exact recipes and explicit prototype limits.
- [x] Implement experimental field and coordinated finish without production defaults.
- [x] Capture same whole/close/reverse/low/play views with retained architecture/foliage, plus old default.
- [x] Inspect all styles as full images; choose or redirect based on visual evidence. Existing geometry checks apply where relevant; no mirrored tests for throwaway low-impact art code.

### Task 3: Adopt strongest visual direction into editable data

Likely files: scripts/terrain_editor/rock_terrain_base.gd, terrain_data.gd, terrain_renderer.gd, editor.gd/editor_hud.gd and isolated new profile module/shader only as necessary after actual visual decision.
- [x] Specify selected serialization and legacy compatibility: reuse ordinary v4cells/local-base/density overrides, no new profile/schema. Four offline authored presets, not arbitrary-contour runtime compilation.
- [x] Add meaningful failing fixtures for changed save/edit behavior, implement and rerun affected existing suites.
- [x] Expose reversible candidate preview through real editor; keep old scene accessible.
- [x] Verify two contours/layouts and two seeds without hidden decorative terrain.

### Task 4: Integrated visual and functional evidence

Files: targeted tests for selected integration, capture/review tooling and final report.
- [x] Fresh actual candidate geometry/support, sculpt/place, undo/redo/save/reload checks; no reuse of older pass claims.
- [x] Matched old/candidate five-view comparisons across two layouts/two seeds and actual performance records with device/settings.
- [x] Fresh independent milestone review per executing-plans; both Important export-loading findings resolved and independently rechecked. Final art acceptance stays open.
- [ ] Commit/push reversible work; show practical preview and concrete limitations to user.

### Task 5: User art acceptance

- [ ] User explicitly accepts the delivered candidate's overall art. Until then goal remains active/incomplete; additional art feedback steers the same goal.

Current candidate milestone2026-10-19: retained sources+ordinary v4records, original default/save separate. First trial loses tree support and retains old deep taper; archived pass1. Current145/153cell cases retain both trees via actual authored footprints, shallow rounded underside in saved density edits. Full art remains unaccepted (broad walls/painted joins); user feedback requested on concrete40frame gallery. Preview land placement is tested; no new building-placement UI. Runtime/full rebuild cost remains~3sec. Independent milestone review found assert-side-effect and raw-PNG loading export defects; one fix pass moves deserialization outside assert and uses imported Texture2D, resource/static regression2/2green. No installed release templates/preset, release build untested.
