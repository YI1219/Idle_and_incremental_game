# Qinglan: licensed human-template replacement

Updated: 2026-09-20. Reviewed version: `qinglan_template_v03.glb`; the runtime has since moved to [clothing v04](../running_cloth/review.md), retaining these human animation tracks. The user rejected procedural motion v02; this replacement is not yet accepted as final art. No performance measurements were taken.

## Requirements versus production choices

**Confirmed:** replace stick-like motion using professional guidance or ready-made human animation; seek lively, graceful xianxia movement; preserve valid assets; use English for development; defer performance verification.

**Production choice:** use the free Standard editions of Quaternius Universal Animation Library 1 and 2 as the human-motion foundation. The user did not specify these particular templates as final xianxia choreography. No purchase or user generation is required.

[Animation Mentor's human walk-cycle tutorial](https://www.animationmentor.com/blog/tutorial-animating-human-walk-cycle/), by supervising animator Jason Martinsen, informs the review of contact/down/passing/up phases, hip weight transfer, chest coordination, heel roll, and arm overlap. These are inspection criteria, not automatic acceptance.

## Sources actually obtained

- [Universal Animation Library Standard](https://quaternius.itch.io/universal-animation-library): official free download, upload 17958403, page changelog v3.0, 43 named animation entries. The larger advertised collection includes other editions; it is not the free Standard inventory.
- [Universal Animation Library 2 Standard](https://quaternius.itch.io/universal-animation-library-2): official free download, upload 17958478, 43 named entries including T-pose. Exact release version was not established.
- Both enclosed licenses explicitly state **CC0 1.0 Universal**. Archives, licenses, source GLBs, manifests and download pages remain under `art/source/third_party/quaternius_animation*/2026-09-20/`. The second pack also contains farming/work candidates; those are not integrated production gameplay.
- [Godot's official retargeting explanation](https://godotengine.org/article/animation-retargeting-in-godot-4-0/) explains rest-orientation differences. The Blender transfer uses source-world pose × inverse source-world rest × target-world rest, then converts to the target local pose. It does not just rename tracks.

## Implemented

The player scene uses the separately versioned template GLB. The original Qinglan, sword, cottage and rejected v02 assets are preserved. Primary body motion is transferred from the source templates. Previous scripted wrist and body modifiers are no longer attached. The sword follows the authored hand with a fixed rest-based grip transform.

| Runtime clip | Source | Native duration |
| --- | --- | ---: |
| idle | UAL1 Idle_Loop | 2.500 s |
| walk | UAL1 Walk_Loop | 1.333 s |
| formal_walk | UAL1 Walk_Formal_Loop | 1.333 s |
| jog | UAL1 Jog_Fwd_Loop | 0.933 s |
| run | UAL1 Sprint_Loop | 0.667 s |
| armed_idle | UAL1 Sword_Idle | 1.667 s |
| attack_1 | UAL2 Sword_Regular_A + Sword_Regular_A_Rec | 1.400 s |
| counter | UAL2 Sword_Block | 1.233 s |
| dodge | UAL2 Sword_Dash | 1.567 s |
| dodge_recovery | UAL2 Sword_Dash | 0.567 s |

Locomotion cadence comes from the source root-motion companions, scaled by target/source leg length (0.595711). Normal 3.6 m/s travel selects jog at about 1.128× native cadence. Gait changes retain stride phase and use hysteresis. Formal walk and armed idle remain comparison candidates, not runtime-selected behavior.

Action clips are not accelerated to fit older action timers. Existing damage, parry, charge, movement and invulnerability rules remain unchanged. Stationary attack/guard recovery may continue after mechanical action state ends; movement or another action may interrupt it. The dash template holds a low pose around 0.4–1.0 s. When dash travel ends at rest, runtime crossfades into the separately extracted recovery beginning at source time 1.0 s, at native speed.

Only garment bones receive minimal secondary response to transferred thigh motion. A preceding full cycle warms the cloth filter before loop keys are baked; no endpoint-copy shortcut is used. Independent code/export review found the first skirt step reduced from 2.08° to 0.079° in idle and 5.80° to 0.67° in formal walk. Ribbons retain a draped pose. This is not cloth simulation or new xianxia choreography.

## Actual visual evidence

- [Walk comparison](walk_comparison.gif), [jog comparison](jog_comparison.gif): source left, Qinglan right, original cadence. Full front/side sequences and chronological contact sheets are retained.
- [Runtime motion with the actual sword](runtime_motion.gif): idle, jog, turn, stop, strike, guard, dash and recovery. Translation is deliberately held in place and labeled.
- [Actual traversal](traversal.gif): live player/controller moving, turning and stopping. [Travel samples](travel_sheet.png), [action samples](action_sheet.png).
- [Main game](courtyard.png), [near game view](character.png): current actor in the existing scene. Environment acceptance is outside this pass.

These are engine captures, not concept images or motion capture. Source and target show corresponding stride phases, heel orientation, alternating legs, running arm bends and torso coordination. The retained model limits how faithfully the complete source silhouette can transfer.

## Fresh technical verification

Template integration **36/36**; loop integrity **123/123**; demo **23/23**; sword runtime **0 failures**. Space transitions **21/21** using the project's established fixed 60-step test setting. The initial unconstrained space run was **20/21**, retained in `space.log`; the previously documented display-frame versus physics-frame peak-sampling limitation applies. This functional check is not a benchmark.

Re-import: **10 meshes, 28 bones, 90 sampled poses**, no unweighted vertices or non-finite geometry. **60 geometry/skinning accessor comparisons** are byte-identical to the preserved candidate; materials, bind matrices and joint order are unchanged. See [preservation and hashes](preservation.json), [round-trip](roundtrip.json), [template test](test.log), [loops](loops.log), [demo](demo.log), [sword](sword_runtime.log), [space](space_fixed_step.log). These checks do not prove naturalness or visual acceptance.

## Remaining visual work

1. Robe and white trousers intersect at raised knees and deep/wide poses. Cuffs, grip/fingers, face and garment topology remain coarse. Refine the preserved model/skinning rather than hiding the issue by reducing human body motion.
2. The rig lacks separate toe and clavicle joints. Foot orientation transfers, but independent toe roll and shoulder articulation cannot transfer fully. No terrain-adaptive foot IK or planted-foot guarantee is implemented.
3. Intermediate collision/analog travel speeds expose the gap between source walk and jog cadence. Phase preservation/hysteresis fix resets and chatter, not continuous gait blending. Normal 3.6 m/s jog is the checked gameplay-speed sample.
4. Stock human movement is not final xianxia acting. Light travel, calm sword carrying, expressive idles, garment flow and work actions still need visual refinement.
5. Mechanical timings remain unchanged. Dash hold/recovery is handled; sword contact/parry landmarks have not passed frame-exact gameplay-effect acceptance.

## Reproduction

`tools/qinglan/retarget_templates.py` opens the preserved Blender candidate, imports both sources and exports the v03 work file, runtime GLB and metadata. Capture fixtures and preservation/re-import tools are in `art/work/animation_template/`. Their animation sampling is for visual review, without timing or hardware metrics.
