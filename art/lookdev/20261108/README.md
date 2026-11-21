# 2026-11-08 识海浮岛视觉 delta

[打开本地实机对比页](compare.html)。默认白天 **31 → 29** 隔离岩壁变化；夜间切换为 **25 → 28** 查看水面高光变化。全部图片为 Godot 原生 `2560×1440` 截图，未修图。

## 最终查看入口

| 用途 | 原图与记录 | 已记录条件 |
|---|---|---|
| 岩壁专项 before | [31整体](31_cliff_before_matched/whole.png) · [5机位记录](31_cliff_before_matched/captures.json) | seed7301、地形预设0、时段0.29；仅4份岩壁源码回到本轮前态 |
| 最终白天与十二时辰 | [29整体](29_final_cycle/whole.png) · [17张记录](29_final_cycle/captures.json) | seed7301、地形预设0；白天5机位＋整体机位12时辰 |
| 最终夜间 | [28反向](28_water_satin_night/reverse.png) · [5机位记录](28_water_satin_night/captures.json) | seed7301、地形预设0、时段0.00 |
| 保留种子2104 | [整体](30_seed_2104/whole.png) · [5机位记录](30_seed_2104/captures.json) | 地形预设0、时段0.29 |
| 保留种子4242 | [整体](30_seed_4242/whole.png) · [5机位记录](30_seed_4242/captures.json) | 地形预设1、时段0.29 |
| 保留种子913 | [整体](30_seed_913/whole.png) · [5机位记录](30_seed_913/captures.json) | 地形预设2、时段0.29；源数据本来无水，仅检查形体、草缘与物件 |

以上记录均为 `valid=true`、`single_scene_capture=true`，通过生产F11处理器净屏并核查帧末草色。统一 Forward+、4×MSAA、冻结动态相位1.25。`valid` 是采集条件验证，不自动代表美术验收。

**31是岩壁专项前态，不是整个项目初态。** 它保留最终草、物件、世界光，仅临时恢复 `procedural_shard.gd`、`terrain_decoration.gd`、`cliff.gdshader`、`cliff_column.gdshader`。31与29的15项全局条件、每张19项相机／景深／时段／灯光／草色等记录逐项完全匹配，源码hash差异恰好这4份；采完已恢复exact final文件。详见[匹配核验JSON](checks/matched_cliff_comparison.json)。

[00接手原状](00_raw_before/whole.png)和[01锁色光](01_locked_before/whole.png)仍在对比菜单保留，但包含色光与旧采集机制差异，不能承担严格形体归因。25／26虽带final或种子名称，只是阶段候选，最终证据以28／29／30为准。

## 视觉 delta 与去留

按岩壁、草石交界、其它材质顺序迭代；同一轮只处理表中所列缺陷。00–06每轮4机位，07起5机位。

| 轮次 | Before缺陷／本轮变化 | 实机结果与去留 |
|---|---|---|
| 00→01 | 暖米雾、太阳72–83.8°偏离argon；恢复预设0名称、冷银灰雾及28/38/42/34°关键帧。 | 采用；晨间38°，保留原草石叶水色表。 |
| 01→03 | 主脊近垂直、未使用真实遮挡；依次加强劈面倾斜差、接入真实投影。 | 斜向转折与接缝投影增加；重复下裙仍需处理。 |
| 04→08 | 过早切面与共同收脚造成薄板、大缝；改闭合四圈、全高宽面及面内斜脊迁移。 | 04、07失败；08连续主体采用，主面延续至根脚。 |
| 09→11 | 核心与外岩光照不一致、石面均匀；依次统一哑光响应、尝试倒角、增加低幅矿物晕染。 | 09影响小但保留；10细肋更突出，回退；11晕染采用。 |
| 11→12 | 外圈块面过密；扩大分段跨度与弦偏差容限。 | 7301／2104外柱36→25、内阶7→5；正反面更连贯，采用。 |
| 13→16 | 护石像悬挂小石、双层薄沿与方直脚；依次延长前脸、单层斜顶、根脚收分、顶面向外下落。 | 13双沿继续修正；14／15／16采用，完整前脸连到底。 |
| 17→19 | 草尖高光试改影响很小；随后查明重复入口场景每帧写回共享草材。 | 17全部撤回、18系列仅诊断；19修复单场景采图，夜草恢复深青。 |
| 19→20 | 软唇种植过早截止；G阈值0.982→0.82，仅新增样本沿真实坡面旋转、内埋8mm。 | whole／reverse／cliff_close复核后保留；7301草簇9465→10098（+6.69%），22个MultiMesh不变。 |
| 20→21 | 草石缺窄土缘；仅ground shader外两环混合已有草色与stone_mid。 | 多机位复核后保留；内草颜色与R0不改。 |
| 21→22 | 入瀑处等距白带像白板；water shader去掉该距离白带。 | 日夜game近景白板消失、断续泡沫保留，采用。 |
| 22→23 | 草簇／芦苇未收到对应shader的昼夜参数；time／environment各一行按实际材质路由。 | palette不改，真实uniform20/20；单场景17张通过。 |
| 23→24→25 | 岩材仍按旧83.8°固定sun_ref提亮，云影偏紫；分轮改由实际太阳受光、朝下AO、修正云影。 | 保留；25夜间reverse仍出现大片纯白水高光，未作为最终版。 |
| 25→27→28 | 同一水面GGX高光抢眼；27试粗糙0.18／specular0.12，28改0.26／0.12。 | 27仍偏亮；28高光收敛，采用。最终白天／十二时辰重拍为29，种子为30。 |

