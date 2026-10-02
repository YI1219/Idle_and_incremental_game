# Qinglan motion and playable-scene refinement

Date: 2026-09-20. **User rejected this animation pass as nonhuman and stick-like.** This report is retained as stage evidence, not an accepted direction. Template replacement supersedes further procedural gait polishing. Performance verification is explicitly deferred and was not run.

## Requirements, choices, and results

| Category | Status |
| --- | --- |
| User-confirmed requirements | Exquisite scene quality; lively, ethereal xianxia animation; existing assets retained; English development; no performance gate this stage. |
| Production choices in this pass | Calmer upper body, more distinct foot trajectory, breathing and head motion, draped ribbon rest pose, delayed fabric waves and turn response, continuous sword arcs, coordinated environment materials. These are implementation choices, not additional user requirements. |
| Implemented | New Qinglan motion asset is wired into the playable player; five refined clips, distinct guard, duration-aware playback, movement selected from actual travel, cloth turn follow-through. Eight Quaternius models and shared environment shaders are integrated in the default courtyard. |
| Verified this pass | In-engine sampled poses, main-game exterior/interior/return screenshots, two module layouts at three cameras, seven functional suites, GLB round-trip, geometry/material preservation. |
| Unverified / not accepted | Final visual acceptance, complete garment intersection removal, terrain-adaptive foot contact, nature placement/collision/interaction, exported-build inclusion, target hardware or long-session performance. |

## Motion changes

The Tripo-source geometry, skin weights, materials, and 28-bone rig are retained. The previous GLB and Blender source are preserved. `qinglan_motion_v02.glb` is the new runtime candidate; `qinglan_motion_v02.blend` is editable. The script `tools/qinglan/refine_motion.py` reproduces it from the preserved source.

- Idle adds restrained breath, small head movement, asymmetry and travelling ribbon motion. Ribbons rest downward rather than holding a horizontal flag shape.
- Locomotion uses a baked two-bone leg solve for clearer ankle trajectories and knee articulation. The torso remains comparatively calm, with modest opposing arm movement. This is an in-place authored cycle, not terrain-aware IK or exact world-space foot locking at every speed.
- Attack, guard and evasion settle back to the idle pose. Delayed cloth envelopes now reach zero at action end. Guard uses its own animation.
- The actual source-clip length determines playback speed, preserving attack/counter/dodge gameplay durations of 0.55/0.80/0.38 seconds. Damage, movement speed, charge and invulnerability rules are unchanged.
- The sword anticipates, cuts and returns through a continuous wrist arc. Runtime cloth and gaze respond with a small delay to turning.
- Locomotion selection uses resolved movement, so pushing into a blocking surface does not keep playing a full-speed walk.

## Visual evidence

- [In-engine motion study](qinglan_motion_v02.gif): actual player, bound starter sword and runtime modifiers. Movement is deliberately shown in place; this is not a traversal demonstration.
- [Actual traversal study](qinglan_traversal.gif): same live movement controller, unchanged travel speed, turns and stops on a neutral review floor.
- [Motion contact sheet](motion_contact_sheet.jpg): sampled idle, step, turn, recovery, strike, guard and evasion frames.
- Previous/refined comparisons: [idle](compare_idle_0.png), [step](compare_walk_1.png), [strike](compare_attack_1_2.png), [evasion](compare_dodge_2.png).
- Actual main game: [courtyard](game_courtyard.png), [character](game_character.png), [interior](game_interior.png), [return outside](game_return.png).
- [Environment refinement and layout review](../visual_refinement/2026-09-20/review.md): sparse water layout and relocated dry layout, three views each. Those static fixtures do not prove free-placement gameplay.

The sampled motion is less rigid, and the ribbon rests and recovers more naturally. The existing face has very little close-up detail; cuffs, collar and skirt skinning still show the asset's roughness. Raised-leg poses can expose coarse under-trousers and garment intersections. The terrain perimeter, bridge, bank and production blocks remain obvious prototypes. This pass is useful progress, but does not establish the requested final level of finish.

## Verification

- [Functional results](functional/results.json): animation refinement, scene-art integration, sword runtime, sword rules, playable demo, scene transition and camera suites all exited successfully. Animation contracts: 121 checks. Scene-art integration: 12 checks. Demo and space: 21 checks each; camera: 8 checks.
- [Exported stance regression](stance_geometry.json): four checks pass with 6 mm limits; both ankles have about 3.77 mm vertical variation and 4.89 mm forward drift in sampled steady straight-travel stance. This measures joints, not soles, turns or blends. Hip lowering uses the correct root-bone basis and cadence is calibrated to the authored stance distance.
- [Blender round-trip](roundtrip.json): 10 skinned meshes, 28 bones, 45 finite pose samples, no unweighted vertices.
- [Preservation comparison](preservation.json): 60 geometry/index/skin accessor comparisons are byte-identical to the previous character; materials are identical. Previous Qinglan, cottage and sword GLB hashes remain unchanged.
- Import and rendered capture logs have no script/shader errors. The helper was also checked beneath a translated and rotated parent to ensure plant world coordinates and contact patches agree. The courtyard sky mode is explicitly restored outside and disabled inside/exploration to preserve those scenes' background behavior.

The checks above concern correctness and visual inspection. Fixed simulation steps used for deterministic capture/tests are not performance measurements.

## Reproduction

From the project root, use Blender with `--background --python tools/qinglan/refine_motion.py`, then let Godot import the new runtime asset. Run `tests/animation_refinement_test.gd` and `tests/scene_art_integration_test.gd` with Godot's `--headless --script` option. Motion capture uses `art/work/animation_review/runtime_motion.gd` at 800 × 700 and a fixed 30-step rate; playable-scene capture uses `art/work/animation_review/current_game.gd` at 1280 × 720 and a fixed 60-step rate. No automatic upload, purchase or Tripo task is involved.
