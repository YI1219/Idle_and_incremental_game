# 当前上下文

更新：2026-11-22（最新六节为英文，见下）；此前内容更新于2026-11-16。用户最新明确请求优先。原goal已由用户清除，不自动重建。

## 2026-11-22 sessions: purpose-built runtime, plan, freeze, first spikes (English)

Owner decision, 2026-11-22 (outranks the 2026-11-21 "stay on Godot and change techniques" stack decision in the section below): a purpose-built runtime is being built. One shared runtime (save, settings, items and warehouse, cultivator and progression, input and camera interfaces, headless simulation) with swappable scene and render layers; the Sea of Consciousness is the first layer and the only one in the first slice; the village and the extraction map join later in the same runtime. Do not re-argue staying on Godot.

What binds (owner, 2026-11-22): the locked gameplay is the hard constraint; the feel of today's picture is the floor to keep and raise; earlier code, requirement notes, specifications and pipeline, including the older sections of this file, are reference and not rules. The agent sets and pursues the art goal and decides engine internals; the owner judges pictures. The agent has full authority over git for this repository; never discard work without a recoverable tag or backup.

How the work is done (owner, 2026-11-22): Fable directs, reviews and decides; Opus 5.5 sub-agents do the implementation, in the same workspace.

Owner answers in two rounds the same day (full list in section 1.1 of the plan):

- First acceptance gate: this Mac (M4 Pro) on its own screen at 3024x1964 and 60 FPS, fallback 1080p at 120 FPS. Windows and thin laptops come later and nothing waits on them; nothing is claimed for them until measured.
- The current island generator is not ported; generation is rewritten in the runtime. Cliff form and surface work continues only in the runtime.
- Water is a source-driven flow: no source, no ponds; a spirit spring is an unlimited outlet; no conserved volume. A new game starts with one spring; moving and removing it are tested cases.
- Each island is designed for 4,096 cells; area is limited by cultivation and realm; more islands can be founded; they are staggered in space at heights the player sets, and several are on screen at once. Fishing is unrelated to island size.
- Wallpaper: watch-only, still camera, a true wallpaper on macOS and Windows; when covered or the display is off the default is no frames with the simulation running, as a user setting; launch catch-up capped at 12 real hours. A day is about 12 minutes. Foliage sways only when a gust passes. A free skinned character model is allowed.

State of the work:

- Plan: `docs/engine_refactor_plan.md`. No owner decision is open (`docs/engine_refactor_plan_questions.md`).
- Phase 0 done. Freeze: tag `godot-freeze-20261122` on `pr-18-lip`, after 40 of 40 regression cases; Godot at the gate resolution on the default island needs 22.4 to 29.4 ms on its default tier and 13.7 to 18.9 ms on its light tier (`art/lookdev/20261122_freeze/`). Lookdev pictures are ignored in git and cloned to `~/Archives/the-scroll-within/lookdev_20261122/`. Raw model sources and candidate assets are in the local-only tag `godot-freeze-20261122-full` because `origin` is public. Exports for the runtime are in `tools/export/` and `runtime/data/reference/`: cells of the four review layouts, the twelve cameras, production traces; 72 Godot reference frames at 3024x1964 are in `art/lookdev/20261122_g1/godot_baseline/`.
- Phase 1 done, checkpoint G1 reached: `art/lookdev/20261122_g1/README.md` and `compare.html`. Runtime work is on branch `runtime-dev` in `runtime/` (Rust, wgpu 30, winit 0.30); `runtime/README.md` lists what exists. All of it is throwaway spike code.
  - S1: a true macOS wallpaper window works; covered, it presents nothing and uses 0.05% of a core; visible at 30 FPS, 3.6% of a core. Timer pacing is not good enough; the shell needs display-driven pacing. Display sleep, session lock and several Spaces are untested.
  - S2: the cached-island structure costs 1.6 to 1.9 ms moving and 0.5 ms still at 3024x1964 on a stand-in scene (budgets 12 and 4 ms).
  - S4: picked the hanging-rock body on a liner over the plain hull. Its rim plan passes the locality test on five islands and rebuilds a whole 4,096-cell island in 172 ms. Its defects are listed in the G1 README.
  - S3: picked line and flat wash on a warm silk-paper ground. With four samples per pixel it costs 5.2 to 8.5 ms a frame at 3024x1964.
- The G1 picks are the agent's and are not art-accepted. The owner has not yet looked at G1.
- The Mac's display runs a scaled mode: 1800x1169 points, 3600x2338 backing pixels, on the 3024x1964 panel, at 120 Hz. The gate is measured at 3024x1964; 3600x2338 is reported beside it.
- Next, unless the owner redirects at G1: phase 2, the shared runtime core and the headless simulation, tested against `runtime/data/reference/production_trace.json`.
- Still true: no lookdev pass is art-accepted; a new runtime does not by itself fix island form or the presence of large cliff faces.

## 2026-11-21 session: reverse wall stagger (English)

Owner call, 2026-11-21 (newest art call, outranks older notes below): the back of the island (`reverse` / `foot_reverse`, clearest on seed 7301 at day and dusk) is a regimented row of like-width, like-height vertical faces, like a palisade. It is a form and arrangement problem of the generated cliff, not a texture-streak or mist-veil problem. Form locks: the face-up shoulder requirement is cancelled; wide verticals, local side protrusions, reverse slopes and a downward inward taper are allowed; no uniform expansion of the cliff ring; organised main-face width and depth, one primary and one secondary face, natural local protrusions, blunt connected lower inward; no guard wall or pillar arrays; heightmap stays the authority for the base shell; never one rock mesh for the whole island. Performance and wallpaper use stay first-class; Godot is not mandatory if another stack clearly wins on performance, gameplay and platforms. Part-one gameplay design is locked by the owner (cultivator worker commanded like an RTS unit, the mouse as a second worker, qi from a spirit spring planted into crops and ore seedlings, crafting for the first exploration outing, qi conduits and formations, prosperity into combat power); village and exploration map are later scenes. No paid Tripo until the owner has reviewed pictures and locked the part-one list.

Work landed in the worktree (uncommitted, not art-accepted, target laptops unmeasured):

- Reverse wall stagger, `art/lookdev/20261121_reverse_stagger/` (`compare.html`, `README.md`): one production file, `scripts/terrain_editor/terrain_decoration.gd`.
  - Cause, measured on the layout data: every outer slab stood 0.66 to 0.89 m in front of the heightmap contour, so the rim was one smooth line in plan with 0.0 to 0.1 m of step between neighbours; all relief came from the lowered rock groups, and three gates tuned to the default island (five fixed compass lobes, an x-range exclusion of both island ends, a land probe that a stair-stepped bowed contour fails) kept them off the back-left wall and west end.
  - `_stagger_outer_faces()`: each outer slab takes a role from its own width plus a fixed per-slab number. A primary steps 0.80 to 1.25 m forward, turns 3 to 6 degrees and may take over a plain neighbour on its plane; a secondary steps back (never under 0.46 m from the contour) and its neighbours stop at its ends. Slabs that offer a rock group hold their place and the faces beside them do not step forward.
  - `sh_filler` in `_rim_run()` plus a one-hop choice in `_prune_overlapping_buttresses()`: 37% of the broad outer runs the old gates left bare offer a group; one is kept only where no first-kind group was offered within 5.25 m and it outranks the other offers in that radius. The old gates and their results are untouched.
  - Every decision is intrinsic or one hop, so the 10.5 m edit-locality bound holds. The owner's 2026-11-16 Option A restraint is kept: six groups on the default island (2 to 6 allowed).
  - Longest plain row (neighbouring outer slabs, no group, joints under 0.30 m of step): seed 7301 from 9 slabs / 38.1 m to 4 / 21.8 m; 2104 from 8 / 34.8 m to 4 / 21.7 m; 4242 from 4 / 22.4 m to 2 / 13.1 m; 913 from 12 / 47.2 m to 5 / 22.7 m.
  - 40 of 40 regression cases pass; 120 native 2560×1440 review frames (default, dusk, three held layouts); cold layout time unchanged at 271 ms.
- Still open from this slice: a primary face carries its lawn up to about 2.1 m outside the heightmap cells; the large reverse faces still lack surface presence (stone shader unchanged); veil, shaded-wall streaks, the hard dusk junction, the pale far pond and slab feet from below are as in the cliff-water package.