水面直接A/B为 [25夜间reverse](25_final_night/reverse.png) → [28夜间reverse](28_water_satin_night/reverse.png)，五机位拍摄条件匹配。**water／foam／waterfall_mist源码hash从28才补入；旧manifest未列水材，不能单靠旧JSON追溯水shader版本。**

## 证据边界

29十二时辰已逐张复核，28夜间反向水面的白亮块已消除；30三组种子未见新增明确悬空或草缘断缝。实机仍有少量直立模块接缝、草下窄带，4242宽瀑口略平；相对参考的自然错落节奏仍可继续雕琢，不等同用户最终美术验收。

- 15十二时辰、16／17旧夜景的草色被重复主场景写回白天，不能作为昼夜美术结论；旧 `valid=true` 未检查此项。17草材试改已全部撤回。18系列诊断图不作为作品展示；原因与复现见[诊断记录](checks/grass_dual_entry_probe.md)。
- 唯一入口仍为 `scenes/terrain_editor.tscn`；权威可编辑地形、独立自然物件保留，无旧屋。R0模板和局部`y=0`草唇不改；12之后派生世界边界随分段改变，不能声称全岛顶冠逐顶点未变。每次采集前后权威地形hash不变。
- 参考意图：宋韵青绿、大块面斜脊、贯穿山根、哑光石材和软种植过渡；实机结果见原图。本轮未定位 `target_ref_journey.jpg`、`target_ref_wallpaper_v2.jpg`、`cliff_ref_01/03/04.jpg`、用户`1.png`，不声称逐图贴齐。参考意图与功能通过均不代替美术判断。

## 查看与复拍

打开`compare.html`，先看whole／reverse块面节奏，再看cliff_close接缝、护肩与草石边缘；左右与滑杆模式均直接使用原图。下方可打开最终十二时辰、夜间五机位和三组保留种子。

| 机位 | center XZ | height | yaw | pitch |
|---|---:|---:|---:|---:|
| game | (0, -1) | 21 | 16° | 27° |
| whole | (-2, -1) | 32 | 16° | 30° |
| reverse | (-2, -1) | 32 | 196° | 30° |
| close | (-10, -5) | 13 | 16° | 30° |
| cliff_close | (-8, 6) | 10 | 16° | 20° |

均为FOV31。正常F5运行唯一入口，F11清UI／返回；返回后点击左上时辰题签逐时推进。采集用原生Godot编辑器主运行参数：

```text
--script tools/art/capture_lookdev.gd -- --job=res://art/lookdev/capture_job.json
```

任务文件示例（必须新目录，工具拒绝覆盖）：

```json
{"out":"res://art/lookdev/20261108/new_capture","suite":"full","seed":7301,"preset":0,"progress":0.29}
```

`quick`5张，`full`5＋12张；复拍最终夜景用`suite:"night", progress:0.0`，不省略progress（night默认0.02）。需确认`single_scene_capture`、帧末草色、F11、源码和权威数据hash检查。当前临时主运行参数已清空，唯一入口正常F5与F11已实机确认。本机CLI图形进程不能连接桌面服务，因此采集使用原生编辑器。

## 验证记录

草唇24/24、argon锁9/9；[20种植检查](checks/grass_field_20.md)14/14；[23材质路由](checks/foliage_route_23.md)20/20。沙箱默认`user://`不可写，临时测试副本仅把测试存档路径改到`/tmp`后，runtime22/22、gameplay45/45；生产存档代码及用户存档未改，日志在[checks](checks/)。这些是约束与功能证据。

[最终实机笔刷记录](checks/brush_final.json)：Apple M4 Pro、Forward+、**实际1277×717**；expand／raise／contract帧时p95为15.761／16.594／16.474ms，最大22.108／19.737／31.453ms；异步worker约0.958–1.196s，publish最大5.576ms。该实测不是2K性能，也不代表Windows轻薄本或MacBook Air达到60FPS。

[九份生产视觉文件的可逆补丁](checks/lookdev_visual_delta.patch)及[清单](checks/lookdev_visual_delta.json)已通过`git apply --reverse --check`，未应用回滚。
