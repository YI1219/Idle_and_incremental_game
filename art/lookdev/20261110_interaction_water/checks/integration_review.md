# 集成只读复核

2026-11-10。审查范围为蓝图生命周期、后台取消、实时水发布／重置／保存、长拖动后的提交／取消，以及床高撤销保量。未修改生产文件，未重跑已有套件，未开启原生窗口。

## Important

### P2 · 早期取消任务的清理访问缺失 chunks

`scripts/terrain_editor/terrain_renderer.gd:487` 的 `_finish_worker()` 无条件读取 `result.chunks`。但 `_worker_build()` 在 contour 或 layout 后收到取消时返回的字典仅有 `field` 与 `cancelled`（377–387行）。取消或继续拖动使旧任务过期后，立即切换预设、加载布局或退出，清理路径会触发 GDScript 错误，并跳过该函数剩余清理。

定向复现已完成。真实创建 renderer、启动 blueprint worker、立即 `cancel_blueprint()` 后调用 `_finish_worker()`，Godot 4.7.2 输出 `Invalid access to property or key 'chunks' on a base object of type 'Dictionary'`，准确定位 487 行。进程退出码仍为0，因此仅看退出码会漏掉此错误。临时复现脚本与日志分别在 `/tmp/scroll_integration_cancel_review.gd`、`/tmp/scroll_integration_cancel_review.log`。

建议清理采用与 `_finish_blueprint_build()` 相同的 `result.get("chunks", {})`，补一项早期取消后 configure/rebuild/释放的回归。此处没有复现数据丢失或崩溃，严重程度为 Important/P2。

## 其余集成结论

- 编辑器只在已提交 terrain 有待发布时暂停 water.tick。未提交蓝图 worker 被排除在 pending 判定之外，因此长拖动中的已发布世界可继续有限水演化。
- raise/lower 提交取权威当前 water_volume，撤销／重做也保留当前连续水量。正式入口 configure 即将体积写入现存格，因此历史记录具备该字段。water/dry 仍属于显式作者改量。
- 水任务独占 solver，terrain publication 的 sync 通过 `_sync_pending` 丢弃旧几何结果、协调新床面再造网格。preset/load 的 reset 等待并丢弃旧任务，重新初始化；保存 flush 消化现有队列并写回连续体积。
- blueprint 的实例与 revision stamp、authoritative revision、staging revision 校验覆盖过期构建发布，取消草稿不修改权威地形。除上述清理路径外，未确认新的 Important/Critical 问题。

## 规格与质量判定

功能集成可在上述取消清理缺陷修正并定向复验后通过本轮复核。已列的现有套件结果由主任务提供，本复核没有重复运行。松手等待时间、增删过渡接合、瀑布薄透／强弱与远端旧岩面最终视觉质量，仍以主任务正在采集的真实 Godot 同条件画面为准。功能审查不构成美术接受或目标硬件性能承诺。

## 修复复验

主任务已将 `_finish_worker()` 清理循环改为 `result.get("chunks", {}).values()`。本复核检查该处修复，并独立重跑原定向复现脚本。Godot 4.7.2 退出0，输出 `REVIEW_AFTER_FINISH sources cleared=true`，无 SCRIPT ERROR 或其他错误。复验日志 `/tmp/scroll_integration_cancel_review_verified.log`，主任务日志 `/tmp/scroll_integration_cancel_fixed.log` 结果一致。

上述 P2 已关闭。本轮指定功能集成审查通过，没有未解决的 Important/Critical 发现。视觉与松手延迟验收边界保持前述要求。
