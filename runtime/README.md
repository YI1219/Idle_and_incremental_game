# The purpose-built runtime

Rust, wgpu, winit. The plan is `docs/engine_refactor_plan.md`; the state of the whole project is in `CURRENT_CONTEXT.md`. Godot does not import this folder (`.gdignore`).

## What exists (2026-11-22)

Only phase 1 spikes: throwaway code that answers a risk question and is not the start of the real crates.

| Spike | Question | Answer so far |
| --- | --- | --- |
| `spikes/s1_wallpaper` | Can this stack hang a true wallpaper on macOS, stop frames when covered, and idle cheaply? | Yes. Behind the icons, above the system picture; no frames and 0.05% of a core when covered; 3.6% of a core at 30 FPS when visible. Timer pacing puts about one frame in twenty a refresh late; the shell needs display-driven pacing. |
| `spikes/s2_render` | What does the cached-island frame cost at the first gate's resolution? | 1.6 to 1.9 ms on the Moving path and 0.5 ms on the Still path at 3024x1964, with a 4,096-cell island and two more in view, on a stand-in scene. Budgets were 12 ms and 4 ms. |

Each spike has a README with what was built, the numbers, and what was not tested.

Not started: S3 (look study), S4 (generator study), and all the real crates (`core`, `render_kit`, `layer_sea`, `shell_desktop`, `shell_headless`).

## Working on it

- Build: `cd runtime && cargo build --release`.
- Anything that draws goes through `tools/perf/gpu_run.sh` from the repository root (mains power check, one GPU job at a time, timeout), with its output sent to a log file.
- wgpu is version 30. Its API differs from older examples (instance descriptor constructors, `CurrentSurfaceTexture`, `Queue::present`, optional bind group layouts and vertex buffers, `multiview_mask`). When in doubt read the crate source under `~/.cargo/registry/src/`.
- The Swift script interpreter on this Mac is broken by a toolchain module conflict; small native helpers are written in Rust instead.
- Evidence goes in a dated package under `art/lookdev/`. Pictures there are ignored by git.
