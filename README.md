# Yunlu Village · Base Demo

Ancient-style xianxia idle incremental game, including sandbox building in the Sea of Consciousness Courtyard, a village, and exploration scenes aimed at procedural generation. For new work, read [current consensus and handoff](CURRENT_CONTEXT.md) first. Current priority is validating art and performance of reusable modules across multiple layouts. The full three-scene system is not implemented yet.

The user uploads, generates, and downloads from Tripo. Images, parameters, and save directories are listed in [generation tasks](art/generation_tasks.md).

Qinglan, an enterable cottage, riverbank and small bridge, plus the starter sword, swing, directional parry, and movement-art practice are already integrated. The original spirit-spring, production-line, exploration, and return kernel still run.

**Art production:** Prefer evaluating complete free packs for generic assets. Custom models keep Tripo → Blender refinement. The running cottage and sword already use refined Tripo assets. Terrain, bridge, and facilities still include prototypes to replace. See [project constraints](AGENTS.md) and [asset status](art/README.md).

**Sword-cultivation combat progress (2026-09-20):** The starter sword has gone through Tripo → Blender refinement and is bound to the right hand. Left click / J swings; right click / K parries; Space spends a movement-art charge. Mouse direction gives a small assist; if the mouse has not moved, aim along facing. The character and the current practice dummy both use vitality/ward rules; close-range spiritual pressure drains ward in both directions. This is a single-dummy practice version. Three enemy attack types, multi-enemy, growth, and sword flight are not integrated yet. [Design](docs/combat.md) · [runtime pose](art/review/sword/runtime/attack20.png).

## Launch

Double-click **Play Demo.command**. Requires Godot 4.7; the script imports models, then starts. **Play Indoor Transition.command** opens the same scene without the import pass (faster if assets are already imported). You can also open `project.godot` in Godot and run.

`试玩基础Demo.command` and `试玩进出屋.command` remain as shortcuts to those two files, so existing Finder or Dock items keep working.

| Action | Keys |
| --- | --- |
| Walk relative to camera | WASD / arrow keys |
| Swing, with a small mouse-direction assist | Left click / J |
| Front parry; one action blocks at most one hit | Right click / K |
| Movement art, 2 charges, 2.4 s to recover each | Space |
| Rotate / zoom camera | Q, E / mouse wheel |
| Pan / recenter | Middle-mouse drag / Home |
| Toggle Build | B; in Build, left click lays ground, Shift + left click removes it |
| Sculpt height (raise / lower / flatten / smooth) | Build panel tools; hold left button; Alt = free height; [ ] = radius |
| Pause | Esc |

Walking into the cottage doorway switches to interior automatically; walking to the indoor south doorway returns. The east bridge can cross the river. River water and off-island areas block walking and dodge. The west dummy can be practiced on repeatedly; dodge during the gold-ring charge; it resets when finished. The south cloud gate still uses the original exploration demo; 7 collects into the pack.

## First-slice scope

- Character: black hair, white trousers, natural skin, bare feet; 28 bones; idle, walk, two historical attacks, and a basic dodge clip. Current sword moves overlay right-arm and wrist pose adjustments. Hems and ribbons use delayed bone motion, not live cloth physics.
- The cottage was replaced with an independent four-view → user Tripo generate/texture → Blender-refined model. 2966 triangles; doorway clear width 1.608 m, height 1.829 m. Character traversal, wall blocking, and indoor transition are verified. The old direct-modeled version remains as history only.
- Rivers use 47 normalized 8-neighbor connection states, 3D top faces, water one step lower, rounded banks, and merged cliffs. This is a reusable procedural geometry module, not 47 hand-painted textures.
- The expanded starting courtyard ground is for scale and traversal demo. The original 48-cell economy zone and original economy formulas remain. The expanded display ground and river are not yet on the land-upkeep ledger. Existing facilities still have placeholder looks.
- The character is still a demo working version: cuffs, collar, foot contact, and large motions still need official art refinement. There is no normal baking, complete combat growth, or save flow.

## Editable assets

`art/source` keeps Tripo FBX and approved concepts; `art/work` keeps Blender files; `art/review` keeps inspection images and reports; `assets` keeps Godot GLBs. Processing scripts are in `tools/qinglan` and `tools/cottage`.

## Verification

The historical results below are not a retest of this round and do not mean art or target-device performance is accepted. After changing implementation, run the related checks.

```sh
python3 tests/run_preview.py tests/demo_test.gd --headless
python3 tests/run_preview.py tests/space_test.gd --headless
python3 tests/run_preview.py tests/camera_test.gd --headless
godot --headless --path . --script tests/sword_rules_test.gd
python3 tests/run_preview.py tests/sword_runtime_test.gd --headless
godot --headless --path . --script tests/combat_test.gd
godot --headless --path . --script tests/terrain_test.gd
godot --headless --path . --script tests/island_volume_test.gd
godot --headless --path . --script tests/rockkit_test.gd
godot --headless --path . --script tests/xirang_test.gd
godot --headless --path . --script tests/heightfield_test.gd
python3 tests/run_preview.py tests/sim_kernel_test.gd --headless
python3 tests/run_preview.py tests/sim_loop_test.gd --headless
python3 tests/run_preview.py tests/sim_research_test.gd --headless
python3 tests/run_preview.py tests/sim_explore_test.gd --headless
```

For in-engine screenshots, run `godot --path . --script tests/capture_demo.gd --resolution 1280x720 --fixed-fps 60`; output goes to `art/review/demo`.

Cottage integration update: default camera distance was set to 16.5 so the roof reads fully. Demo 21/21, indoor space 21/21, camera 8/8 passed. In-engine image: `art/review/demo/courtyard.png`.

Sword-cultivation integration: rules tests and runtime integration tests had zero failures; Demo 21/21, space 21/21. Runtime poses overlay right-arm and wrist adjustments on original animations and keep hem/ribbon delay. This is not a complete final animation set or a full-pose intersection review. The practice dummy is still a historical placeholder; no new visible asset was made to replace Tripo for it.