## 2026-11-21 session: performance, light tier and stack decision (English)

`art/lookdev/20261121_perf_stack/` (`README.md`, `compare.html`). All numbers are from the development Mac (M4 Pro, mains power); no target laptop was measured.

- Stack decision: stay on Godot and change techniques. An empty viewport with sky and post effects adds nothing measurable to a frame, so the engine is not the cost; every saving found is a technique change Godot can make. What would reopen it: a measured target laptop that the light tier and the listed next steps cannot bring into budget.
- Measurement trap: an idle window on this Mac presents at only about 85 frames a second, so single-viewport timings at 1080p and below sit at that ceiling and hide feature costs. Earlier 1080p and 720p numbers in this file were taken that way. Use `tools/perf/bench_presets.gd` (K identical viewports sharing one world, frame time divided by K) for tier costs.
- One 1080p render of the default tier costs 12.4 ms: 2x MSAA 2.9 ms, SSAO and SSIL together 1.8 to 2.0 ms (they share a pre-pass, so either alone saves little), foliage cards 2.0 ms, sun shadows 1.7 ms, grass 1.6 ms; cliffs and water are nearly free.
- Light tier landed: `preview_quality.gd` `set_light()`, `editor.gd` `set_light_preview()`, menu entry 轻量画质 in `shihai_hud.gd`. SMAA instead of MSAA, SSAO and SSIL off, far blur off. Default tier unchanged. 35 to 43% cheaper than the default at 1080p, 1440p and 4K on three views (1080p: 7.0 to 8.8 ms against 12.0 to 15.4 ms); stills within about 2/255 of the default. Moving-grass shimmer under SMAA not judged.
- Other renderers: Mobile runs the scene at about 8.3 ms with a close picture (no SSAO or SSIL); Compatibility is about as cheap but the stone blows out and ponds turn grey.
- Wallpaper mode uses 38 to 42% of one core at 30 FPS; about 19 points are the GDScript water simulation on worker threads (10 cycles a second, 32 ms each), about 7 the main thread.
- Water has no source: the default ponds fall from 71 units to 7.3 in five minutes and the solver never sleeps, so a hung wallpaper loses its ponds and falls. Recommended and not done (it changes the finite-water behaviour the owner asked for on 2026-11-10): make the part-one spirit spring a water source and put the solver to sleep at steady state.
- 40 of 40 regression cases pass; `tests/preview_quality_test.gd` has 19 checks.

## 2026-11-21 session: part-one gameplay core and object list (English)

The owner's 2026-11-21 brief opened part-one gameplay (design lock recorded in the stagger section above). Landed, uncommitted:

- `scripts/gameplay/base/base_catalog.gd` and `base_sim.gd`: a node-free simulation of the supply pipeline for the first outing. Spring makes qi; fields and ore beds mix qi and water in their own ratios; hearth, furnace and forge consume those products with qi; conduits carry qi and a closed ring wakes a formation (1.25x speed for what it encloses); the cultivator works through a queue of orders and fetches missing water or qi itself; hunger and thirst slow work to half at worst and never stop it; a fasting pill suspends both; the mouse does one unit of work per click on its own; prosperity and cultivation give combat power; `to_dict()` / `from_dict()` save it; one long tick equals many short ones, so it can run while hung as a wallpaper.
- `tests/base_supply_loop_test.gd`: 39 checks, all pass. The first outing's kit (one blade, two healing pills, three spirit meals) comes together after about 7 minutes of simulated play. This test is not in the 40-case list of `cases.json`.
- Not done: nothing is wired into `scenes/terrain_editor.tscn`. No placement on the island, no cultivator in the scene, no HUD. Walking is straight-line distance, not a path over terrain. Numbers are first-pass tuning values. The older `scripts/gameplay/` director, fishing and realm files are untouched.
- `docs/part_one_objects.md`: the part-one object list against the existing pictures, a review of those pictures, what is still to make, and three choices for the owner. No new picture was generated and nothing was sent to Tripo.

## 2026-11-20 to 21 sessions (English)

Wave brief from the user, 2026-11-20 (outranks older notes below): performance is first-class, the world must run cheaply on low-end devices and as a hung wallpaper without giving up the current beauty or the classical Chinese atmosphere; palette stays warm mist / olive grass / soft grey stone; major cliff faces were plain and paper-flat, undersides stepped and shelf-like, water and falls stiff and paper-like. Wrap GPU work in `tools/perf/gpu_run.sh` (send its output to a log file, a pipe waits out the whole timeout). No paid Tripo.

Work landed in the worktree (all uncommitted, none art-accepted, target laptops unmeasured):

- Cliff presence, `art/lookdev/20261120_cliff_presence/` (`README.md`): `stone_cliff_character()` in `stone_surface.gdshaderinc` (plates, fissures, mossy brow on steep faces), blunt level slab feet in `procedural_shard.gd`, and `tier1_frac = 1.0` in `terrain_decoration.gd`. Reviewed 2026-11-21: bottoms calmer but still a stepped dark skirting; shaded faces read as streaked concrete.
- Root veil, brushed faces, pond and waterfall, `art/lookdev/20261121_cliff_water/` (`compare.html`, `README.md`): five shaders, `procedural_shard.gd`, `preview_quality.gd`, one global in `project.godot`.
  - Root veil in `stone_surface.gdshaderinc`, used by `cliff_column.gdshader` and `cliff.gdshader`: from about -2.5 m to -5.7 m the rock eases to the palette `stone_mist` tone and then frays away, so slab feet at different depths no longer show and tall faces carry a top-to-root gradient at every hour. `root_veil_strength = 0` turns it off.
  - `stone_cliff_character()` now reads the hand-painted wash (`gouache_stone_sol61`) instead of the mineral photo: broad brush planes and a few dry strokes. Same four taps.
  - `procedural_shard.gd`: the band under each slab's collar takes the shading normal of the face below it, which removes the square tone patches under the grass lip. Vertex positions unchanged.
  - `waterfall.gdshader` rewritten: glassy lip, pattern laid along the square root of the drop so it stretches and speeds up, pulsed white ropes, thinning sheet, fraying outline, vertex billow, outer fall thinning into the veil. Five noise lookups instead of seven.
  - `water.gdshader`: sky sheen from the engine's sky radiance (`sky_sheen = .28`), sparse drifting light lines from fields the shader already had, per-light shading skipped.
  - Cheaper stone shading: new global `stone_fine_relief`, set by `preview_quality.gd` (0 in balanced, 1 in native), skips the cliff micro-relief; a three-tap stone-tooth term worth under one 8-bit step is removed. Balanced cliff fragments go from 19 taps and 8 noises to 10 and 4; stills change by a mean of 0.04 to 0.16 of 255.
  - Cost on M4 Pro, AC power, one live scene: veil, fall and pond are cost-neutral (4K 29.94 vs 30.13 ms for the task-start shaders); skipping the relief saves about 0.5 ms at 4K (29.60 vs 30.10 ms) and 0.15 ms at 1080p. 40 of 40 regression cases pass (`checks/suite.json`).
- Still open: a strong band where the dark wall meets the veil at dusk; the far pond is paler at the lowest camera pitch; frayed slab feet are open shells from directly below; veil heights are constants tied to the current hull depth; no measurement on target laptops.

## 2026-11-19 session (English)

Latest user decisions, 2026-11-19 (these outrank older notes below):

- Art: rock shapes come first. The overall cliff face is liked; some rocks are too fragmented.
- Product: hanging as a desktop wallpaper is a key value of the game.
- Gameplay scope: keep fishing and land credits; the other leftover systems (meditation and the rest) are not needed. Village and exploration move to part two. Earlier character models were unsatisfactory; use a simple model. Gameplay rules are a proposal under discussion with the user; stage two has not started and no gameplay code was changed.
- Tripo input pictures: the agent may choose between `codex` and `agy` for image generation and use it. No Tripo job was submitted.

Work landed in the worktree (all uncommitted, none art-accepted, target laptops unmeasured):

