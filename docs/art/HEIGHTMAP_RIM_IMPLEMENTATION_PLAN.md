# 高度图外缘实现计划

状态：计划，未改网格。分支 `cursor/heightmap-island-shell-6210`。对照图 `floating-isle-rim-plan/ref_01.png`–`ref_04.png` 只规定岩面语言（宽竖面、错肩、斜角相接、钝厚的合并底），不规定岛形、道具数量或瀑布位置。

不重新启用 Contour 岛体，不用 marching squares、样条、可编辑轮廓、轮廓偏移，也不再把拟合外环重新三角化。下面凡是写到 `Contours._outlines` / Douglas-Peucker，都是当前代码的现状，阶段 1 要从高度图壳上拿掉。

## 证据表

| 职责 | 文件 / 函数 | 当前行为 | 计划中的改动 |
| --- | --- | --- | --- |
| 高度与占地 | `scripts/terrain_editor/terrain_data.gd` `cells` | `Dictionary[Vector2i, {height, water}]`。有格子即占地。`height` 以 0.5 为步长，范围 -4..12。`water` 为 -1 或 0..7，显示高度是 `water * 0.5`，且必须低于岸高。 | 仍是唯一外形权威。外缘顶点不写回 `cells`。 |
| 脏块 | `TerrainData.invalidate` / `chunk_of` | 块边长 8。改一格会脏周围 3×3 块，并使 `revision` 加一。 | 外缘更新只读这些脏格。不要另做一套轮廓编辑。 |
| 笔刷 | `TerrainData.apply_brush` | 仅 `raise` `lower` `expand` `contract` `water` `dry`。`expand` 在空位新增格子；`contract` 删除格子；抬降只改已有格的 `height`（水格若岸被抬过水面则变干）。半径 0.1..16。 | 外缘只响应这六种。不新增笔刷。 |
| 连续拖动与提交 | `editor.gd` `begin_paint` / `continue_paint` / `_input`；`TerrainData.begin_stroke` / `end_stroke` | 按下 `begin_stroke`，拖动按距离插值多次 `apply_brush`（最多 256 步）。松开 `end_stroke`，把本次前后状态压入撤销栈（最多 64）。 | 保持。外缘在 `end_stroke` 之后的现有刷新里更新，不在每一步鼠标事件里重做全岛。 |
| 撤销 / 重做 / 存档 / 种子 | `undo` / `redo` / `serialize` / `deserialize` / `make_preset` | 撤销的是格子和岩石采样，不是网格。存档版本 1–4，含 `seed`（默认 7301）和格子。`editor.gd` `save_layout` / `load_layout` 写 JSON。 | 外缘不进存档。种子只继续驱动装饰哈希。 |
| 顶面网格 | `heightmap_island.gd` `_fill_tops` / `_emit_poly`；`chunk_geometry.gd` `Surface` | CPU 组三角，再 `Surface.mesh()` 成 `ArrayMesh`。没有把高度图采样到 GPU 再位移出顶面。格子先被裁到 `grass_loops`（外环内缩）和台地环。 | 顶面改回未裁切的格子方块。与外缘共用同一批角点。 |
| GPU 位移 | `terrain_renderer.gd` `_start_morph`；`cliff.gdshader` `terrain_morph_offset` | 发布后用着色器把顶点 Y 从上一顶面插到下一顶面。不是顶面的生成方式。 | 不改这条过渡。外缘几何仍在 CPU。 |
| 侧壁、底 | `HeightmapIsland.refresh` → `_prepare_loop` → `_lip_bevel` → `_cone` → `_emit_cap` | 外环来自 `Contours._outlines`（沿格边走，再 Chaikin），然后 Douglas-Peucker、沿弧重采样、内缩。`_cone` 把环收到 `KEEL_Y = -4.6`，`wall_inset` 是一条随深度变陡的内收。`_emit_cap` 在龙骨高度封一整张底。 | 改为从真实顶边挤出多段岩壁。底改成各段自己的钝脚，不再为封底重做全岛。 |
| 薄壳 / 长坡 / 切口的来源 | 同上，以及 `_clip_to_rings`、`_bulges` | 拟合环会切进格子，草地再被裁，唇上还有内缩倒角。`wall_inset` 从约 0.18 增到 1.32，竖向跨度到龙骨，所以侧壁是长坡而不是宽竖面。全岛一张底要求刷新时把所有块标脏（`flush_dirty` 里的注释）。 | 顶点留在格子边界上。内收只发生在靠下的一段。高度笔刷不动底的连接关系。 |
| 台地 | `_build_plateaus` / `_terrace_walls` / `_grass_risers` | 显示高差 ≥ `ROCK_RISE`（0.75）时，用另一套 `Contours._outlines` 做台地环再拉一面墙。小于此、大于 0.04 的高差走 `_grass_risers` 的草地立面。 | 台地改由相邻格子的真实共边生成，不走外轮廓。与外圈岩壁分开。 |
| 分块、法线、材质、上传 | `TerrainRenderer.flush_dirty` / `_rebuild` / `_publish` | 壳整岛重算后，已有块和 `triangle_chunks` 全部进入队列。每帧默认最多建 2 块（`flush_dirty(2)`）。法线在 `_flat_quad` 里按面写。崖用 `shaders/terrain_editor/cliff.gdshader`，草用 `ground.gdshader`。`_quiet_blocks` 把草设为橄榄、石面浮雕压低。 | 保持分块上传和现有材质。阶段 5 才把“整岛重算”收成脏区更新。 |
| LOD | — | 在 `scripts/` 和 `scenes/` 中未找到地形 LOD。 | 不添加。 |
| 碰撞 | — | `scenes/` 与 `scripts/terrain_editor` 中没有 `StaticBody3D` / `CollisionShape3D`。点选是 `TerrainRenderer.pick` 对已发布三角做射线。 | 不新增物理体。外缘三角必须继续进入 `_pick_faces`，否则笔刷打不中新侧壁。 |
| 装饰与水面 | `terrain_decoration.gd` `populate`；`heightmap_island.gd` `_interior_hydro` / `_shell_fall` / `_water_loops` | 树、路、栏、岸石由种子和格子生成，不是用户逐个摆放。水是笔刷写在格子上的字段。瀑布由水格向外或向低邻溢出时生成。 | 不新增路刷或瀑布刷。外缘改动不得改 `surface_at` 的含义。 |
| 道具 | `terrain_props.gd` `sync` | 长椅、灯、菜畦是代码里的固定节点，用 `surface_at` 贴地；脚印上有水或高差则隐藏。没有找到用户拖移 / 旋转后再存档的路径。 | 不补这套编辑。道具继续独立于外缘网格。 |
| 性能计数 | `TerrainRenderer.last_rebuild_ms` / `rebuild_count`；`editor.gd` `last_edit_ms` | 有计时字段。本轮没有测量数值。 | 阶段 0 先记基线。未测量前不判断谁更便宜。 |
| 旧单元挤出 | `chunk_geometry.gd` `build` | 能把格边挤到 `BOTTOM = -6`。全库没有调用点。高度图走的是 `HeightmapIsland.build`。 | 不把它接回主路径，避免第二套侧壁。 |
| 塑岩回退 | `TerrainRenderer.flush_dirty` | `sculpt_base_enabled` 时 `active_shell` 变为 `"contour"` 并调用 `contours.refresh`。默认 `use_heightmap_shell` 为真，预设不打开塑岩底。 | 不扩展这条回退，新外缘不调用它。 |

