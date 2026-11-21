# 识海浮空岛 · 壁纸化目标图 Prompt Pack v2（sol 6.1 / 实机可达）
# The Scroll Within — Wallpaper TARGET Prompt Pack v2
更新：2026-11-09（Asia/Shanghai） · 基于 lookdev `art/lookdev/20261108/` 最终实机版（29/28）
相对 v1（astra，`20261108_wallpaper_targets`）的修正：用户反馈 v1「不是实机能做出来的效果、整体风格与预期差距大」。本版强调 **Godot lookdev 可达的下一小步**，构图忠实于 BASE 实机截图，禁止概念画式发明。

## 与 v1 的关键差异（必须遵守）

1. **In-engine achievable**：TARGET 必须像「从当前 BASE 再 polish 一点」的可达态，而不是新概念美术。禁止发明新轮廓、新道具、新建筑、新岛屿、不同机位布局或完全不同的光雾。
2. **风格贴回实机色温**：仍锁 argon「天青烟岚 · 宋韵青绿」，但避免 v1 的过绘 / 过 stylized / 概念海报感。色温与体量应贴近 REAL lookdev：暖金主光 + 青空补光、柔哑光、宋韵青绿；岛体外形、台地、瀑池、树丛位置与 BASE 一致可读。
3. **构图锁死 BASE**：imagegen 时每张必须带对应 BASE 作 reference；输出构图、镜头、岛轮廓、水面位置、树石摆放尽量与 BASE 同框；只允许改善草石交接、斜脊竖根、瀑口层次、水面高光收敛等 lookdev 缺口。
4. **参考游戏只借气质不借造型**：The Regreening / Journey / Tiny Glade 只借软形体、哑光色块、留白氛围；禁止抄它们的建筑、沙漠橙、废墟柱、UI、羊群等。

## 风格锁 Style Lock（贴实机；不可改写成别的风）

**中文主锚：** argon 预设0「天青烟岚 · 宋韵青绿」
- 冷银灰雾、低饱和苔草绿、米灰石、玉色水面（与当前 Godot 截图同色系）
- 暖金主光 + 青空补光 + 云反射（SSIL 氛围），强度与 BASE 日/夜一致量级
- 唯美、低面数、大色块、古风配色；乡野与仙山意境
- 柔和的大形体与圆钝转角；哑光／手绘感表面；压低表面碎噪声
- **本版额外：** 保持 Godot 低面数可读性；不要油画厚涂、不要超现实体积光、不要海报级景深虚化

**明确靠近的风格参考（项目文档 + `art/reference/` 已有锚）：**
1. 《绿意新生／The Regreening》— 软形体、协调哑光色块（只借材质关系）
2. Journey — 远山云海与简化形体（只借空间层次，不借沙漠橙）
3. Tiny Glade — 圆钝转角与种植接合（只借草石接触，不借建筑）
4. 宋韵青绿山水气质（非写实照片；非赛博；非欧美硬边 fantasy）

**English style block (paste as-is):**
`style lock: argon preset "天青烟岚·宋韵青绿"; Godot lookdev-reachable polish of THIS floating island screenshot; soft low-poly large color blocks; matte painted surfaces; cool silver-gray mist; desaturated moss green grass; rice-gray stone; jade water; warm gold key + cool sky fill matching the BASE plate; Song blue-green; subtle next-step polish NOT fantasy concept art; NO new architecture; NO new islands; NO invented props; NO peach-pink fog; NO desert orange; NO over-painted poster look; NO photoreal DSLR; NO hard fantasy`

## 共用负向 Negative（全变体共用）

中文：发明新建筑/新岛屿/新道具、概念海报过绘、油画厚涂、超现实体积光、管风琴柱、足球网格岩、沙漏腰、二十面体球、桃粉雾、沙漠橙、规整重复模块缝、硬边卡通描边、过曝白水高光块、塑料感草皮、写实照片噪点、现代建筑、科幻机械、文字水印、UI、logo
English: `invented architecture, new islands, new prop sets, overpainted concept-poster look, thick oil-paint look, surreal godrays, pipe-organ cliff columns, soccer-ball rock grids, hourglass waists, icosahedral blobs, peach-pink fog, desert orange, repeating modular seams, hard cartoon outlines, blown-out white water specular slabs, plastic turf, photo noise, modern buildings, sci-fi machines, watermark, UI, logo, text`

## 宽高比 Aspect
壁纸横屏 `16:9`（尽量接近 BASE 的 2560×1440 构图；生成原生尺寸可保留）

---

## STYLE BLOCK（所有变体前置）

```
【风格】天青烟岚·宋韵青绿｜贴合当前 Godot 实机色温｜唯美低面数大色块｜哑光手绘感｜冷银灰雾｜低饱和苔草绿｜米灰石｜玉水｜暖金主光+青空补光
【可达】这是现有浮空岛 lookdev 的「下一小步 polish」目标，不是新概念场景；构图/岛形/机位必须贴近给定 BASE 实机图
【靠近气质】The Regreening + Journey + Tiny Glade 的软形体与哑光色块（禁止抄建筑/沙漠橙/UI）
【主体】识海浮空岛 hangout：无房屋；现有草甸台地；外圈斜脊岩壁与竖向山根；软草唇与草石窄土缘；现有入瀑与玉色水池；现有少量树/灌木/石凳位置
【品质】可作为桌面壁纸的游戏环境目标板；大形体可读；F11 净屏无 UI
```

