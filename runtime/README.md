# The purpose-built runtime

Rust, wgpu, winit. The plan is `docs/engine_refactor_plan.md`; the state of the whole project is in `CURRENT_CONTEXT.md`. Godot does not import this folder (`.gdignore`).

## What exists (2026-11-24)

Only phase 1 spikes: throwaway code that answers a question and is not the start of the real crates. Phase 1 is done; its checkpoint is `art/lookdev/20261122_g1/`. The owner reviewed G1 on 2026-11-23, kept the hanging-rock body and rejected look B; the study tool was rebuilt toward the natural look of the Godot baseline. The owner reviewed that package the same day and asked for four adjustments (close a hollow terrace joint, make slopes and ramps buildable, align rock walls with the Godot baseline, clearer water); they are made and await the owner's second review: `art/lookdev/20261123_natural/` (`README.md`, `compare.html`, second review set in `final2/`). Phase 2 has not started.

| Spike | Question | Answer |
| --- | --- | --- |
| `spikes/s1_wallpaper` | Can this stack hang a true wallpaper on macOS, stop frames when covered, and idle cheaply? | Yes. Behind the icons, above the system picture; no frames and 0.05% of a core when covered; 3.6% of a core at 30 FPS when visible. Timer pacing puts about one frame in twenty a refresh late; the shell needs display-driven pacing. |
| `spikes/s2_render` | What does the cached-island frame cost at the first gate's resolution? | 1.6 to 1.9 ms on the Moving path and 0.5 ms on the Still path at 3024x1964, with a 4,096-cell island and two more in view, on a stand-in scene. Budgets were 12 ms and 4 ms. |
| `spikes/s34_study` | Which island construction and which look? (S4 and S3) | Hanging rock on a liner (kept by the owner). The G1 look (line and flat wash) was rejected; the tool now draws the natural look: Godot's trees, props, lawn, stone painting and far field ported, lit in linear light; rim pieces after the Godot cliff (tall faces, buttress slabs); clear ponds over a visible bed; slope cells and the ramp stroke (cell layout version 2). With the camera moving it costs 5.6 to 7.7 ms a frame for one island, with or without ramps, and 10.8 to 11.2 ms for a 4,096-cell island at 3024x1964 (idle machine, round 9). The rim plan and the top surface are local under edits, ramps included; a 4,096-cell island builds in 290 ms with props and grass (measured on a busy machine in the second review set; 246 ms idle before the ramp work). |

Each spike has a README with what was built, the numbers, and what was not tested.

`data/reference/` holds what was exported from the frozen Godot project: the cells of the four review layouts, the twelve fixed cameras, the props of their scenes, and traces of the GDScript production simulation (the oracle for the phase 2 port). It also holds three demonstration layouts made by the study tool's ramp stroke (version 2, not Godot exports): `layout_7301_0_ramps.json`, `layout_4242_1_slope.json`, `layout_2104_0_ramps.json`.

Not started: the real crates (`core`, `render_kit`, `layer_sea`, `shell_desktop`, `shell_headless`).

## Working on it

- Build: `cd runtime && cargo build --release`.
- Anything that draws goes through `tools/perf/gpu_run.sh` from the repository root (mains power check, one GPU job at a time, timeout), with its output sent to a log file.
- wgpu is version 30. Its API differs from older examples (instance descriptor constructors, `CurrentSurfaceTexture`, `Queue::present`, optional bind group layouts and vertex buffers, `multiview_mask`). When in doubt read the crate source under `~/.cargo/registry/src/`.
- The Swift script interpreter on this Mac is broken by a toolchain module conflict; small native helpers are written in Rust instead.
- Colours are authored as display values. Write them to a plain 8-bit target, not an sRGB one, or everything comes out brighter and paler than authored.
- Evidence goes in a dated package under `art/lookdev/`. Pictures there are ignored by git.
