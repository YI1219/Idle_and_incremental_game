# 独立动态水面渲染

更新于 2026-11-10。实现文件为 `scripts/terrain_editor/water_renderer.gd`，检查文件为 `tests/water_renderer_test.gd`。本报告记录独立渲染模块的功能与 CPU 检查，实际 Godot 画面由主任务统一采集验收。

## 集成调用

先完成 `terrain_renderer.configure(data)` 及初始地形发布，再创建此节点并调用以下接口。节点可以挂在编辑器或 terrain_renderer 下。

```gdscript
var water_renderer: Node3D = preload("res://scripts/terrain_editor/water_renderer.gd").new()
add_child(water_renderer)
water_renderer.configure(data, terrain_renderer)

# 仅由编辑器的 _process 驱动。
water_renderer.tick(delta)

# 权威地形提交或新地形发布后。
water_renderer.sync()

# 预设切换、读取布局或替换 data 实例后。
water_renderer.reset(data)

# 保存、固定截图和显式退出前。
water_renderer.flush()
```

`configure` 与 `reset` 等待初始静态水面完成发布，初始模拟时间为 0 秒。需要固定有实际出流的初始瀑布画面时，调用 `tick(0.1)`、`flush()`，随后冻结编辑器处理。冻结期间只要没有显式 tick，水量及发布版本均保持不变。

`sync` 合并待协调请求。后台任务结束后才读取权威 data 调用 solver.sync，并重新制作快照，旧拓扑几何结果会在发布前被丢弃。`flush` 等待全部任务，消化已接收的有限时间队列，协调最新作者编辑，并通过 solver.write_to_data 写回连续 `water_volume` 及求解器基线。

## 线程与发布

- 单个后台任务独占求解器，并完成水量推进、轻量 FlowField、三层水面网格及两张 CPU 图像。每次推进最多 0.1 秒，常规更新间隔 0.1 秒。
- 等待队列最多 0.3 秒，另可有一个 0.1 秒在途任务。超出积压上限的墙钟时间被舍弃，物理体积仍按实际推进守恒。
- 主线程复制独立作者快照，任务完成后再创建或更新纹理、替换完整网格、绑定共享材质与更新 mist。ImageTexture 尺寸相同时复用，发布流程包含闲时 water_volume 写回。
- `_exit_tree` 与 `NOTIFICATION_PREDELETE` 都等待在途任务，覆盖已加入场景及 detached 节点的释放。
- `flow` 仅在闲时可读写。实时 UI 可读取稳定的 `published_volume`、`published_discharged_volume`、`published_depths`、`published_heights`、`published_basins`、`published_surfaces`、`splash_points`、`fall_veils` 及 `publication_revision`。逐步确定性检查先调用 flush。

## 网格、材质与场数据

- FlowField 继承 ContourTerrain，仅使用 solver.basins 的相同水位与权威 cell 床高制作水面，复用 `_cap`、`_falls` 与法线处理。没有调用完整地形 refresh。
- 独立节点名为 `water`、`waterfall`、`bank`，复用 terrain_renderer.materials 对应实例。旧地形同名层会在 configure、sync、flush 及新 chunk 入树时隐藏，静态 shore 与 lake_bed 保留。遍历会跳过独立渲染器自己的子树。
- 瀑布边沿根据正值 solver.last_transfers、实际下游高度和原始单元边的横向范围启停，堵塞邻边无法借用近旁流量。边沿进一步细分至约 0.4 米后采样。
- `_flow_edges` 提供 `rate` 和 `[0,1]` 范围的 `intensity`，后者为 `clamp(rate / 0.45, 0, 1)`。父任务的 `_falls` 与 waterfall shader 负责把该强度用于水帘透明度。splash、veil metadata 也携带最近贡献单元边的实测 rate 与相同 intensity，供 mist 缩放。
- solver 的 null 目的地没有方向字段。当前外排公式对同源的所有缺失邻边具有相同水头，渲染按这些边平均分配同源外排总 rate。落向虚空时保留既有外落差估计。
- 动态 shore RGBA8 图分别存岸距除以 3、深度除以 4、冲击强度及湿标记。岸距为有限范围的同 basin 网格传播。绑定 `shore_field`、`shore_origin`、`shore_extent`。
- 全局 live RGBAF 图分别存绝对物理水位、深度、归一化出流及 terrain-cell-present。`live_water_rect` 为全部权威 cell 的包围矩形，`live_water_active` 在存活发布时为 1，退出时为 0。干单元的 R 为床高，G 为 0，A 为 1，空岛发布 1×1 零场。
- 可见网格省略低于 2 毫米的水深，求解器保留全部正体积。水面沿用既有 0.045 米视觉偏移。
- mist.sync 始终同时接收正常 terrain_renderer.contours.land_regions，保留下方地根薄雾。

## 已运行检查

Godot `4.7.2.stable.official.ed1daf0bf`，本开发机 headless 检查。

- `tests/water_renderer_test.gd` 47/47。
- `tests/water_flow_test.gd` 92/92。
- 覆盖有限初始水量、无隐式补水、接收水体、材质及纹理发布、网格有限坐标、后台单所有者、任务中拓扑编辑、旧层隐藏、邻接堵塞门控、重置、空岛、干岛、冻结、亚可见体积和入树及 detached 释放。
- 回归过程实际复现了相邻堵塞边误画瀑布、detached 节点在任务完成前释放导致崩溃、嵌套挂载时误隐藏独立水面。三个回归均已通过对应检查。
- 全项目旧测试与原生图形/着色器采集由主任务统筹，本模块报告范围为上述两套已运行检查。

以下为最近一次运行的 CPU 墙钟毫秒，worker 含 solver、mesh、images。publish 包含主线程 water_volume 写回、资源替换、纹理上传提交及 mist 更新，未包含 GPU 完成时间。

| seed / preset | cells | 0.1s worker | solver | mesh | images | publish | snapshot | sync |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 7301 / 0 | 623 | 23.343 | 5.694 | 16.786 | 0.863 | 1.815 | 0.153 | 1.206 |
| 2104 / 0 | 623 | 24.112 | 5.996 | 17.328 | 0.788 | 1.930 | 0.163 | 1.265 |
| 4242 / 1 | 503 | 21.291 | 4.803 | 15.802 | 0.686 | 1.509 | 0.134 | 1.048 |
| 913 / 2 | 571 | 0.296 | 0.001 | 0.012 | 0.283 | 1.647 | 0.137 | 1.148 |

时间字段包含 `last_advance_worker_ms`、`last_advance_stages`、`last_worker_ms`、`last_worker_stages`、`last_publish_ms`、`last_snapshot_ms` 和 `last_sync_ms`。flush 的最后一次任务可能只是零时间重制，分析求解耗时时使用 last_advance 字段。

## 验证边界

10Hz 水面快照之间直接替换，流纹继续由共享材质的时间参数驱动。草裁切、薄流瀑布外观、地形形变期间的接合与几处角度仍需主任务的实际 Godot 画面判断。

纹理为覆盖地形包围框的一单元一像素网格。正常预设尺寸很小，合法极端稀疏坐标可扩至 2049×2049，两张 CPU 场图合计约 80 MiB，并有对应纹理及更换图像的瞬时内存开销。大型领域的 solver、mesh 和同步写回成本尚未测量。

这些 headless CPU 时间不能代表 Windows 轻薄本或 MacBook Air 的约 60FPS 目标硬件性能，也不能代替美术验收。
