# 现有崖石精修：先验证一块

2026-10-15。用户明确选择：现有模型精修与新模型路线均可，**先尝试现有模型精修；足够则不做新模型，不足再转新模型**。

当前只需要一块未贴图的主崖石，来源为保留的 Quaternius `Rock_Medium_2`（244 三角面）。`Rock_Medium_1`（342 三角面）与概念的高石/低岩肩仅作后续备选。没有 Tripo 提交任务，没有开始新模型四视图制作，也没有要求纹理付费。

资料：`art/work/cliff_refinement/2026-10-15/index.html`、`START_HERE.md` 与 `art/work/cliff_refinement/cliff_refinement_pack_2026-10-15.zip`。其中保留原始 glTF/bin/贴图/许可副本、各五张未改动源几何的 Godot 灰模检视图、用户参考、当前实机问题图、生成的造型精修参考和输出目录。文件哈希及源三角面/尺寸信息在 `refinement_manifest.json`。

源视图复现：`godot --path . --script tools/art/capture_cliff_sources.gd`。检视工具只为节点覆盖中性灰预览材质，源模型文件不改动。原模型四方向视图是检查证据，不是新模型的四视图输入。

本轮侧壁缩窄/增密试验 `natural13` 与增高试验 `natural14` 均被撤回：前者暴露更多堆叠台阶，后者拉成长石板。崖石几何仍是经过检查的 `88248c4` / `natural12` 候选；后续已保留实际池底、短草根/已有草叶小簇、`fracture2` 岩块进退、`weather3` 材质混杂、`reflection3` 近岸倒影及 `shore1` 岸石落位；这些失败造型试验不是新待办或当前渲染。

下一步由用户在 Blender 精修现有主崖石，保存到 `art/work/cliff_refinement/2026-10-15/output/cliff_main_v1.blend` 与 `cliff_main_v1.glb`。Codex 检查灰模并接入同一段可编辑岛缘，验证完整露岩/截取侧壁、近远与反向实景、组合比例、封闭、支撑、瀑布避让和拾取。先实际验证再扩展模块或决定新模型路线。

交接包当前问题图已更新到 `1c2ebc7` / `shore1` 的实际岛缘与全岛截图，逐图哈希记录在 `current_runtime_evidence`；旧阶段截图保留作证据，不作为当前外观。原模型灰模检视及六个源文件不变。

整体美术 goal 仍 active：宽板形体、草根小垫片的衔接和水体完整倒影仍不具备最终接受证据。模型精修结果尚未收到；没有完成、性能或概念同等质量的声明。
