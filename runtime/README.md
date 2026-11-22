# The purpose-built runtime

Rust, wgpu, winit. The plan is `docs/engine_refactor_plan.md`; the state of the whole project is in `CURRENT_CONTEXT.md`. Godot does not import this folder (`.gdignore`).

## What exists (2026-11-22)

Only phase 1 spikes: throwaway code that answers a question and is not the start of the real crates. Phase 1 is done; its checkpoint is `art/lookdev/20261122_g1/`.

| Spike | Question | Answer |
| --- | --- | --- |
| `spikes/s1_wallpaper` | Can this stack hang a true wallpaper on macOS, stop frames when covered, and idle cheaply? | Yes. Behind the icons, above the system picture; no frames and 0.05% of a core when covered; 3.6% of a core at 30 FPS when visible. Timer pacing puts about one frame in twenty a refresh late; the shell needs display-driven pacing. |
| `spikes/s2_render` | What does the cached-island frame cost at the first gate's resolution? | 1.6 to 1.9 ms on the Moving path and 0.5 ms on the Still path at 3024x1964, with a 4,096-cell island and two more in view, on a stand-in scene. Budgets were 12 ms and 4 ms. |
| `spikes/s34_study` | Which island construction and which look? (S4 and S3) | Hanging rock on a liner; line and flat wash on a warm silk-paper ground. The rim plan is local under edits and a whole 4,096-cell island rebuilds in 172 ms. With four samples per pixel the look costs 5.2 to 8.5 ms a frame at 3024x1964. |

Each spike has a README with what was built, the numbers, and what was not tested.

`data/reference/` holds what was exported from the frozen Godot project: the cells of the four review layouts, the twelve fixed cameras, and traces of the GDScript production simulation (the oracle for the phase 2 port).

Not started: the real crates (`core`, `render_kit`, `layer_sea`, `shell_desktop`, `shell_headless`).

## Working on it

- Build: `cd runtime && cargo build --release`.
- Anything that draws goes through `tools/perf/gpu_run.sh` from the repository root (mains power check, one GPU job at a time, timeout), with its output sent to a log file.
- wgpu is version 30. Its API differs from older examples (instance descriptor constructors, `CurrentSurfaceTexture`, `Queue::present`, optional bind group layouts and vertex buffers, `multiview_mask`). When in doubt read the crate source under `~/.cargo/registry/src/`.
- The Swift script interpreter on this Mac is broken by a toolchain module conflict; small native helpers are written in Rust instead.
- Colours are authored as display values. Write them to a plain 8-bit target, not an sRGB one, or everything comes out brighter and paler than authored.
- Evidence goes in a dated package under `art/lookdev/`. Pictures there are ignored by git.
