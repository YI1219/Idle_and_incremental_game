#!/usr/bin/env python3
"""Measure the colour boxes of the natural-look rounds on the final frames and write boxes.json.

Run from the repo root on the Mac (needs PIL and numpy):
    python3 art/lookdev/20261123_natural/checks/measure_boxes.py

Each box is measured on the reduced copies (1300 px wide) of the Godot reference frame and of the
runtime's final frame of the same view and hour: the median display colour (0..1) and the 10th and
90th percentiles of luma. The tolerance used during the rounds was 0.02 per channel on the median.
"""
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
REF = os.path.join(PKG, "..", "20261122_g1", "godot_baseline")
FINAL = os.path.join(PKG, "final")

# name, hour, view, box (x0, y0, x1, y1) on the 1300 px reduced frames
BOXES = [
    ("lawn", "day", "terrace_close", (950, 180, 1100, 250)),
    ("wall", "day", "terrace_close", (450, 420, 700, 470)),
    ("pond", "day", "terrace_close", (500, 270, 700, 320)),
    ("block face", "day", "cliff_close", (680, 430, 860, 560)),
    ("sky", "day", "cliff_close", (20, 20, 250, 180)),
    ("cloud left", "day", "whole", (40, 500, 200, 650)),
    ("cloud right", "day", "whole", (1180, 700, 1290, 830)),
    ("cliff", "dusk", "whole", (620, 600, 700, 660)),
    ("lawn", "dusk", "whole", (650, 280, 750, 320)),
    ("cloud", "dusk", "whole", (40, 500, 200, 650)),
    ("cliff", "night", "whole", (620, 600, 700, 660)),
    ("lawn", "night", "whole", (650, 280, 750, 320)),
    ("cloud", "night", "whole", (40, 500, 200, 650)),
]
RUNS = {"day": "n_7301", "dusk": "n_dusk", "night": "n_night"}


def measure(path, box):
    img = np.asarray(Image.open(path).convert("RGB")).astype(np.float64) / 255.0
    x0, y0, x1, y1 = box
    region = img[y0:y1, x0:x1].reshape(-1, 3)
    med = np.median(region, axis=0)
    luma = region @ np.array([0.2126, 0.7152, 0.0722])
    p10, p90 = np.percentile(luma, [10, 90])
    return {"median": [round(float(v), 3) for v in med], "luma_p10": round(float(p10), 3), "luma_p90": round(float(p90), 3)}


def main():
    rows = []
    for name, hour, view, box in BOXES:
        run = RUNS[hour]
        ref_rel = f"../20261122_g1/godot_baseline/{hour}/small/{view}.png"
        run_rel = f"final/{run}/small/{run}_{view}.png"
        ref_path = os.path.join(PKG, ref_rel)
        run_path = os.path.join(PKG, run_rel)
        row = {"name": name, "hour": hour, "view": view, "box": list(box), "reference_frame": ref_rel, "runtime_frame": run_rel}
        row["reference"] = measure(ref_path, box) if os.path.isfile(ref_path) else None
        row["runtime"] = measure(run_path, box) if os.path.isfile(run_path) else None
        if row["reference"] and row["runtime"]:
            row["max_channel_difference"] = round(max(abs(a - b) for a, b in zip(row["reference"]["median"], row["runtime"]["median"])), 3)
        rows.append(row)
        ref_m = row["reference"]["median"] if row["reference"] else None
        run_m = row["runtime"]["median"] if row["runtime"] else None
        print(f"{hour:5} {view:13} {name:11} reference {ref_m} runtime {run_m} diff {row.get('max_channel_difference')}")
    with open(os.path.join(HERE, "boxes.json"), "w", encoding="utf-8") as fh:
        json.dump({"note": "Median display colour (0..1) and luma p10/p90 of each box on the 1300 px reduced frames.", "boxes": rows}, fh, indent=1)
        fh.write("\n")


if __name__ == "__main__":
    main()
