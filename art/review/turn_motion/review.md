# Captured turn-footwork retarget review

Date: 2026-09-20. This is an asset and alignment review; final integrated movement and clothing review is separate. No performance benchmarks were run.

Four real human turn clips are available in `assets/characters/qinglan/turn_motion.tres`, a Godot AnimationLibrary targeting `QinglanRig/Skeleton3D` with the existing 28-bone rig. The library carries full primary-body motion. It does not synthesize stepping from sine waves or rotate an unchanged running pose.

| Clip | CMU source and frames, inclusive | Duration | Captured heading change |
| --- | --- | --- | --- |
| turn_left_90 | 69_24, 121–277 | 1.30 s | +90.38° |
| turn_right_90 | 69_20, 193–349 | 1.30 s | −96.86° |
| turn_left_180 | 69_13, 433–625 | 1.60 s | +161.33° |
| turn_right_180 | Sagittal mirror of the same 69_13 interval; limbs swapped | 1.60 s | −161.33° |

The half-turn contains the main planted pivot and a short settling interval. Its anatomical poses remain captured data. The runtime controller may map the extracted heading to the requested turn angle; the raw heading is retained in metadata instead of falsely labeling it exactly 180°. Quarter-turns include steps through the change of direction. No global playback acceleration was applied.

## Transfer and root motion

The reader reconstructs source world transforms from the original Acclaim skeleton and motion channels. Retargeting preserves captured world bone directions and corrects the different anatomical rest directions and target bone axes before calculating parent-relative joint rotations. This matters because the Acclaim rest legs are splayed while Qinglan's rest legs are nearly vertical.

The continuous source pelvis heading is removed from skeletal poses. `turn_motion.json` stores per-clip `root_curve` rows `[seconds, yaw_radians, root_x, root_z]`, beginning with zeros. The trajectory is expressed relative to the actor's initial facing, +Z in Godot; positive yaw turns left. These curves let the actor turn and move in sync with the recorded feet while using collision-aware controller movement. Matching `foot_curve` rows contain `[seconds, Lx, Ly, Lz, Rx, Ry, Rz]` for the grounded, yaw-removed target Foot.L/R bone heads in Godot local coordinates. `sole_height_curve` contains `[seconds, left_min_y, right_min_y]` from evaluated bare-foot mesh soles, allowing supporting-foot selection independent of ankle roll. A controller that adapts heading to a requested angle should also warp root travel and pivot position around the supporting foot; scaling yaw alone can slide the stance foot. The half-turn's net travel is about 3.4 cm; the quarter turns travel about 38 cm and 47 cm respectively.

A proportion correction translates the pelvis vertically until the lowest visible bare-foot sole is 3 mm above ground. It retains all captured joint rotations and relative foot lift. Secondary skirt and ribbon response follows the existing template convention. No base character GLB or source mesh was overwritten; the transfer container uses v04 only for exporting and diagnosing skeletal animation.

## Verification and visual inspection

- Imported all four clips into Godot and saved a separate AnimationLibrary; observed correct lengths and skeleton paths.
- `verification.json` compares every mapped world bone direction against the corresponding captured direction at all baked keys, including mirrored limbs. Maximum measured error is 0° at float precision.
- Evaluated the deformed body mesh throughout each clip. Minimum support-sole height stays 0.003 m, within floating-point error, after grounding correction. The alternate foot visibly lifts during replants.
- Inspected engine-rendered pose strips for all four clips. The half-turn transfers weight, replants the feet and changes torso orientation; both quarter turns retain forward stepping and separate arm/leg motion. The refreshed strips use the final grounded clips on v04, with visible ground shadows. They are source/retarget evidence, not final v05 clothing acceptance.
- The v04 rear waist/lining breaks visible in the strips were reported to the clothing refinement task. The final outfit must be reviewed with these same turn clips.
- The source lacks final xianxia acting polish. Qinglan's rig has no toe/clavicle articulation. Source-grounded footwork and correct alignment do not establish final naturalness or user art acceptance.

Rebuild tools: `tools/qinglan/turn_source.py`, `turn_retarget.py`, `turn_extract.gd`, `turn_verify.py`, and `turn_review.gd`. Workfile and transfer GLB: `art/work/turn_motion/`. Original sources and exact retrieved terms: `art/source/third_party/cmu_turns/`.
