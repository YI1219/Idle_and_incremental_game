# 降低后竖薄片诊断

2026-11-10。只读生产源码，诊断脚本和证据全部位于本目录。5份目标生产源码与 `source_before` 的 SHA256 相同，见 `edit_cracks_source_audit.json`。

## 已复现的终态缺陷

唯一入口 `scenes/terrain_editor.tscn`，默认 preset 0、seed 7301。停止场景自动演进后，通过生产 `Data.apply_brush` 每笔锁定点击处同层，中心 `(-8,-5)`、半径 `3.8`、`lower` 连续4笔，使该草台 `3.5 → 1.5`。每笔正常提交/发布，最终显式推进到 `morph_progress=1.0`、退役 chunk 为0。

- `crack_native/03_upper_final_reverse.png` 可见穿过灌木旁的长斜灰色刀片，形态与用户截图相符。该图为真实 Godot Forward+ 2560×1440 输出。
- `crack_native/01_upper_half_morph.png` 为第4笔过渡半程，`02_upper_final.png` 为同机位终态。终态仍有薄片。
- `crack_native/05_lower_final.png` 是另一确定输入，中心 `(13,0)`、半径3.8、同层连续4笔降低，可见邻水窄石片。
- `edit_cracks_fixture_04.json` 保存第一组权威数据，`edit_cracks_native.gd` 固定镜头、时间 `.29`、材质相位1.25。初始水只推进 `.1s` 后冻结。未读取用户未保存布局。

## 来源已定位到独立冠柱

`crack_layers/02_hide_columns.png` 只关闭 `cliff_column*`，保留 generated cliff，长斜刀片消失。隐藏 `stone_mantle` 后刀片仍在。`edit_cracks_rays.gd` 使用完全新建的 Decoration、没有 previous_runs，对同一数据重生成，射线仍命中同一独立岩柱，因此不依赖历史缓存。

具体为 `cliff_column_c`，`edge=(-9.182611,-8.119175)`，`pose.origin=(-9.174484,3.5,-8.096272)`，`width=3.813650`，`height=2.631579`，`is_step=true`。

| 原生图像像素 | 石片命中点 | 权威顶面 |
| --- | --- | --- |
| (1500,850) | (-9.148115,2.862362,-7.141125) | 1.5 |
| (2200,800) | (-10.654700,3.095045,-6.722658) | 1.5 |

两点在 `land_regions[3.5]`、`rim_regions[3.5]` 和该柱的冠顶投影之外。详见 `edit_cracks_rays.json`。第一片具体三角形为 `(-9.321654,3.118421,-7.069638)`、`(-7.891925,1.594737,-7.672120)`、`(-8.635057,1.723421,-7.343657)`。

## 精确的几何接口不一致

`terrain_decoration.gd` 的 `_column_layout` 在494–510行给每个累计高度轮廓生成冠柱，也包括新凹坑的负 winding 内环。`_rim_run` 将它识别为 step，959行按落差放大整块源模型。1354–1385行仍直接实例化完整的 wall-only `render_mesh`，柱侧/背面可超出其冠顶投影。

同时，`rim_union.gd` 48行单独保留原负 winding hole，92行原样放回最终区域。原孔仍按权威地形切除草冠，但整块柱墙没有套用相同的孔/低台面裁切约束。于是编辑暴露出伸进较低草台的源墙面，冠顶在该区域没有连续封闭面，出现刀片观感。`stable_runs` 保留远端分段并非这组输入的触发条件。

## 已排除的方向

`edit_cracks_incremental.gd` 用生产 `_worker_build → _affected_chunks → staging → publish` 做24笔跨 chunk 交错降低，每笔最终逐 chunk 与当前完整 field.build 比较。`cliff`、`stone_mantle`、`rim_green` 均一致，最终 morph均1、retiring均0。差异仅远端 grass 平面三角划分，full rebuild后全部一致。见 `edit_cracks_incremental.json`。

`edit_cracks_topology.json` 中原始、单圆笔、48交错笔、增量终态的高低累计轮廓都保持嵌套。没有证据支持扩大 affected chunks、修改 morph 或改 block_mantle 来解决这条刀片。

## 最小修复建议

在冠柱生成入口给“负 winding 内环且外侧接受面是较低 land”的新台阶使用已有连续 generated cliff 封壁，跳过不受孔约束的独立 step 冠柱。真实贯穿岛体的空洞应继续走原 base 逻辑。不要仅隐藏可见三角形，也不要用装饰覆盖洞口。若仍要在此类凹坑使用冠柱，须将柱实体裁到同一权威孔/接受台面边界并封闭切面。

`probe_decoration_without_hole_columns.gd` 是仅供因果验证的检查副本，暂时跳过所有负 winding 内环冠柱。`crack_hole_guard/00_full.png` 证明确定输入中的长斜刀片消失，生产文件未使用该副本。这个诊断副本未区分贯穿空洞，不能直接拷贝到生产。剩余边缘台阶平面与悬空自然物也需通过正式生成修复后的多角度检查。

建议最小 RED/GREEN 使用上述两个射线。修复后要求在真实顶面1.5上方不再命中这块 `cliff_column_c`，随后检查同机位正反向、undo/redo、原始基线与保留种子。

## 诊断边界

初次 surface-only 的“空中三角形”扫描没有扫描独立冠柱，因此其0项结果不能作为无薄片结论。后来原生分层和独立柱射线已覆盖此遗漏。`crack_layers/01_hide_cliff.png` 的隐藏函数使用前缀，也同时隐藏了 columns，不能单独用它判断 generated cliff 的贡献。02图仅隐藏 columns，定位成立。

本报告确认确定输入的长斜源柱刀片。用户当前运行中未保存布局未被读取，尚不能声称所有裂缝已被同一根因覆盖。没有改动物理水量，没有美术验收或目标硬件帧率结论。
