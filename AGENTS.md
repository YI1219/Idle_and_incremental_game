# Project working constraints

Read `CURRENT_CONTEXT.md` first, then `docs/engine_refactor_plan.md`. The owner's latest explicit requests take precedence.

- Direction (owner, 2026-11-22): a purpose-built runtime is being built in `runtime/` (Rust, wgpu). Do not re-argue staying on Godot. One shared runtime with swappable scene and render layers; the Sea of Consciousness is the first layer; the village and the extraction map join later in the same runtime and are not in the first slice.
- What binds: the locked part-one gameplay (plan 2.7) is the hard constraint. The feel of today's picture is the floor to keep and raise. Earlier code, requirement notes, specifications and pipeline are reference, not rules.
- The Godot project is frozen at tag `godot-freeze-20261122`. It stays runnable (`scenes/terrain_editor.tscn`, Godot 4.7.2) as the picture baseline. No cliff form, surface or gameplay work continues in Godot. Change it only to add export or capture tools the runtime needs, and rerun the 40-case list (`run_suite.py` beside the lookdev packages) if you do.
- First acceptance gate: this Mac (M4 Pro) on its own screen at 3024x1964 and 60 FPS, fallback 1080p at 120 FPS. Windows and thin laptops come later; never claim their performance from this machine. Battery runs are invalid as frame-rate evidence.
- The agent sets and pursues the art goal (plan 3.1). The owner does not judge engine internals: decide, then show pictures and measurements. Only the owner's eye is art acceptance; tests, metrics and the agent's own review are not.
- Git: on 2026-11-22 the owner granted the agent full authority over this repository (commits, tags, branches, pushes, ordinary management). Never discard work without a recoverable tag or backup. `origin` is a public repository: raw model sources (`art/source/`) and candidate assets (`assets/candidates/`) are kept out of pushed history (local tag `godot-freeze-20261122-full`), and lookdev pictures are ignored and stay local.
- GPU and capture work on the Mac goes through `tools/perf/gpu_run.sh` (mains power check, one job at a time, timeout). Send its output to a log file; do not pipe it.
- No paid Tripo or similar. Free assets only, with source and licence recorded in `ATTRIBUTION.md`.
- Report actual runtime or Godot output separately from references and concepts. Do not dump full-resolution stills into a transcript; write files and cite paths.
- Use English with the owner. Update concise current records rather than accumulating contradictory handoffs.
