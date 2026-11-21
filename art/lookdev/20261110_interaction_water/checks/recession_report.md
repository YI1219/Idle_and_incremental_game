# 自然退水时的固定出口床面

2026-11-10。生产改动限定于 `contour_terrain.gd`、`lake_bed.gd`、`local_lake_bed.gd`。新增回归为 `tests/water_recession_test.gd`。

## 原因与修改前证据

60 秒后的上池物理水位为 3.14567522935513 米，源单元权威 `cells.height` 为 3 米，历史 water=7 表示的初始水位为 3.5 米。独立水面正确退水，静态几何仍按 3.5 米封闭出口。

对原生 `water_evolution_final/water_060s_outlet.png` 的相机做 CPU 三角形射线追踪，旧米色横唇多点首先命中 lake_bed。原图像素 (1000,465) 命中 (1.842776,3.432693,1.707224)，该单元床高为 3 米。其他三个诊断像素命中高度为 3.208268、3.093700、3.318156 米。

两个来源叠加形成障碍。

- lake_bed.height_at 按邻近干岸把池床抬向初始水面以下 0.06 米。狭窄出口两侧的干岸坡会在口内连成高于实际床面的横坡。边界封闭四边形的上沿又统一保持在 3.5 米。
- ContourTerrain 的湿壁来自 nominal land_regions，顶部也保留在 3.5 米。3.1 米高的两条跨口水平射线分别在 x=1.568580 和 x=1.588516 命中静态墙面，水位降低后无法表现为开放出口。

原生产源码和 SHA256 已保留在 `checks/recession_source_before/`。诊断前先运行回归，8 项中有 6 项实际失败。

## 局部修复

新增静态出口床高查询，仅识别作者水域面向较低地面或虚空的单元边。完整干岸继续保留原高程。实现选取沿实际出口边宽度的局部通道，向池内最多 2 米、向外 0.45 米，以覆盖原来 1.45 米宽岸坡在狭窄口内相接的部分。

- 池床在该局部通道使用已有权威床高采样结果，边界封口上沿降到同一固定床高。普通床网格和 soft_water_corners 的 local_lake_bed 路径同时处理。
- 湿壁局部截到同一固定 raw bed 顶。原 nominal outlines、干草冠面和独立岩块布局仍用于固定地形构图。
- 水量求解及独立水面保持原实现，静态出口几何由权威作者地形决定。完全干燥时该出口床面与湿壁也保留相同形状。
- 原接收端 wet-wall clearance 归零与封口结构保留。

## 功能与几何复核

Godot 4.7.2 official。本次已运行以下检查。

| 检查 | 结果 |
| --- | --- |
| water_recession_test | 16/16 |
| waterfall_terrace_seal_test | 16/16 |
| water_renderer_test | 48/48 |
| terrain_locality_test | 15/15 |
| sol61_scene_test | 7/7 |

退水回归包含观察到的 60 秒水位、固定作者床面、原图四条诊断射线、两条高于床面的跨口通路、原干草顶点与岩块布局、soft-corner 床路径以及完全干燥端点。修改后四条诊断射线均命中 3 米及以下，3.1 米跨口射线保持开放。

修改前后干草顶点 hash 均为 2221245740，columns 均为 518139912，mass 均为 572092373。三个保护值已加入回归。自然退水后的 data 床高逐单元保持一致，完全干燥时静态 cliff 和 lake_bed 顶点也与有水状态相等。

## 原生图形诊断

最小诊断使用生产唯一入口，seed7301、preset0、Forward+、4×MSAA、原生 2560×1440、日景 progress0.29、相位1.25。显式推进生产 water_view 600 个 0.1 秒步长后冻结，输出以下两张图。

- `checks/recession_native/water_060s_outlet.png` 与旧退水图的同名相机、灯光、景深及其他共同采集字段完全一致。目测旧米色横唇消除，退水面接到实际床面，左右肩部闭合。
- `checks/recession_native/water_060s_shoulder.png` 补充 yaw20° 的侧角，肩部与既有底部封口连续。

诊断留存量 38.7691668069786，累计外排 32.2308331930213，与修改前 60 秒结果逐数相同。metadata 的 errors 为空，bed_heights_fixed 为 true，记录的所有生产源码 SHA256 与采集后磁盘一致。

图形进程 PID16678 已以 exit0 结束。诊断脚本为 `checks/capture_recession.gd`，记录在 `checks/recession_native/recession_diagnostic.json`。

## 待主任务统一复核

下池旧封口和水岸在侧角仍有浅色细边。本次保留既有接收端封口结构。最终日夜、保留种子、完整演进及交互采集由主任务重新生成，本报告的两张原生诊断图用于核对本次出口问题。
