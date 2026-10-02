# Qinglan garment v06 — refinement candidate, visual acceptance incomplete

Date: 2026-09-20. Runtime: [qinglan_garment_v06.glb](../../../assets/characters/qinglan/qinglan_garment_v06.glb). Work file: [qinglan_garment_v06.blend](../../work/qinglan/qinglan_garment_v06.blend).

**Functional and preservation checks pass. The requested visual acceptance is not fully met.** Knee-length trousers and exposed calves are restored, and garment-only secondary motion is active. Remaining inner-layer/leg intersections, angular sleeve faces and folded hem artifacts still require refinement. This is not a finished character or an intersection-free outfit.

## Diagnosis and retained changes

Inspection began with CURRENT_CONTEXT.md, AGENTS.md, the three v04/v05 reviews, actual v05 Godot frames and the Blender work file. v04 extended the trousers to the ankles and removed 113 covered-calf faces; v05 retained both. v05 sleeves were bound principally to the arm chain, ribbon bends were constant in the preserved clips, and the old `motion_follow_through.gd` was not attached to the player. Surface maps could not address those motion limitations.

- Restore the v03 trouser topology (64 vertices per leg) and original knee hem at authoring z=0.296945, about 1.7 cm below the knee joint in this 1.12 m character. Keep the v05 upper waistband fit and woven materials; ease the hem radius by 10% around the restored skin.
- Restore all v03 Body geometry and weights, including the 111 vertices / 113 calf faces omitted by v04. **No additional body mask** was introduced. This restores the v03 outfit body, not a newly reconstructed anatomical mesh.
- Retain the Tripo-derived robe topology. Reweight 757 sleeve vertices to six new garment controls (one sleeve and two cuff controls per arm), take in their free depth and lift hanging excess by at most 2.5 cm. Retain wrist openings, body rig and original motion.
- Reweight 2,110 lower-robe vertices. Central front/back panels follow the outer thigh envelope rather than an average of opposing legs. Side panels keep bounded local thigh/shin support; four new hem controls add free-edge bend. This improves front-panel continuity but does not remove all intersections or coarse panel folds.
- A [garment-only modifier](../../../scripts/characters/garment_motion.gd) adds bounded damped response to acceleration, authored arm/stride motion, hip bob and actor turns. Ribbon links have progressively delayed responses; cuffs also react to root yaw; hem tips combine delayed movement with a knee-clearance bend. No humanoid bone is overridden. There is no cloth solver or runtime per-vertex collision solver.
- Keep indoor walk, courtyard gentle jog, exploration run, CMU turns, movement/collision rules and combat behavior. Reset garment state on relocation; input blocking lets the zero-velocity outfit settle instead of resetting it every frame.

Godot applies the modifier after animation using its physics callback and supplied delta; zero-delta evaluation adds no spring energy. The implementation follows the [SkeletonModifier3D timing contract](https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html). This is controlled skinning, not simulated fabric or general collision handling.

## Actual Godot evidence

- [Walk / gentle jog / exploration run, before and after](gaits_before_after.gif): real player/controller, three seconds per gait, starting from rest. Top is v05, bottom v06.
- [Turns, before and after](turns_before_after.gif): ten-second real-controller sequence, including starts, quarter turns, reversal and stop. All original engine frames are retained in `before/` and `after/`.
- [Paired side run](run_side_comparison.jpg), [v05 run sheet](before_run_sheet.jpg), [v06 run sheet](after_run_sheet.jpg), [gentle jog](after_gentle_jog_sheet.jpg), [half-turn poses](after_turn_right_180_sheet.jpg).
- Regression surveys: [attack](after_attack_1_sheet.jpg), [counter](after_counter_sheet.jpg), [dodge](after_dodge_sheet.jpg), [recovery](after_dodge_recovery_sheet.jpg).
- Actual play scene: [courtyard](courtyard.png), [nearer character](character.png).

540 final phase frames cover 15 clips (the ten originals, gentle jog and four CMU turns), 12 phases each, from front/side/rear. The in-place phase surveys hold actor heading per camera and use authored cadence with prescribed velocity inputs, including 6.2 m/s for dodge. They are not a replacement for actual traversal: the paired controller captures apply production animation speed, trajectory and heading. The cloth-only surveys hide the sword for visibility; traversal and play-scene captures retain it.

All images are engine renders, not concept art or Blender-only renders. Packaging only crops/resizes/labels rendered pixels and encodes GIFs; it synthesizes no intermediate motion. [Capture manifest](capture_manifest.json) identifies the final asset. Metal Forward+, Godot 4.7.2, Apple M4 Pro; 960×960 phase views and 960×640 traversal. Fixed stepping is a reproducibility fixture, **not a performance measurement**.