- Rock shapes, `art/lookdev/20261119_rock_shapes/` (`compare.html`, `README.md`): `terrain_decoration.gd` gains `_merge_narrow_columns()`. Outer pillars on contour runs under 2.65 m fold into the broad slabs beside them; thin fingers of land, outward bumps and shoulder hosts keep their pillars. Default layout 30 columns to 24. Fragment counts from the ID metric fall 15 to 23% on three layouts and 4% on seed 913, with exposed core hull unchanged. Stepped slab bottoms and tone patches inside a slab face are untouched.
- Native 4K, `art/lookdev/20261119_native4k/` (`README.md`): `grass_field.gd` gains a 28-triangle clump level between 56 and 14; balanced mode in `preview_quality.gd` uses the very-low SSIL gather, native mode restores the project value. On AC power, six alternating rounds: 4K 29.91 to 33.77 FPS, 2K 56.95 to 60.49 FPS. The rest of a 4K frame is the look itself (2x MSAA, SSAO+SSIL, shadows, DoF).
- Model pictures, `art/source/model_refs_20261119/` (`README.md`): `assets.json` plus `build_prompts.py` give 78 assets and 168 picture prompts in five tiers; generation scope today is tier A and the simple cultivator.

Operations learned today:

- The Mac ran on battery during the first perf session and shut down from under-voltage at about 16:25. Check `pmset -g batt` shows AC Power before any Godot or capture run; a frame rate that falls round after round is a power signal. Runs from that period are in `art/lookdev/20261119_native4k/checks/invalid_low_battery/`.
- From the Fiji PC use Windows OpenSSH (`C:\Windows\System32\OpenSSH\ssh.exe`); Git Bash ssh rejects the BOM in the ssh config.

## 当前画面 · 方案 A 净化岩壁、硬折角与台缘反向露岩过渡

2026-11-16 针对用户反馈此前版本因岩壁过碎过繁不如 `before` 美观，在通过同机位概念草图对齐用户偏好后，将繁杂版完整归档至 `art/lookdev/20261114_cliff_optimization/rejected_busy_v2/`（偏平版保留于 `rejected_flat_v1/`），严格按用户选定的**方案 A（一主一辅、大面留白）**及四项明确要求落地实际 Godot 画面：

- 对比审阅页 [`art/lookdev/20261114_cliff_optimization/compare.html`](art/lookdev/20261114_cliff_optimization/compare.html)（仅展示实际 Godot 原生输出，与概念参考图严格分离）：包含 `final/`、`final_edits/`（缩/扩/降/抬）、`final_held2104/`、`final_held4242/`、`final_held913/`、`final_night/` 共 64 张原生 2560×1440 Forward+ 实拍（全部 `valid=true, errors=[]`），支持与 `before/`、`before_edits/`、`rejected_busy_v2/`、`rejected_flat_v1/` 及上轮构图基线同机位同光照对比。
- 核心生产改动：
  1. **方案 A 大面留白与主次斜肩**（`terrain_decoration.gd`）：互斥半径收至 `5.25m`（编辑局部影响 `<= 10.5m`），移除台阶翼侧碎块与自动台缘散石（`_outcrops = []`，点缀物件交由玩家自行摆放），保留约七成安静连贯米灰崖面、2–3 块主次硬切斜肩巨石及宽阔无遮挡右侧下瀑。
  2. **消除立柱怪异转折与保持硬朗折角**（`procedural_shard.gd`）：重写 `_add_varied_body` 与 `_add_continuous_body` 为单调平直收分断面，彻底消除瀑布右侧竖柱中段鼓肚与 `S` 形收腰怪折；将 `_soften_pair` 与抱脚巨石法线软化收紧至 `(20.0, 0.26)` 并恢复单平面斜切顶盖，确保转角硬朗利落。
  3. **石壁反向露岩与稀疏秃草坪过渡**（新增 `cliff_rim_balding.gd`，联动 `terrain_renderer.gd`、`grass_field.gd`、`grass_lip_soften.gd`、`rim_surface_detail.gd`、`ground.gdshader`）：沿约三成外缘干崖岬角收窄悬挑草唇、清空外沿草簇，使与受光崖壁同明度的米灰露岩及短矮稀疏干草坪自然反向咬入台地；内部庭院台阶与步道水岸保持原有葱郁草缘。
  4. **护壁净空与编辑一致性**（`block_mantle.gd`、`contour_terrain.gd`）：钳制 `minf(h - 2.15, -0.45)` 并过滤异向 Voronoi 块，消除 `edit_contract` / `foot_reverse` 高墙凸出楔块。9 个受保护光照、法线、石材着色器与 `cliff_shoulder_join.gd` 全程零改动（`checks/audit.json` 已核验）。
- 40/40 自动化测试通过（31 headless + 9 native；含 `cliff_form_variety_test` 57 checks、`cliff_near_consistency_test` 217 checks、`cliff_outer_foot_test` 1019 checks、`grass_lip_soften_test` 24 checks）及 90 帧 `scenes/terrain_editor.tscn` 原生冒烟通过（`SMOKE 90 FRAMES: pending=false chunks=21`）。功能通过不等同于美术验收（`art_accepted: false`），目标 Windows 轻薄本／MacBook Air 性能仍未在目标机测（`target_hardware_performance_measured: false`）。

## 当前画面 · 台地、树群与岩脚

2026-11-14用户批准借鉴《人间牧场》的空间组织，继续第一阶段实际庭院构图。当前默认干地形成后侧5m宽高台、3.5m庭院、前侧2.5m低肩与1.5m下层；以水平草台打断连续岩墙。树木改为左侧三棵主群、后侧单株点景与右侧大小双株，池面／踏石周围留白。地面仍为同一可编辑TerrainData，自然物仍独立placement。

- 最新审阅 `art/lookdev/20261114_courtyard_composition/compare.html`。正式目录final／final_held2104／final_held4242／final_held913／final_night，共50张原生2K，46组前后机位／色光／相位／质量一致。默认preset0干地有意改高程；另外两preset及旧存档地形不迁移，种植／清路规则会影响它们重新生成的装饰画面。水床／出口记录保持。
- 保留先前cliff_shoulder_join的长斜面与局部收脚算法，不再用整块压短产生“小凸包”。本轮生产只改terrain_data、terrain_decoration、grass_field、grass_lip_soften，材质／取色／环境光照保持。后两者拓宽草路留白，并处理新转角草缘的交叉条带和凹四边形错误对角线；没有靠改法线遮盖折面。
- 39组适用检查通过（30headless＋9native），正常入口90帧通过。新构图31、实传草根避路3、历史与当前台阶封口67、草唇24均通过；草唇先RED2→1→0。旧封口固定3.3m探针与新2.5m低台冲突，已保留历史地形fixture并同时覆盖当前地形，未删掉原缺陷回归。构图只读审查无重要发现，随后草缘修复以失败复现和完整回归核查。
- 已看多角／多种子／夜景实拍，仍待用户美术确认。局部直壁、拼缝与薄尖未整体重做；目标Windows轻薄本／MacBookAir性能未测。前后源码／patch／SHA／审查和边界见新包checks；candidate与不带final的held目录是草缘修复前中间证据，不能当当前输出。
- 上轮岩脚形变的专项对照仍在 `art/lookdev/20261113_cliff_join/`；cliff_foot整层压短已被否定。唯一入口仍terrain_editor.tscn，无人物／旧屋／二阶段扩展，保留其他dirty work。

## 玩法讨论检索 · 待本轮重新确认

2026-11-13用户要求查Codex聊天并重新确认玩法。已从本地只读聊天数据库找回旧目录“挂机增量游戏”下《讨论游戏理念与设计调整》（thread `01a08f3e-85e8-7923-87d3-4c8a302ed42e`，重点2026-09-11、09-13用户原话）；09-13连续纠偏了早期劳动/筑基神识、设施储灵、点击与角色工作、自动化、物流和联机归属。另09-20 thread `01a0b742-1891-7982-90c7-a036c406ada6` 的用户消息 `01a0bdb1-aaea-7b21-905b-bad4b7ab21ac` 明确三场景：沙盒识海庭院、村子、程序生成探索。

来源为 `~/.codex/thread_history_1.sqlite` 的用户消息，旧JSONL有些已不存在；目录关联见 `~/.codex/state_5.sqlite`。这只是本轮确认的历史依据，不自动恢复已放弃要求、旧计划或二阶段实现，不把当前残留玩法代码视为设计定稿。下一次以用户本轮确认更新口径。

