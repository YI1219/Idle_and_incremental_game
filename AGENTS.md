# Project working constraints

Read `CURRENT_CONTEXT.md` first. The user's latest explicit requests take precedence.

- Current scope is first-stage PCG and actual Godot visual quality only. No gameplay/content/save/economy/combat/character expansion until the user explicitly starts stage two.
- Keep one project version and one scene entry: `scenes/terrain_editor.tscn`, the historical visual baseline with the old house removed. Do not restore deleted experiments, old plans or archive folders.
- Follow `docs/art_direction.md`. The initial complete courtyard is the composition reference; recent modular experiments were rejected as worse. Reference The Regreening for soft forms, coherent matte/painted surfaces, grouped vegetation and readable paths while retaining ancient-Chinese xianxia direction.
- The old cottage model, its textures and source files were explicitly deleted for replacement. Do not reintroduce it or infer approval of another house from historical screenshots.
- Nature props remain independently editable; visible courtyard land shares authoritative terrain data. Do not add a separate locked decorative ground or bundle tree/rock placement as one tool.
- Keep changes reversible going forward, but the user explicitly authorized this cleanup to delete old files, extra local versions and old Git history, including remote branches. Do not repeat that purge unless newly requested.
- Prefer existing assets. Tripo single-image is suitable for simple props with unimportant backs; use consistent independent views where silhouettes/back views matter. Reuse `tools/tripo`. Inspect geometry before texturing, preserve new originals and task parameters, and never infer further paid batch authorization.
- Report actual Godot output separately from references/concepts. Match seed/camera/resolution/light conditions, inspect several angles and a few held seeds for PCG changes. Functional tests do not establish art acceptance.
- About60FPS on a Windows thin-and-light and MacBook Air remains an unmeasured target. Do not claim target hardware performance from this development machine.
- Use Chinese with the user. Update concise current records rather than accumulating contradictory handoffs.
