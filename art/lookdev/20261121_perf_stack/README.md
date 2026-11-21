# Performance and stack: measurements, a light tier, and the engine decision (2026-11-21)

Owner brief (2026-11-21): performance is first-class; the world must run cheaply on low-end devices and as a hung wallpaper without losing its look; Godot is not mandatory if another stack clearly wins on (1) performance, (2) the part-one gameplay and (3) Windows thin-and-light laptops, MacBook Air-class machines and wallpaper use. "Spend real time proving or disproving this. Measure."

All numbers here are from the development Mac (M4 Pro, mains power, Godot 4.7.2, Metal). **No target laptop was measured. Nothing here claims 60 FPS on one.** Other apps were running on the Mac throughout (load average 5 to 7); every comparison is taken inside one process with the variants replayed forward then backward.

## Decision: stay on Godot, change techniques

1. Performance. The engine itself is not what costs. An empty Godot viewport with sky and post effects adds nothing measurable to a frame (`data/scale_balanced_1920x1080.json`: slope of frame time against the number of empty viewports is -0.06 ms). The whole 12.4 ms of a 1080p frame is the content and the techniques chosen for it (table below). A custom renderer would pay the same for the same techniques; every saving found is a change of technique that Godot can make too, and the first one is already made here (the light tier, about 40% cheaper).
2. Gameplay. Part one is an RTS-style base on an editable island with data-driven production. The island generator, live editing, water and 40 regression cases already exist in this stack (about 14,000 lines of generator script). A rewrite would spend months re-reaching today's picture before the first gameplay line.
3. Platforms. Godot exports a project like this to Windows and macOS (no export preset exists yet and export templates are not installed on the Mac). Hanging as a wallpaper needs a small piece of native window glue on each system whatever the engine is; that is not a reason to change engines.

What would reopen the question: a measured target laptop that the light tier and the steps under "Next" cannot bring into budget.

## A measurement trap, found and fixed

An idle window on this Mac presents at only about 85 frames a second (11.5 to 12 ms a frame), with the scene hidden, with all scripts stopped, and even with the scene viewport not rendered at all (`data/cpu_floor_1920x1080.json`). A single 1080p viewport costs about the same, so its frame time sits at that ceiling and feature costs disappear: in a plain single-viewport run, hiding all geometry "saved" 0.6 ms (`data/ablate_1920x1080.json`, kept as the example of the trap). Earlier 1080p and 720p numbers in this project were taken that way and understate differences.

Method used from here on (`checks/probe_scale.gd`, `checks/probe_ablate_k.gd`, `tools/perf/bench_presets.gd`): the scene is drawn into K identical viewports that share one world and the frame time is divided by K. Frame time is linear in K (12.36, 24.45, 37.18, 49.09 ms for K = 1 to 4), so the slope is the real cost of one render: 12.2 ms at 1080p.

## Where a 1080p frame goes

Default ("balanced") tier, `whole` view, 1920×1080, cost of one render 12.4 ms. Saving when one thing is removed (`data/ablate_k3_1920x1080.json`, `data/light_k3_1920x1080.json`):

| Removed | Saving | Note |
| --- | --- | --- |
| 2× MSAA | 2.9 to 3.0 ms | SMAA in its place costs 0.27 ms, FXAA 0.04 ms |
| SSAO and SSIL together | 1.8 to 2.0 ms | either alone saves 0.15 to 0.67 ms: they share a normal pre-pass that only goes when both are off |
| Foliage cards (tree crowns, bushes) | 2.0 ms | 27,752 triangles; layered alpha cards, so mostly overdraw |
| Sun shadows | 1.7 ms | a 2048 atlas saves 0.1 ms; two splits instead of four is 1.5 ms slower |
| Grass blades | 1.6 ms | 1.3 M triangles at full detail |
| Far depth of field | 0.5 ms | |
| Distant mountains | 0.6 ms | 1.0 M triangles |
| Cloud deck | 0.6 ms | |
| Ground, lawn rim, lake bed | 0.55 ms | |
| Glow | 0.3 ms | |
| Cliffs and rocks | under 0.1 ms | the whole stone kit is nearly free |
| Water, falls, foam, mist | under 0.3 ms (noise) | |
| Lighting of all materials (unshaded view) | 3.6 ms | |

Halving the 3D resolution (FSR) saves 3.9 ms; a 0.67 scale saves 2.7 ms.

## Godot's other renderers on the same scene

| Renderer | One 1080p render | Picture |
| --- | --- | --- |
| Forward+ (current) | 12.2 ms | reference |
| Mobile | about 8.3 ms | close to the reference, a little flatter: it has no SSAO or SSIL (`stills/renderer_mobile/`) |
| Compatibility (OpenGL) | about 7.9 to 8.6 ms | not usable as is: stone blows out to white, ponds turn grey (`stills/renderer_gl_compatibility/`). It would need its own material pass |

Both ran the scene without a script or shader error. Mobile is a real option for a still lighter tier, but the renderer is chosen at start-up, not switched live.

## The light tier (implemented)

`scripts/terrain_editor/preview_quality.gd` gains a third tier beside "native" and the default: `set_light(true)`. Edges are smoothed after the frame (SMAA) instead of by 2× MSAA; SSAO and SSIL are off (so the shared pre-pass goes too); the editor drops the far blur (`editor.gd`, `set_light_preview`). The scroll menu's quality row gains 轻量画质 between 流畅预览 and 原生画质 (`shihai_hud.gd`). The default tier is unchanged. Leaving the tier restores every setting it touched.

Cost of one render on the M4 Pro, full pixels, three views (`data/bench_m4pro.json`, `tools/perf/bench_presets.gd`):

