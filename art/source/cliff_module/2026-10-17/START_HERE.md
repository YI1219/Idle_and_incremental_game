> 当前状态（2026-10-17）：用户已授权 Codex 操作本次 Tripo 白模，但随后暂停生成，先做表示方式与材质实验。四图保留为后备，不需要用户手动提交；目前没有任务或积分支出。以下为保留的输入说明。

# 崖石模块：一次白模试验

2026-10-17。四张独立输入已实际检查，允许先验证一个未贴图模型。它们是同一块岩体的绘制参考，并非精确测量的正投影或已完成的游戏画面。旧的两张左视图均排除。

## 只需要这一步

在 Tripo 一次多视图任务中分别放入下列四图，生成**一个**白模。不要把四图拼成一张，也不要分别生成四个模型。

| 视图 | 输入文件 |
| --- | --- |
| 正面 | [front.png](inputs/front.png) |
| 左侧 | [left.png](inputs/left.png) |
| 右侧 | [right.png](inputs/right.png) |
| 背面 | [back.png](inputs/back.png) |

四图专用文件夹：`/Users/yi/Projects/games/yunlu-pr9-astra/art/source/cliff_module/2026-10-17/inputs/`。也可使用[四图压缩包](../../../work/cliff_module/2026-10-17/cliff_module_inputs_v1.zip)。只提交 inputs 内这四张 PNG，其他图片为过程记录。

## 建议设置

- 模式：**P2.0 / Smart Topology Mesh，多视图**。
- 拓扑：**Triangle，目标5,000面**。这是本模块的试验预算，不是目标电脑性能已达标；比现有634/816三角面输入给大岩面转折、侧向厚度和收束留出更多空间。不要先做整岛或多套变体。
- **关闭纹理生成**，无骨骼、无动画。先看白模形状，不先支付纹理费用。
- 导出 **GLB**，保存原始下载为 `/Users/yi/Projects/games/yunlu-pr9-astra/art/source/cliff_module/2026-10-17/tripo/cliff_module_white_v1.glb`。已有同名文件时另存v2，不覆盖原件。任务链接/参数截图若有可一并保留；实际参数、任务编号目前未知。

以上是建议参数，尚未替你创建任务，也没有花费账号积分。当前 Tripo 的多视图与拓扑/面数入口参考[官方 P2.0 流程](https://www.tripo3d.ai/blog/mesh-game-character-p-2)；实际账号可用项与费用以界面为准，不把旧的免费重试/纹理价格反馈当作今天所有账号的保证。

## 这次模型要验证什么

它是约4m宽、3.2m高、2.2m深的一块连通崖石：不等宽岩面、上缘高低肩部、局部深缝、下部合进共同岩体。不是树石组合包、固定庭院或完整浮岛；草/土/藤蔓独立。现有树木、建筑和整体布局保留。

返回白模后由 Codex 检查侧向厚度、宽窄关系、闭合与孤立碎片，完成允许范围内的 Blender 精修，再接回小场景。还必须检查转成同一可编辑体积后是否保住形体；新模型并不能自动解决采样造成的变圆或材质问题。白模不合格时先反馈具体形体缺口，不进入纹理阶段；不把图片漂亮或检查通过说成美术完成。

当前源文件流程和[六张新原生实机对照](../../../review/terrain_fidelity/2026-10-17/basal_planes/README.md)记录了为何停止继续调下收切面。默认仍为spall_finish1；本任务尚未替换任何运行资源。

图片由内置 image_gen 生成，完整提示词见[prompts.json](prompts.json)与[left_v3_prompt.txt](left_v3_prompt.txt)，文件哈希见[manifest.json](manifest.json)。[独立四视图复查](review.md)记录了适用范围及仍存在的表面细节差异。