未在代码中确认、因此不写进步骤的事项：本机耗时数字、物理碰撞、地形 LOD、用户道具的自由变换存档、顶面的 GPU 位移生成、紫/橙调试墙（当前崖和草着色器里没有）。

## 1. 建议方案（对应现有代码）

权威仍是 `TerrainData.cells`。顶面仍由 `HeightmapIsland` 在 CPU 上按格出面。外缘是展示层：只读顶面的真实外边界，挤出多段岩壁，可以有竖面、局部外探和向内收，这些侧面不写回高度场。

具体替换：

- 删除高度图路径上的拟合环。`refresh` 不再调用 `Contours._outlines`、`_prepare_loop`、`_panelize`、`_inset_ring`。草地不再 `_clip_to_rings`。
- 外缘边 = 有格、且该侧邻居不在 `cells` 里的那条格边（`ChunkGeometry.SIDES` 的四个方向，`HeightmapIsland._square` 的角点）。连续、共线、同高的边合成一条宽竖面。拐角仍是格子上的拐角。
- 锯齿的限度：占地若是台阶，唇线就保持台阶。只合并共线边，不把台阶收成斜弦。参照图里的斜角，是在真实拐角外侧加一个展示用的短面，不删掉台阶，也不另存一条轮廓。
- 每条外缘做三段：近顶的肩、主体竖面、底部向内收的钝脚。肩高按该段的哈希错开，避免一圈水平环。底脚在相邻段之间焊在一起，形成厚底，而不是 `KEEL_Y` 上的一整张盖。
- 内部台地另算：邻居存在且显示高差 ≥ `ROCK_RISE`。它只用这段高差，不掉到外圈的底。小高差继续走现有 `_grass_risers`。
- 只抬/降/倒水/抽干时，外缘的水平折线不变，只改相关段的 Y，以及高差跨过 `ROCK_RISE` 时的台地面。扩/缩才增删外缘边并重焊受影响的底。阶段 1 可以仍整岛重算，但数据要按这个分类组织，方便阶段 5 收成脏区。

