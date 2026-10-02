# Tripo Studio prepare (no generate)

Local Playwright helper that opens Studio, selects multiview, uploads the four views from a task manifest, applies suggested settings, then **stops**. It never clicks **生成模型**.

## Setup (once)

```bash
cd /path/to/Idle_and_incremental_game
python3 -m pip install -r tools/tripo/requirements.txt
python3 -m playwright install chromium
```

First run: log in manually in the opened window (Cloudflare / account). The profile directory keeps the session.

Default profile: `~/.tripo-studio-profile`  
Override with `--profile`.

## Run

```bash
python3 tools/tripo/studio_prepare.py art/source/cottage/2026-09-20/manifest.json
```

Options:

| Flag | Meaning |
| --- | --- |
| `--headed` | Show browser (default) |
| `--headless` | Headless (usually fails Cloudflare / login) |
| `--profile DIR` | Persistent Chromium user data |
| `--timeout-ms N` | Default navigation/action timeout |
| `--no-pause` | Exit after fill without waiting for Enter |

## Manifest fields used

Views (required): `views.front|left|right|back.file` relative to the manifest directory.

Settings (any one of these objects):

- `studio` (preferred for this script)
- `suggested_settings`
- `tripo_suggested_settings`

Recognized keys:

| Key | Example | Studio action |
| --- | --- | --- |
| `route` / `model` | `smart_mesh`, `P2.0`, `high_quality`, `v3.1` | 智能网格 / 高精度模型 |
| `topology` | `triangles` / `quads` | 三角面 / 四边面 |
| `target_faces` / `face_limit` | `3000` | 面数控制 |
| `texture` | `false` | Prefer geometry-first (high-quality: leave texture toggles off when possible) |

Upload slot order matches Studio: **前 → 左侧 → 右侧 → 后** = front / left / right / back.

## Safety

- The script refuses to click any control whose label contains `生成模型`.
- Do not pass credentials on the command line; use the persistent browser profile after a manual login.