## 最新优化 · 云海远山分层

2026-11-13继续推进非水体优化。本轮落实background_renderer与共享sky_surface：远山/四层远云/背景天空半宽半高HDR渲染并从主天空背景通道合成；近两层岛腰云、庭院、岩壁与主天空环境光数学保持，主后处理只一次。内部像素启用270万/停用230万滞回，1080p绕过；原生画质、排序不安全/扩建越界时回原路径。首帧和resize暖帧，逐帧同步镜头/色光，最小化停止子视口，释放恢复材质/层。

- 最终M4Pro/Godot4.7.2可见验证窗口、真实2K/4K目标、正常水/昼夜、3秒预热+8秒采样ABBA；每条实际绘制帧数=循环帧数。2K53.97→58.01FPS(+7.5%)、P9519.59→18.45ms；4K27.39→29.52(+7.8%)、P9538.17→35.51ms。早期窗口遮挡下循环FPS虚高样本排除。目标Air/Windows及温度功耗未测，原生4K仍慢，非大量可见内容扩容验证。
- `art/lookdev/20261113_background_foliage/compare.html`：32张实拍/16对原生2K，四布局正反近景及主布局低角/高处/日夜/黄昏；机位、水、相位、色光元数据匹配。全图平均差0.0098–0.0556/255，主布局三处岩壁内部+地面抽查最大1/255。远景无限深度/降采样会轻微改变远景景深及极少边缘，4242反向瀑布边缘局部最大88/255，非全图无损/用户美术验收。
- 植被early-alpha和完全属性顶点复用原型22项通过，但没有可靠提速证据，未动生产植被；全屏不透明合成面亦未采用。原型16机位首/次帧无额外整帧延迟；生产原生23项覆盖首次取消、活动resize、同帧镜头/色光、暂停/恢复、native/低分辨率/扩建回退及释放清理。
- 34组适用回归通过(28headless+6native)，正常入口90帧无错误；独立只读审查无Critical/Important，覆盖建议已补齐。本轮Godot运行/测试均退出，仅留原编辑器29442。来源、最小patch、最终hash、原始采样及边界见包内README/checks；保留其他dirty work。

## 最新优化 · 非水体天空光照更新调度

2026-11-13用户要求优化范围扩到水以外。已测试岩壁噪声复用、云海计算重排和稳定材质去过渡discard，正常循环无可靠收益，均未改生产shader。仅落实time_solar_system.gd天空辐射贴图调度：普通昼夜用同质量INCREMENTAL分帧过滤，初始化/手动预设等仍QUALITY并保护至少一个渲染帧，色光参数/材质/几何/采样与分辨率不改；新增sky_update_test。

- M4Pro/Godot4.7.2正常实时循环、固定真实像素、3秒预热+8秒采样、ABBA：2K56.71→57.55FPS，P95 20.34→18.27ms；4K28.24→28.63FPS，P95 37.99→36.10ms；4K输出/1080p3D67.64→68.36FPS，P95 17.35→15.78ms。平均增幅约1–1.5%，主要减慢帧1.6–2.1ms；原生4K仍慢，目标Air/Windows及功耗温度未测。早期临时force_draw探针漂移大，不作收益证据。
- `art/lookdev/20261113_render_work/compare.html`：30张原生2K/15对，四布局正反近景及低角/夜/黄昏，固定机位/水/相位/色光，QUALITY对INCREMENTAL稳定输出15对逐像素相同。另168帧640×360双世界慢速昼夜与三次手动切换，160×90连续颜色统计及18个完整640关键帧最大差均1/255；已检查整体，未推断用户已美术验收。
- 调度8项RED2→GREEN0；33组适用回归通过(28headless+5native)，旧二阶段人物测试仍按已知不适用排除。独立审查无Important；全局frames_drawn不保证独立隐藏SubViewport已绘制，当前唯一正常入口适用，多视口需另做完成跟踪。普通入口90帧通过，本轮进程均退出，仅留原编辑器。证据/起点/最小patch/边界见包内README及checks；不整体回滚其他dirty工作。

## 最新优化 · 水更新数据布局与扩建成本

2026-11-13用户批准借鉴讨论中的连续数组、减少复制、局部工作。仅改water_flow/water_renderer两份生产脚本，新增water_scaling_test；唯一场景、岩壁几何/材质/色泽/光照与渲染质量参数保持。

- 水流热循环用Float64连续缓冲、预计算邻接和湿格/接收格工作集；row-major索引原生排序保留原数值顺序。仅全部有效水头非正时休眠，无epsilon弃水/降频；作者输入版本/seed变更时才替换只读快照。普通发布只写变化水量，干地底图复用后补湿格和outgoing格。
- M4Pro/Godot4.7.2 headless ABBA，同一流水区、只增加独立干地区域：623/2492/9968总格数，完成40次水更新807.38→720.24 /1334.13→788.82 /3397.72→1064.62ms，少10.8%/40.9%/68.7%；最终水量/外排量精确相同。不是16倍可见内容或全岛PCG性能。原型小岛求解慢13%的排序问题已定位修复，最终100步874.81→833.34ms。
- 正常实时渲染、固定像素、3秒预热+8秒采样、ABBA：原生2K56.83→56.85FPS、4K28.25→28.25、4K输出/1080p内部3D68.03→67.91，波动内持平。当前GPU固定画面成本仍在，不称整场景FPS/温度功耗改善，目标Air/Windows轻薄本仍未测。初次拓扑/快照、显式编辑同步及地形轮廓仍有全岛工作，水盆整理随湿区增长，全幅场图像/上传仍随覆盖面积增长。
- `art/lookdev/20261113_water_scaling/compare.html`：28张实际Godot原生2K/14对，四布局正反近景及主布局低角/夜景，机位/数据/光照/相位匹配；11对逐像素相同，3对各9像素微差最大5/255，已检查整体，非用户美术验收。12case/30step共4560项水状态、网格/元数据/场图逐值/字节一致；32组适用回归通过(28headless+4native)，旧二阶段人物测试按已知不适用排除。独立审查的微量下溢错误睡眠和非法原始水量写回已RED→GREEN修复复核，无剩余Important问题。
- 所有对照/原始数据/起点源码/最小patch/计划与边界在该包README及checks；不整体回滚其他dirty工作。测试/采图/性能运行自退出，结束保留用户原编辑器，普通入口复核见normal_entry.log。

## 最新性能要求 · 扩建余量与岩壁保护

2026-11-12用户追问后续岛屿扩建、内容增加时的真实性能方案。当前岩壁状态必须保住，尤其色泽、明暗与光影；不能将默认小岛FPS提升视作扩建承载能力已验证。须区分固定画面成本、随全岛规模增长的更新成本和编辑重建卡顿，并通过扩容压力场景验证。11月13日已落实上节水路径，其他架构调整仍未实施，未推断用户已美术验收。

## 最新优化 · 天空方向数学与后处理

2026-11-12继续优化FPS，仅四个天空相关shader、preview_quality和采图工具改动；承接上轮草14面远LOD、2×MSAA、4096阴影，不换默认资产、不扩展玩法。

- 天空/云海/远山直接从非零视线求高度、太阳角距和暖侧权重，减少角度往返；颜色/HDR/雾常数保持。精确极点回旧路径，保留signed-zero及1.57夹角行为。日夜球面/极点GPU测试4项，采样8bit像素差0，先RED后GREEN；不代表所有浮点输入的形式证明。
- 默认AO只改半尺寸，景深只改VeryLow采样；强度/范围/模糊次数/jitter、SSIL及云细节保留。原生开关按ProjectSettings恢复原AO/景深采样，既有MSAA/阴影恢复、动态分辨率、壁纸30FPS与最小化暂停保留。
- M4Pro/Godot4.7.2、正常渲染循环、真实水/光照、固定机位与像素、关闭限帧/VSync，3秒预热+8秒采样：2K51.87→57.51FPS（+10.9%），4K25.49→28.62（+12.3%）；4K输出固定1080p内部3D64.05→68.66（+7.2%）。固定状态AB/BA复采支持收益；目标轻薄本/Air、温度功耗未测，全像素4K仍慢。
- 对照 `art/lookdev/20261112_fps_shaders/compare.html`：36张/18对Godot实拍，28张原生2K覆盖四布局/多角/日夜，8张4K含全像素和1080p内部3D。相机/数据/水/光照/相位/scale匹配；整体接近，FSR近景存在局部采样差异，不称全画面无损或用户已验收。源码与采样设置有hash/元数据。
- 31组适用回归通过（27headless+4原生），旧二阶段人物测试按已知不适用排除。只读审查无重要问题，非零前提和signed-zero建议已补齐。早期variants.log的TIME冻结正则中间问题已修正，最终用variants_final.log/variants.json及runtime数据。
- 普通入口90帧通过，本轮运行/采图/测试自退出，结束只留原编辑器，无调试窗口。重运行唯一场景加载；回退仅用本轮快照/patch，不整体回滚其他dirty work或候选资产。

