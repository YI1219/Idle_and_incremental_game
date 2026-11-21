# Freeze of the Godot project (2026-11-22)

The owner decided on 2026-11-22 to build a purpose-built runtime and authorised a freeze of the tree as it stood. This package records the state of that tree. It is the baseline the runtime is compared against. Nothing here is art-accepted.

Tag: `godot-freeze-20261122` on `pr-18-lip`. Machine: MacBook Pro (Mac16,8), M4 Pro, built-in display 3024x1964, mains power, Godot 4.7.2.

## Regression list

`checks/suite.json`, `checks/suite.log`: the 40-case list of the earlier cliff rounds, run unchanged through `../20261121_perf_stack/checks/run_suite.py` on the tree that was committed: 40 ran, 0 failed.

## Godot at the first gate's resolution

`data/bench_native_panel.json`, `data/bench.log`: `tools/perf/bench_presets.gd -- --sizes=3024x1964`, default 623-cell island, one island in view, single viewport.

| Tier | whole | game | reverse |
| --- | --- | --- | --- |
| native | 30.62 ms | 38.36 ms | 29.28 ms |
| balanced (default) | 23.68 ms | 29.42 ms | 22.39 ms |
| light | 14.64 ms | 18.91 ms | 13.70 ms |

An idle window presented every 12.27 ms in the same run; every figure is above that, so none is clipped by it. Against 16.7 ms for 60 FPS the default tier misses on all three views and the light tier misses on the closer play view.

## What is where

- In the tag: code, shaders, tests, tools, docs, the assets the scene uses, and the scripts, notes and data of every lookdev package.
- Not in git: lookdev pictures (`.png`, `.jpg`, `.webp`, `.exr` under `art/lookdev/`), ignored and left in place; a clone of the whole folder is at `~/Archives/the-scroll-within/lookdev_20261122/` on the same disk.
- Local-only tag `godot-freeze-20261122-full`: the same tree plus `art/source/` and `assets/candidates/` (about 580 MB of raw model sources and unadopted candidates). Not pushed, because `origin` is a public repository.

## To get back to this state

`git checkout godot-freeze-20261122` restores the project; `git checkout godot-freeze-20261122-full -- art/source assets/candidates` restores the raw sources if the working copies are lost; the lookdev pictures come from the clone.
