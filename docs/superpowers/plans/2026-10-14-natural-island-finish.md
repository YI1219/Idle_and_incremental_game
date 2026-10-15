# Natural Island Finish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox tracking.

**Goal:** A softer natural island body and water finish coherent with the Chinese fantasy sky.
**Architecture:** Keep terrain/support geometry authoritative. Bake controlled crease normals for the retained stone meshes, correct materials to use them, refine existing rim/cliff assembly and sod contact. Rework water optics using the existing depth/shore/impact field. Judge final rendering through matched captures.
**Tech Stack:** Godot 4.7, GDScript, spatial shaders, retained Kenney/Quaternius sources.
**Spec:** docs/superpowers/specs/2026-10-14-natural-island-finish.md

## Global Constraints
- Keep original trees/buildings and overall footprint; preserve editable land and continuous underside.
- No new original custom models, fixed decorative ground or purchasing.
- No grey perimeter stroke or painted green shoulder; local rooted cover and stone exposure.
- Actual runtime screenshots; art/function/performance acceptance separate.

## Review Focus
- Smooth normals must preserve topology, bounds, winding and meaningful sharp corners.
- Rock accents must remain supported after edits and not turn the bottom into hanging pillars.
- Sod and vines must contact the current visible stone, without new protruding plates.
- Calm water must show view-dependent reflection and readable banks at both zoom ranges.
- Original trees/buildings, controls and authoring data must remain intact.

### Task 1: Coherent rock, sod and water finish
**Files:** scripts/terrain_editor/stone_normals.gd, terrain_models.gd, procedural_stone.gd, rim_surface_detail.gd, rim_outcrops.gd; terrain material shaders; tests/terrain_stone_normals_test.gd.
**Interfaces:** stone_normals.soften(mesh:ArrayMesh, crease_degrees:float, strength:float)->ArrayMesh returns identical vertex/index/UV/color/material data with finite normalized crease-aware normals. Uses retained source surfaces; final field and picking geometry unchanged by normal baking.
- [x] Write and run a failing geometry-preservation/crease-normal test.
- [x] Implement controlled normal baking and integrate stone sources; remove shader forced flat-normal response and random per-triangle paint.
- [ ] Capture representative rim and lake; refine broad stone/ground transitions, diverse retained stone selection and water/fall reflection until the chosen variants are visibly better.
- [x] Capture six or more matched full-scene views; inspect close/whole/reverse/bottom for regressions.
- [x] Run normal preservation, outcrop support, closure/union/rhythm, vine/shrub, editor/homestead and actual-render decoration regeneration checks.
- [ ] Update review/current context/gallery, commit and obtain independent review; fix material correctness or regressions, then push.


## Verified progress — 2026-10-15

`natural12` is a functional candidate, not final art acceptance. Source clipping now uses exact cap polygons and one shared drawn ground top; actual rotated shoulders fit around falls, and picking uses drawn walls plus the shared top. Four source cut profiles and the geometry-preserving normals helper have meaningful regressions. All 54 headless terrain scripts and five rendered scripts pass; review follow-up adds the new mineral bitmap to mipmap coverage and retires the obsolete zero-probe crown-tint check. Eight principal matched runtime views exist.

Independent review found no Critical/Important remaining correctness defect for a reversible progress commit. It agrees broad slab geometry, turf cards and opaque water still keep the art goal open. Mineral albedo/provenance is recorded; original source models/textures and authoring data remain untouched. Production micro-displacement is zero after its seam-producing trial was rejected. The next art decision is mass proportions/rhythm, then sod and water clarity; do not mark the refinement or final delivery boxes complete yet.

## Independent water step while the user's cliff refinement is pending