## 最新资产库 · Tripo预算批次

2026-11-12用户授权15000积分预算上限，需求/风格统一优先，复杂模型用多视角，重复操作必须脚本化。本轮30份真实白模已下载并保留全部原始/参数；24份三档几何技术通过，6份问题版保留，不等于美术验收。旧批次230点另计。新台账budget.json确认界面报价1030、3项各10未取得有效贴图保守占额，累计1060/15000，无重复付费提交；未推断退款。

- 精选13套已配色候选：双坡山居v02、方亭v02、院门、短廊、松、厚冠柳v02、圆岸石、玉簪、木凳、石桌、石凳v02、陶盆、石灯。三档总40816/18168/5986面，单材质、运行512/1024；原始2K保留。各档实回导和91张实际Godot单体图完成。石板/竹篱/厚圆灌木贴图只回到白模，三笔ambiguous全额占额，不自动重提。
- 实际审阅art/lookdev/20261112_style_library/compare.html（临时庭院10张原生2K、五机位前后严格匹配）及review.html（13套单体/源文件）。山居/门/凳/灯/玉簪/盆6个独立组件均通过权威地形干地支撑；地形、水、镜头、光照和共同生产源码哈希一致。唯一入口和默认庭院没有替换，旧屋未恢复，二阶段未启动。
- 原始与输入在art/source/style_library_20261112；候选assets/candidates/style_library_20261112。三档共享一个材质/贴图的可选godot_runtime组件已编译重载验证；石灯用godot_runtime_v02。共同custom AABB消除毫米级切换缺口，原生精确等距的零厚度双绘如实保留。目标Windows轻薄本/MacBookAir帧率仍未测。
- tools/tripo/studio_batch.py/budget_ledger.py/studio_texture_batch.py负责独占profile、上传等待、源GLB身份/源SHA、实际quote和单次reserve/click。贴图更新原卡时间而非新增卡；收集用已核验项目permalink，发布前核世界三角面等价与真实底图/UV。未来异步submit-only增加可见扣分回执等待，未确认即停、保留预算；不是点击后立即导航。
- tools/art/prepare_style_materials.py→process_style_library.py→process_textured_library_batch.py自动缩图/哑光/三LOD/UV保留焊接；compile_style_library_runtime.gd生成共享资源。Blender5.2重复设置colorspace会重建GENERATED图使尺寸回退，缩图后不再赋colorspace。UV seam拆点需显式焊几何但保loopUV，未填洞。相关Python53项、共享资源重载/篡改拒绝和原生采图通过；技术通过不代表风格已获用户认可。

- 交付：Downloads/scroll_style_library_20261112/ 与同名zip（约161MiB），521个复制文件SHA一致、ZIP与离线链接复核通过；精简包包含13精选，完整30份探索仍在项目内。所有本轮生成/采图/处理watch均已退出，未操作用户原编辑器。

## 前轮优化 · 草远景精度与实际FPS

2026-11-12用户允许从模型精度等角度继续优化，整体观感不明显下降。本轮仅改grass_field/preview_quality/runtime_power三个生产脚本及正式采图工具，保留岩壁、材质、光照参数、植被数量与所有资产。

- 草近景96面/中档与顶点法线色UV不变，最远LOD每簇28→14面，保留7叶外沿/根尖，去内部截面脊。默认2×MSAA、4096方向阴影；“原生画质”恢复原MSAA（4×）与8192阴影。2K以下像素不降；保留原4K动态预算、30FPS壁纸/60FPS交互与最小化暂停。
- M4Pro、Godot4.7.2、正常渲染循环、真实水/光照、固定BASE_A、关闭限帧/VSync，3秒预热+8秒采样：原生像素2K41.08→51.67FPS（+25.8%），4K21.51→25.56（+18.8%）；4K输出固定1080p内部3D61.44→63.10，收益较小。Windows轻薄本/MacBookAir未测，全像素4K仍慢。普通Window首轮被OS限尺寸的成绩排除，最终固定SubViewport的resolution/texture_size一致。
- ablation表明远山面数多但去掉几乎不提升，因此未减远山；保留SSAO/SSIL、云、石材/灯光。原生2K固定状态绘制约24.5→19.2ms，4K47.2→39.7ms，组合复采支持收益，主要来自MSAA/阴影而非单纯全场减面。
- 对照 `art/lookdev/20261112_fps/compare.html`：28张原生2K/14对，同scene切任务起点/当前设置，四布局正反近景、主seed低角草缘与夜景；相机/光照/数据/水/相位一致。整体接近，细边缘和细阴影有精度取舍，不称无损或用户已验收。正式采图记录实际MSAA/scale/阴影尺寸与质量/功耗源码hash。
- 修复前轮功耗逻辑把headless虚拟Window.mode=MINIMIZED误当真实最小化，导致输入停处理的边界；新断言先RED后GREEN。30组现阶段完整回归通过（27headless+3原生），含quality12/power16/草LOD4/淹水20/草恢复8；旧二阶段人物测试按已知不适用排除。独立审查无重要问题，证据追溯建议已落实。
- 所有本轮调试/采样/测试进程自退出，结束保留原编辑器，无运行窗口。重运行唯一场景加载。回退只看包内任务起点快照和小范围patch，不整体回滚其他dirty work。

## 最新实现 · 岩壁形态多样性

2026-11-12用户要求打散岛背面重复竖柱。本轮仅改生产procedural_shard.gd：八槽位保留三种斜脊，五种改为宽板、斜肩、双折肩、低岩肩、收腰，连续实体断面配统一仿射斜切。原根岩走varied=false保持原网格/法线/色/UV；顶冠/collar/cap、摆放/权威地形/自然物/材质/光照均不改。

- 最新审阅 `art/lookdev/20261112_cliff_variety/compare.html`。before为任务起点5张，final与held2104/4242/913共28张最终原生2K，含正反面与两侧角度；默认5对相机/光照/数据完全一致，保护源码哈希一致，仅shard变化。candidate/refined/pre_collar_*均为中间诊断。
- 新形体49、原冠/根岩保护16与共享接点/封壁/内部编辑60/瀑口/局部稳定/场景/草唇/草接触共10组通过。独立审查发现首肩环上穿collar，新增有向边检查先5失败，统一主体下移.03后49/49，复核关闭。
- 变化可见但局部深色接缝、既有薄尖轮廓仍在，结果待用户美术验收；未测目标设备性能。重运行唯一场景加载，不操作用户旧窗口或布局。任务起点/最终源码与本轮patch在checks，保留其他dirty work。采图及测试均已自退出。

## 最新优化 · 壁纸常驻负载与水更新

2026-11-11—12用户要求与岩壁agent并行做性能，尽量保画质并结束关调试窗口。本轮仅五个生产文件editor/runtime_power/preview_quality/water_renderer/grass_recovery，保留并行岩壁修复；无材质、光照、物理水量求解器或玩法扩展。

