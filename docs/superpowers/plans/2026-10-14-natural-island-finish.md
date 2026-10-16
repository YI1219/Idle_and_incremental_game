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


## Crown–root–base connection — current continuation

Ruling: inspect the whole connection before further source cuts. Actual category/no-root/no-crown-shadow captures show a projecting crown foot, not only a shadow artifact. Blender v1 lower-section recession moves the low .62 cap through long crossing edges; v2 protective section reduces that drift but creates tiny source triangles dropped by runtime and still looks like hanging plates. Neither is selected. The render-only shell-expansion study also fails: insufficiently bounded displacement stretches remote/internal faces and causes water artifacts, so it is not valid runtime acceptance evidence. Preserve these rejected studies, leave selected main_v4/tall_v2 and all source geometry unchanged.

A separate real defect is visible in this investigation: rim union rebuilds the continuous shell with flat normals, losing its earlier smooth shallow joins. Restore crease-aware normals only on that backing, preserving geometry, colors, UVs and real hard turns.

- [x] Actual-scene layer isolation; versioned Blender v1/v2 work/validation; reject detached-plate recession.
- [x] Reproduce 1,329 shallow shared joins with artificial seams on baseline. Restore crease-aware normals: zero seam failures, 588 sharp joins retained.
- [x] Inspect11 matched actual captures/eight principal views; retain only the modest lower-core normal correction.
- [x]12 affected headless plus actual editor339/339 and regeneration42/42 pass, independent review supports limited retention; docs/gallery updated. Reversible checkpoint verified; full art goal remains open.


## Single retained-source shoulder and foot — October16 continuation

Previous turn made authoritative progress and pushed29c0863 (continuous base normals). Ruling: the separate roots and flat-ended crown create a stacked construction. Refine the same retained-source lower foot downward and modestly inward, protecting whole faces crossing all runtime cap planes; do not add sliver-producing horizontal sections. Anchor clipping/scale to original source bounds, so extension does not renormalize the grass cap. Omit separate roots only for these integrated-foot wall modules; continuous backing remains. Compare extension/return strengths in the real scene, reject teeth/plate variants. Outcrops, trees, water and authored data keep existing sources.

- [x] Reproduce active model0extra-depth/36detached roots in new integration regression; initial parse failure discarded, corrected red test exits1. Blender work copies v1/v2/v3 keep topology634/816 and closed positive volume, original source hashes protected.
- [x] Neutral models and11matched actual views inspected; selectv1, reject shorter v2 band and too-heavy v3.
- [x]16 headless checks pass, compression2185/0/1186 and editor339/339 pass. Corrected regeneration42/42 observed; temporary log/exit-status loss at continuation explicitly recorded. Review supports limited retention; root-depth test update preserves thresholds. Docs/gallery ready for reversible checkpoint. Full goal remains active.


## Direct rock sculpting — October16 user correction

The user explicitly rejects "player builds a mountain, then the system combines stones". Player and prefab author must directly sculpt the same rock/mountain volume. First implement additive/subtractive/planar volume brushes in authoritative TerrainData, mesh their result, publish/pick it through the terrain renderer, and reuse these exact brushes for an authored example. This is not an automatic rock scatter/assembly pass. Existing scene sources remain until the sculpted sample is visually accepted. Sparse signed-distance samples permit overhangs and cuts rather than another stepped height-only facade. A .25m lattice is a first quality/cost choice, not final performance acceptance.

- [x] Write failing direct-volume tests: connected add strokes, subtraction, bounded plane cut, finite outward closed mesh, mixed terrain/rock undo/redo, atomic save/load, invalid-input rejection.
- [x] Implement `rock_sculpt.gd` (sparse bounded field and brush patches) and `rock_sculpt_mesh.gd` (deterministic shared-edge tetrahedral contouring). Keep shape authored, with no implicit extra rock placement.
- [x] Integrate authoritative samples/history/serialization into TerrainData, snapshot/publication/picking into the renderer, and three brush choices/cursor into the existing editor.
- [x] Reuse the production brush API for a representative authored cliff group; inspect actual engine before/after/edit/cut captures. Keep a study if quality is insufficient; do not claim a prototype is final island art or replace the whole rim blindly.
- [x] Run affected data/runtime/editor checks and one fresh independent review; update current status and push reversible work. Finish restrained stone-value balancing separately from the new shape evidence.

