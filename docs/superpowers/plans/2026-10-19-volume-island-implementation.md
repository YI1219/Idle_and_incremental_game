# Freely Sculptable Ancient Island — Implementation Plan

Approved in chat on 2026-10-19. Execute inline with the Godot and Blender production skills. This supersedes the previous first-gate plan's limited editing scope and static-mother-first sequence. User art gates remain mandatory.

## Goal and architecture

Hybrid authored forms, low-poly assets and reusable surface materials; one authoritative editable volume, including caves and overhangs. Internal sampling is not a visible block grid. Preserve the original scene, source assets, old saves and unrelated experiments. Direct native screenshots only, no review websites.

## Delivery gates

1. **Local art + sculpt gate:** reuse an actual existing closed rock source; prepare a 0.25m editable patch with grass/soil/stone, bottom and lake. Exercise tunnels, shelves and a breached basin. Compare source versus converted geometry and simple versus detailed materials. Deliver native screenshots and real measured build cost. Do not expand rejected shapes.
2. **Volume architecture:** chunked local builds, immutable job snapshots, shared border samples; main-thread coherent publication of display/picking/collision/support and stale-job rejection. World-space materials cover new faces. Versioned document and old-loader compatibility. No up-front adaptive voxel/native-plugin rewrite.
3. **Complete mother scene:** approved gray-tile/cream-wall/timber cottage, geometry-first authorized Tripo flow after four inspected separate views; initial1000–1500actual triangles, one material/1024atlas. Existing rocks refined first; offline baking only if useful. Independent vegetation/props and geometry-derived shores. User art acceptance before second layout.
4. **Sandbox:** independent object placement/move/rotate/delete, real footprint support, expand/contract/heights and arbitrary sculpt; history/save/load; second distinct layout using identical modules/rules.
5. **Acceptance:** source/default preservation, cross-chunk tunnels/thin ledges/isolated solids, fast edits, stale builds, water breach, undo/redo and save fidelity. Art acceptance is separate. Measure original-scale benchmark and2xarea/4xprops stress scene;1080plow~60FPS target still needs MacBookAir/Windows thin-and-light tests, plus2houridle test.

Water default (question unanswered): static levels and explicit waterfall outlets, three-dimensional basin validity after editing; invalid water hidden and repair/undo/drain available. No real-time fluid simulation. Detached solids are static; structural-collapse physics is not added.

## First gate contract

- New independent `terrain_volume` document/base/surface and a native study scene; no default scene or old loader modification.
- Existing Tripo master v2 is a source study, not an approved official asset. Preserve GLB/hash; derive a runtime preset reproducibly from its closed triangles. No new paid generation or texture job at this gate.
- Use existing0.25m sculpt tools/history. Persist new source identity + overrides in separate version5study saves; reject mismatched sources atomically. This does not migrate old saves.
- Canonical field controls terrain geometry, picking and lake validity. Decorative props never conceal a missing solid boundary.
- Initial implementation may rebuild the small patch synchronously to measure the actual bottleneck; do not claim async/chunked editing implemented until stage2 exists.
- Compare same-camera states; distinguish old whole-scene baseline from this isolated patch. Do not claim an isolated patch is the final whole-island improvement.

## Progress

- [x] Baseline legacy sculpt29/29 fresh; new volume test RED (document missing).
- [x] Sample preserved source and implement patch document/history/save/basin validation.
- [x] Native material/shape/edit captures; inspect all relevant views and record limitations. Art is explicitly not passed.
- [ ] User local art gate; not implied by passing tests.
- [ ] Stages2–5, subject to preceding user art gates.

## Execution decisions

Work in the current checkout using independent new entrypoints: latest reference/design changes and ignored source binaries live here; do not move, reset or clean them. This is a local validation scene, not production integration. No implementer delegation. No final-goal completion claim before user art and target-device acceptance.

## Checkpoint2026-10-20

Fresh document19/19 and native11/11; legacy sculpt29/29/base23/23.11native captures, clean final runtime/capture logs. TwoP2review findings reproduced RED and fixed GREEN in one pass: empty terrain publication and a center pillar falsely invalidating surviving lake water. No deferred review minors. Full-project headless scan encountered old .blend import configuration; it is not claimed as a successful release build.

Ruling: a bounded0.25m/single-lake study is the first deliverable, not production architecture. Cover mask is source-specific and vertex interpolated, water opaque; no high-poly bake claimed. Actual art defects are recorded and a concrete direction question sent. Do not proceed to whole-island until user local art acceptance.
