# 识海浮空岛 · 壁纸目标图

[打开四组对照页](compare.html) · [完整原始 Prompt Pack](PROMPTS.md) · [实际调用参数与输出溯源](GENERATION.json)

BASE 是现有 Godot 原生截图的逐字节副本；TARGET 是以对应 BASE 约束构图和布局的生成概念目标。并排展示用于讨论理想视觉方向，**不是 Godot 修改前后实拍**，也不表示该效果已落地或通过用户美术验收。

## 风格与生成约定

锁定 argon 预设0「天青烟岚 · 宋韵青绿」：冷银灰雾、低饱和苔草绿、米灰石与玉水，暖金主光、青空补光和云反射；软大形体、圆钝转角、协调的哑光手绘色块。保留无房屋的浮岛与原布局，参考气质以 The Regreening、Journey、Tiny Glade 和宋韵青绿山水为界。

`PROMPTS.md` 与用户提供的 Prompt Pack 字节一致。每次生成原样采用其中的完整 Style Lock（含英文 style block）、中文 STYLE BLOCK、English companion、对应 A/B/C/D 变体，以及完整中英双语 Negative；变体里的占位符展开为这些原文，B/C 的附加负向要求保留。

本轮使用 Codex 内置 image_gen，对 A/B/C/D 各调用一次。四张 TARGET 已生成，原生输出均为 **1672×941 PNG**，接近 16:9；提示词请求 2560×1440，工具实际返回上述尺寸，保留原图而未放大。原始生成文件留在 `$CODEX_HOME/generated_images/`，项目与 Downloads 包均保存其逐字节副本。本轮未修改 Godot 场景、网格或玩法。

每次输入对应 BASE，以及 `art/reference/journey/00.jpg`、`art/reference/tiny_glade/00.jpg` 两张辅参。Journey 只借鉴简化形体和空间层次；Tiny Glade 只借鉴柔和形体与种植接合，提示词明确排除它们的建筑、UI与沙漠橙配色。展开后的完整原文、额外构图约束和引用顺序均保存在 `GENERATION.json`。

重点看 B 的软草唇、断续窄根土和大面斜脊，以及 A/D 的整体与背侧节奏、C 的夜间石面和玉水。四图为独立生成，石面分块、植被细节和水池比例并非跨视角严格一致；云雾也遮挡了部分山根，不能代替几何设计或实机验证。

## 底板与机位映射

四张 BASE 均为原生 2560×1440、seed7301、地形预设0、FOV31、Forward+ / 4×MSAA、动态相位1.25，已通过生产 F11 清 UI。A/B/D 时段0.29，C 时段0.00。数值用于追溯 BASE；生成图只受构图参考约束，不构成逐像素同条件实机对照。

| 变体 | 原始 Godot 截图 | 本包 BASE | 对应 TARGET 文件名 | 机位 |
|---|---|---|---|---|
| A · 日景全身 | `29_final_cycle/whole.png` | [BASE_A_day_whole.png](BASE_A_day_whole.png) | [TARGET_A_day_whole.png](TARGET_A_day_whole.png) | whole · yaw16° / pitch30° / height32 |
| B · 草石交界特写（优先） | `29_final_cycle/cliff_close.png` | [BASE_B_cliff_close.png](BASE_B_cliff_close.png) | [TARGET_B_grass_rock_hero.png](TARGET_B_grass_rock_hero.png) | cliff_close · yaw16° / pitch20° / height10 |
| C · 夜景全身 | `28_water_satin_night/whole.png` | [BASE_C_night_whole.png](BASE_C_night_whole.png) | [TARGET_C_night_whole.png](TARGET_C_night_whole.png) | whole · yaw16° / pitch30° / height32 |
| D · 日景反向 | `29_final_cycle/reverse.png` | [BASE_D_day_reverse.png](BASE_D_day_reverse.png) | [TARGET_D_day_reverse.png](TARGET_D_day_reverse.png) | reverse · yaw196° / pitch30° / height32 |

原始截图根目录：`/Users/yi/Projects/games/the-scroll-within/art/lookdev/20261108/`。采集参数见其下 `29_final_cycle/captures.json`、`28_water_satin_night/captures.json`，实机证据边界见该目录 `README.md`。

## 后续 Godot 精修

岩壁与草石交界仍需在实际 Godot 中精修，**草石交界优先**：处理草下水平窄带、种植贴合与窄根土过渡，再检查斜脊和竖根如何弱化模块接缝、宽瀑口的跌水层次。TARGET 用来明确追求的形体和材质关系；落地后仍需固定种子、机位、分辨率与光照，复查正反向、近景和保留种子。
