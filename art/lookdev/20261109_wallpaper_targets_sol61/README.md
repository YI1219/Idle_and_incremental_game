# 识海浮空岛 · 壁纸 TARGET v2（sol61）

[打开四组 BASE / TARGET 对照](compare.html) · [完整 v2 Prompt Pack](PROMPTS.md) · [逐次生成参数与溯源](GENERATION.json)

本包讨论 20261108 最终实机版 29/28 的下一小步 lookdev polish，草石交接优先。BASE 为 Godot 原生实拍的逐字节副本，TARGET 为内置 image_gen 根据对应 BASE 生成的参考图。实际画面与可达性仍需后续 Godot 精修、同条件复拍和用户美术判断。

## 相对 astra v1 的修正

用户否决 v1 的原因为「不是实机能做出来的效果」「整体风格和预期有很大差距」。本轮采用用户指定的 v2 prompt pack，将改动范围收敛到现有草唇、草石窄根土、岩壁接缝与瀑口的小幅 polish。

- **构图贴回 BASE。** 每次仅输入对应实机底板作为构图依据。双台地、两池两瀑、小径和主要树石位置基本跟随原图。对照 v1 A/B，v2 保留了现有宽斜面和竖根的大部分分块关系，减少了重新设计整面山体的幅度。
- **材质与色光贴回实机。** 保留低面数大色块与米灰岩壁，围绕草缘种植贴合和哑光接触关系调整。可达性的依据是改动意图对应现有地形、草场和材质系统的局部工作量，具体效果需要实机验证。
- **B 为主要讨论图。** 草簇沿崖顶贴合，草唇遮住原有灰色窄带，根土过渡趋向细窄。保留的局部偏差见下表，可直接与 BASE 对照判断。

## 风格锚与生成方式

锁定 argon 预设0「天青烟岚 · 宋韵青绿」，冷银灰雾、低饱和苔草绿、米灰石与玉水，暖金主光和青空补光。The Regreening 只借软形体与协调哑光关系，Journey 只借空间层次，Tiny Glade 只借圆钝转角与种植接合。本轮图像输入均为对应 BASE 单图。

`PROMPTS.md` 与 `/tmp/scroll_wallpaper_targets_sol61_PROMPTS.md` 字节一致。每次调用保留原文关键差异、完整 Style Lock、中文 STYLE BLOCK、English companion、对应变体及完整中英负向词，展开占位符后补充单图编辑与构图约束。完整实际提示词保存在 `GENERATION.json`。

生成顺序为 B → A → C → D，各调用一次内置 image_gen。四张 TARGET 均保存工具原生 **1672×941 PNG**，BASE 均为 **2560×1440 PNG**。原始生成文件保留在 `/Users/yi/.codex/generated_images/`，本包保存其逐字节副本。`sol61` 沿用本轮工作包名称，内置工具返回信息中的底层图像模型未披露。

## A / B / C / D 映射

原始实机图位于 `art/lookdev/20261108/`。四张 BASE 均为 seed7301、地形预设0、FOV31、Forward+、4×MSAA、动态相位1.25，经生产 F11 净屏。A/B/D 时段0.29，C 时段0.00。以下参数用于追溯 BASE，TARGET 以生成模型近似跟随构图。

| 变体 | 实机来源 | BASE | TARGET | BASE 机位 |
|---|---|---|---|---|
| A 日景全身 | `29_final_cycle/whole.png` | [日景全身底板](BASE_A_day_whole.png) | [A 日景全身](TARGET_A_day_whole.png) | whole · yaw16° · pitch30° · height32 |
| B 草石交接优先 | `29_final_cycle/cliff_close.png` | [岩壁近景底板](BASE_B_cliff_close.png) | [B 草石交接](TARGET_B_grass_rock_hero.png) | cliff_close · yaw16° · pitch20° · height10 |
| C 夜景全身 | `28_water_satin_night/whole.png` | [夜景全身底板](BASE_C_night_whole.png) | [C 夜景全身](TARGET_C_night_whole.png) | whole · yaw16° · pitch30° · height32 |
| D 日景反向 | `29_final_cycle/reverse.png` | [日景反向底板](BASE_D_day_reverse.png) | [D 日景反向](TARGET_D_day_reverse.png) | reverse · yaw196° · pitch30° · height32 |

## 逐图检查与保留的偏差

| 图 | 可讨论的局部 polish | 生成偏差与尚存缺口 |
|---|---|---|
| A | 草唇柔化，池瀑与原有斜面关系基本保留，瀑口增加少量泡沫层次 | 下沿云雾增厚，部分山根变淡。树冠、岸石与岩面细节有重绘，局部草色偏黄。 |
| B | 原宽斜面和竖根朝向保留，草石贴合最清楚，灰色水平窄带被草缘弱化 | 部分根土仍连成浅黄细边，边缘草簇偏大且略密。直立分块感和右侧短护面仍可见，尚未完整达到断续自然接合。 |
| C | 原布局基本保留，水面高光较细碎，瀑口泡沫增加 | 云海及整体曝光明显低于 BASE，曝光锁定未充分达到。池中亮波纹和下瀑尾泡沫增加，这些变化需要单独判断。 |
| D | 反向大块面框架保留，草缘更柔，池岸层次可读 | 背侧横向台阶和竖向重复感仍可见，草色略偏黄。局部出水被重新解释为小跌级。 |

四张 TARGET 独立生成，局部树石、草丛、瀑口和岩面分块存在跨视角差异。查看时以主要布局、材质接触和大块面关系为讨论尺度。C 的曝光偏移、A 的增雾以及 B 的连续土边均已保留原始输出供判断。

## 后续 Godot 精修

后续先处理草石交界，沿真实坡面贴合草簇，让根土宽度与高低自然断续，再弱化直立模块接缝和草下水平窄带，最后补宽瀑口的轻微跌水层次。届时需固定 seed、相机、分辨率和光照复拍，检查正反向、近景及保留种子。TARGET 提供目标关系，实机可达程度须由这一步建立。

## 交付位置

- 仓库包 `/Users/yi/Projects/games/the-scroll-within/art/lookdev/20261109_wallpaper_targets_sol61/`
- Downloads 包 `/Users/yi/Downloads/scroll_wallpaper_targets_sol61_20261109/`

两包包含同一组四张 BASE、四张 TARGET、PROMPTS、README、GENERATION 和离线对照页。哈希核对记录在 `GENERATION.json` 中。
