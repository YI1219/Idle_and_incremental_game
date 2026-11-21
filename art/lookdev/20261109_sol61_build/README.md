# sol61 Godot 实机质感与对照包

当前版本在 `rock_readability_day`、`rock_readability_night`，四张原生2K壁纸在 `wallpapers/`。用户明确偏好“累计岩面”左侧final_day的岩面清晰度，认为后续变平。本轮已恢复该版的两份岩面/投影源码，保留新草甸。此前将去细纹视为净改善的判断被这次反馈纠正。整体仍未达到TARGET美术标准。

[打开离线对比页](compare.html)

唯一场景入口为 `scenes/terrain_editor.tscn`。人物和坐垫已移除。权威地形、y=0草唇、独立自然物件与argon0保留，BASE机位继续用于全部验收图。

## 岩面清晰度纠偏

用户指定“累计岩面与草唇”组左侧 `final_day` 更好看。核对同机位原图后，后续较大的投影偏移削弱了斜面转折与局部阴影层次。本轮不继续做清理扫描，直接恢复 `final_day` SHA256对应的terrain_environment.gd和stone_surface.gdshaderinc（shadow_bias恢复0.035，撤回stone_albedo_gain补偿）。草的形体、分组、根位置与材质保持最新meadow_fans版本。

`meadow_fans_day/night → rock_readability_day/night` 是本次纠偏实拍；左侧final的源码与恢复后的岩面源码逐项hash相同。旧清理版及其诊断保留作历史证据，不能继续当作获认可的岩面优化。岩面细自阴影纹会随原响应保留；后续处理它必须同时保住用户偏好的转折清晰度。

本轮10张2K图覆盖固定日夜全景、近景、反向等5机位，场景7项及argon9项通过。没有重新改变地形或PCG草根规则。此前三个保留种子的草甸证据对应meadow_fans旧投影参数，不能冒充本次新实拍。

## 草甸成簇与材质响应

`planted_meadow_day/night → meadow_fans_day/night` 仅修改grass_field.gd与grass_blades.gdshader。叶片由较细的统一低草改为连续低草与局部草扇，沿既有世界坐标drift形成高低起伏；保留28簇/平方米的候选密度、草根位置与所有阻挡规则。低草保持连续哑光底面，高簇才加强根部暗色和尖端亮色，叶尖曲线减少下卷。岩石、水、光照、雾、太阳及BASE机位未改变。

内部试验 `clustered_meadow_day` 因过高草墙/平地空斑被否决；`tufted_meadow_day/night` 因重复亮边勾叶被否决。它们不进入Downloads审阅镜像。最终候选经只读复核，近景、全景及反向均有可见收益，未见必须撤回的退化；高簇叶片仍偏肥，前沿草仍偏均匀，不能宣称TARGET对齐。

[草甸Before / After / TARGET裁片](meadow_compare/grass_before_after_target.png)只缩放分析副本，所有原生实拍保持原始字节。此组采集的全部相机/光照参数与地形hash相同；源码hash除两份草文件外还包含临时采集参数的project.godot差异，记录在checks/meadow_capture_audit.json。

## 前轮岩面与草唇修正

以下为历史诊断；shadow_bias=0.35与albedo_gain=0.80方案已按用户反馈撤回，不代表当前岩面。

上一轮把岩面的织物状颗粒当成了材质细节，判断有误。隔离实拍保留纯色和平法线时噪声仍在，关闭太阳投影后噪声消失。深度偏移与法线偏移分别扫描后，采用太阳shadow_bias 0.035→0.35，shadow_normal_bias保持0.70。原生对照中树根、踏石与凸岩的接触阴影仍贴合。

解除错误遮挡后，通过石材 `stone_albedo_gain=0.80` 校正主材质亮度，保留原有粗糙漫反射和米灰颜料洗色。未改变本轮的雾、曝光、太阳角度或场景构图。

草唇实例原本在贴坡后再次按坡度压缩叶高，造成薄草片观感。本轮解除该重复压缩，用既有organic_drift调节扇形草簇宽高。草的根位置、密度与地形顶冠保持原有数据。全景收益小于近景，草仍偏均匀绒毯。