- 编辑上限60FPS；静置F11壁纸30，镜头输入后60保持2秒。最小化暂停场景，只5Hz监控，恢复续行；失焦但可见仍动画。退出还原原限帧。30FPS是时间采样取舍，静帧空间画质保留。
- 水轮廓/三角化精确按可见格集合缓存，共享法线仅归一化一次；完全相同的床面/水状态跳过资源发布。草恢复复用未变边界。动态分辨率排除限帧等待、清掉模式切换旧样本，稳定达到上限后每5秒小幅试探恢复清晰度。
- M4Pro原生720p实时壁纸、关闭VSync，3秒预热+8秒采样：91.05→30FPS，进程CPU按单核45.09%→34.11%；最小化0.49%，恢复场景/30FPS通过。是进程CPU实测，非整机功耗或温度。固定100步水更新完整CPU路径preset0/1约少6%/9%，无水约少50%，水量与外排逐值相同。
- 原生2K不限帧显式绘制34.58→34.24ms、4K64.89→65.77ms，持平；GPU侧仍慢，不称原生4K60FPS，Windows轻薄本/MacBookAir未测。保留此前4K动态3D预算。
- `art/lookdev/20261111_performance/compare.html`：20张原生2K、四布局正反及主seed近景/日夜，10组前后逐像素一致；同一live scene只切本轮水算法，岩壁等共用当前版本。1360项网格/法线/UV/贴图字节相同，29组首阶段相关回归通过。旧gameplay_m1_m2因已移除人物报错/超时单列。独立审查两项画质恢复/采样问题已补测修复，新法线/隐藏暂停无重要问题。功能通过不扩大美术验收。
- 所有本轮运行/采图/测试进程已自退出。最终检查另有岩壁agent活跃的cliff_variety采图/测试进程，未中断，需其结束后自行关闭；原Godot编辑器保留。重新运行唯一入口加载修改。完整数据、范围差异和边界见包内README及checks/final_validation.json。

## 最新资产探索 · 新 Tripo 书斋与石水钵

2026-11-12用户明确要求结合此前策划/概念设计开始新Tripo建模，授权使用充裕额度，候选暂不删除，并强调性能。此最新授权覆盖旧的暂停生成/批次额度限制；沿视觉资产目标安排后续批次，不因付费重复询问。仍未启动第二阶段玩法。

- 已真实生成3个白模：石钵P2.0、书斋A P2.0、同四向输入的书斋B v3.1。界面标价100+100+30=230点。原始GLB、imagegen参考/完整prompt、manifest、日志、尝试标记和Blender源均保留于art/source/courtyard_20261112。旧屋没有恢复，新候选未替换默认庭院。
- 主要候选：assets/candidates/courtyard_20261112/mountain_study_hq，三档8508/3988/1196三角面，约6.2×4.56×3.90m；stone_basin为1494/598/238面、直径约1.1m。均单surface/材质、0纹理。原始书斋B有一片异常底座三角片，独立修整后各档开放边/非流形边/退化面/游离点均0；原始未改。
- 书斋A格栅较清楚但有2394开放边界与局部缺面，保留比较，正确尺寸产物为mountain_study_v02；mountain_study为错误方向/归一化中间稿，不作为交付。A最低档导出1196、Godot导入1194。B较闭合但门窗、瓦面、柱脚偏软，仍待精修。不是美术验收。
- Godot默认导入未自动使用GLB顶点色，使用粗配色需绑定共享palette_vertex.tres；配色只分几何高度，未做木构分色/正式UV贴图。LOD文件已生成，未接入距离切换/碰撞/交互。
- Downloads镜像scroll_tripo_candidates_20261112/及同名zip（34.58MiB）含原始/源文件/参数/三档LOD；art/lookdev/20261112_tripo_candidates/review.html为最终审阅入口，final/24张实际Godot单体输出，书斋A/B五机位严格匹配。根目录图是早期材质诊断，不当最终。9个LOD实际导入渲染，未改唯一入口，也未做完整庭院构图验收；目标硬件FPS未测。
- 高精度新版UI缺少P2.0数量控件，旧通用helper dry-run已停止，没付费；任务内generate_hq.py复用原pipeline，显式关闭默认开启的贴图生成、验证10000面后单次提交。P2.0仍直接用tools/tripo/studio_generate.py。不用个人浏览器profile，不重提模糊任务。

## 最新修复 · 岩壁共享接点与局部漏补壁

2026-11-11用户要求核查使用体验并集中修岩壁。本轮仅改block_mantle.gd、contour_terrain.gd，保护认可材质/光照与独立自然物。

- 背衬按各面第一顶点高度内缩，拆开共享接点；改用共享组最低cap。真实初始/降低/抬高分裂点8/8/14→0/0/0。新28项含接收面边界，旧11失败→0。
- 干台阶封口只查整段中点，半段暴露却因中点被冠覆盖而跳过；改按冠边交点拆段，对未覆盖区间复查接收面再补。三种子24条严格距离射线，旧16失败→0。斜角原生实拍凹窗已补上；薄尖轮廓/源岩块搭接和偏直补壁仍存在，不宣称全部岩壁问题清零。
- 对照art/lookdev/20261111_cliff_repair/compare.html，最终final_junctions为9对18张原生2K；final_whole为5机位最终生产实拍。相机/光照逐项匹配，同live scene仅切两处任务起点逻辑；源码哈希匹配。junctions/after/edit_after为中间诊断，勿当最终。
- 本轮编辑体验回归覆盖蓝图/取消/异步/松手反馈/落笔平面/镜头/撤销。没有重测帧率或时延，仍按前轮约.7秒真实地形发布、4K依赖动态降分辨率的边界陈述。
- 27组当前适用回归通过（24组headless、3组原生），含新两组专项、内支撑60、瀑口16；详见checks/final_suite.json；原生淹水/草恢复/LOD通过。旧gameplay_m1_m2_test仍要求已删除人物，空引用并超时，单独记录，不是通过项，不恢复二阶段内容。只读审查无重要问题。
- 原整段中点干湿早筛、冠内侧壁遮挡、非重合点/T接边仍为未覆盖边界。功能通过不等于美术验收。重运行唯一场景加载修改。

## 最新实现 · 松手渐变承接地形等待

用户提出用快速渐变特效承接偏慢的地形处理。已复用原有蓝图网格，在editor松手入口立即启动局部青玉渐变流动，新增轻微浮升、移除浮散。约.35s开场后持续流动，真实地形显现到65%时约.18s淡出，与原.55s地形动画重叠。取消下一笔、撤销均按当前权威地形更新反馈。

- 三个生产文件为editor.gd、edit_preview.gd和对应shader，等待期间复用代理网格。新回归19项，另有蓝图/异步/过渡/runtime/落笔平面/控制/scene/argon，共9组本轮检查通过。
- M4Pro原生2K、固定机位、生产松手入口、无截图写盘实测，四案例首帧完成绘制14.14–28.59ms，松手回调.10–6.99ms。短点真实地形发布709.97–753.03ms，完整过渡约1.26–1.30s；长按已预建约6.86ms发布。反馈最近一次构建.74–.83ms，松手复用已绘制蓝图。此变化改善等待反馈，原生4K偏慢仍待优化。
- 最新包 `art/lookdev/20261111_edit_release/compare.html`，Downloads为 `scroll_edit_release_20261111/`。20张原生2K关键帧、两段左右同步原生帧拼接动图。旧/新反馈同机位同数据，统一在.70s发布用于观察交接；独立真实时延见latency.json。其余shader相位1.25，预览时钟每步.05s推进。
- 旧效果以本轮开始时的preview脚本/shader加载，附仅刷新蓝图的commit适配。当前源码校验通过。临时遮罩仍有较直边界，观感待用户体验；比较页离线检查。重新运行唯一场景入口加载本轮修改。

## 前轮修正 · 通用落笔高度、草渐变与4K响应

用户纠正“对齐”为全部地面编辑共用鼠标起点高度，随后要求淹水渐隐、退水从周围草坪蔓延恢复，以及进一步改善4K帧率。最新包 `art/lookdev/20261111_editor_response/compare.html`，Downloads为 `scroll_editor_response_20261111/`。16张原生关键帧、两段原生帧序列动画。重新运行唯一场景入口加载本轮修改。

