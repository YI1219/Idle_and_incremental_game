# Contextual gaits, stepping turns and fabric review

Historical version evidence. Current runtime and unresolved visual status are in the [v06 garment review](../garment_v06/review.md). The v04 ankle-length trouser extension was not the intended design and is reverted to knee length in v06.

Date: 2026-09-20. Reviewed version: fabric v05. This records implemented changes and fresh functional/rendered evidence, not user art acceptance. No performance measurements were taken.

## User requirements and production choices

The user confirmed visible transitional turn footwork, a jog between walk and run, courtyard jogging as the usual pace, and running for exploration. The user also reported plastic-looking clothing and asked whether simulation was needed. Exact speeds, blend weights, thresholds and durations below are implementation choices that remain tunable.

| Context | Current movement | Production speed | Motion source |
| --- | --- | --- | --- |
| Interior | Walk | 0.8 m/s | Preserved Quaternius walk |
| Courtyard | Gentle jog | 2.0 m/s | New 1-second phase-aligned blend: 45% walk, 55% jog |
| Exploration | Run | 4.5 m/s | Preserved Quaternius sprint template |

The new gentle jog is a separate animation resource; the original jog remains preserved. Its estimated native travel speed is 1.9867 m/s, derived from blended source-cycle distances, not a measured guarantee of perfect stance-foot locking. Low actual speeds still select walking. Gait transitions preserve stride phase. No new combat ability, sprint key or village scene was added.

## Turn implementation

Four real human stepping clips are retargeted from the [CMU Graphics Lab Motion Capture Database](http://mocap.cs.cmu.edu/). [Exact sources, terms and acknowledgment](../../source/third_party/cmu_turns/README.md), [retarget review](../turn_motion/review.md), and [curve metadata](../../../assets/characters/qinglan/turn_motion.json) are retained. CMU permits product inclusion but forbids direct resale of its raw or converted motion data; this is not CC0. Existing Quaternius loop licensing remains unchanged.

- Turns of about 60° or more brake into a stepping transition. Quarter turns use 1.3-second clips; half-turns use 1.6-second clips at captured cadence. Smaller direction changes steer gradually within the gait.
- Actor heading follows captured pelvis heading. Translation is adapted around the same supporting foot at both ends of each sample interval, using foot-position and actual sole-height curves. This avoids introducing the foot displacement caused by scaling only the heading.
- The half-turn source contains about 161.33° of captured heading, mapped to the requested corner. Right half-turn is a sagittal mirror with swapped limbs. These adaptations are documented rather than presented as an untouched, exactly 180° source capture.
- Input release or a new direction may end a turn at a supported-foot transition after the initial 0.15 seconds. New actions, input blocking and relocations clear the turn immediately. Same-named turn restarts explicitly blend from the outgoing pose.
- Captured displacement uses the existing wall/ground collision path. If a support step is materially blocked, the controller blends back into gradual gait steering for that direction rather than repeatedly replaying the blocked step. This fallback is not collision-aware foot IK.
- Animation and movement use the physics clock. Captures explicitly advance both at the same fixed step; they are visual fixtures, not benchmarks.

## Fabric and clothing fit

The runtime now uses [qinglan_fabric_v05.glb](../../../assets/characters/qinglan/qinglan_fabric_v05.glb), refined from the preserved v04 work file. Six embedded textile maps provide restrained color variation, weave normals and roughness. Existing sleeve and lower-robe volume is reduced. Upper trouser rings are fitted beneath the robe and the waistband follows the hips, removing the broad white waist/upper-thigh patches found during turn review.

Godot imports the textile maps but drops the exported specular extension. [fabric_finish.gd](../../../scripts/characters/fabric_finish.gd) applies a low 0.18 specular value to cloned cloth instance materials. [Actual runtime material inspection](materials.log) verifies the maps and override. The Blender sheen setting is not claimed as an equivalent Godot feature.

No cloth solver was added. Surface finish and oversized/fitted geometry required correction independently of simulation. The garment continues to use skinning and existing secondary animation. Full drape, collision-aware cloth and more responsive cuffs/ribbons remain open refinements. Broad cuffs and coarse folds still limit softness; this pass does not establish final xianxia character quality.

[Fabric/fit review and paired Blender renders](../fabric_v05/review.md) distinguish those CPU renders from the actual Godot captures below. [Preservation verification](../fabric_v05/export_verification.json) confirms all ten original animation tracks, rest transforms, inverse bind matrices and mesh topology are unchanged. Robe positions and upper trouser geometry/bindings changed; lower trouser geometry and the existing covered-calf body are retained. No faces or additional body surfaces were masked in v05.

## Actual Godot previews

- [Walk / courtyard jog / exploration run](gaits.gif): three seconds, showing starts and full travel at each context pace.
- [Stepping turns](stepping_turns.gif): ten seconds of the real courtyard player controller, including 90° turns, a reversal and stopping.
- [Turn contact sheet](turns_contact_sheet.png): selected frames from that same final capture.
- [Current courtyard](courtyard.png) and [closer in-game character](character.png): actual play scene, retaining existing environment and prototype objects.

The GIFs are packaged from unaltered engine frames, cropped/labelled for comparison, at their sampled 30 Hz cadence. No intermediate motion is synthesized. Source frames and sampled controller states remain in the adjacent `*_frames` directories. Reproduce with `art/work/gait_review/capture.gd`, `capture_game.gd` and `package_previews.py`.

Inspection of final sampled frames shows separate gaits, foot replants through turns and removal of the broad waist patches. This does not prove absence of intersections at all phases, all clothing blend combinations or near obstacles. Remaining source drift, transitions between different motions, bare-foot/toe articulation and cloth dynamics require continued visual judgment.

## Fresh verification

All nine functional test scripts below passed on the final controller/assets with Godot 4.7.2. Fixed simulation cadence is used for deterministic functional checks, not performance acceptance.

| Check | Result |
| --- | --- |
| `gait_context_test.gd` | 36 checks, 0 failures |
| `running_turn_test.gd` | 99 checks, 0 failures; left/right turns and reversals at 30/60/120 Hz |
| `turn_transition_test.gd` | 520 assertions, 0 failures; most are per-frame heading continuity checks; also adapted angles, release, redirection, same-name blend, real blocked step, actions and relocation |
| `template_motion_test.gd` | 36 checks, 0 failures |
| `animation_refinement_test.gd` | 123 checks, 0 failures |
| `space_test.gd` | 22 checks, 0 failures |
| `demo_test.gd` | 29 checks, 0 failures |
| `sword_runtime_test.gd` | 0 failures |
| `combat_test.gd` | 0 failures |

Doorway and bridge checks were updated for the intentionally slower courtyard/interior paces and the captured turn durations. They still test reaching the destination, physical collision and transition cover; they no longer require travel distances that assumed the old universal 3.6 m/s speed.

An independent code review identified angle-warp foot displacement, uninterruptible turns, collision mismatch and same-name restart blending. Those were corrected and covered by the targeted tests. Logs are adjacent to this report. [Runtime and preserved-asset hashes](runtime_hashes.json) identify the reviewed files. The original Qinglan, v03/v04 runtime assets, starter sword and cottage retain their previous hashes.

No original replacement, purchase, Tripo operation or performance benchmark was required. Functional passing and source preservation remain separate from visual acceptance.