Review focus: negative/chunk-crossing brush coordinates; empty/dry/wet terrain and volume-only layouts; brush size/sample-limit atomicity; invalid load preserving history/current data; snapshot picking matching the published mesh. Independent original sources and current island/pond footprint remain preserved.

Direct-sculpt checkpoint:volume29/29,published9/9,legacy data301/301/runtime22/22 and affected support/closure checks pass. Native editor339/339,input-helper8/8,regeneration42/42 and11default tone_final captures pass. Independent Important morph/pick mismatch fixed with red→green actual-render fixture(10,117→0silhouette changes);post-fix volume/runtime pass. Minor native full-pointer-route coverage deferred. Both sculpt1/sculpt2 forms rejected; no replacement of default cliffs. Direct volume tooling does not yet integrate the existing base/grass coverage, and full lookdev acceptance remains open.


## Coherent sculptable terrain base — current continuation

The previous volume brush trial is functional but overlays retained cliffs/caps and fails art. Seed the sculpt field from the existing authored terrain itself in a reversible opt-in mode. One derived closed skin must replace old grass/cliff draws, expose both grass/rock coverage and update support/picking. Brush samples, history and serialization stay authoritative. The existing default island remains the comparison until actual whole/close views pass art. No automatic rock assembly, extra locked land, tree/building replacement or user model delivery.

- [x] Red regression: carving actual pre-existing ground, one closed grass/stone/base skin, no retained cap/wall, support follows carved top, save/load and switching back.
- [x] Implement derived base signed field from authoritative cell contours and calm bottom; sparse edits override it. Mesh base crossings and all edited cells, including internal positive carve samples.
- [x] Integrate opt-in conversion/history/save/snapshot, single-skin material, actual support and decoration contact; add native pointer editing coverage.
- [x] Inspect representative and whole actual views; reject clay/sheet geometry and grey/painted lip. Only adopt visual improvements. Run affected fresh checks/review, update current status and push reversible checkpoint.

Coherent-base checkpoint: original-ground carve, closed skin, actual pointer/picking/undo, version3 save/load and base-budget tests pass. Review found and fixed atomic history restoration and thin-ledge support; red→green evidence retained. Wet-bottom material contamination fixed with actual rendered positive/negative controls. Default art remains tone_final; coherent-base studies are rejected for broad/rounded or coarse forms. Five-view base5 is functional-stage evidence only. Finite shore/vine support and legacy regressions pass; target-device cost, arbitrary sculpted water routing and final art remain open.

## Directly authored geological shoulder — current continuation

Base5's sphere/short-plane strokes still make clay-like walls. Larger plane cuts were actually tested and rejected for sheeting and loss of nearby lawn. Prototype an unequal convex shoulder brush with a basal inward plane, keeping its lower end within the common island body. If useful as a local shape improvement, expose that exact brush through the player API; do not retain a private prefab-only shape path. Keep the default until the whole scene is artistically accepted. Limit derived cover to the original grass footprint so new stone cannot inherit distant lawn paint; enlarge retained grass fans in irregular groups only, without cuffs.

- [x] Preserve rejected plane/straight-foot studies; implement the chosen shoulder brush through bounded atomic volume edits/history/save and actual pointer use.
- [x] Check original grass coverage, native rooted tuft/compression and sculpted mesh support; retain only useful art changes.
- [x] Capture seven matched views including a correctly framed grass join; review shape and contacts separately from function, update current evidence and push.

## Water material finish — current continuation

Actual default shore view still shows a polygonal caustic web across the pond and a striped waterfall sheet. First freeze review clocks at the same phase in real engine captures. Replace the hard cellular bed-light network with broken curved interference light and inspect shallow/deep/shadow response; keep the physical bed/refraction and bounded reflection. Then test broader, subtly drifting waterfall strands instead of dense cloth-like streaks. No layout/source/lighting changes. Preserve only visibly useful candidates, rerun actual depth/motion/reflection/refraction and editor checks, review and push. Full island art remains open.