- 撤回上轮“齐平”，工具栏六项。地面工具拾取权威height map实际顶面，整笔锁定起点示意平面，扩张新增沿该高度接续。水下取床面，高侧墙起笔保留顶部归属偏移。已有高台内部可起笔取高再向外拖。原生输入3.5m取高、三格扩张均3.5m，蓝图/取消/提交/一次撤销保留。
- 新grass_recovery独立视觉覆盖度，水到对应格后约.65s渐隐缩短，草叶/草唇/地表同步。退水沿相邻干草传播，每格约.85s，深坑也可由高处邻草恢复，再淹中断。全岛无草源时选择外边界干燥3s后重播再向内传播。物理水量独立；原生像素8项和逻辑11项通过，完整恢复轮廓一致。
- 4K默认按运行耗时动态在1080p–2K内部三维间调节，UI/输出仍4K，FSR1+2xMSAA；2K以下原生。菜单“原生画质”恢复scale1/4xMSAA。HUD改显示状态变化时重绘，弧进度按1/256更新，采样120帧重绘120→13。云层仅裁去零透明区域。
- Apple M4Pro实际运行、悬停与水流开启，4K流畅预览均值33.80→22.48ms，p50 17.73、p95 35.33ms，均已落到1080p内部三维。全原生4K运行均值92.90ms仍偏慢，当前慢帧尚存。旧约47ms为冻结场景、不同负载；GPU计时不可用。两次运行结束水量受实际经过时间影响有差异。目标硬件约60FPS未测。
- 24组最终回归通过，输入15、动态画质10、runtime22、内部支撑60、原生草渐变8/淹水20/LOD4及原有蓝图/水量/场景。最终源码哈希与16帧一致。草动画按生产视觉时钟.05s推进，物理水冻结，恢复演示用既有退水工具；区别于实时性能测量。当前右侧坑地仍有较直台阶接缝，功能通过不等于视觉验收。
- 当前认可岩材质受保护。性能烘焙草信号及sky模式试验收益不足，已撤回生产改动，仅保留诊断记录。比较页离线检查，浏览器交互待打开确认。

## 前轮修复 · 4K、淹水与编辑裂痕

2026-11-10用户最新：4K巨卡；沉降水下仍有草；地面难对齐且出现裂痕。最新审阅包 `art/lookdev/20261110_editor_stability/compare.html`，Downloads `scroll_editor_stability_20261110/`。28张当前原生帧，早期诊断不作为最终效果。未操作用户旧窗口或未保存布局，需重新运行加载。

- 预览默认2K三维像素预算，高分辨率窗口UI仍原生，FSR1空间放大+2xMSAA。卷菜单“原生画质”恢复scale1与原有4xMSAA，2K以下保持原生。草簇增加远景真实几何LOD，完整近景顶点/法线/色彩保持。固定BASE_A开发机原生2K38.48→24.66ms、原生4K63.11→46.94ms、4K流畅预览23.76ms。显式整帧绘制均值，Metal GPU计时不可用；不声称目标硬件/原生4K60FPS。
- 水下草材质统一按实时R绝对水面与实际根高判断，G只确认有水。ground改用既有湿泥石底材，草唇/主草整叶收束丢弃，退水恢复；高台邻水干草保留。根点2mm干唇边界和倾斜MultiMesh原生像素20/20；物理有限水量求解器不变。
- 裂痕终态复现为内台阶源柱的无冠覆盖侧背墙，不是过渡/脏chunk。裁退不安全内柱及关联脚石，缺少源冠包覆的干高低台阶合并连续cliff壁。初始三种子30柱→25，5根均内部step，所有外圈种类/位姿逐项相同；初始内部局部外观改变已实拍。几何采样不等于精确布尔，不保证任意极端布局绝无接缝。
- 当时曾新增“齐平”，已于2026-11-11按用户纠偏撤回，当前全部地面笔刷共用落笔平面。默认贴格与卷菜单贴格开关保留，升降/撤销保当前水量。
- 22组最终检查通过（原17加内部编辑60、齐平9、预览画质7、原生淹水20、草LOD4）；内部几何含460向下/672水平支撑射线，三种子连续/深降/凹坑连边/撤销。退水首轮2条旧绝对几何hash因有意内柱回退失效，改湿/干两状态草顶/岩块不变量后16/16，物理出口保护保留，独立补审通过，首轮失败日志保留。
- 当前原生松手→发布：短点662–785ms，长按预建完成约10ms，拖动628–918ms；之后约.55s过渡，仍非瞬时。本轮保护认可岩面主材质/光照/远景，不再雾化。before/after分材质或几何在同一live scene内切换，共用其他当前内容，6组机位/数据/水量完全匹配，具体来源见README。浏览器file协议未绕过，比较页仅离线校验。

## 最新实现 · 蓝图编辑与守恒水流

2026-11-10用户当前任务：编辑不卡顿、松手提交蓝图、右键取消/无效红框、增删升降淡出、旧远端岩形稳定、自然有限水量与瀑布水花。原goal已清除，不自动重建；本轮水量局部功能为用户明确授权，无其他玩法扩展。

- 生产唯一入口仍terrain_editor.tscn。editor左拖只写独立draft，release原子提交为一次undo；右键/Escape/失焦取消，不能操作红色，降低草稿在原顶面可见。绘制期间后台预构建，松手直接采用最新匹配结果；过期任务提前停止，不发布过期staging/worker。取消后重置/退出清理错误已独立复验修复。
- 增删旧/新网格用互补覆盖升降，.55s完成，旧网格不瞬消。局部chunk复用，稳定现有轮廓分段，seed7301/2104/4242远端岩块位姿15项通过。保留远端网格不保证与全岛重建草面三角划分逐顶点相同。
- water_flow有限体积连续水深，同池摊平、依出口落差传入下池或计入外排，无自然补水。water_renderer独立后台水网格，每次最多.1s，排队最多.3s；编辑待发布时暂停水收集。保存flush，加载/预设reset。抬桥时原水量分给直接相邻湿连通分区；bed undo/redo保留当下水量，不把历史水量补回。
- 瀑布单层玉色流水、真实run一致落向保持口宽，断续下行反光与落点小水滴；流弱时淡去。已修复邻近transfer错误挂在本池侧墙形成分离窄条。旧湿壁封口仍通过。中段仍偏平、底缘较齐，美术结果待用户验收。
- 原生M4Pro松手→发布实测：长按预先完成约6–11ms，短点约688–751ms，持续拖约897–990ms；阔笔3.8短点约799ms/拖动约971ms；实际显示另加约一帧。过渡再用约.55s。当前短点/拖动仍有等待，不能称瞬时；未证明目标Windows轻薄本/MacBookAir60FPS。
- 水量原生演进：初始71，60s后留存38.769166807、外排32.230833193，总量误差<1e-10，地形床面不变。静帧加速离线采样，非实时录像。常规实拍先真实流动.1s再冻结做同机位比较。
- 最新包 art/lookdev/20261110_interaction_water/，最终final_day/final_night与held2104/4242/913；interaction_ready为最新生产输入与过渡阶段，controls_review为尺寸/镜头，water_evolution_review为修复后退水。waterfall_before_day仅在同一live scene内恢复旧瀑布几何/材质/雾，不代表本任务所有修改前整工程。02/03/04/05/06为工程内试验与早期候选，不进最终审阅镜像。Downloads审阅镜像scroll_interaction_water_20261110。
- 已有17组最终功能回归全过；包括蓝图13、异步16、过渡8、局部稳定15、入口水集成11、求解92、渲染48、瀑形9、封口16、runtime22、scene7、argon9、草唇24、草接触4、新退水16、控制29、层面锚定12。功能通过不等于美术验收。保护认可石材、光照与远景，人物仍移除。

- 用户后续纠偏已实现：尺寸按钮细/中/阔文字+更大点击区，默认中2.2；光标/侧面归属台阶顶面锁定，整笔锁层，扩张只相连同高地块，收缩/升降不穿到下层。补回孔洞优先同一鼠标平面位置，静止草稿不蔓延；侧面/外沿拾取回归runtime22保留通过。
- 相机右拖在固定半径球面旋转，实际Y随俯仰变化；滚轮才联动距离和19/27/68度俯仰（缩放设置6/21/100），保留显式BASE采集机位。真实控件与固定距离轨道原生检查通过。
- 60s退水发现并修复nominal3.5m岸坡/闭合面悬唇：静态出口局部固定到rawbed3m，未随水位移动旧干岸/岩块。新退水16、旧封口16与固定干草/columns/mass哈希通过。
- 最终F11帧后另有editor.gd指针填洞修正，清屏采集不执行该输入方法；按真实采集源码保留hash，差异在validation.json披露。最终interaction_ready与锚定12覆盖该输入。运行中旧预览需重新运行场景加载修改，未擅自结束用户旧窗口。

