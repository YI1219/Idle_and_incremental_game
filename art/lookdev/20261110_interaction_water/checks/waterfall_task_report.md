# 瀑布流水与落水飞溅

更新于 2026-11-10。本报告仅涵盖 waterfall_task.md 指定的瀑布职责，编辑器与性能工作由主线程负责。

## 已实现

- `_falls` 以单层水片生成瀑布，删除高不透明度的重复内核。每个 connected spill run 使用按边长汇总的统一外向，避免左右端沿各自法线随落差靠拢。完全闭合外露轮廓保留各边外向。
- 嘴唇至底部保持横向原宽，位移从 0.16m 浅唇逐渐趋近 0.225m。删除静态几何褶皱，浅表起伏交由材质的移动流纹表现。未修改湿壁封口和权威水位计算。
- UV.x 编码 FlowField 实际传入的 0–1 流强，UV.y 编码米制落差。静态旧调用默认强度 1。chunk 内与裁剪路径都保留该 UV，删除历史上随后覆盖它的两处世界坐标投影。
- 材质改为薄玉色水片，破碎移动反光、微法线、温和透射，白色主要集中在接收水位的撞击区。保留 flow_time、sun_direction、refraction_strength 与 terrain_morph 接口，保留外瀑终端渐隐。
- 口部白边降低至原 alpha 的 0.32 倍并随流强变化，底部小卷浪缩小。飞溅、落水环、veil 元数据保留流强，弱流对应弱效果。
- 内瀑取消沿帘云雾。接收水面增加 12 个小水滴和 3 个局部薄喷雾，尺寸、透明度跟随流强。外瀑终端云雾仍保留，land-region 深根云丝生成段保持原样。

## 修改范围

- scripts/terrain_editor/contour_terrain.gd 的瀑布方法及 build 瀑布 UV 处理
- shaders/terrain_editor/waterfall.gdshader
- scripts/terrain_editor/waterfall_mist.gd
- shaders/terrain_editor/waterfall_mist.gdshader
- tests/waterfall_flow_shape_test.gd

未提交。共享 contour 文件中的其他工作由主线程维护，未整文件回退。没有新资产、建筑、角色或环境灯光改动。

## 回归证据

- `waterfall_shape_red.log`，首轮 6 项中 5 项失败，捕获旧几何收窄、过大唇位移、弱流 UV 缺失、物理落差缺失与重复 core。
- `waterfall_shape_chunk_red.log`，扩展后 9 项中 1 项失败，捕获 chunk build 覆盖流强 UV。
- `waterfall_shape_green.log`，9/9。覆盖嘴底宽度、浅唇、强弱流顶点编码、物理落差、单水片、veil/impact 流强与 chunk 裁剪 UV。
- `waterfall_seal.log`，4 种子共 16/16，仍命中封口上层岩壁。
- `waterfall_renderer.log`，47/47，动态出版、有限体积、工作线程和正常入口行为回归通过。

旧 348 项 integrated probe 未作为此次判据运行。其固定 puff 数、4 个 apron/impact、重复层数等断言与本次明确改变的设计冲突，且原工具会写入旧审阅包。未通过修改新设计迁就旧断言。

## 实际渲染与待验收

`waterfall_native_probe.gd` 继承现有正式采集器，仅生成 `waterfall_probe/close.png`，原生 Forward+ 2560×1440、seed7301、phase1.25、日景 .29。`waterfall_native.log` 正常退出，无着色器错误，captures.json 显示 valid=true。此次 close 为池水机位，画面没有瀑布，故它仅支持图形编译与池水机位检查，不能作为瀑布外观验收证据。该采集早于最后的 chunk UV 覆盖修复。

已与主线程协调，图形进程退出后主线程才做性能基准。最终含瀑布近景、全景、反向、夜景和保留种子的实拍由主线程完成。

剩余需看实拍的风险包括薄水片后的湿岩剪影是否过显、浅唇与各方位湿壁是否相交、低流量下反光是否仍像白线，以及小飞溅在正常距离的可读性。功能通过不等于美术验收，未宣称目标硬件达到 60FPS。

## 实拍失败后的修正

主线程 `02_waterfall_flow_day/game.png` 与 `close.png` 显示首轮存在明显问题，水幕呈浅青色平板、可见三角亮差，右侧还有分离窄条。此次结果未达到普通流水外观，原生 shader 无错误不足以证明视觉正确。

`waterfall_edges.log` 实测内瀑出现一个独立宽 0.333m 的 run32，其外侧 +0.28m 仍是上层 basin1，但 nearest transfer 目标被分配为下层 basin0。主 run40 的实际外侧正确属于 basin0。该分离条由 FlowField 的目标吸附造成，主线程负责实际接收支持验证与正常入口回归。曾在 `_falls` 尝试的过滤/补桥已全部移除，避免双处修补和人为跨越无流量的边。

材质进一步降低背景湿壁透射份额，提高主水片连续性，压低法线扰动与宽面高光，改为较深玉色上有细碎长短变化的下行反光。细流纹使用每米 24 倍横向采样、较低纵向频率和随流强变化的移动速度，降低旧反光阈值以避免绝大多数表面成为无纹平板。此次修正的实际视觉检查仍待后续原生帧。

## 最终单帧原生自检

主线程修正 FlowField 后，使用 `waterfall_hero_probe.gd` 继承 `capture_flow.gd`，只拍同一 hero 机位 game，保留其相机、灯光和权威数据审计。

- `03_waterfall_flow_day/game.png` 已实际查看。右侧分离窄条消失，三角亮差明显减轻，流纹可读，但亮纹偏通长整齐。
- 随后将细纹纵向频率从每米 0.45 调到 1.8，并以移动 packets 打断次级亮纹，反光混合量从 .68/.20 降到 .43/.12。`04_waterfall_flow_day/game.png` 已实际查看，亮纹成为长短不同的断续下行水纹，玉色底保留。素材为实际 Godot 输出。
- 有真实接收水的终点从 receiving height +0.07m 调至 +0.015m，landing/splash 随之贴近实际水面。外瀑终点仍为原值，封口湿壁保持不变。fixture 相应检查新的真实接收高度。
- 两次均为原生 Forward+ 2560×1440、seed7301、preset0、phase1.25、day .29，同机位。`waterfall_hero03.log` 和 `waterfall_hero04.log` 均正常退出且 valid=true，无着色器错误。04 的 captures.json 保留完整相机、源哈希和审计信息。
- 最终再次运行 shape 9/9、seal 16/16、water_renderer 48/48，其中第 48 项由主线程新增，回归实际 preset 的分离侧壁吸附问题。

04 是本子任务最终候选。中段玉色底面仍略平、底缘较整齐，落水小水滴在该单帧中可见但偏细。尚需主线程的全景、斜角、夜景和保留种子审阅，最终美术验收归用户判断。采集结束已通知主线程，未与后续性能或交互采集并发。