Water checkpoint: retained curved interference light, larger broken ripple gaps, wider drifting fall strands with original opacity/transmission, and reflection confidence fades. Rejected thin gauze and unhelpful mip blur. Seven matched camera/principal-clock water comparisons and11main captures are current. Fresh native water fixtures, editor339/339, extended regeneration42/42, compression,417bed probes/0failures and finite shore/vine/fall checks pass. Initial two coverage failures corrected in production without lowering thresholds; phase-swept refraction negative control now exercises existing foreground rejection. Independent review supports modest retention and finds no actionable correctness issue. Full art remains open; next local study carves below retained shoulders using the same player plane brush, protecting the original grass cap.


## Deterministic bounded plane cut — current continuation

The full-strength plane brush currently lerps old density across its outer region, so an identical repeat changes the transition again; selected positive-side rock can remain. Reproduce that behavior with a real volume, then replace iterative blending with one bounded CSG removal, retaining radius/world/sample guards and stored density compatibility. Capture the same local return/lip strokes before promoting anything. This is a player/prefab shared brush correction, not automatic assembly. If exact cuts still produce poor bodies, reject the art and address initial base proportions rather than stamp more details. Run affected volume/history/picking/support/editor checks, independent review, document and push a reversible checkpoint.


Base-profile diagnosis: cumulative lower-level regions also include higher land, delaying higher exterior recession to the lowest terrace. Keep cumulative top/cap union, but apply the outer body's recession once using a smoothly weighted nearby authored ground height. Existing version3 files without a profile marker retain the legacy derivation; newly converted layouts save version4 with a mandatory explicit local profile. Profile stays fixed across mode toggles, resets on preset/load with history, and renderer snapshots carry it. First prove high/low shoulder/core, old-file appearance and atomic unknown-profile rejection, then compare unshaped/local/full-shoulder forms before choosing an art default.


Foundation checkpoint: plane10/10 and local profile15/15 after red→green regressions; initial low shelf loss beside tall land fixed with a continuous cap envelope and independently rechecked. All ten affected headless checks and native pointer17/17/editor339/339/material controls pass. Final source volume is one closed connected skin with unchanged cells. Finite grass/shore/vine support passes. Seven camera- and principal-water-clock-matched views across four states remain art studies: broad walls, hull mass and hard contacts persist, so default surface_final geometry remains unchanged. Exact local cuts also remain visually rejected. Version4 marks new local profiles; old v3 legacy derivation preserved. See the plane_sculpt review for current evidence and limits; goal remains active/incomplete.

## Subtractive cliff composition — current continuation

Use the approved direct-sculpt authoring path to study major local planes rather than additional perimeter stamps. Add `tools/art/author_unified_cliff_chisel.gd`, called by an explicit capture-only `chisel` argument in `capture_sculpt_base.gd`. Work on the local-height base through public bounded plane cuts only: several oblique full-height returns, unequal near-vertical clefts, and two local cap exposures. Keep original cells and all scene sources unchanged. Capture the same seven cameras/four principal clocks as local_body2; inspect silhouette, grass contact and lower continuity before any production adoption. This is an art study with existing brushes, not a new runtime feature; meaningful acceptance is actual views plus exact undo/serialization/closed-source verification if retained. Reject holes, knife lips and a more regular hull. Do not turn a rejected study into default art.


Subtractive study result: chisel1/chisel2 each7clean native captures, both rejected for thin caps/pockets/pointed fins; no default geometry promotion. A separate actual-material comparison retains shared fine stone-normal strength.20→.07, without albedo/maps/geometry changes. Seven camera/four-water-clock-matched pairs and11main captures show modest close improvement, slight distant gain; independent review concurs. Fresh native editor339/339,wet-material controls,bed light/depth/morph and compression pass. Full art remains incomplete. Current stone_soft1 default images supersede surface_final only for the quieter fine normal response; previous shape/support evidence remains stage-specific.

## Rim-cover contact isolation — current continuation

