# 连续守恒水量任务报告

2026-11-10。状态 DONE。Godot 4.7.2.stable.official.ed1daf0bf。

## 交付范围

- 新增 `scripts/terrain_editor/water_flow.gd`，独立 typed GDScript RefCounted 数值求解器。
- 新增 `tests/water_flow_test.gd`，92 项行为检查。
- 本报告。未编辑其他生产文件，未提交。场景、输入、材质和实际画面验证由父任务接续。

## 对外接口

```gdscript
configure(data: TerrainData) -> void
sync(data: TerrainData) -> void
step(delta: float) -> void
total_volume() -> float
write_to_data(data: TerrainData) -> void

var depths: Dictionary[Vector2i, float]
var heights: Dictionary[Vector2i, float]
var discharged_volume: float
var basins: Array[Dictionary]
var last_transfers: Array[Dictionary]
```

- `depths` 只含正水深，单位面积下也等于体积。`heights` 只含湿格，给出绝对水面。消费者只读。
- `basins` 含 `id`、`cells`、`height`、`volume`。`cells` 为格坐标到 `true` 的 Dictionary。`id` 每次重建按稳定坐标序生成。
- `last_transfers` 含 `from`、`to`、`rate`、`source_height`、`target_height`。出岛 `to=null`。同边多个子步合并，`rate` 为本次传入 delta 内实际转移体积除以 delta，表面高度保留最后有流量子步的值。
- 追加的 `write_to_data` 是显式持久化入口。它先对账，再把每个现存格的实时体积写入 `water_volume`，更新内部作者状态基线。`configure`、`sync`、`step` 不写 TerrainData，也不触发渲染或全局状态。
- 未变化的 `sync` 和持久化保留当前流量元数据。发生床高、拓扑或作者水量变化时清除旧流量。

## 数值与编辑语义

- 每格面积为 1，床高直接读取 `cells[cell].height`。没有 optional volume 时，初始深度由 `max(water * .5 - bed, 0)` 给出。有效 `water_volume` 优先，包括 legacy `water=-1` 的接水格。负数和非有限 optional volume 归零。
- 流率系数为 .45，驱动水头为上游表面高于 `max(source bed, target bed, downstream surface)` 的正值，再取水头的 1.5 次方。四邻接、同时计算、按供体总预算缩放，接收体增加量与供体减少量一致。空域接收量累计到 discharged。
- 子步最大 .025 秒，按 `ceil(delta / .025)` 整数计数并均分时长，正常 .1 秒 tick 实测恰为 4 步，不再执行浮点尾差的第五步。零、负数、非有限 delta 不推进。正体积没有干涸阈值，包含 `1e-20` 水深保留检查。
- 已有平池按体积和各床高重新求水平面，来水传播到已有池全域。仅合并整体表面范围在 .025 米内的相邻湿格，明显落差继续保持独立水池。体积下降时较高床格退出湿池。
- 同数据未变的格保留实时体积。床高变化保留并在已有池中重分配体积。旧笔刷抬床时有效 legacy 标志变为 -1、optional volume 未变的情况按床高编辑保量处理。编辑开始前用 `write_to_data` 固化当前量，可避免旧笔刷重新推导初始量。
- 删除格的水累计到 discharged。新增干格从零开始。显式改水量或干燥命令只重置对应作者编辑格，属于有意修改初始量，不计作物理出岛。删除、作者编辑或抬床干隔断造成的原池断开会先拆连通分量。新高床挤出的旧水仅均分给直接相邻的湿连通分量，各分量原有水量保留；无相邻湿分量的孤立抬床水保持其体积，后续按真实通量溢出。平池求解使桥接格变干时，公开 basins 也立即按剩余湿格重新拆分。

## RED / GREEN 证据

1. 先写测试，再运行 `godot --headless --path . --script tests/water_flow_test.gd`。求解器文件尚不存在，退出 1，`WATER FLOW: 1 checks, 1 failures`。
2. 首次实现后排除了两个测试夹具错误。过长小数写法在当前 GDScript 中被解析成零，改成科学计数法 `1e-20`。打开原闭合夹具的边界格时确实产生出岛流，补齐外侧高床后才检查闭合守恒。
3. 发现未变化的 sync 和持久化会清空当前可视流量。先新增两项行为回归，退出 1，`WATER FLOW: 80 checks, 2 failures`。随后让无编辑的 sync 保留输出，重跑 80/80 GREEN。
4. 独立审查发现三项此前80项未覆盖的缺陷。近等面 configure 求平后桥接格变干，公开 basin 仍跨过干格。批量抬高中格并降低右格时，旧池成员直接合算，造成原有左右水跨新干隔断拉平。反复减时长的循环使 .1 秒多执行一次约 `6.94e-18` 秒子步。
5. 先补审查夹具与测试侧子步计数子类，实际 `WATER FLOW: 92 checks, 7 failures`。按项修正后依次为6失败、3失败、0失败。近等面桥接夹具 `bed=[0,1.01,0]`、`volume=[1,.01,1]` 现得到独立两池，各体积1.005。抬床夹具初始3格各体积1，中格床高改3、右格床高改-2，现得到左右各体积1.5、表面1.5/-.5、中格干。两侧各保原有1，额外各接收中心位移的.5，后续10tick独立保量。子步计数实测 .1 秒恰4步，`1e-20` 秒完整1步。
6. 最终命令如下。数值套件退出 0，92 checks，0 failures。语法检查退出 0，无解析错误。

```sh
godot --headless --path . --script tests/water_flow_test.gd
godot --headless --path . --check-only --script scripts/terrain_editor/water_flow.gd
git diff --check -- scripts/terrain_editor/water_flow.gd tests/water_flow_test.gd
```

覆盖 legacy 初始化、continuous override、供体减少/接收体增加、闭域长时守恒、开域 retained+discharged 守恒、平池精确等面、池全域接收入流、保留瀑布落差、干岛不生水、高床阻水、多出口供体耗尽缩放、退水高床变干、极小深度、床高编辑、拓扑拆池、删除出岛、作者改水与干燥、持久化基线、数据切换、无效 delta、5 秒长帧、分帧等价、插入顺序确定性、实际 preset 0/1/2 及其 basin 输出一致性、configure干桥拆池、批量床高编辑干隔断、四子步计数与极小delta完整推进。

已运行的独立既有检查均通过，分别为 `argon_world_lock_test.gd` 9/9、`grass_lip_soften_test.gd` 24/24、`sol61_grass_contact_test.gd` 4/4、`waterfall_terrace_seal_test.gd` 16/16。父任务要求集成期间停止额外套件，本任务未运行 scene/runtime/blueprint 集成套件。

## 限制与后续验收

- 求解器采用四邻接高度场与准静态平池，不提供动量、浪涌或三维流体。
- .025 米为近等面合池容差，.45 为本轮系数选择。显式作者命令有意改变水量，守恒断言针对无补水命令的自然演化及床高/拓扑对账。
- 编辑器常规有限正 delta 按完整时长推进。极长 delta 的子步数受64位整数范围和实际计算时间限制，常规调用使用约 .1 秒。
- 浮点舍入误差保留在池内最低床格，公开 heights 使用同一精确池面值。测试采用 1e-9 体积误差，实际预设采用 1e-8。对接近浮点总和上限的巨大输入体积未做承诺。
- 本轮新增的抬床水位移规则为按相邻湿连通分量等分，属于准静态作者编辑约定。实际 Godot 水面、流向、瀑布粗细、编辑交互及目标硬件帧率尚由父任务验证，本报告只证明数值和所列独立检查。
