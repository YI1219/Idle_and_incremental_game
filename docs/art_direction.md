# Floating Isle：当前美术思路

## 目标与比较基准

第一阶段只做PCG与实际画面。以刚接手时完整庭院的历史Godot截图为比较基准，见 `art/baseline/original/`；这是一份人工构图样本，尚不是稳定的整场景PCG或美术验收。最近的模块化小样未达到它的完整性，旧路线已停止。

旧房屋由用户明确要求更换，模型与源文件已删除；历史截图里仍可见它，只是记录。当前场景无房屋，不放临时代替建筑，也不自动提交新生成任务。

## 风格

唯美、低面数、大色块、古风配色，有乡野与仙山意境。参考[《绿意新生／The Regreening》官方场景画面](https://store.steampowered.com/app/3419080/The_Regreening/?l=schinese)：

- 柔和的大形体和圆钝转角先支撑空间，再考虑小细节。简单内收的平悬崖底部可以成立，不以复杂岩体为目标。
- 地面、岩石、植物与建筑采用协调的明暗尺度和哑光／手绘感表面；保留关键轮廓，压低表面碎噪声。低面数、少纹理、形体设计和氛围分别判断。
- 植物形成块面，路径保持清楚；建筑区域、水岸和树群有连续空间关系。留白有位置，不把完整庭院简化为空草坪和一圈薄墙。
- 保留青绿水面、米灰岩石、灰青屋瓦方向与远山云海，不照搬参考游戏的沙漠橙色或工业道具。

已实际观察的官方参考（外部游戏展示图，非本项目实机）：

- [房屋、路径与台地表面](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/3419080/28df53490fbb0f921ea4910c764b27209cb0a890/ss_28df53490fbb0f921ea4910c764b27209cb0a890.1920x1080.jpg?t=1792506175)
- [成片草花与通路](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/3419080/64f85294e7c512defdeef88e46fbd3ff24eab5bc/ss_64f85294e7c512defdeef88e46fbd3ff24eab5bc.1920x1080.jpg?t=1792506175)
- [河谷与台地层次](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/3419080/442699acc8bdc52fd02595b726578f4a5960887e/ss_442699acc8bdc52fd02595b726578f4a5960887e.1920x1080.jpg?t=1792506175)

未安装或试玩参考游戏；其具体面数、shader和内部生成方式未知。

## 当前样本

2026-10-21：固定 `art/baseline` 的布局、seed 7301 和游戏／整体／反向／近景机位，只改地表与接合。草坪是低噪声的灰橄榄绿大色块；路径土、零星裸地和崖顶肩部共用米灰土壤，路径保持一条清楚的柔和色带；岩石是哑光米灰块面，崖缘从草色过渡到土壤再进入石面。水仍是青绿。简单内收平底保持原样。比较对象是 `art/baseline/current/`（无房屋）和 `art/baseline/original/`（仅构图）。这轮不是验收，也不把规则扩成整岛悬崖重写。

重拍：`Godot --path . --script tools/art/capture_baseline.gd -- --out=res://art/baseline/surface_joint`。工具拒绝覆盖已有 `captures.json`。本轮 `art/baseline/surface_joint/` 是同一脚本的 llvmpipe 输出，机位与 `art/baseline/current/captures.json` 一致，预热 3 帧；`before/` 是同一渲染器上的改前画面。这不是美术验收。

以后需要新房屋时先设计比例、屋顶和檐口，协调场景风格。复用Tripo工具：简单且背面不重要的模型可用单图；需要多面轮廓的采用一致独立视图。先检查白模，再决定修整或贴图。此次清理不生成模型、不产生费用。

阶段完成须用户认可真实游戏视角下的效果，并在多个seed／视角稳定复现。只有明确启动第二阶段才能填充游戏内容。
