# Island style capture · 2026-10-02

Default-camera shots of `scenes/play.tscn` after the closed-volume / organic-coast / soft-shore / readable-cloud pass. The courtyard concept image remains look/mood reference only.

Reproduce:

```sh
godot --path . --script tests/capture_island_style.gd --resolution 1280x720 --fixed-fps 60
```

| File | View |
| --- | --- |
| `overview_play.png` | Default distance, play mode, no build grid |
| `closeup_play.png` | Near distance, play mode |
| `overview_build.png` | Default distance, build mode, 息壤 and subtle grid |
| `closeup_build.png` | Near distance, build mode |
| `underside_low.png` | Low side angle: closed rocky cone in the cloud sea |

PNG binaries stay local (`art/**` gitignore). Copies used for review are also in the agent artifacts folder.

This is not target-device performance evidence. Software-renderer captures are paler than a discrete GPU; cloud sea uses opaque vertex-colored billows plus puffs so the mounds still read there.