| Size | View | Native | Balanced (default) | Light |
| --- | --- | --- | --- | --- |
| 1920×1080 | whole | 14.84 ms | 12.49 ms | 7.26 ms |
| 1920×1080 | game | 18.82 ms | 15.38 ms | 8.83 ms |
| 1920×1080 | reverse | 14.38 ms | 12.04 ms | 6.99 ms |
| 2560×1440 | whole | 21.05 ms | 16.63 ms | 9.69 ms |
| 2560×1440 | game | 27.87 ms | 21.53 ms | 13.18 ms |
| 2560×1440 | reverse | 20.76 ms | 16.06 ms | 9.62 ms |
| 3840×2160 | whole | 40.89 ms | 30.26 ms | 18.79 ms |
| 3840×2160 | game | 52.54 ms | 38.41 ms | 24.97 ms |
| 3840×2160 | reverse | 38.13 ms | 28.40 ms | 17.44 ms |

Light is 35 to 43% cheaper than balanced (35% only in the heaviest row, the 4K play view). The `game` view (the closer play camera) is the heaviest of the three.

What the picture trades (`stills/tiers/`, `compare.html`; one frozen scene, 2560×1440, five views): mean difference from balanced 1.0 to 2.1 of 255. At native pixels edges look the same; contact shading in creases and under the grass lip is slightly weaker, and the far blur is gone. Not checked: shimmer of thin grass in motion, which MSAA handles better than SMAA; that needs a look at the running game, not stills.

What this means for the target, as arithmetic only: at 1080p the light tier needs 7.0 to 8.8 ms here, so it holds 60 FPS on a machine whose graphics are up to about 1.9 to 2.4 times slower than this M4 Pro, and a 30 FPS wallpaper on one up to about 3.8 to 4.8 times slower. Where the target laptops fall is unknown until they are measured. To measure one (Godot 4.7.2 and this project folder on it, mains power):

```
godot --path . --disable-vsync --script res://tools/perf/bench_presets.gd -- --out=/abs/path/bench.json
```

## Wallpaper mode: where the processor time goes

Wallpaper mode at 1280×720, 30 FPS cap: 38 and 42% of one core in two runs (`data/wallpaper_cpu_before*.json`, the project's `tools/perf/runtime_load_probe.gd`). A 4 s sample of that process:

| Thread | Share of one core |
| --- | --- |
| Twelve worker threads together | about 19% |
| Main thread | about 7% (90% of its time is the frame limiter's sleep) |
| Metal command queue | about 2% |

The worker time is the background water simulation. Measured headless (`checks/water_cost.gd`): 10.1 cycles a second, 32.3 ms each (solver 22.7 ms for 0.1 s of simulated time, mesh 8.9 ms, field images 0.7 ms), about a third of a core.

Two things follow, and the second is a product problem, not only a cost:

- The solver never goes to sleep while anything trickles, and the trickle decays without ever stopping.
- There is no source of water. The default ponds hold 71 units; 38.8 are left after one minute, 7.3 after five, 1.2 after fifteen (`data/water_runout.log`). A wallpaper left hanging loses its ponds and falls within minutes while the solver keeps running.

Recommended, not done here because it changes how water behaves (the owner asked for finite water on 2026-11-10): let the part-one spirit spring be a source that feeds the top pond; with inflow equal to outflow the levels settle, the solver can be put to sleep at steady state with the falls still drawn from the last flow rates, and the processor cost of water goes to zero. Moving the solver's inner loop out of GDScript would then only matter during edits.

## Next, in order of value

1. Measure the three tiers on the real target laptops with the command above. Everything else should be ranked again after that.
2. Water: spring source, steady-state sleep (above). Removes about 20 to 30% of a core from the wallpaper and keeps the ponds alive.
3. Foliage cards: 2.0 ms for 28,000 triangles. Fewer, larger cards over an opaque crown core should recover most of it.
4. A cached island for the wallpaper and for a still camera: draw the static island (stone, ground, trees, shadows, post effects) once into a texture with its depth, then each frame draw only that picture plus water, falls, mist, clouds and whatever moves. The static part is nearly all of today's frame, so this is the step that could bring integrated graphics to 60 FPS. It is a rendering restructure (my estimate: about a week), and it is the same thing a custom engine would do.
5. Balanced tier: SMAA instead of 2× MSAA would save 2.8 ms of 12.4 if a look at the moving grass confirms it.
6. Mobile renderer with ambient occlusion baked into the stone and ground, as a tier below light.

## Evidence

- `data/scale_*.json`, `data/cpu_floor_1920x1080.json`: floor and cost-per-render probes. `data/ablate_k3_1920x1080.json`, `data/light_k3_1920x1080.json`: cost breakdown and candidate settings. `data/bench_m4pro.json`: tier benchmark. `data/water_runout.log`, `data/wallpaper_cpu_before*.json`: water and processor.
- `stills/tiers/` (25 frames), `stills/renderer_*/` (15 frames), `compare.html`.
- `checks/suite.json`: the 40-case regression list rerun after the tier was added; `tests/preview_quality_test.gd` grows from 12 to 19 checks. `checks/normal_entry.log`.
- `checks/light_tier_check.gd`: the tier switched through the editor's own entry points in the real scene; light, native and back to the default restore every setting.
- `checks/production.patch`, `checks/final_sha256.txt`, `checks/source_before/`.
- An invalid first breakdown run (a size list passed as one string, so no render target existed) was deleted; nothing here uses it.

## Roll back

Restore `scripts/terrain_editor/preview_quality.gd`, `scripts/terrain_editor/editor.gd`, `scripts/gameplay/ui/shihai_hud.gd` and `tests/preview_quality_test.gd` from `checks/source_before/`, or apply `checks/production.patch` in reverse. `tools/perf/bench_presets.gd` is a new file. Do not reset other uncommitted work.

`target_hardware_performance_measured: false`.
