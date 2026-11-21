# sol61 Godot 实机收敛

目标与约束来自用户 2026-11-09 指令及 `../20261109_wallpaper_targets_sol61/`。TARGET 是生成参考；本包 captures 是实际 Godot 输出。唯一入口 `scenes/terrain_editor.tscn`，不扩展玩法，不新增建筑、角色或地面层。

## 执行与验证清单

在当前用户指定的唯一工作区内直接执行，保留接手时已有的未提交修改。使用现有权威 contour / rim_union、y=0 草唇、独立自然物件与 argon 预设0；不另建项目版本或分叉场景。

- [ ] 移除场景中的 CultivatorActor 实例与其坐垫，检查正常运行、F11、切换种子均不重新创建人物；建立无人物 before。
- [ ] 草石：`grass_lip_soften.gd` 的浅软唇保留权威边界，`grass_field.gd` 沿真实斜面补足外缘草，`ground.gdshader` 将根土改为窄而断续；先复拍 B，再看 A/D。
- [ ] 岩壁：在 `procedural_shard.gd` / 既有布局内弱化齐平横圈与直立接缝，让斜脊接续全高山根；不变更 BASE 相机。
- [ ] 水：在现有瀑布网格与 shader 内调整宽瀑口轻微层次，保持细碎缎面水光；检查 C 及正反向。
- [ ] 最终 A/B/C/D：原生 2560×1440，Forward+、4×MSAA、动态相位1.25、F11净屏；seed7301/preset0；A/B/D progress0.29，C progress0.00。保留原 BASE 的相机数值。
- [ ] 复核 seed2104/preset0、4242/preset1、913/preset2；运行草唇、argon与场景回归。
- [ ] 完成 compare.html、源码/相机/光照 manifest、Downloads 镜像及逐项交付审计。

## 视觉判断

优先用 TARGET_B 的种植接合做尺度；A 的加雾、C 的额外压暗、B 的偏大草簇和跨图重绘不照搬。保持现有构图、调色表与日夜光照量级。功能通过不等于用户美术认可，目标硬件60FPS未实测。

## 当前证据

2026-11-09：已读取当前记录、AGENTS、美术方向、TARGET README/PROMPTS 并查看四张 TARGET。工程为 Godot 4.7.2 Forward+；本包尚未拍摄。接手时源码与29/28实机记录一致的范围将在 before manifest 中核对。
