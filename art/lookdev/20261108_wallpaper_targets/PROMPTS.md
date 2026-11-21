# 识海浮空岛 · 壁纸化目标图 Prompt Pack
# The Scroll Within — Wallpaper TARGET Prompt Pack
更新：2026-11-08（Asia/Shanghai） · 基于 lookdev `art/lookdev/20261108/` 最终实机版（29/28）

## 风格锁 Style Lock（必须原样保留，不可改写成别的风格）

**中文主锚：** argon 预设0「天青烟岚 · 宋韵青绿」
- 冷银灰雾、低饱和苔草绿、米灰石、玉色水面
- 暖金主光 + 青空补光 + 云反射（SSIL 氛围）
- 唯美、低面数、大色块、古风配色；乡野与仙山意境
- 柔和的大形体与圆钝转角；哑光／手绘感表面；压低表面碎噪声

**明确靠近的风格参考（项目文档 + `art/reference/` 已有锚，勿发明未收录工作室名）：**
1. 《绿意新生／The Regreening》— `docs/art_direction.md` 主比较基准：软形体、协调哑光色块、成片植被与可读路径
2. Journey（风之旅人）— `art/reference/journey/`：远山云海、简化形体、史诗留白
3. Tiny Glade — `art/reference/tiny_glade/`：温润乡野、圆钝转角、壁纸级小品场景
4. 宋韵青绿山水气质（非写实照片；非赛博；非欧美硬边 fantasy）

**English style block (paste as-is):**
`style lock: argon preset "天青烟岚·宋韵青绿" (Celestial Azure Mist · Song-dynasty blue-green); soft low-poly large color blocks; matte painted surfaces; cool silver-gray mist; desaturated moss green grass; rice-gray stone; jade water; warm gold key light + cool sky fill + cloud bounce; aesthetic of The Regreening + Journey + Tiny Glade; Song-dynasty blue-green landscape feel; floating-island hangout wallpaper quality; NO cartoon pipe-organ pillars; NO soccer-ball rock grids; NO peach-pink fog; NO desert orange; NO industrial props`

## 共用负向 Negative（全变体共用）

中文：管风琴柱、足球网格岩、沙漏腰、二十面体球、桃粉雾、规整重复模块缝、硬边卡通描边、过曝白水高光块、塑料感草皮、写实照片噪点、现代建筑、科幻机械、文字水印、UI、logo
English: `pipe-organ cliff columns, soccer-ball rock grids, hourglass waists, icosahedral blobs, peach-pink fog, repeating modular seams, hard cartoon outlines, blown-out white water specular slabs, plastic turf, photo noise, modern buildings, sci-fi machines, watermark, UI, logo, text`

## 宽高比 Aspect
壁纸横屏 `16:9` / `2560×1440` 意图（生成时尽量接近 2K 横图）

---

## STYLE BLOCK（所有变体前置，勿删）

```
【风格】天青烟岚·宋韵青绿｜唯美低面数大色块古风｜哑光手绘感｜冷银灰雾｜低饱和苔草绿｜米灰石｜玉水｜暖金主光+青空补光
【靠近】The Regreening 绿意新生 + Journey 风之旅人 + Tiny Glade 的壁纸级环境气质；宋韵青绿山水，不是写实照片
【主体】识海浮空岛 hangout：无房屋；可编辑草甸台地；外圈连贯斜脊岩壁与竖向山根；软草唇与草石窄土缘；一处入瀑与玉色水池；少量树/灌木/石凳
【品质】可直接当桌面壁纸的游戏环境概念图；大形体错落有致；留白与远山云海；F11 净屏无 UI
```

English companion:
```
game environment concept art, wallpaper-ready floating island, Song blue-green xianxia pastoral, soft large masses, rounded bevels, matte painted rock and grass, coherent cliff buttresses with continuous vertical roots to the island underside, soft planted grass lip with narrow soil transition at rock junction, jade basin waterfall, warm gold sunlight and cool azure skylight, silver mist, The Regreening + Journey + Tiny Glade mood, ultra-clean composition, no UI
```

---

