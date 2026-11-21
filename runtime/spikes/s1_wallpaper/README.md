# Spike S1: a wgpu window as a true macOS wallpaper

Throwaway code. Question: can the chosen stack (Rust, wgpu 30, winit 0.30) hang a window as a real desktop wallpaper on macOS, stop presenting when it is covered while a simulation keeps ticking, and pace itself cheaply at 30 frames a second?

Measured 2026-11-22 on the development Mac (MacBook Pro Mac16,8, M4 Pro, built-in display, mains power). Evidence: `art/lookdev/20261122_runtime_spikes/s1_wallpaper/`.

## What was built

- `src/main.rs`: `--mode=wallpaper` makes a borderless full-screen window, then sets the NSWindow to the desktop window level, on all Spaces, stationary, out of window cycling, ignoring the mouse. `--mode=cover` is an opaque full-screen window above everything, used to cover the wallpaper. A counter stands in for the simulation at four steps a second. A per-second log records frames presented, steps, the occlusion flag and processor time.
- `src/bin/winlist.rs`: prints the on-screen window order at desktop-like levels and the display mode.
- `tools/run_test.sh OUT_DIR stop|draw`: the test. Run it through `tools/perf/gpu_run.sh`.

## Results

| Question | Result |
| --- | --- |
| Does it sit behind the icons and above the system picture? | Yes. On-screen order, front to back: Finder icon window (level -2147483603), the spike (level -2147483623), the Dock's wallpaper window (-2147483624). Bounds are the whole screen. |
| Does the system say when it is covered? | Yes. An opaque full-screen window above it produced `occluded=true` within a frame or two, and `occluded=false` when it left. wgpu also reports the surface as occluded. |
| Covered, default setting (no frames) | 0 frames a second, 0.05% of one core, simulation steps unchanged at 4 a second. |
| Covered, "keep drawing" setting | Also 0 presented frames: macOS hands out no drawable for a covered window. On macOS the setting can only keep the renderer's own off-screen work alive; nothing reaches the screen either way. 0.39% of one core. |
| Visible at 30 frames a second | 30.00 frames a second, 3.6% of one core, with a trivial full-screen shader at 3600x2338. This is the floor of the wallpaper's cost on this machine before any island is drawn. |
| Frame pacing | Median gap 33.33 ms; 95th percentile 37.5 to 40.0 ms; 99th 39.0 to 41.8 ms; worst 42.0 ms. About one frame in twenty lands one display refresh (8.3 ms) late. |

## What this means for the plan

- A true wallpaper on macOS is achievable with this stack. The attach is a dozen lines of AppKit messages on the window winit creates.
- The display is set to a scaled mode: 1800x1169 points with a 3600x2338 backing store on a 3024x1964 panel, at 120 Hz. A full-screen window is therefore asked to fill 3600x2338 pixels (8.4 M), not 3024x1964 (5.9 M). The first gate is measured at the panel's 3024x1964 as the owner said; S2 measures both.
- Timer pacing is not good enough for the plan's Ambient criterion (99th percentile at 33.3 ms). The shell needs to pace from the display's own refresh callback. Not done here.
- The "keep drawing when covered" setting needs an honest description on macOS (see the table).

## Not tested

- Display sleep, session lock and fast user switching (not triggered remotely, to avoid locking the machine mid-session).
- More than one Space, more than one display, Stage Manager.
- A screenshot of the composed desktop: screen capture from a remote shell has no permission to include other applications' windows, so the window order above is the evidence, not a picture.
- Windows. That is a later gate.