阴影偏移与自遮挡的机制可查Godot 4.7文档。实际取值以本工程原生实拍决定。[Light3D文档](https://docs.godotengine.org/en/4.7/classes/class_light3d.html)

## 前后证据

| 对照 | 修改前 | 修改后 | 隔离范围 |
| --- | --- | --- | --- |
| 岩面恢复 | `meadow_fans_day/night` | `rock_readability_day/night` | 恢复用户偏好的左版岩面/投影源码，草不变 |
| 草甸质感 | `planted_meadow_day/night` | `meadow_fans_day/night` | 仅草叶形体、高低分组与叶材质 |
| 前轮整体 | `final_day/night` | `planted_meadow_day/night` | 岩面自影、石材反照率与草唇宽高 |
| 岩面质感 | `final_day` | `clean_stone_day` | 阴影深度偏移与石材反照率 |
| 草唇体积 | `clean_stone_day` | `planted_meadow_day` | 仅grass_field.gd，光照条件一致 |
| 历史主材质 | `12_material_before_locked_day/night` | `final_day/night` | 仅回放六个与实际08 hash相同的shader及材质绑定 |
| 草石脏接触带 | `00_before_day` | `03_planted_contact_day` | 早期窄根土、贴坡和薄草皮投影修正 |
| 瀑尾白色透底 | `10_painted_surface_day` | `11_water_satin_day` | 既有瀑布材质 |

06原图保留为用户指定基准。对比页默认显示岩面恢复；草甸单项对照仍固定到meadow_fans，历史自阴影清理明确标为已撤回。旧捕获保持原始字节，`wallpapers/`始终为最新原生图的字节复制。

`checks/material_probe_20261109`、`shadow_probe_20261109`、`normal_bias_probe_20261109`保存诊断原图与脚本。诊断中的禁用投影/屏幕GI只发生在该进程。生产场景保持投影、SSAO和SSIL开启。

## 采集条件

Godot4.7.2、Forward+、2560×1440、4×MSAA、动态相位1.25、生产F11净屏处理器。主验收seed7301/preset0，A/B/D progress0.29，C progress0.00。工具不访问用户布局存档，只捕获一个场景实例，并核对人物缺席、数据与源码不变。

- A/C使用center(-2,-1)、height32、yaw16°、pitch30°、FOV31°。
- B使用center(-8,6)、height10、yaw16°、pitch20°、FOV31°。
- D沿用A的center/height/pitch/FOV，yaw196°。

草甸阶段保留种子实拍在 `meadow_seed_2104`、`meadow_seed_4242`、`meadow_seed_913`，依次为preset0/1/2。913本身无水。此前continued_seed与held_seed系列保留作历史证据。

[材质裁片](material_compare/junction_contact_sheet.png)与[像素样本](material_compare/metrics.json)只将分析副本缩到TARGET的1672×941。TARGET存在局部生成漂移，像素差用于找问题。原生验收PNG未经后期修改，裁片不含参考人物。

## 材质来源与验证

新增颜料贴图 `assets/terrain_editor/gouache_stone_sol61.png` 通过内置image_gen生成，已作为Godot资源加载并启用mipmap。它作为无光照颜料参与真实渲染。原贴图保留，完整提示和溯源在 `checks/stone_texture_prompt.txt` 与 `checks/stone_texture_provenance.json`。

最新草改动后，场景7项与草接触/UV4项通过，25张原生2K图覆盖日夜与三个保留种子；前轮草唇24项、argon9项和runtime22项的日志保存在checks。runtime仅在/tmp测试副本换保存目录。Windows轻薄本/MacBook Air约60FPS仍未实测。

浏览器交互尚未实测，Chrome工具未获授权。对比页已检查JavaScript语法及动态图片链接。项目临时采集参数已清空，已正常启动并实按F11核对净屏，运行窗口保留。

Downloads审阅镜像位于 `~/Downloads/scroll_sol61_build_20261109/`，参考包沿用旁边的 `scroll_wallpaper_targets_sol61_20261109/`。镜像携带最新图、必要前后证据、分析和审计文件，失败小包留在工程内追溯。