The active source still has compact rounded root cuffs and narrow curved grass fans. Capture a fresh same-camera/four-water-clock baseline, isolate source blades without cuffs, and judge actual root contact before adding any density. Reuse retained grass geometry, preserve original sources, cap/wall geometry and player data. If removing the applied cuffs improves contact, replace their construction rather than merely hiding submitted geometry. Then compose a few unequal, rooted fan directions/low-height groups using the same final cap support and compression anchors. Reject thin dark combs, broad hanging sheets and continuous green outline. Actual root support, shader compression, outcrop trim, edited regeneration and seven matched views precede retention; independent review separates art from function. This follows the user-authorized lookdev direction and is not a bundled nature placement feature.


Contact checkpoint: leaves-only isolation and unequal upright/outward/low source fans retained; solid cuff generation/drape and cuff shader tint/fray removed. Missing-source/source-cover regression red2failures→green0manufactured pads, original depth/support/finite/upload bounds retained. Eleven headless scripts pass plus expand/raise/contract/unified support fixtures. Native editor339/339,default compression1953/0/1103 and regeneration42/42 pass. Independent review supports modest near-contact retention, slight far gain; same deterministic sampling but possibly more surviving groups after cuff gate removal. Seven matched pairs and11fresh main captures; current cover_finish1, full art incomplete.

## Local solid smoothing — current continuation

Diagnosed rejected intersecting bounded-plane studies: thin residual solids are real geometry; normal/material softening cannot remove them. Test one shared public `rock_smooth` brush on the same authoritative field, with simultaneous six-neighbor averaging, compact radial influence, existing world/radius/sample bounds and ordinary history/save. Preserve a flat field, reduce a one-node protrusion, leave out-of-radius samples unchanged, reject capacity/world/nonfinite inputs atomically, retain closed finite actual meshes and v4 roundtrip. Only after those pass, expose as HUD item10 and test real pointer publish/undo. Add an explicit author helper that uses these exact brushes after a local chisel composition, capture rough/smoothed at seven matched cameras/four water clocks, and reject clay/blob forms. No base-profile reinterpretation, automatic stone assembly, tree/building/layout changes or default-art promotion before visual judgment. Tool correctness is not the art goal; useful work must include actual comparative shape evidence.

Smoothing evidence:6passes round the wall too much;2passes soften cut edges but retain a pointed hanging spur. Both remain rejected as default art. Reconsider the cut domain: bounded half-space/sphere intersections are leaving narrow residual fins. Reuse the existing geological shoulder signed volume as a subtractive `rock_cleave` operation (same public player/prefab entry), rather than composing more bounded spherical planes. Preserve existing tools/indices; append HUD item11. Verify subtraction/untouched outside, closed mesh/history/JSON/atomic guards and actual UI; author one geological recess on the coherent body, followed by2public smooth stamps, and inspect seven matched views before any adoption.


Direct-solid checkpoint: smooth21/21 and cleave12/12, real red→green evidence; native pointer25/25/editor339/339,10headless scripts and finite grass/shore/vine/contact fixtures pass. Initial native cut-bottom oracle corrected after actual ray diagnosis; closure/support thresholds unchanged. Recess2 local inset removes the hanging fin but remains unaccepted as whole-island art. Real cap-rock lower-third support regression60failures→0/120probes; helper applies only to unified dry props, with baseline0/160probes and real lowering/retention/removal controls. Final source skin696,744vertices/one component/zero invalid edges/unchanged cells. Six stages/seven matched views available in solid_sculpt.html. Independent review finds no actionable correctness issue and rejects default promotion. Keep cover_finish1 default and active art goal. Next shape investigation should treat the wall's broad planes and lower proportions together, not expand a pattern of local stamps.


## User-directed clean-finish recovery

User rejects accumulated visual direction as worse than early and asks for clean/beautiful without plastic. Compare retained edge_final with current cover_finish1 first; keep rejected unified volume studies separate. Fresh default7-view control; sequentially reduce mineral color contrast/broad dark-brown deposits, reduce excessive large-face normal softening, then quiet ground color/soil/grit and shrink oversized shoreline reeds. Preserve roughness/fine normal maps, localized roots, source geometry/data/tree/building/light/water algorithms. Inspect all7 matched final views and11main captures; relevant normals/mip/source/support/editor/compression/bed/regeneration checks, independent critical art review, docs and reversible push precede retention. No new tools or asset generation. Retain only restrained clarity improvement; repeated slabs, cap cuts and heavy bottom remain active major-form work, not solved by this pass.
