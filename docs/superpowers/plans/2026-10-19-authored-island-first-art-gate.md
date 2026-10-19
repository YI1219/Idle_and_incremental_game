# Authored Island First Art Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans inline. Do not delegate implementation tasks. Stop at the user art gate before expanding functionality.

**Goal:** 建立可回退的实际基线、完成房屋与地形组合母版，以直接截图让用户判断是否值得参数化。

**Architecture:** 首阶段仅新增工具场景及捕获入口，不替换生产地形、默认模型或用户数据。源文件保留，候选房屋和地形使用独立引用；合格以后才设计正式编辑数据接入，不提前承诺密度／网格／曲线存储格式。

**Tech Stack:** 当前 Godot 4.7.2，已有原生截图流程，必要时 Blender；项目级 Godot 与 Blender 技能。

**Spec:** `docs/superpowers/specs/2026-10-19-authored-island-design.md`

## Global Constraints

- 原件与旧存档保留；现役房屋允许重做／找资源，不锁死旧模型。
- 不采用被否决的浅岛柔光路线，不建展示网页，不批量生成或默认付费。
- 原版／候选使用明确可复现的镜头与渲染设置；AI 参考图不称实机。
- 未获母版美术认可，不扩展为第二布局正式集成或通用编辑器。
- 出现实质偏差立即整理证据并讨论；普通代码错误自行修复。

## Review Focus

- 当前房屋实际加载的 GLB、实例非等比缩放和叠加门／屋顶效果须分别辨认，不只归咎原模。
- 原版捕获不得载入失败候选、修改源数据或覆盖用户存档；用捕获前后序列化比较检查。
- 画面必须包含完整建筑与植被，不能用局部或灰模掩盖协调问题；逐张查看五类截图。
- 新资源必须有来源与适用许可；没有许可依据的源码／模型只能研究，不直接分发或接入。
- 低角与反向不能有依靠主镜头掩盖的拼缝、挂脚或空背面；艺术关口明确列出未解决项。

## Task 1: Reference, skills and actual baseline

**Files:**
- Create: `.agents/skills/{godot,blender-3d-asset-generation}/` and `.agents/skills/SOURCES.json`
- Create: `art/source/reference_research/2026-10-19/manifest.json` and `README.md`
- Create: `tools/art/capture_authored_island_baseline.gd`
- Create: `art/review/terrain_fidelity/2026-10-19/authored_island/baseline/` actual PNGs and capture JSON
- Modify: current context, asset status and generation-task status to point at the new spec.

**Interfaces:** capture script extends the existing `capture_rim_round.gd` helper, creates the unmodified `scenes/terrain_editor.tscn`, and saves `{whole,play,close,reverse,low}.png` plus camera/data/source evidence. No production code changes.

- [x] Install the two inspected skills at fixed reference commit; retain licenses and verify actual Godot version.
- [x] Preserve selected upstream text sources in ignored local cache, mark them study-only, record URLs and SHA256 in manifest.
- [x] Read current cottage loading and instance transforms; list original GLB versus renderer modifications in the baseline review.
- [x] Run Godot parse check for the capture tool, then native capture with original data/rendering; inspect every frame and check capture errors, data identity and logs.
- [x] Commit only this milestone's sources/docs/skills; keep older unrelated dirty files and failed experiments separate. Do not report goal completion.

## Task 2: House and landform mother scene

**Files:** create separately named work sources, runtime candidate assets only after inspection, and `tools/art/` study scene/capture files under the same review date. Exact representation and asset candidate are selected from Task 1 evidence, not guessed in advance.

**Interfaces:** consumes the baseline's scene, camera set and source manifest. Produces a separately reproducible complete Godot scene and same-view screenshots; no formal editor/save migration.

- [ ] Choose and explain the house production approach using actual source defects and scene-scale silhouette; present a concrete resource/shape candidate before any paid action.
- [ ] Build the terrain mother form with designed major masses and transitions, using shared boundary definitions. Do not use a new seed/material sweep as a replacement for shape design.
- [ ] Compare full-scene screenshots at each substantive shape revision. On regression or scope change, stop expansion and discuss immediately.
- [ ] Capture the five required views, inspect original/candidate together, and report unresolved art defects directly to the user.
- [ ] Wait for explicit mother-scene art acceptance before writing the second-layout/editor implementation plan. A rejected mother scene is a negative result, not completion of the goal.
