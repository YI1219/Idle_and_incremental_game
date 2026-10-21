# Tripo Studio manifest pipeline

Supports `submission_mode: single_image` and legacy four-view manifests (omitted mode defaults to multiview). `studio_prepare.py` only fills controls; `studio_generate.py --dry-run` verifies the generation UI without submitting, and an authorized `--yes` submits one geometry-only model. Keep manual login/security challenges user-operated.

Single-image manifests use `input.file` (optional `input.sha256`), not duplicated four-view slots. Settings may use `recommended_parameters`, including `target_triangles`; existing settings blocks keep precedence. `output_original` is resolved relative to the manifest and preserved without overwrite. Example:

```json
{
  "submission_mode": "single_image",
  "input": {"file": "inputs/single.png"},
  "recommended_parameters": {
    "route": "smart_mesh", "topology": "triangles",
    "target_triangles": 2500, "texture": false
  },
  "output_original": "tripo/original_white.glb"
}
```

Before the paid click, generation creates an exclusive `<output-stem>.generation_attempt.json` marker. Any ambiguous click or interrupted run must be inspected; do not delete the marker and resubmit to recover a download. Dry-run does not reserve an attempt. Existing original files are not overwritten, including download-only mode.

## Prepare only

Local Playwright helper that opens Studio, selects the manifest’s single-image or multiview mode, uploads its input images, applies suggested settings, then **stops**. It never clicks **生成模型**.

## Setup (once)

```bash
cd /path/to/floating-isle
python3 -m pip install -r tools/tripo/requirements.txt
python3 -m playwright install chromium
```

First run: log in manually in the opened window (Cloudflare / account). The profile directory keeps the session.

Default profile: `~/.tripo-studio-profile`  
Override with `--profile`.

## Run

```bash
python3 tools/tripo/studio_prepare.py art/source/new_asset/manifest.json
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

Multi-view inputs: `views.front|left|right|back.file`, four independent files relative to the manifest directory. Single-image input: `input.file`; `submission_mode` selects one mode, and single-image mode ignores any retained legacy `views` entries.

Settings (any one of these objects):

- `studio` (preferred for this script)
- `suggested_settings`
- `tripo_suggested_settings`
- `recommended_parameters` (fallback when the above blocks are absent)

Recognized keys:

| Key | Example | Studio action |
| --- | --- | --- |
| `route` / `model` | `smart_mesh`, `P2.0`, `high_quality`, `v3.1` | 智能网格 / 高精度模型 |
| `topology` | `triangles` / `quads` | 三角面 / 四边面 |
| `target_faces` / `face_limit` / `target_triangles` | `3000` | 面数控制 |
| `texture` | `false` | Prefer geometry-first (high-quality: leave texture toggles off when possible) |

Upload slot order matches Studio: **前 → 左侧 → 右侧 → 后** = front / left / right / back.

## Prepare-only safety

- `studio_prepare.py` refuses to click any control whose label contains `生成模型`.
- Do not pass credentials on the command line; use the persistent browser profile after a manual login.
## Authorized geometry generation helper

`studio_generate.py MANIFEST --dry-run` uploads/settings/screenshots without
Generate. After explicit task authorization, `--yes` clicks Generate once,
waits and exports GLB. It forces quantity1 because Studio persists prior batch
size. Inspect dry-run screenshots and logs before submission. Texturing is
refused by this helper. After an ambiguous paid click, do not rerun `--yes`;
inspect existing task and use `--download-only` only after matching the asset.

If bundled Chromium is absent, `--channel chrome` uses installed Google Chrome
with the same dedicated persistent Tripo profile. Never use a personal browser
profile or expose stored credentials. Manual login/security challenges remain
user-operated.