参照图里的宽竖面、错肩、斜角、钝底，都落在这三段展示网格上。不拿参照图去改池塘、路或瀑布的位置。

## 2. 要改的模块

阶段 1 及以后才改代码。本文件提交时不动这些函数。

| 位置 | 改动 |
| --- | --- |
| `heightmap_island.gd` `refresh` | 外缘改由格边生成。顶面用未裁切的格子。台地与外缘分开。 |
| 同文件 `_fill_tops`、`_clip_to_rings`、`_bulges`、`_terrace_bulges` | 草地/水面用格子方块。去掉为了拟合环而做的外探三角。 |
| 同文件 `_cone`、`_column`、`_emit_cap`、`_lip_bevel`、`_prepare_loop`、`_panelize` | 外缘挤出改为多段竖面 + 钝脚。拟合与内缩函数从高度图路径移除，不保留第二条轮廓。 |
| 同文件 `_build_plateaus`、`_terrace_walls` | 改为扫描四邻高差，不再为台地调用 `Contours._outlines`。 |
| 同文件 `_embeds` | 仍是稀疏楔石，挂在外缘段上，不形成石裙。数量仍由现有哈希控制。 |
| `terrain_renderer.gd` `flush_dirty` | 阶段 5：高度笔刷不要把所有块标脏。在此之前保持现有全量刷新，以免半更新的壳。 |
| `tests/heightmap_island_test.gd`、`tests/terrain_editor_runtime_test.gd` | 阶段 1 同时改断言：外缘跟格边走，单格仍有朝外的陡面，默认壳仍是 heightmap。 |
| 着色器、`terrain_props.gd`、`terrain_decoration.gd`、`terrain_data.gd` 笔刷 | 阶段 1 不改。过渡与嵌入在阶段 4 只调已有材质参数。 |

`wall_inset` 的现有数值被测试锁住。新剖面用自己的段深，不改这个函数的契约，直到测试明确改掉。塑岩分支保持原样，新代码不调用 `contours.refresh`。

## 3. 数据流与更新顺序

1. 权威：`apply_brush` 改 `cells`，`invalidate` 标脏块。
2. 顶：脏格的方块，高度用 `_top`（有水则 `water * 0.5`，否则 `height`）。
3. 外缘：只从顶面的暴露边来。先合并共线，再挤三段。
4. 底：只焊接本轮拓扑有变的那些段的钝脚。纯高度笔刷不重焊。
5. 自动装饰：现有 `terrain_decoration.gd` `populate`，在壳发布之后，仍按种子和 `surface_at`。
6. 用户实体：`TerrainProps.sync` 用 `surface_at` 贴已有节点。没有用户摆放数据要迁移。
7. 缓存与点选：`triangle_chunks`、`_pick_faces`。缓存可以有边 id 和邻接，但不进 `serialize`，也不能当笔刷去改。

