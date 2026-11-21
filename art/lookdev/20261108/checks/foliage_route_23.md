2026-11-08，第 23 轮装饰草簇/芦苇调色路由验证。

生产改动仅两行条件：`terrain_environment.gd` 和 `time_solar_system.gd` 中，旧 foliage 分支由物件 kind 判断改为实际 `foliage.gdshader` 路径判断。使用 `decor_vertex_color.gdshader` 的草簇/芦苇因此进入已有 `decor_sky_shadow/lit` 分支。未改任何 palette 数值、shader、网格或种植数据。

`foliage_route_23_probe.gd` 在单一入口场景的真实资产材质上检查夜间 time 路径与预设 0 environment 路径；同时确认实际 foliage 材质继续接收原 dark/light 调色。

- 修改前：`foliage_route_23_red.log`，20 项中 8 项失败，草簇与芦苇的两个 decor 参数在两条应用路径下均未设置（null）。退出码 1。
- 修改后：`foliage_route_23_green.log`，20/20 通过。退出码 0。
- 源快照仅保留在 `/private/tmp/foliage_route_23_before/`，未复制进项目。

复现修复后状态（项目根目录）：

```sh
godot --headless --path . --script res://art/lookdev/20261108/checks/foliage_route_23_probe.gd --log-file /private/tmp/foliage_route_23_recheck.log
```

探针不修改生产文件或用户布局。红/绿日志保留原始 macOS CA 证书读取提示；本记录是实际材质参数路由验证，不代替第 23 轮原生 2K 多机位与十二时辰美术验收。
