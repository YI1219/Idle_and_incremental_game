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

`weather3` follow-up retains root-zone shared material relief and cuff-side fray without cutting retained source blades or changing geometry. Eight principal views inspected from eleven fresh captures, root compression 2,398/0/1,573 pixels passes; independent review agrees a small improvement with no concrete defect. Exact-source paired timing probe returned zero Metal GPU counters and is explicitly invalid for performance acceptance.

## Bounded near-shore reflection follow-up

`reflection3` adds current-screen opaque reflection over the physical bed. Real rendered mirror-marker test failed on the old shader then passes expected/moved/angled positions with disabled/removed/stale controls. Long/strong trace studies produced pale reflected ghost masses; selected variant reduces range/strength and fades 3–12 m. Reviewer identified a minor bisection endpoint mismatch, now fixed by resampling the validated hit. Eleven matched captures, eight principal views inspected. No geometry/layout change, full reflection and temporal/performance acceptance still open. See reflection review for exact checks and invalid/limited timing conclusions.

## Shore-stone support correction

Latest user feedback: shore stones feel floating and separated from ground. Lowest dry vertices already intersected land, but lower flanks emerged too high; fully wet accents used a fixed offset from water instead of actual lake-bed support. `shore1` seats the retained mesh lower-third in actual bank triangles and its wet underside on the actual bed. New four-edit-fixture regression red901 sample failures → green0/4,445 probes, stone counts retained; shore props/transition and rendered regeneration pass. Eleven captures/eight principal views inspected; no geometry/source/XZ-layout change. Contact improves, simple stone shapes and hard material joins remain.

## Authorized Blender source refinement — latest user correction

The user explicitly authorizes Codex to operate model tools and cannot optimize models themselves. This supersedes the user-operated Blender handoff for the selected existing cliff source. Use the installed Blender5.2.1 CLI; originals and Tripo website restrictions remain.

- [x] Refine a copy of Rock_Medium_2 in Blender: unequal tilted major faces and two/three local offset shoulders through the middle/lower body; no dense rubble or global rounding. Save versioned work and grey GLB, validate closed outward finite mesh and source hashes.
- [x] Inspect neutral whole-source and clipped-wall views before runtime selection.
- [x] Add the selected retained-source refinement to runtime crown profiles, preserving source fallback and authoritative cap/shore/closure/picking. Prove source selection with a failing-then-passing integration test and run existing source clipping/contact/closure/edit tests.
- [x] Capture eleven matched actual island views; eight principal views inspected. Independent review supports v4 as a modest improvement, not full acceptance. Update stale user-action docs and commit/push this reversible candidate.

Ruling: refine the existing licensed source directly rather than inventing a replacement model; latest user authorization removes the previous Blender handoff blocker. Existing generated concept is a shape guide, not model evidence.

Selected v4:634 triangles; inherited thin knife folds repaired from source silhouette vertices, broad local shoulders, original6 source hashes unchanged. V1/v2 rejected for banding; v3 retained inherited folds. All13 headless checks plus actual editor339/339 and regeneration42/42 pass. Main broad wall/source1 and grass contacts remain open; no full-goal or target-device claim.

## Remaining high stone and rooted contact — October15 continuation

Previous goal turn made actual progress: main v4 integrated, checked and pushed5fe569a. This pass refines remaining source1 and root-cuff composition under the same user authorization, with unchanged layout, main v4 and continuous bottom.

- [x] Inspect source1 and matched model4; add failing selected-tall-source regression.
- [x] Save/inspect versioned Blender tall variants; reject convex tall_v1's pointed lower mass. Select tall_v2 retaining source topology and broader oblique turns,816tri, zero nonmanifold/degenerate faces. Original source hashes unchanged.
- [x] Inspect full outcrop and clipped wall in actual11-view tall2 captures; all8 source/crown closure cases pass.
- [x] Reduce raised oval cuff top, retain3 unequal uniformly scaled grass fans and jittered intervals. Rooted2 uncovered13 unsupported sample roots; rooted3 bounds patch widths and checks actual cap winding for cuff/fan anchors, then0unsupported/4,407 roots. Rooted1 parse-error captures are invalid, removed from comparison evidence.
- [x] Complete14 affected headless and3 rendered editing/compression checks on final rooted3; inspect8 matched principal views, independent review, update current docs/gallery and commit/push.