## Variant A — 日景全身壁纸 Day whole wallpaper
**用途：** 主目标图；对应实机机位 `whole`（yaw16° pitch30° height32）的壁纸化理想态

```
SUBJECT: 识海浮空岛日景全身壁纸；从斜上方俯瞰整岛；连贯斜脊大面岩壁代替密柱；草甸软唇沿崖缘自然种植；草石交接有窄根土过渡、无脏边；宽瀑口有错落跌水而非平板；玉色水面；远山云海留白
CAMERA: wide establishing, slight high angle, 16:9 wallpaper framing, FOV~31 feel, generous sky negative space
LIGHTING: daytime progress~0.29, warm gold key ~28–42° azimuth feel, cool sky fill, soft cloud bounce, gentle SSIL ambience
STYLE: {paste STYLE BLOCK}
QUALITY: masterpiece game art wallpaper, cohesive silhouette, readable large shapes, soft atmosphere
NEGATIVE: {paste Negative}
ASPECT: 16:9
```

**对照缺口（目标要修好的）：** 直立模块接缝消失；草下水平窄带消失；宽瀑口不再偏平；草石交接用心、自然。

## Variant B — 草石交接英雄特写 Cliff+grass junction hero
**用途：** 用户本轮最优先；对应 `cliff_close` 的壁纸级理想交界

```
SUBJECT: 岩壁与草甸交接处英雄特写；米灰哑光斜面岩体；全高护壁斜顶与根脚收分；草簇沿真实坡面种植并微微内埋；最外缘窄根土过渡带；接缝被大面斜脊与竖根吃掉；无悬浮小石、无双层薄沿
CAMERA: intimate cliff_close hero, three-quarter to the massif, shallow depth cues, 16:9
LIGHTING: warm gold grazing light revealing soft bevels; cool fill in recesses; no harsh specular on stone
STYLE: {paste STYLE BLOCK}
QUALITY: material-readability hero still, wallpaper crop, lovingly crafted grass-rock junction
NEGATIVE: {paste Negative}, floating pebbles, double thin lips, hard UV seams, turf clipping
ASPECT: 16:9
```

## Variant C — 夜景全身 Night whole
**用途：** 对应 `28_water_satin_night` 理想态；水面缎面高光收敛

```
SUBJECT: 识海浮空岛夜景全身壁纸；冷银灰雾更明显；深青草；岩壁大面仍可读；瀑布泡沫断续而非等距白板；水面玉色缎面、高光收敛无大片纯白 GGX 块
CAMERA: same whole establishing angle as Variant A for A/B comparability
LIGHTING: night/moon-cool key, residual warm bounce minimal, soft mist, restrained water specular
STYLE: {paste STYLE BLOCK}
QUALITY: night wallpaper mood, calm hangout island
NEGATIVE: {paste Negative}, blown white water slabs, neon, peach fog
ASPECT: 16:9
```

## Variant D — 日景反向机位 Day reverse
**用途：** 对应 `reverse`（yaw196°）；检查岛背侧块面节奏与草缘

```
SUBJECT: 日景反向机位壁纸；看向岛的另一侧外立面；斜脊与竖根连续到底；草唇不断裂；瀑池与对岸层次清楚
CAMERA: reverse establishing, yaw opposite to Variant A, same height language
LIGHTING: same day argon lock as Variant A
STYLE: {paste STYLE BLOCK}
QUALITY: wallpaper-ready reverse establishing shot
NEGATIVE: {paste Negative}
ASPECT: 16:9
```

---

## 使用说明
1. 生成时把当前实机图当作 **composition / layout reference**（BASE），目标是 **aspirational TARGET**，不是原样复制低模缺陷。
2. 推荐输入参考：`29_final_cycle/whole.png`、`cliff_close.png`、`28_water_satin_night/whole.png`、`29_final_cycle/reverse.png`；风格辅参：`art/reference/journey/`、`tiny_glade/` 各 1 张即可。
3. 输出文件名建议：`TARGET_A_day_whole.png`、`TARGET_B_grass_rock_hero.png`、`TARGET_C_night_whole.png`、`TARGET_D_day_reverse.png`，并另存 `BASE_*.png` 拷贝实机底板以便对照。
