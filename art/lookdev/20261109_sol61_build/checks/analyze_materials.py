"""Reproducible material crops. Source captures are never modified."""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PACK = Path(__file__).resolve().parents[1]
OUT = PACK / "material_compare"
OUT.mkdir(exist_ok=True)
SIZE = (1672, 941)
REGIONS = {
    "meadow": (650, 270, 860, 310),
    "lit_stone": (425, 480, 550, 640),
    "front_stone": (920, 520, 1040, 650),
    "junction": (500, 240, 1150, 550),
}
TARGET_DIR = PACK.parent / "20261109_wallpaper_targets_sol61"
if not TARGET_DIR.exists():
    TARGET_DIR = PACK.parent / "scroll_wallpaper_targets_sol61_20261109"
SOURCES = {
    "TARGET_B": TARGET_DIR / "TARGET_B_grass_rock_hero.png",
    "previous": PACK / "final_day/cliff_close.png",
    "clean_stone": PACK / "clean_stone_day/cliff_close.png",
    "06": PACK / "06_planar_soft_edges_day/cliff_close.png",
    "07": PACK / "07_feel_rebuild_day/cliff_close.png",
    "08": PACK / "08_primary_material_day/cliff_close.png",
    "current": PACK / "planted_meadow_day/cliff_close.png",
    "material_before_locked": PACK / "12_material_before_locked_day/cliff_close.png",
}
report = {
    "analysis_size": SIZE,
    "note": "Native Godot captures remain untouched at 2560x1440. Only these analysis copies are resized to TARGET size. TARGET has local generated composition drift; color/texture samples and absolute pixel differences are diagnostics, never an art acceptance score. All crops exclude the reference character.",
    "regions": REGIONS, "samples": {},
}
images = {}
for label, path in SOURCES.items():
    if not path.exists():
        continue
    image = Image.open(path).convert("RGB").resize(SIZE, Image.Resampling.LANCZOS)
    images[label] = image
    samples = {}
    for name, rect in REGIONS.items():
        crop = image.crop(rect)
        crop.save(OUT / f"{label}_{name}.png")
        rgb = np.asarray(crop, dtype=float)
        luma = rgb @ np.array([.2126, .7152, .0722])
        gradient = (np.abs(np.diff(luma, axis=0)).mean() + np.abs(np.diff(luma, axis=1)).mean()) / 2
        low = np.asarray(crop.filter(ImageFilter.GaussianBlur(3)), dtype=float)
        samples[name] = {"mean_rgb": rgb.mean((0, 1)).tolist(), "mean_luma": float(luma.mean()),
                         "mean_neighbor_gradient": float(gradient), "fine_texture_rms": float(np.sqrt(((rgb-low)**2).mean()))}
    report["samples"][label] = {"source": str(path.relative_to(PACK.parent)), "regions": samples}

labels = [label for label in ("TARGET_B", "previous", "clean_stone", "current") if label in images]
sheet = Image.new("RGB", (1300, 344 * ((len(labels)+1)//2)), "#172124")
draw = ImageDraw.Draw(sheet)
for i, label in enumerate(labels):
    x, y = (i % 2) * 650, (i // 2) * 344
    draw.text((x+10, y+10), label + (" / generated reference" if label == "TARGET_B" else " / real Godot"), fill="#e3e9db")
    sheet.paste(images[label].crop(REGIONS["junction"]), (x, y+34))
sheet.save(OUT / "junction_contact_sheet.png")

if "current" in images:
    for label in ("TARGET_B", "material_before_locked"):
        if label not in images:
            continue
        difference = np.abs(np.asarray(images[label], dtype=float) - np.asarray(images["current"], dtype=float))
        crop = difference[240:550, 500:1150]
        Image.fromarray(np.clip(crop*3, 0, 255).astype("uint8")).save(OUT / f"current_vs_{label}_absolute_difference_x3.png")
(OUT / "metrics.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print("Wrote diagnostic crops and metrics:", OUT)
