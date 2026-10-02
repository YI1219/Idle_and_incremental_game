# Island style capture · 2026-10-02

Default-camera shots of `scenes/play.tscn` after the rock-kit underside replaced the smooth inverted cone. The courtyard concept image remains look/mood reference only. Organic coast, grass shoulder, sloped pond banks, and 息壤 volume cost are unchanged.

Reproduce:

```sh
godot --path . --script tests/capture_island_style.gd --resolution 1280x720 --fixed-fps 60
godot --headless --path . --script tests/rockkit_bench.gd
```

| File | View |
| --- | --- |
| `overview_play.png` | Default distance, play mode, no build grid |
| `closeup_play.png` | Near distance, play mode |
| `overview_build.png` | Default distance, build mode, 息壤 and subtle grid |
| `closeup_build.png` | Near distance, build mode |
| `underside_low.png` | Low side angle: rock-kit cliffs in the cloud sea |
| `large_island.png` | Expanded ~4× courtyard from a high three-quarter |
| `large_island_underside.png` | Expanded island from a low side |
| `multi_island.png` | Main island plus seven satellites |
| `rockkit_bench.txt` | Piece / triangle / draw-call / frame-time sample |

PNG binaries stay local (`art/**` gitignore). Copies used for review are also in the agent artifacts folder.

This is not target-device performance evidence. Software-renderer captures are paler than a discrete GPU; cloud sea uses opaque vertex-colored billows plus puffs so the mounds still read there.