Independent review supports modest high-stone/root-contact improvement, no actionable runtime defect; report conditional for rejected tall_v1 convex reconstruction corrected. Broad panel masses, crisp cap contacts and water finish remain open, not full goal acceptance.

## Water depth and quiet mineral bed — October15 continuation

Previous rooted3 turn changed authoritative state and pushedcd0f4cc. Six actual probe captures isolate reflected/flat-normal/plain-bed layers; plain bed removes the cloudy granularity, whereas disabling reflection or water normal does not. First probe compilation was invalid and replaced with correctly expanded include captures.

- [x] Carry authored water level in bed vertex color through weld/chunk publication; regression must fail before change and pass default plus valid water edit. Byte encoding supports existing0..7 water levels.
- [x] Quiet submerged dry-rock normal/map contrast, retain material texture; add low-contrast moving light web on actual bed with depth fade and shadows. A rendered shallow/middle/deep/off/moved fixture must first fail, then pass.
- [x] Judge actual pond/whole-island views against rooted3; do not retain flat uniform fill or dense luminous grids. Run affected bed/shore/reflection/fall/edit checks and independent review, update current comparison/docs, commit/push.

This pass does not add decorative land or alter island/water footprint, source models or authored depths. Full art and target-hardware acceptance remain unproven.

Selected clear3: quieter mineral bed and shared wet substrate, sparse warped .12 lightweb. All7 affected headless checks and final actual capture/SSR/impact/editor/regen queue pass; added default-strength and morph-equivalent fixture passes. Independent review twice supports local improvement, not full art acceptance. Cost remains unmeasured.

## Broad face refinement — October15 continuation

Previous turn was progress: clear3 water changes committed/pushed f1d5bdc. Current matched rim still shows large clean planar fronts with a thin cap. Use the authorized Blender refinement path for source2: preserve the retained source silhouette/outer-skin repair, add unequal near-vertical oblique plane turns rather than another horizontal band or detached rubble. Judge neutral source and actual clipped wall before retaining. Existing tall_v2, trees, water and calm lower closure stay.

- [x] Selected-source regression fails missing v5 then mismatched actual profiles; versioned Blender candidates saved. Final original source selection retained; hashes unchanged.
- [x] Compare representative rim and matched11-view studies. All v5–v8 and joint1 shapes rejected; no new runtime model retained. See stone_contact review for concrete failures.
- [x] Retain mineral2 shared stone/short root-earth material after rejecting broad mineral1 contact; final16 headless and five rendered checks pass,11 captures/eight views inspected, independent review supports limited retention. Update current docs/gallery and reversible commit/push.

## Waterfall body, foam and mist — October15 continuation

Previous turn was progress: mineral2 material and rejected form evidence pushed2854203. Fixed-phase actual layer isolation identifies heavy mist and always-opaque central foam as the main white blanket, with continuous fine strands on the curtain. Keep existing authored waterfall geometry/contact metadata and pond/land footprint. Reduce blanket mist, give foam/core and ripple arcs real partial coverage/moving gaps, and separate broader transparent flow from sparse white aeration. Judge against matched receiving/free-fall close cameras and the eight principal scene views; no opaque cloth, uniform dim veil or erased flow.

- [x] Foam old40,000opaque core/rings0gaps fails, new0opaque/26,598moving core and14,564gaps/17,557moving rings passes. Refraction old0changes fails, selected4409/default1883/foreground0/73edge rejection passes.
- [x] Ten actual layer captures identify mist/core blanket. Reject thin flowing1 and over-transmissive flowing2; flowing3 palette with corrected projected displacement selectsflowing4. Six fixed-phase near pairs and11 main captures/eight principal views inspected; review supports limited improvement.
- [x] Six headless and final9 rendered queue entries pass, including falls35/35,impact8/8,SSR729,editor339/339,regeneration42/42. Current docs/gallery updated; commit/push reversible checkpoint. Thin curtain and concentric ring shape remain; projection magnitude/orthographic/zoom and target GPU are unverified, not full goal acceptance.
