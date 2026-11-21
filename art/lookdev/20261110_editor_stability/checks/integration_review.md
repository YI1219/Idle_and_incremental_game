# 本轮集成只读审查

2026-11-10。审查基准为 `checks/source_before/` 中的本轮起点。审查对象为当前生产文件及新增测试。遵循 `CURRENT_CONTEXT.md`、`AGENTS.md`、`docs/art_direction.md` 与本轮 `WORK.md`。

## 结果

未发现可确认、需要立即修复的 Critical 或 Important 级别问题。

## 已核对范围

- `terrain_data.gd` 和 `editor.gd` 的齐平工具入口、落笔采高、整笔锁高、独立蓝图、松手提交、取消和一次撤销路径。齐平加入床面编辑的当前水量保留分支，撤销与重做沿用该分支。
- `shihai_hud.gd` 新增工具、画质与贴格按钮的绘制和命中区域，原有尺寸、水阶、撤销与折页位置随工具数量计算。
- `preview_quality.gd` 的尺寸刷新、2K像素预算、原生切换和MSAA恢复。缩放限制作用于3D，Viewport/UI尺寸保留。
- `grass_field.gd` 的LOD索引。近景属性数组保留，各LOD索引沿用同一叶片的根、对应截面与尖端。
- `ground.gdshader`、`rim_green.gdshader`、`grass_blades.gdshader` 与 `live_water.gdshaderinc` 的实时水场接口、无水/无效texel、绝对根高、过渡显示高度、完整叶片收束和退水恢复。生产调用处均使用新的vec3签名。
- `terrain_decoration.gd` 的源柱覆盖重检、缓存恢复后裁退、柱空间桶重建和关联脚石移除。`contour_terrain.gd` 的干内台阶封闭并入现有cliff表面，随后重建三角索引。保留有意贯穿空洞和湿瀑口分支。
- 新增五份测试及已有RED/GREEN日志、裂缝和淹水报告。核对了水求解器/渲染器的初始化、蓝图期间演进、发布时同步和持久化接口。

## 退水测试基准补审

`water_recession_test.gd` 的两条旧绝对hash断言曾在最终首轮出现失败。对应hash包含本轮明确裁退的5根不安全内部冠柱及其草面重组三角划分。`interior_column_audit.json` 对起点源码和当前源码作三种子逐项比较，记录30→25根、相同5根内部柱回退，以及每组 `exterior_unchanged=true`。本轮初始局部外观变化另有 `scene_review_final/` 同机位实拍。

将这两条断言改为同一权威床面、两种实际水量状态分别生成后的草顶vertices和columns/mass相等，符合退水回归的固定床面、固定干岸与独立岩块位置职责。现有物理出口射线、3m床面、自然60秒退水、零水量终点、cliff与lake_bed顶点不变量继续执行。`final_tests/water_recession_final.log` 为16项通过。本次判断为有依据的测试职责收束，历史外圈身份由本轮起点逐项审计另行保护。

当前 `interior_terrain_edit_test.gd` 保护连续降低的真实几何、warm/fresh生成、孔洞连边、撤销和贯穿空洞。初始外圈身份的三种子证据位于 `interior_column_audit.json`。

补审同时读取 `scene_review_final/captures.json`、`controls_review/controls.json` 和最终齐平9/9日志。原生控件记录含真实输入派发、取消恢复、9格对齐、撤销恢复与4K两档缩放/MSAA切换。淹水像素测试新增显式绘制和可指定输出目录，20条判定沿用。

## 证据边界

- 本次为静态独立审查，并读取已有测试证据。最终全套回归和当前冻结源码的原生实拍由主任务执行。
- `final_tests/terrain_level.log` 已按当前源码记录9项通过。
- 内台阶覆盖判定采用源网格顶点、边中点和重心采样。已有回归覆盖多种子、连续降低、深降、凹坑连边与撤销，任意编辑布局仍需要持续实际几何检查。
- 5根初始内部台阶冠柱的回退会改变局部初始外观，其美术影响交由主任务同机位正反角实拍核对。功能通过不构成美术验收。
- 4K测量来自Apple M4 Pro开发机。目标Windows轻薄本与MacBook Air帧率尚未测量。

审查产物为本记录。