`continue_paint` 里的每一步只改权威数据。网格仍由 `TerrainRenderer._process` → `flush_dirty` 在笔刷提交后的帧里上传。不要改成每帧重做全岛。

## 4. 分阶段

### 阶段 0 — 基线

依赖：无。  
交付：用现有 `last_edit_ms`、`last_rebuild_ms`、`rebuild_count`、`pending_chunk_count`，对一次 `expand` 和一次 `raise` 各记一笔。记下当前外缘来自 `Contours._outlines`。  
验收：有数字，且没有改网格。  
风险：无。  
回退：不产生代码。

### 阶段 1 — 最小可编辑外缘

依赖：阶段 0 的记录。  
交付：外缘 = 暴露格边的共线合并 + 一段竖直面向下固定深度（试 2 m）。草地是完整格子。扩/缩/抬/降后，墙跟格子走。  
验收：直边合成一块宽面；单格台阶还在；`terrain_editor_runtime_test` 里单格仍有朝外且中心高度在 (0, 1.3) 的陡面；默认 `active_shell == "heightmap"`；无 `cliff_column_*`。唇线上能看见占地本身的台阶，这是对的。  
风险：拟合环删掉后，近景会重新露出格子台阶。这不是回退失败。  
回退：撤销该阶段提交。不要用开关把拟合环留在旁边。

### 阶段 2 — 岩体与底

依赖：阶段 1 的边表。  
交付：肩 / 竖面 / 钝脚。肩高按段错开。凸角加一个外侧短三角，顶点仍盖住原来的格子角。相邻钝脚焊接。去掉全岛 `KEEL_Y` 盖。  
验收：侧壁以竖面为主，底部比纸片厚，并且向内；扩缩会改变底的连接，只抬高不会。  
风险：焊接缝若按世界距离乱连，会在窄湾封死。焊接只允许沿外缘相邻的两段。  
回退：撤销该阶段提交，回到阶段 1 的单段竖面。

### 阶段 3 — 内部台地（语义已经存在）

依赖：阶段 1。可与阶段 2 并行，但不要共用外缘的底。  
交付：邻居存在且显示高差 ≥ 0.75 时，在共边上做短岩壁。更小的高差仍用 `_grass_risers`。不再为台地调用 `Contours._outlines`。  
验收：预设里上下层之间仍有岩壁；它的高度等于两格显示高之差，不落到外圈底。抹平台地后岩壁消失，外轮廓不变。  
风险：水格的显示高是水面，抬岸可能同时改台地分类。按 `_top` 的现规则处理，不另写一套。  
回退：撤销该阶段，台地暂时只留草地立面。

### 阶段 4 — 草 / 土 / 石过渡与稀疏嵌石

依赖：阶段 2 的肩。  
交付：肩的上沿与草地共顶点。颜色仍用 `_quiet_blocks` 的橄榄与软灰，以及现有 `cliff.gdshader`。嵌石继续用 `_embeds` 的稀疏楔，只挂在足够长的外缘段上。  
验收：唇上没有第二圈倒角，也没有草地方齿；嵌石数量仍少，不连成裙。  
风险：把肩做成另一条内缩多边形就会回到本计划禁止的偏移。肩只能是外缘网格的第一段。  
回退：去掉嵌石偏移，肩段深度改为 0。

### 阶段 5 — 交互与性能

依赖：阶段 2，以及阶段 3 若已合并。  
交付：笔刷分类。`raise` / `lower` / `water` / `dry` 只更新脏格影响到的段的 Y 和台地。`expand` / `contract` 才改边表和钝脚。仍遵守 `flush_dirty` 每帧两块的上传预算。  
验收：与阶段 0 同一操作对比。高度笔刷的壳重算不再遍历全部格子。交互路径仍是按下、拖动、松开、撤销、存档再读回。  
风险：脏区漏了邻块，会出现裂缝。`invalidate` 已经脏 3×3，外缘更新至少覆盖这一圈。  
回退：恢复整岛 `refresh`，保留新几何。

## 5. 可调参数