The current opaque bed-color approximation still reads as a shaded sheet. Prototype an actual lake bed derived from the existing water contours and authored cell bed heights, replacing the grass cap hidden under each water level. Preserve original data, footprint, dry land, picking at the visible water surface, published revisions and edit regeneration. Use one shared global subdivision grid including contour breakpoints to keep nonplanar bed joins continuous, with a shallow supported-bank ramp and no raised sill at waterfalls. Add a dedicated mineral bed material and test screen-space refraction/transmission of that actual opaque geometry. No new fixed landscape or custom stone model is involved.

- [x] First reproduce missing physical bed/hidden wet grass in a meaningful geometry test.
- [x] Generate contour-clipped bed, exclude wet regions from grass both before/after rim union, and prove coverage/depth/source preservation/edit regeneration.
- [x] Prototype water optics over actual bed; compare matched shore/overview/reverse views and reject regressions.
- [x] Run affected closure/picking/shore/edit checks and rendered regeneration before retaining or pushing.

Verified `water_final`: 55 headless and five rendered scripts pass. Follow-up bed checks cover published chunk meshes (417 probes, no internal open edges), and a synthetic intersecting-hole cap fails the old path with 28 errors then passes with centralized intersection rows. Eight matched principal views inspected. Screen-space approximation remains limited; cliff/sod art still needs further work. See the physical-water review and checks manifest.

## Rooted turf follow-up

The existing rolled sod front has inverted top-face winding, while its back is horizontally offset and remains above the ground. Correct outward winding, bury the back below the cap/inside the real crown, and smooth the closed patch normals before chunk publication. Judge compact tuft alternatives against the saved `water_final` rim view. Reject the broad leaf/fingered silhouettes if they still read as paper or dripping paint; do not hide the source cliff limitation with denser decoration. Preserve compression, anchors and whole-patch outcrop trimming.

- [x] Reproduce wrong above-ground winding in a dedicated actual-scene test (970 inward top triangles).
- [x] Inspect compact rooted patch alternatives at the representative rim; retain only a clear improvement.
- [x] Verify turf contact/normals, anchors, outcrop trimming, published mesh and compression, plus editor/decor regeneration.
- [x] Capture matched whole/close/reverse/bottom views and update review/docs with remaining visual limitations.

Selected `turf5`: very short rooted cuffs and uniformly scaled retained grass fans replace long sheets. `turf1`–`turf3` molded/fingered silhouettes rejected; `turf4` source-fan trial led to shorter cuffs and taller unequal fans. 13 affected headless scripts and three rendered scripts pass. Independent review found no actionable technical defects but notes oval pads and cliff slab shapes remain unaccepted. Next decisive art step remains the user's actual main-stone refinement, then composition at that real shape; no further decorative escalation while it is missing.

## Latest side-rock / edge-shape correction — October15

The user supplied the complete floating-island concept again, explicitly prioritizing side stone masses and angular irregular edge shape. Keep hard corners/shoulders/recesses; soften illumination/material/contact rather than smoothing the perimeter. A retained-source placement trial widens deterministic setbacks/turns and varies overlap without adding density or changing source meshes. `fracture1` was too open and failed unchanged rhythm criteria; `fracture2` retains tight backing overlap and has a modest visible improvement. All17 affected headless and three rendered checks pass; independent art/code review agrees to retain it as progress, not acceptance. Latest reference and priority are in the rebuilt existing-source handoff. The broad source panels still need actual model refinement; no custom geometry was produced.

## Surface mixing correction — October15

Latest user feedback identifies uniformly clean rock faces and separated grass/stone materials as a major quality gap. Independently of pending source refinement, strengthen existing mineral/detail maps and add uneven world-space weathering, small deposits, and soil/lichen below actual dry caps. Share deposit coordinates with ground; fragment grass/earth and path margins without changing geometry or adding a lip stroke. `weather1` overly broad tan patches rejected; `weather2` retains finer, restrained mixing. Eight principal matched views (11 actual captures) inspected; remaining crisp cap cuts and oval root pads are still unaccepted. No new bitmap/model generated. See material-weathering review for fresh verification and remaining limitations.
