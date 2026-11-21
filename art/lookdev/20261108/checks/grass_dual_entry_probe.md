2026-11-08：夜间草叶异常的捕获链路诊断证据。

`grass_dual_entry_probe.gd` 与 `grass_dual_entry_probe.log` 原样复制自 `/private/tmp`。脚本仅供 headless 诊断，不是场景入口，也不修改、加载或保存用户布局。

复现命令（项目根目录）：

```sh
godot --headless --path . res://scenes/terrain_editor.tscn --script res://art/lookdev/20261108/checks/grass_dual_entry_probe.gd --log-file /private/tmp/grass_dual_entry_recheck.log
```

实测：启动参数同时给出场景路径与 `--script` 时，Godot 4.7.2 仍自动加载并运行 `current_scene=TerrainEditor`。诊断脚本没有手动实例化场景；它把该场景共享草材的 `grass_base` 从晨色 `(0.238, 0.352, 0.214)` 写为夜色 `(0.1512, 0.2613, 0.2199)`，等待 24 帧后又读到晨色。进程退出码为 0；日志中的 macOS CA 证书读取错误保留原样，与这次参数覆盖观察无关。

关联代码：`GrassField._material` 是静态共享资源，捕获脚本创建的第二个场景引用同一草材；原捕获脚本只禁用了手动场景。自动场景的 `editor._process → gameplay.tick → time_system.tick → apply_to_scene` 可继续覆盖共享草色，而两场景分别创建的地面材质不受该覆盖。此证据支持先修正捕获场景隔离，不能据旧夜景认定草叶调色或 `ground_cover` 有错。

这是运行机制证据，不是美术验收。修正后的单场景原生 2K 实拍与帧末调色校验另见后续捕获轮次。
