# Native 4K frame rate (2026-11-19)

Goal: raise the frame rate at native 3840×2160 (3D scale 1.0) on the Mac without lowering visible quality. Single entry `scenes/terrain_editor.tscn`. Cliff meshes, materials, light, shadows, MSAA, depth of field and plant counts are unchanged. All numbers are from the development machine (M4 Pro, Godot 4.7.2, Metal Forward+) and say nothing about a MacBook Air or a Windows thin-and-light.

## Method

`checks/probe_ablate.gd`: one process and one live scene; a real 3840×2160 SubViewport shown in a visible 1280×720 window; balanced quality (2× MSAA, 4096 shadow atlas, half-size SSAO, very-low DoF sampling), scale 1.0, no frame cap, VSync off, no image I/O. Each variant is applied, warmed 1.5 s, sampled, restored; the list replays forward then backward. Frame rate uses `Engine.get_frames_drawn()`.

Two caveats found while measuring:

- This machine showed a floor near 11 ms per frame (an empty scene with post effects off stayed at 87 to 95 FPS regardless of resolution, MSAA or sky). It is a cap, not an additive cost, and only distorts variants close to it.
- The first session ran on battery. `pmset -g log` shows battery warnings at 15:59 and 16:09 and the Mac shut down from under-voltage. Runs from that period sit in `checks/invalid_low_battery/` and are not used. Ablation numbers below were taken earlier in that session at falling charge, so read them as proportions; the final before/after pairs were re-measured on AC power.

## Where a native-4K frame goes (`ablate_1/2/3.json`, base about 34.3 ms)

| Item | Change when removed or hidden |
| --- | --- |
| SSAO and SSIL together | -7.15 ms (SSIL alone -4.03, SSAO alone -0.73) |
| 2× MSAA → off | -5.84 ms (4× costs another +4.93) |
| Grass blades | -5.0 to -5.4 ms (still about -4.1 ms at half resolution) |
| Sun shadows | -2.80 ms (casters alone -0.58; 8192 atlas +2.60) |
| Depth of field | -2.14 ms |
| Foliage cards | -1.93 ms |
| Cliffs | -1.51 ms |
| Two near cloud decks | -1.30 ms (distant mountains: no measurable change) |
| Ground | -0.48 ms |
| Water, waterfall, mist | about 0 |
| Half-resolution background layering off | +3.16 ms |
| Full "native quality" set (4× MSAA, 8192 shadows, full SSAO, no layering) | +7.41 ms |
| 3D scale 0.5 | -17.87 ms |

Grass: replacing all root-anchored vertex math with constants saved 0.51 ms, halving the LOD bias saved 2.40 ms. The cost is triangle count, not vertex shading. At 4K every clump used the 56-triangle middle level (about 745k grass triangles in view); at 2K the same camera uses the 14-triangle far level.

## Changes

1. `scripts/terrain_editor/grass_field.gd`: a 28-triangle level (key `.016`) between the 56- and 14-triangle levels. It keeps both bends of each leaf and drops only the cross-section ridge. The ridge rises under 9 mm and normal, UV and colour run linearly across the leaf, so the flat quad shades alike once the ridge is subpixel. The full near mesh and the far level are untouched.
2. `scripts/terrain_editor/preview_quality.gd`: balanced quality uses the engine's very-low SSIL gather; native quality restores the project setting. SSIL is gathered at half size and blurred four times.

## Result (AC power, six alternating rounds each, same live scene, every round in the same direction)

| Target pixels | Before | After | Gain |
| --- | --- | --- | --- |
| 3840×2160 | 29.91 FPS (33.43 ms) | 33.77 FPS (29.61 ms) | +12.9% |
| 2560×1440 | 56.95 FPS (17.56 ms) | 60.49 FPS (16.53 ms) | +6.2% |

Data: `checks/final_4k.json`, `checks/final_2k.json`. Native-quality mode at 4K was not re-measured after the changes.

## Picture checks

- `grass_lod/`: 4 cameras at native 4K, frozen time, wind and water. Repeat-frame noise is 0. Before/after mean difference 0.021 to 0.065 of 255; pixels differing by more than 8/255 stay under 0.13% and sit on single leaf edges; the `whole` camera is pixel-identical. Not lossless.
- `ssil_quality_probe*/`: 1080p, 2K and 4K, maximum difference 4 to 6 of 255.
- `final_day/`, `final_night/`: both changes together at native 4K, day and night; same order of difference. I looked at the 1:1 worst-case crops for the grass pairs and the night game view and saw no difference.

## Checks run after the changes

`grass_lod_test` 4/4 (native), `preview_quality_test` 12/12, `sol61_scene_test` 7/7, normal entry 90 frames with no errors. The full 40-case list was rerun with the rock-shape change in `../20261119_rock_shapes/checks/suite_final.json`.

## What is left costs visible quality

2× MSAA (5.8 ms), SSAO and SSIL (about 5.8 ms after this change), shadows (2.8 ms) and depth of field (2.1 ms) are the look itself. Measured options if a trade is acceptable: MSAA off at 4K about 34.7 FPS before these changes; DoF off about 30.7; 3D scale 0.5 about 59.6. The product has no "native 4K pixels with balanced effects" mode today: default renders 2K internally and upscales, and "native quality" also switches to 4× MSAA and 8192 shadows (about 23.8 FPS before these changes).

## Roll back

`checks/source_before/` holds the two scripts at task start (`checks/start_sha256.txt`). Restore those two files only.

`art_accepted: false`; `target_hardware_performance_measured: false`.
