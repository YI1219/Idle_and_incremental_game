# Running, turning and garment correction

Historical version evidence. Current runtime and unresolved visual status are in the [v06 garment review](../garment_v06/review.md). The v04 ankle-length trouser extension was not the intended design and is reverted to knee length in v06.

Updated: 2026-09-20. Reviewed character: `assets/characters/qinglan/qinglan_clothed_v04.glb`. This is a refinement of the retained Tripo/Quaternius character, not a rebuild. Final art acceptance remains open. Performance verification remains deferred; this pass collected no benchmarks.

## Confirmed request

The user asked specifically about running and turning while running, and rejected the body appearing outside the cloth. Earlier requirements still apply: preserve valid assets, human template body motion, an ancient-style xianxia silhouette, white trousers and bare feet. Technical checks are separate from visual acceptance.

## Implemented changes

**Running and turns:** normal travel remains 3.6 m/s and uses the licensed human jog template. The controller now accelerates and brakes instead of changing velocity instantaneously. Movement follows the character's facing. A 90° corner reduces travel briefly; a 180° reversal brakes, pivots and accelerates again. Brief braking pauses retain stride phase. Collision, input blocking, teleports and action boundaries clear motion correctly. Combat rules and action speeds are unchanged. No separate sprint control was added; the faster `run` template remains in the asset and was included in clothing checks.

**Clothing:** the lower robe previously relied on four broad skirt controls that only weakly followed thigh pitch. Its surface stayed behind when the knee rose. The v04 refinement reweights 2,115 existing robe vertices toward the leg chain, while retaining the hip transition, sleeve weights and some garment response. The robe's geometry and materials remain unchanged.

The existing white trousers ended near the knees. Their upper panels are retained, the lower panels now reach the ankles, and four additional support loops improve knee bending (64 to 128 vertices per leg). A clearance check on the complete retained skin exposed a remaining approximately 2.5 mm back-knee intersection in an extreme sampled pose after tailoring. The outfit therefore also omits 113 permanently covered calf faces from its runtime body mesh. This is an outfit mask, not cloth simulation or a claim that the complete source skin never intersects clothing. The complete body remains preserved in v03 and earlier source files. Head, hands, feet and ankle-boundary points are unchanged.

All ten exported animation clips are byte-identical to v03, including their timings. No new procedural body curves or wrist overrides were introduced. The starter sword, cottage and original source files are preserved.

## Actual visual review

[Running and turning preview](running_turns.gif) uses the real player/controller and sword, with actual travel on a neutral 1 m grid: start, straight running, 90° turn, 180° reversal, another corner and stop. The tracking camera is for inspection; this is not an in-place loop presented as traversal. The sequence contains 240 rendered frames; pose sampling is fixed solely for reproducibility.

[Before/after clothing](clothing_before_after.png) shows the old garment on the left and the revised one on the right, at the same human jog pose. [Jog garment sheet](jog_garment_sheet.png), [faster run sheet](run_garment_sheet.png), and [dash sheet](dodge_garment_sheet.png) show eight phases from front, side and rear. Additional paired stills cover idle, attack and guard. The reviewed legs no longer visibly break through the robe as in the earlier sample; the longer trousers and retained bare feet are visible in the new running capture.

## Fresh verification

- Running controller: **60/60** checks, including corners/reversals, stop distance, stride phase, blocking, relocation, walls, walkable edges and action boundaries. Simulated 30/60/120 Hz steps check behavior across delta values, not rendering performance. Unobstructed movement/facing alignment is 1.0; return to full speed is about 0.20 s after a 90° turn and 0.53–0.57 s after reversal.
- Template runtime: **36/36**. Animation loops: **123/123**. Demo: **23/23**. Sword runtime: **0 failures**. Space transitions: **22/22** with the established fixed-step setting.
- The old space test expected more than 0.6 m of travel within 12 ticks after reveal, which assumed instantaneous full speed. With intentional acceleration, held input correctly produces 0.305 m and 2.81 m/s. Its expectation now checks meaningful forward progress (>0.20 m) and rising forward speed; no movement exception was added merely to satisfy the old threshold.
- Re-import: **10 meshes, 28 bones, 90 sampled poses**, no unweighted vertices or non-finite geometry. [Asset check](asset_check.json) confirms unchanged animation data, materials, bind matrices, accessory geometry and robe geometry. The retained body points are a subset of source points; head/hands and foot/ankle boundaries are preserved. Weights are normalized with at most four influences.

Evidence: [running tests](running_turn_test.log), [template](template_test.log), [loops](loop_test.log), [demo](demo_test.log), [sword](sword_test.log), [space](space_test.log), [round-trip](roundtrip.json), [clothing changes](clothing_refinement.json). `clearance.json` checks selected calf vertices; after the outfit mask those covered samples are omitted, so its zero visible points must not be interpreted as physical clearance of the complete source body.

## Production choices and remaining limits

Braking rates, pivot rate, leg-driven garment weighting and the outfit mask are implementation choices addressing this request, not newly confirmed design requirements. The turn uses the existing blended locomotion/idle motion, not a separately authored turn clip. Dedicated planted-foot turn acting, intermediate-speed gait blending, cloth volume and layering in extreme poses, finger grip, toe/clavicle articulation and final xianxia expressiveness remain refinement targets. Garment deformation is skinning, not physical cloth simulation. Passing these checks does not approve final visual quality or establish intersection-free behavior in every future pose.

## Reproduction and preservation

Run `tools/qinglan/retarget_templates.py` to reproduce the licensed v03 motion base, then `tools/qinglan/refine_clothing.py` to produce the separately versioned v04 outfit. The latter reads the preserved `qinglan_template_v03.blend`; it does not overwrite it. Work file: `art/work/qinglan/qinglan_clothed_v04.blend`. Review capture and verification scripts are under `art/work/running_cloth_review/`. Official source and license details remain in the [human-template review](../animation_template/review.md).
