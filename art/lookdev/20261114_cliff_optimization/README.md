# 2026-11-16 方案 A 净化岩壁、硬朗折角与台缘反向露岩过渡

## 背景与对齐目标

针对用户对先前繁杂版本（已完整归档至 [`rejected_busy_v2/`](rejected_busy_v2/)）与偏平版本（[`rejected_flat_v1/`](rejected_flat_v1/)）的反馈，通过同机位概念草图确认审美偏好后，严格按用户选定的**方案 A（`before` 净化强化版）**及具体修改意见在 Godot 生产管线落地：

1. **一主一辅、大面留白（方案 A 构图）**（`terrain_decoration.gd`）：将外缘抱脚巨石互斥半径收回到 `5.25m`（双跳局部影响半径 `<= 10.5m`），排除台阶翼侧碎块，全岛仅保留 **2–3 块主次分明的硬切单斜面抱脚巨石**，约七成崖面维持安静连贯的米灰大平面，右侧下层瀑布下方宽阔通透、无碎石拥堵。
2. **消除竖柱怪异鼓肚/收腰转折 + 保持硬朗折角**（`procedural_shard.gd`）：重写 `_add_varied_body` 八组断面与 `_add_continuous_body` 脊线幅度，保证所有立柱沿高度单调平直收分、彻底消除瀑布右侧侧翼剪影的中段鼓肚与 `S` 形收腰折弯；将 `_soften_pair` 与 `_build_root_boulders` 法线软化阈值从 `(55°, 0.65)` 收紧至 `(20°, 0.26)`，并恢复单平面硬切斜削顶盖，保留清晰硬朗的低多边形折面转角。
3. **移除自动台缘散石 + 新增石壁反向露岩与稀疏秃草过渡**（`terrain_decoration.gd`、`cliff_rim_balding.gd`、`grass_field.gd`、`grass_lip_soften.gd`、`rim_surface_detail.gd`、`ground.gdshader`）：停用自动生成的台缘散落石块（`_outcrops = []`，交由玩家自行摆放）；新增世界空间锚定的 `CliffRimBalding` 外缘场，在约三成干崖岬角与硬转折处收窄草唇悬挑、清除外唇与露岩区 3D 草簇，让米灰风化岩面与短矮干橄榄稀疏草坪反向咬入台地，打破“100% 浓密草坪单向覆盖石壁”的单调边界。
4. **缩边护壁净空与编辑局部一致性**（`block_mantle.gd`、`contour_terrain.gd`）：将 `stone_mantle` 上沿钳制在 `minf(h - 2.15, -0.45)` 并过滤异向/远端 Voronoi 碎片，彻底消除 `edit_contract` 与 `foot_reverse` 高墙中段凸出三角块；`expand` / `contract` / `lower` / `raise` 保持 `> 10.5m` 远端零扰动及异步线程与全量重建逐块一致。

## 修改范围与边界

- **生产脚本与地表着色器（11 份）**：
  - `scripts/terrain_editor/procedural_shard.gd`
  - `scripts/terrain_editor/terrain_decoration.gd`
  - `scripts/terrain_editor/cliff_rim_balding.gd`（新增）
  - `scripts/terrain_editor/terrain_renderer.gd`
  - `scripts/terrain_editor/grass_field.gd`
  - `scripts/terrain_editor/grass_lip_soften.gd`
  - `scripts/terrain_editor/rim_surface_detail.gd`
  - `scripts/terrain_editor/block_mantle.gd`
  - `scripts/terrain_editor/contour_terrain.gd`
  - `scripts/terrain_editor/rim_outcrops.gd`
  - `shaders/terrain_editor/ground.gdshader`
- **新增 / 更新测试（4 份）**：`tests/cliff_form_variety_test.gd`（57 checks，含立柱零收腰折返断言）、`tests/cliff_near_consistency_test.gd`（217 checks，含方案 A 肩石数量、零自动散石、`>10.5m` 局部性与 `CliffRimBalding` 断言）、`tests/cliff_outer_foot_test.gd`（1019 checks）、`tests/cliff_outer_color_test.gd`。
- **受保护文件（9 份，全程零修改）**：
  `terrain_environment.gd`、`stone_normals.gd`、`time_solar_system.gd`、`cliff_shoulder_join.gd`、`stone_surface.gdshaderinc`、`cliff.gdshader`、`cliff_column.gdshader`、`cliff_rock.gdshader`、`cliff_palette.gdshaderinc`。

## 实拍采集与验证结果

- **实拍对照页面**：[`compare.html`](compare.html)（仅包含实际 Godot 渲染输出，与概念草图严格分离）
- **原生 2560×1440 Forward+ 实拍（共 64 张 PNG，`valid=true, errors=[]`）**：
  - `final/`（12 张，种子 `7301` 预设 `0` 白昼）
  - `final_edits/`（4 张，`edit_contract` / `edit_expand` / `edit_lower` / `edit_raise`）
  - `final_held2104/`（12 张，种子 `2104` 预设 `0`）
  - `final_held4242/`（12 张，种子 `4242` 预设 `1`）
  - `final_held913/`（12 张，种子 `913` 预设 `2`）
  - `final_night/`（12 张，种子 `7301` 夜景 `progress=0.83`）
- **自动化验证**：`40/40` 全部通过（`31` headless + `9` native），另加 `scenes/terrain_editor.tscn` 90 帧原生 Forward+ 冒烟测试通过（`SMOKE 90 FRAMES: pending=false chunks=21`）。
- **明确边界**：
  - 所有自动化与渲染功能测试通过不等于最终美术验收（`checks/audit.json` 中 `art_accepted = false`，待用户通过 [`compare.html`](compare.html) 确认）。
  - Windows 轻薄本与 MacBook Air 约 60FPS 目标仍为未实测项（`target_hardware_performance_measured = false`）。