## What remains open

Short trousers, exposed calves and bare feet now match the intended design. The phase sheets show reduced broad white lower-trouser breakthrough compared with the ankle-length v05 outfit, and actual motion has additional cuff/ribbon/hem response. However, the broad angular back-sleeve face still reads as a sail in some arm poses. Coarse folds and exposed inner panels remain during high knee flexion; attack and dodge are particularly challenging. Near-camera softness and a consistently clean hem have not reached acceptance.

[720 final post-modifier poses](deformed_poses.json) were inspected by CPU skinning with the exported inverse bind matrices and triangle BVHs. [Intersection diagnostics](intersections.json) found **zero sampled left/right calf-foot intersections and zero left/right trouser intersections**, but **nonzero robe–trouser, robe–calf and knee-hem–skin intersections remain**. Counts include internal/thin-shell surfaces and are not a count of visible defects. They are also not grounds for declaring the outfit clean. Existing masking, removed samples or a single good frame are not used to claim clearance.

An offline capsule-guided vertex-fitting trial reduced some penetration counts but visibly damaged folds/seams. It was rejected and is not in the runtime. [Trial report](clearance_fit.json), its input poses and separate work files preserve the evidence. Further fitting should respect panel continuity and independently supported free edges; a cloth solver would not by itself repair coarse source topology. No solver was added on speculation.

Toe/clavicle articulation, hand grip, facial expression, shoulder/cuff shape and final xianxia finish remain open. No target-device FPS, long-idle energy or stability claim is made.

## Fresh verification and preservation

All ten test scripts passed on the final runtime/controller:

| Script | Checks / result |
| --- | --- |
| garment_motion | 40,059 assertions, 0 failures; most are repeated per-bone/per-frame invariants |
| gait_context | 36 / 0 failures |
| running_turn | 99 / 0 failures |
| turn_transition | 520 / 0 failures |
| template_motion | 37 / 0 failures |
| animation_refinement | 123 / 0 failures |
| space | 22 / 0 failures |
| demo | 29 / 0 failures |
| sword_runtime | 0 failures |
| combat | 0 failures |

[Machine-readable results](tests.json) and individual logs are adjacent. The template test now permits exactly the garment modifier, while the new test verifies all humanoid transforms through the actual modifier signal across 11 movement/turn/action/recovery clips. It also covers 30/60/120 Hz response, real menu blocking, zero-speed root turns and relocation reset. Independent review reproduced the blocked-frame reset and omitted root-yaw defects; both were fixed. Isolated mutations reintroducing them fail 4 and 6 assertions respectively.

[Preservation](preservation.json): 381 pre-existing source/assets retain their SHA-256 values. All ten original clips retain byte-identical time/value accessor data and interpolation for all 84 channels per clip. Channel node indices are remapped to the same named bones because the rig gained controls; no original motion curve changes. Original 28 rest transforms and inverse bind matrices are identical. Thirty exporter-generated constant channels for the ten new controls are removed from each clip; runtime secondary motion drives those controls separately. Originals remain untouched.

[Mesh verification](mesh_preservation.json): complete v03 outfit-body positions, faces and weights restored; robe faces unchanged; ribbon/belt geometry and bindings unchanged; original trouser face topology restored. [Round-trip](roundtrip.json): 10 meshes, 38 bones, 90 finite sampled export poses, no unweighted vertices. Four normalized weights per runtime vertex are verified separately.

## Reproduction and tooling

No tools, packages, plugins or add-ons were installed: existing Blender 5.2.1, Godot 4.7.2, Python, NumPy and Pillow suffice. Production Blender commands use factory startup. No Cursor collaboration, Tripo operation, purchase or original replacement occurred. This directory has no Git repository, so no commit/push is claimed.

1. `blender --factory-startup -b --python-exit-code 1 --python tools/qinglan/refine_garment.py`
2. `python3 tools/qinglan/preserve_garment_tracks.py`
3. `godot --headless --editor --path . --import`
4. Run `art/work/garment_v06/capture_after_phases.gd` at fixed 60 Hz, and `capture_after_traversal.gd` at fixed 30 Hz; run `capture_game.gd` for play-scene views. Use the normal Metal renderer here.
5. Run `sample_deformation.gd` headlessly, then Blender `check_intersections.py`. Run the ten tests and preservation/mesh/round-trip scripts.
6. `python3 art/work/garment_v06/package_previews.py`

The v05 baseline capture explicitly loads v05 with the v06 modifier disabled. `fit_garment_clearance.py` is a rejected experiment that writes only separate trial outputs; it is not part of the production build above.
