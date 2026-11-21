2026-11-08，第 20 轮草缘种植验证。仅 `grass_field.gd` 扩大软唇种植范围；这些记录是几何与数量证据，不是实机美术验收或目标硬件性能实测。

- `grass_field_20_green.log`：临时具体变换检查 14/14 通过。旧平地与混合边缘已种样本的打包变换逐字节一致；新样本在正、反三角绕序下均贴合向上法线，簇中心与每片叶根距平面为 -8mm，最大误差小于 0.001mm；G<.82 外缘仍留空。
- `grass_lip_20.log`：既有 `tests/grass_lip_soften_test.gd` 24/24 通过，覆盖 7301/2104 的预设 0 与 7301 的预设 1。
- `grass_field_20_count.log`：7301、预设 0、唯一入口场景，22 个草叶 MultiMesh 节点共有 10098 簇；相对旧 9465 簇增加 633 簇，即 +6.6878%，基线比率 1.066878。此计数不提供 FPS 或笔刷延迟结论。

复现命令（项目根目录；只给 `--script`，不额外传场景路径）：

```sh
godot --headless --path . --script res://art/lookdev/20261108/checks/grass_field_20_probe.gd --log-file /private/tmp/grass_field_20_recheck.log
godot --headless --path . --script res://tests/grass_lip_soften_test.gd --log-file /private/tmp/grass_lip_20_recheck.log
godot --headless --path . --script res://art/lookdev/20261108/checks/grass_field_20_count.gd --log-file /private/tmp/grass_field_20_recount.log
```

变换对照脚本依赖本轮修改前的 `/private/tmp/grass_field_before_20.gd` 源快照；按任务要求该快照未放入项目。两个检查和数量统计均退出 0。日志保留启动时已有的 macOS CA 证书读取提示。统计脚本只在独立进程内实例化唯一入口并读取数量，不写生产文件或用户布局。