English companion:
```
Godot lookdev-reachable wallpaper target, subtle polish of the attached BASE screenshot of this floating island, Song blue-green xianxia pastoral, soft large masses, rounded bevels, matte painted rock and grass, keep the same island silhouette camera props and basins as BASE, improve grass-rock lip and cliff bevel continuity, jade basin waterfall, warm gold sunlight and cool azure skylight matching BASE, silver mist, no new architecture, no invented layout, ultra-clean, no UI
```

---

## Variant A — 日景全身 Day whole（构图锁 BASE_A）
**用途：** 对应实机 `whole`；在同框内修好斜脊/草唇/瀑口，仍像同一局 Godot 画面

```
SUBJECT: 同一张识海浮空岛日景全身；严格保持 BASE 的岛轮廓、台地、双水池、瀑布位置、树木与小径布局、镜头俯角；只 polish：连贯斜脊大面岩壁、草甸软唇、草石窄根土过渡、宽瀑口轻微错落跌水、玉色水面；远山云海可略柔但勿改构图
CAMERA: match BASE establishing framing exactly (whole · high angle · 16:9)
LIGHTING: match BASE daytime warm gold key + cool sky fill; do not invent stronger volumetric beams
STYLE: {paste STYLE BLOCK}
QUALITY: reachable Godot lookdev next step, wallpaper crop of THIS scene
NEGATIVE: {paste Negative}
ASPECT: 16:9
CONSTRAINT: composition-faithful to reference image 1 (BASE); improve materials/junctions only
```

## Variant B — 草石交接英雄特写（构图锁 BASE_B，本轮优先）
**用途：** 用户最优先；同 cliff_close 机位，用心优化草石交接，仍像实机可做

```
SUBJECT: 同一岩壁与草甸交接特写；保持 BASE 岩体朝向与草甸位置；米灰哑光斜面；草簇沿真实坡面微微内埋；最外缘断续窄根土（高低不等，禁止一条水平脏边）；接缝被大面斜脊与竖根弱化；无悬浮小石、无双层薄沿；不要换成别的悬崖造型
CAMERA: match BASE cliff_close hero framing
LIGHTING: warm gold grazing like BASE; cool fill in recesses; no harsh stone specular
STYLE: {paste STYLE BLOCK}
QUALITY: material-readability hero still that a Godot pass could approach
NEGATIVE: {paste Negative}, floating pebbles, double thin lips, hard UV seams, turf clipping, redesigned cliff silhouette
ASPECT: 16:9
CONSTRAINT: composition-faithful to reference image 1 (BASE_B); grass-rock junction is the only hero change
```

## Variant C — 夜景全身（构图锁 BASE_C）
**用途：** 同 night whole；水面缎面高光收敛；色光仍是 argon 夜景量级

```
SUBJECT: 同一识海浮空岛夜景全身；保持 BASE 布局与机位；冷银灰雾；深青草；岩壁大面可读；瀑布泡沫断续；水面玉色缎面、高光收敛无大片纯白；勿改成月夜幻想海报
CAMERA: match BASE night whole framing (same as day whole angle)
LIGHTING: match BASE night/moon-cool key; restrained water specular
STYLE: {paste STYLE BLOCK}
QUALITY: reachable night lookdev wallpaper target
NEGATIVE: {paste Negative}, blown white water slabs, neon, peach fog, fantasy night poster
ASPECT: 16:9
CONSTRAINT: composition-faithful to BASE_C
```

## Variant D — 日景反向（构图锁 BASE_D）
**用途：** 同 reverse 机位；检查背侧块面与草缘，仍同岛

```
SUBJECT: 同一日景反向机位；保持 BASE 背侧外立面轮廓与道具；斜脊与竖根连续；草唇不断裂；瀑池与对岸层次清楚；只做可达 polish
CAMERA: match BASE reverse establishing
LIGHTING: same day argon lock as Variant A / BASE
STYLE: {paste STYLE BLOCK}
QUALITY: reachable reverse establishing target
NEGATIVE: {paste Negative}
ASPECT: 16:9
CONSTRAINT: composition-faithful to BASE_D
```

---

## 使用说明（v2）
1. 每张生成必须附加对应 BASE 为 **composition authority**；Journey/Tiny Glade 至多作辅参且明确禁止抄造型。
2. Use case 偏好：image-to-image / edit-like polish of BASE，而不是从零 concept。若工具只有 generate+reference，仍要在 prompt 写死 composition-faithful。
3. 输出：`TARGET_A_day_whole.png` 等；另存 BASE 副本；写 README 说明相对 v1 为何更可达。
4. 不要覆盖 `art/lookdev/20261108_wallpaper_targets/`；写入新目录 `art/lookdev/20261109_wallpaper_targets_sol61/`。
