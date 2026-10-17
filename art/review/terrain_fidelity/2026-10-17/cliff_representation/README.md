# 崖体表示与材质交界对照

2026-10-17。49张新Godot原生实机图，33张隔离、16张实际场景。当前默认仍为 `spall_finish1`，未推广任何研究几何或材质。图片不是imagegen结果。

## 结果

三块已有相邻崖石36/37/38的封闭源几何（墙面＋封口盖）逐字节保留。原始组合2188三角面、3个相交封闭体；原生Manifold合并2248三角面、1个封闭连通体；同一合并体经过现有0.25米密度采样与四面体重建后19240三角面、1个封闭连通体。合并、重建、裁剪输出在1e-5位置焊接下均无非双用边、无定向边配对缺陷、无重复顶点退化面、正有向体积。裁剪控制顶面Y3.25，体积101.718→96.143m³。

有限表面取样：合并→重建11240点平均2.68厘米、95分位8.90厘米、最大取样17.29厘米；反向24050点平均0.44厘米、95分位2.45厘米、最大取样12.53厘米。合并→原始组合的11240点最大取样0.413毫米，按1毫米浮点最近点容差检查。它不是逐字节几何保持、面积加权分布或精确Hausdorff上界。重建体积约缩小0.55%。

原生平面法线对照中，合并保留原有外观；采样导致窄缝变浅、边缘收缩及格子折面。对三个版本应用同一65度法线平滑算法（不是相同法线向量）后，明暗阶梯减轻，但丢失形状没有回来。保留下来的源大面仍然宽、偏圆，细长三角面的阴影接痕也在；合并算法没有把来源自动变漂亮。

材质控制使用完全相同合并网格与地图，比较线性混合和真实源高度参与混合。原始地图由原程序重生成到独立目录，两张PNG与原件SHA256逐字节一致，并额外保留当初生成法线的float32高度场。没有把矿物颜色当高度。高度混合边缘更碎更硬，仍像涂色，缺少实体草簇/薄土厚度。**不采用这版混合，不把它当作草石接缝完成。**

实际场景仅在截图工具中替换3个绘制实例。三种几何对照共用石材与同一法线算法；原正式版本保留实例色与原法线，仅供上下文参考。按正式source_stone_crown的墙面绘制方式，一致不绘制草地下Y3.5的水平封口盖；闭合源与测量文件仍保留盖。草地、藤蔓、建筑、树和其余底体保留，作者数据哈希未变，四个水体时钟1.25；云雾实时变化。实际近景仍能看到草沿收缩/变圆，远景增益很小。未宣称支撑、碰撞、拾取或编辑再发布通过，因为它只是绘制对照。

## 判定与后续

保留原生几何合并/裁剪作为形状保真的可行候选和质量对照；不替换默认地形。0.25米表示对这些源的损失得到直接证据，但不能据此认定所有造型问题都来自采样。下一项有价值的工作是小范围保留棱面的表示/重建验证，同时保留源约束，不能单换算法名后继续丢失同样数据。源的大形与实体草土接触也仍需改善。暂不生成Tripo、不改引擎、不加全岛噪声或铺更多岩块。

本轮不接受整岛美术、不证明任意玩家编辑、CSG连续笔刷响应或目标设备性能。原生计时只记录可能缓存的结果提取与导出；不能与重建耗时作性能优劣比较。纯重建计时已放在网格构建结束处，仍只代表开发机的一次小样。

## 复现

项目根目录依次执行：

```sh
/opt/homebrew/bin/godot --headless --path . --script res://tools/art/probe_cliff_manifold.gd
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/art/sample_cliff_representation.py
/opt/homebrew/bin/godot --headless --path . --script res://tools/art/reconstruct_cliff_probe.gd
python3 tools/art/bake_terrain_detail.py --output art/work/cliff_representation/2026-10-17/height_maps --height-data
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/art/measure_cliff_representation.py
/opt/homebrew/bin/godot --path . --script res://tools/art/capture_cliff_representation.gd
/opt/homebrew/bin/godot --path . --script res://tools/art/capture_cliff_representation_scene.gd
python3 tools/art/build_cliff_representation_review.py
```

Godot4.7.2、Metal Forward+、M4Pro。Blender5.2.1附带numpy。既有二进制源与图片按项目约定仅保留本地，工具、报告、来源及判定提交。图库为 `http://127.0.0.1:18771/cliff_representation.html`。

## 校验与被排除的证据

每个网格节点三方向BVH符号检查遇到13处分歧；全部通过独立float64三方向逐三角面交点计算解决，另每41节点抽查，共1174个独立三方向检查，0个多数票修正。321个距表面1e-4米以内节点另外记录；零值沿用现有场的空气侧微偏置。它是有界验证，不是绝对无错分类保证。

第一轮隔离捕捉漏了材质依赖，所有该轮材质图无效，整轮留在 `rejected_missing_palette`，不计49张。第一轮场景图绘制了与草地重合的源封口盖，有条纹深度冲突，16张留在 `rejected_cap_overlap`，也不计49张。最终完整重跑无脚本/材质错误，7组相同相机元数据、图片写入返回值、分辨率和文件哈希由图库构建工具校验。

独立审查确认源拼接逐字节一致、定向边配对、面数和无正式修改；指出并修正了计时标注和场景顶盖问题。审查者看过隔离对照；修正后的16张场景图由主代理复核，不冒称已做第二轮独立审查。详细报告在validation.json与logs。