## 最新水体调整 · 稍清澈

用户要求水体稍清澈。本次只改water.gdshader三行，吸收系数(2.35,1.12,.98)→(1.78,.84,.76)，近岸倍率.62→.58，倒影.58→.47，折射.012→.009。浅岸透射略增、水色稍轻，收益温和，深水/倒影仍柔化且边缘锯齿可见。结果待用户验收。

art/lookdev/20261110_clearer_water/compare.html，Downloads镜像scroll_clearer_water_20261110。正式实拍仅04_day_pair、05_night_pair，共16张2K。较早分次采集遇到contour/rim_union同步更新，正式改为同一场景实例内在内存切换两版水材质，每图water_shader_snapshot_sha256标识实际材质来源。8组前后相机/光照/相位完全相等，场景数据与采集期磁盘源码检查通过。场景回归7/7，图形采集无着色器错误。新近景为池水诊断角，whole/reverse仍为BASE_A/D。此次未操作运行中的用户窗口。

## 最新修复 · 瀑口空腔

用户于2026-11-10指出瀑布右侧草台下有明显空腔。已在斜角65°近景复现，上一轮常规机位漏检。

- 根因有两处。block_mantle.gd将台阶背衬统一沿共享法线内缩0.68m，底脚脱离下层水岸并可下沉；contour_terrain.gd湿岩避让水帘的距离又延续到接收水面端点。射线会穿到远端岛底。
- 已让背衬内缩在下层支撑高度附近归零，内瀑湿壁的避让也在下层端点归零。仅这两个生产文件有本轮改动。当前代码对应20261110_waterfall_cavity/03_fixed_day与04_fixed_night。
- 同机位日夜、正面与左右斜角实拍确认空腔及底缝闭合。2104、4242各两角度复核通过。4种子封口射线16/16、场景7/7、运行22/22、argon9/9、瀑布348/348通过。先RED12/12，再残留底缝RED4/16，最后GREEN16/16。
- 最新对照 art/lookdev/20261110_waterfall_cavity/compare.html，Downloads为scroll_sol61_waterfall_cavity_20261110。19张原生2K保留帧，44文件镜像。01_before_detail为修复前，03_fixed_day为修复后。诊断角度目测匹配用户图，whole仍为BASE_A。前后全部相机/灯光元数据与权威data哈希相同。
- 先前polish包中的06_final仍保留原始漏洞证据，最新状态请看空腔修复包。旧包不覆盖。岩面折线、台阶接缝、水面反射锯齿仍可见。
- runtime测试初次被测试目录写入限制中断，正常权限重跑22/22。受限的两个遗留测试进程已核对PID结束。普通入口已用官方Godot启动；电脑控制工具超时，未确认新运行窗口的可见/F11状态。生产F11由本轮19张原生采集验证，场景入口测试通过。project.godot无临时采集参数。

## 已认可基线与前一轮精修

用户认可 `20261109_sol61_build/rock_readability_day/night` 的整体质感；此前明确偏好累计岩面对照左侧final，已撤回shadow_bias=.35与stone_albedo_gain=.80。后续必须保住这版岩面清晰度，不能靠去纹、柔化或全局光雾替代材质/接合质量。

最新请求为五项精修：草石交界、减少岩壁重复、岩底、瀑布、石板路奇怪阴影。本轮已完成可保留候选与证据，**五项新结果待用户美术验收**，不宣称完全达到TARGET。

## 查看与交付

- 最新包 `art/lookdev/20261110_sol61_polish/`，入口 `compare.html`，可切五类缺陷与全景/草石近景/道路近景/反向/夜景。当前 `06_final_day/night`，壁纸A–D在wallpapers。
- Downloads：`~/Downloads/scroll_sol61_polish_20261110/`，184文件逐项SHA256一致。55张保留原生2K帧（含10张认可基线、25张逐类日景、5张最终夜景、15张保留种子）；4壁纸为最终原图字节复制。失败试验实拍仅留工程，未进入审阅镜像。
- 旧认可包 `art/lookdev/20261109_sol61_build/` 与其Downloads镜像301文件保持原样，可作为完整历史回退；不要覆盖旧截图或整体git回滚。
- 唯一入口 `scenes/terrain_editor.tscn`。临时采集参数已清空，项目重载后已正常启动、实按F11，确认HUD/画笔/人物缺席、提示消退。普通预览1278×719，验收图另为原生2560×1440。运行窗口保留。

## 本轮保留变化

1. `01_planted_junction_day`：grass_lip_soften外沿更圆厚、宽窄不齐；ground shader窄根土暖且断续，y=0顶冠不变，无宽蓝灰脏带。收益温和。
2. `02_path_contact_day`：cliff_rock shader仅prop_kind=2路径侧壁，将预染深蓝改为同源米灰，保留真实投影/AO/触地/网格。蓝黑描边明显减轻。
3. `03_cliff_rhythm_day`：procedural_shard八岩型的RIDGE/SLANT/FOLD/TILT/CREST方向、高度、宽窄更错落。原顶冠、主岩材质/法线/光照保持，正反向清晰度保住。
4. `04_planar_roots_day`：只通过原ROOT_FOLD平面方程收束下段前脊，保留侧背完整包壳与闭合；收益温和。全脚内缩、新增heel环及任意脚点偏移均未采用，分别会露壳/成薄片/扭折大面。共面回归先RED8/24，修正后GREEN24/24。
5. `06_final_day/night`：contour瀑口卷唇、真实落差alpha编码；waterfall shader与mist按完整落差对齐消隐/喷雾。加厚core、外瀑去screen注入与致密水体减轻湿岩剪影矩形透底；恢复细银白流纹，避免中间试验的青色厚帘退化。玉色池面主体未改。

四份保护源码 terrain_environment.gd、stone_surface.gdshaderinc、stone_normals.gd、time_solar_system.gd与认可基线哈希相同，sun.shadow_bias=.035。无全局色光/雾/曝光微调，无新人物、建筑、玩法或道具架构。

## 证据与边界

- TARGET/BASE沿用 `art/lookdev/20261109_wallpaper_targets_sol61/` 与Downloads参考包，TARGET是生成参考，实拍是Godot输出，不能混用。BASE机位/seed7301/preset0/FOV31锁定；日景progress.29，夜景.00，Forward+、4×MSAA、相位1.25、生产F11。
- 工具 `tools/art/capture_lookdev.gd`，现在采集hash额外含terrain_paths、water_corners、waterfall_mist脚本。工具不读写用户布局，只捕获单场景。五类before/after的所有相机/光照元数据及权威data哈希相同；差异源码严格限定到对应缺陷类。详见checks/capture_audit.json。
- 保留种子2104/preset0、4242/preset1、913/preset2（无水）实拍已抽查whole/B/reverse，未见新孔洞、露壳、遮路；夜景流纹/路径仍可辨。反向岩壁下半部仍较暗。
- 尚有局部草缘齐整、岩壁拼接/薄竖缝与薄尖轮廓、踏石形状偏等距、瀑布水丝略白略齐、外瀑左缘中下段短亮条/小台阶。不要把局部收益夸成完全对齐。
- 场景7、argon9、草唇24、草接触4、岩体几何24、瀑布数据348项通过；日志、源码前后快照、补丁及只读复核在checks。功能通过不等于美术验收；Windows轻薄本/MacBook Air约60FPS仍未实测。
- 对照页通过30种JS视角/类别状态与所有图片/manifest/TARGET链接检查。浏览器工具明确因file:协议策略拒绝预览，未绕过；浏览器交互未实测。

## 不可破坏的约束

仅第一阶段PCG与实际画面；保持单项目单入口、人物/坐垫/旧屋缺席。可见地面共享权威contour/rim_union，保留R0/y=0，树石等自然物独立编辑。argon0「天青烟岚·宋韵青绿」：冷银灰雾、低饱和苔草绿、米灰石、玉水，暖金主光/青空补光、SSIL，太阳方位28–42°。遵循docs/art_direction.md。

保留大量既有dirty work，不整体reset/clean、不重复历史purge，不恢复已删实验/旧计划/旧屋/分支。不碰Thor USB或/mnt/usb_disk1，不递归搜索lead/operations/results/agents，Tripo额度按2026-11-12最新明确授权使用，保留原始与任务参数。