未写“现有”的默认值都是试验值，阶段 2 之前不要写死成美术验收。

| 参数 | 含义 | 来源 | 范围 | 代价 |
| --- | --- | --- | --- | --- |
| `ROCK_RISE` 0.75 | 多高算岩壁 | 现有常量 | 外缘与台地共用 | 只影响分类，几乎无算量 |
| 竖面深度 2 m | 阶段 1 单段墙有多高 | 试验 | 仅阶段 1 | 每条边 2 个三角 |
| 肩深 0.4–1.6 m | 错开的上段 | 试验，哈希用现有 `_unit` | 每段一个值 | 多一截四边形 |
| 脚深 1.5–3 m，内收 0.4–1.2 m | 钝脚多深、收多少 | 试验 | 每段 | 底边变短；过大就会在窄湾相交 |
| 斜角外探 ≤ 0.35 m | 凸角外侧的短面 | 试验 | 只在凸角 | 每角 1–2 个三角 |
| `wall_inset` | 旧锥的内收曲线 | 现有，测试锁定 | 阶段 2 不沿用到新剖面 | 改它会先打坏测试 |
| 嵌石哈希门槛 | 多少段生成楔石 | 现有 `_embeds` | 外缘段 | 每块数个三角 |
| `flush_dirty` 的 `max_chunks` 默认 2 | 每帧上传块数 | 现有 | 渲染器 | 调大会让单帧更长 |
| `CHUNK_SIZE` 8 | 块边长 | 现有 | 数据与网格 | 本计划不改 |

## 6. 美术职责

- 几何：格子顶、外缘三段、台地短壁、钝脚、凸角短面、稀疏楔石。只在 `heightmap_island.gd`。
- 法线与材质：面法线继续由 `Surface.triangle` / `_flat_quad` 写出。崖、草继续用现有着色器和 `_quiet_blocks`。不换引擎，不加第二套调色。
- 散布：`terrain_decoration.gd` 的种子摆放。外缘计划不改摆放规则。
- 手工资产：`terrain_props.gd` 里的长椅、灯、菜畦，以及 Kenney 模型。不把它们做进外缘网格。

## 7. 性能与交互验收

阶段 0 用同一种操作各测一次：半径 2 的 `expand` 一笔，和半径 2 的 `raise` 一笔。记录 `last_edit_ms`、下一次 `flush_dirty` 的 `last_rebuild_ms`、`rebuild_count` 增量、`pending_chunk_count`。阶段 5 用同一脚本再测。通过标准是高度笔刷不再整岛重建外缘；不是一个预先假定的毫秒数。

交互通过标准：六种笔刷、拖动插值、松开提交、撤销/重做、`save_layout` / `load_layout` 之后格子不变，外缘只是这些格子的函数。点选仍能打到新侧壁。不要求、也不添加用户自由摆放道具。

## 8. 架构问题（其余已按代码默认）

1. 塑岩打开时仍会切到 Contour。默认：留下这段现有分支，新外缘不接入、也不在本计划里删除它。
2. 底用“每段钝脚”而不是现在的全岛盖。默认采用钝脚，因为全岛盖是 `flush_dirty` 把所有块标脏的原因。
3. 用户自由摆放道具在当前代码里不存在。默认：不做。若以后要做，另开存档字段，不放进外缘缓存。

## 9. 第一笔最小改动

只做阶段 1，并且单独提交。

在 `HeightmapIsland.refresh` 里，外圈不再调用 `Contours._outlines`。遍历 `source.cells` 的四边，邻居缺失则记下这条边；把同一直线上、高度相同、首尾相接的边收成一条。每条从显示顶面向下 2 m 生一块平面（`_flat_quad`，崖材质）。`_fill_tops` 对每个格子直接出方块，不再裁到内缩环。

做完应看到：沿直线的若干格共用一块宽墙；拐进去一格的台阶仍然是台阶；`expand` 后新格的外缘出现在新边界上，`contract` 后消失；`raise` 只把这块墙的顶抬高。单格测试仍能在东侧或南侧打到一面朝外的陡崖。画面上的台阶是占地本身，不是拟合失败。
