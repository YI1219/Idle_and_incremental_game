# 淹水草地修复

## 根因与修改

- `ground.gdshader` 始终画草地，`rim_green.gdshader` 的边缘真实草叶从未读实时水场。`grass_blades.gdshader` 只按 texel 的 G 水深缩局部 Y，倾斜实例还留下 XZ 叶片，邻近高台也会被同一湿 texel 误藏。
- 四个分配的 shader/include 现在以水场 R 绝对水面减实际根高，G/A 只确认有水且 texel 有效。地面和草根采用过渡后显示高度。边缘草以 UV.x 承台高度采水，保留原有埋根收束点。
- 水深 0.5–4mm 平滑切换，5mm 浅水已完整露出既有 `wet_bank_material` 泥石底材，草绒法线随之减弱。草叶收束完整 XYZ 并丢弃淹没片元，退水自动恢复。干地原有草色、起伏和风算式保留。
- 生产改动只在 `ground.gdshader`、`rim_green.gdshader`、`grass_blades.gdshader`、`live_water.gdshaderinc`。权威地形、求解器、有限水量、独立自然物没有改动。

## RED / GREEN

- 原生 Forward+ `tests/flooded_ground_test.gd` 初始 17 项中 4 项失败，命中地面未换材、rim 草残留、倾斜草残留、高根误淹。证据为 `flooded_red.log` 与 `flooded_pixels_red/`。
- 追加高于水面 2mm 的 rim 干唇用例，20 项中 1 项失败，定位到把 -6mm 埋根点当承台高度。`flooded_edge_red.log` 留存该 RED。
- 最终 20/20 通过，见 `flooded_green.log` 与 `flooded_pixels/results.json`。5mm 水深下 rim 6628 像素变 0，倾斜真实 MultiMesh 草 2249 像素变 0。0.7m 高根仍为 2249 像素，rim 高出水面 2mm 保持原叶片。地面和两种叶片退水与干态逐像素差为 0。
- 相关 headless 回归通过，scene 7/7、水集成 11/11、草唇 24/24、草接触 4/4。日志为 `flooded_related.log` 与 `flooded_contact.log`。全工程汇总回归由主任务执行。

## 实际 Godot 画面

- `flooded_surface_reframed/seed_7301/` 是清楚的主证据，正/侧/反向 65°、原生 2560×1440、4×MSAA、日景 .29、相位 1.25。`01_before_flooded_*` 与 `02_after_flooded_*` 在同一 live scene 内仅切三份草 shader，`03_dry_brush_restored_*` 为既有 dry 工具实际排水后的恢复。
- `flooded_surface_native/seed_7301|2104|4242/` 为首轮 21 张实拍。反向近景前景遮挡较多，主要用作保留种子检查。补拍 10 张改善瞄点，合计 31 张。没有读取用户布局。
- 每个种子在上池岸边用两笔真实 lower，分别影响 13 和 11 格，再让原求解器演进 3 秒，11 个原干地格被实际淹没。留存加外排相对初始水量误差均为 `1.61e-12`。
- 9 组 before/after 的相机、灯光、相位、权威 data hash 与水量均匹配，所有采集帧内 data 保持不变，原生采集无 shader 错误。详见 `flooded_native*.json` 与 `flooded_audit.json`。
- 正向主图可直接看见绿草池底变成既有泥石色，侧向和反向确认同样变化，排水图恢复草地。图中既有竖薄墙、瀑布硬边及树石仍可见，由其他职责处理。此处为实际 Godot 输出，美术结果待用户验收。

## 证据边界

- 31 张实拍早于最后 rim 采水点从 -6mm 埋点改为 UV.x 承台面的窄边界修正。该修正已由新增原生像素 RED/GREEN 覆盖，主任务最终整体验证应加载当前代码。
- 排水实拍采用现有 dry 工具，3 秒水流演进与 before/after 守恒检查单独记录。没有声称自然流动会排空封闭低洼池。
- 只在 Apple M4 Pro 开发机验证功能与图像，没有测目标 Windows 轻薄本或 MacBook Air 性能。
