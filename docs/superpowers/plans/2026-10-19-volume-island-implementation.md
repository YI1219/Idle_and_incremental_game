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

## Initial checkpoint2026-10-20 (c8c558f)

Fresh document19/19 and native11/11; legacy sculpt29/29/base23/23.11native captures, clean final runtime/capture logs. TwoP2review findings reproduced RED and fixed GREEN in one pass: empty terrain publication and a center pillar falsely invalidating surviving lake water. No deferred review minors. Full-project headless scan encountered old .blend import configuration; it is not claimed as a successful release build.

Ruling: a bounded0.25m/single-lake study is the first deliverable, not production architecture. At this initial checkpoint cover was source-specific and vertex interpolated; water opaque; no high-poly bake claimed. Actual art defects are recorded and a concrete direction question sent. Do not proceed to whole-island until user local art acceptance.

## Local contact correction2026-10-20

Diagnosed legacy cover without lighting and measured unchanged conversion with finite nearest-surface probes. A single world-space height/planting map now evaluates contact per fragment in the isolated study, reducing triangle color smearing without replacing geometry or changing source/save data. Old shader branch remains for matched controls. Fresh document21/21 and native12/12, old/new vertex+normal hashes identical, tunnel/breach/undo freshly captured. See `art/review/terrain_fidelity/2026-10-20/volume_diagnosis/`.

The user has since selected refinement of the existing mother's main shape, grass/stone contact and bank; that direction question is answered. Do not treat this as art acceptance or start stage2/3. No changed generation budget or new model job.

## Existing-source local revision2026-10-20

One separate existing-vertex Blender correction preserves the cap/height/topology and converges the lower body; a designed shallow pond and optional narrower world-space grass contact are captured separately. [Evidence and limitations](../../../art/review/terrain_fidelity/2026-10-20/volume_shape/README.md). Fresh document21/21,bank10/10,refined-source8/8,native12/12. Mother-shape/bank captures verify real tunnel/breach/exact undo; old/new save-source cross-replay rejected. Independent bounded review found no Critical/Important defect. Original source/default/preset/save remain.

Local visual judgment is still insufficient: pond/lower contour improve, but middle/rear major forms and cap-edge facets remain unfinished. User art gate stays unchecked. No whole-island expansion or stage2/3/paid job. Full goal remains active.


## Main-plane and contact continuation2026-10-20

[Side-plane evidence](../../../art/review/terrain_fidelity/2026-10-20/volume_planes/README.md): initial radial implementation failed source intersections and stopped before sampling; corrected inward monotone plane compression passes source checks but is art-rejected (broad wall/angular turf). No third whole-mother squeeze/taper parameter rule. [Short-leaf resource pairing](../../../art/review/terrain_fidelity/2026-10-20/volume_grass/README.md) preserves old geometry, uses3existing short leaf components, fixes tiny-root triangle handling,1008triangles/288roots. Local cut/full erasure/undo verified, art gain modest and incomplete. Fresh original21/21,refined8/8,new-source15/15,grass8/8; independent bounded review no Critical/Important findings. All stage2–5/art gates remain incomplete.

Completed one [existing-module local trial](../../../art/review/terrain_fidelity/2026-10-20/volume_modules/README.md): three existing rocks→1816triangle closed source→17556triangle unedited authoritative skin; matched native source and edited captures, tunnel/breach/exact undo, separate source-bound data. More legible planes/recess, still ledges/angular turf/separate feet. User art gate remains unchecked; optional main-mass direction question pending. Source-specific planting bound and actual-basin physical grass fix lower dry coverage without changing geometry; old defaults/presets preserved. Fresh original21/21,refined8/8,prior matrix15/15,module7/7,grass8/8+9/9,native original12/12; independent bounded review no Critical/Important delta finding. Existing mesher produces1192collapsed triangles in the unedited captured mesh; remaining skin connected/zero bad edge use. Stage2–5 remain incomplete. No whole-island/perimeter-column scatter, hidden ground, new scratch official geometry or paid job. Original sources/default/presets/saves retained. Full goal remains active.


## Edited-surface correctness continuation2026-10-20

[Strata/basin evidence](../../../art/review/terrain_fidelity/2026-10-20/volume_strata/README.md): hold the existing module geometry fixed, cache immutable source top and pack source-depth/actual-basin channels into the existing contact texture. Deep new floors expose rock; actual wet footprint replaces radial shading, invalid lakes clear wetness. Physical grass rejects deep cut soil loss.8matched native shader pairs/actual production-GPU probes, exact data/mesh-normal identity and undo. New test RED3/8→GREEN8/8; fresh original21/21,refined8/8,matrix15/15,module7/7,grass8/8+9/9,native original12/12. Independent review no actionable findings. Original/default/presets/saves preserved. This supersedes the earlier material-limit notes, not their historical capture pixels. Main shape/art remains inadequate; optional direction question unanswered. No stage2–5 or whole-island/house/paid work. Full goal active.


## Form-versus-light decision2026-10-20

[Native light diagnosis](../../../art/review/terrain_fidelity/2026-10-20/volume_light_diagnosis/README.md):8fresh matched frames, only key yaw40→−35°, exact terrain/grass attributes and data unchanged. Front readability improves; separate feet/ledges/blank rear persist, reverse worsens. No side-light adoption or numeric sweep. Agent rejects the three-rock composition and recommends structural reshaping of the preserved single-body mother, with the user-required deviation discussion before changing route. New concrete discard/retain question pending; supersedes older optional closeness question. No new source generation/whole-island/stage2–5/house job. Previous strata/basin implementation retained, full goal active/incomplete.


## Collision precision correction and direction dependency2026-10-20

[Correction evidence](../../../art/review/terrain_fidelity/2026-10-20/volume_collision_precision/README.md): raw/direct display triangles never had the1192collapsed faces. Mesh.get_faces uses0.1mm TriangleMesh snapping, also used by old create_trimesh_shape. Publish local collision from exact vertex/index arrays, preserve display/density/source. New precision RED3/6→GREEN6/6 across3sources; native12/12,original21/21,strata8/8,module7/7,grass8/8+9/9 fresh; independent review no actionable findings. Direct grass-root drift0, prior≤.079mm was helper rounding. This supersedes earlier degeneration/GPU-drift descriptions, not historical hashes/data.

The discard/retain shape-route question remains unanswered over light diagnosis, revalidation and this precision correction. Known independent stage1 correction is now complete; further form work requires the user-requested deviation discussion. No next aesthetic sweep or stage2–5/whole-island/house/paid job. Full goal incomplete and awaiting that decision.
