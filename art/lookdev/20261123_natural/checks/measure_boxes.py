#!/usr/bin/env python3
"""Measure the colour boxes of the second review and write boxes.json.

Run from the repo root on the Mac (needs PIL and numpy):
    python3 art/lookdev/20261123_natural/checks/measure_boxes.py

Each box is measured on the reduced copies (1300 px wide) of the Godot reference frame, of the
second review's frame (final2/, "runtime") and, for walls and ponds, of the first review's frame
(final/, "before"): the median display colour (0..1) and the 10th and 90th percentiles of luma.
Where the island differs a little in framing, the runtime box differs from the reference box; the
before box is always the runtime box. The tolerance used during the rounds was 0.02 per channel.
"""
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)

# name, hour, view, reference box, runtime box (None: same), group, change
# group: wall / pond record a "before" value; change: which of the owner's four changes it serves.
BOXES = [
    ("lawn", "day", "terrace_close", (950, 180, 1100, 250), None, "other", ""),
    ("wall", "day", "terrace_close", (450, 430, 700, 480), (450, 420, 700, 470), "wall", "rock walls"),
    ("pond centre", "day", "terrace_close", (500, 260, 700, 310), (500, 270, 700, 320), "pond", "water"),
    ("block face", "day", "cliff_close", (680, 430, 860, 560), None, "wall", "rock walls"),
    ("sunlit wall", "day", "outer_hull", (330, 450, 480, 640), (360, 450, 480, 640), "wall", "rock walls"),
    ("shaded wall", "day", "outer_hull", (200, 440, 290, 600), None, "wall", "rock walls"),
    ("upper pond", "day", "outer_hull", (300, 275, 540, 300), None, "pond", "water"),
    ("lower pond", "day", "outer_hull", (700, 340, 900, 380), None, "pond", "water"),
    ("sunlit wall", "day", "foot_front", (660, 420, 830, 680), None, "wall", "rock walls"),
    ("pond", "day", "foot_front", (800, 185, 1050, 225), None, "pond", "water"),
    ("sky", "day", "cliff_close", (20, 20, 250, 180), None, "other", ""),
    ("cloud left", "day", "whole", (40, 500, 200, 650), None, "other", ""),
    ("cloud right", "day", "whole", (1180, 700, 1290, 830), None, "other", ""),
    ("cliff", "dusk", "whole", (620, 600, 700, 660), None, "wall", ""),
    ("lawn", "dusk", "whole", (650, 280, 750, 320), None, "other", ""),
    ("cloud", "dusk", "whole", (40, 500, 200, 650), None, "other", ""),
    ("cliff", "night", "whole", (620, 600, 700, 660), None, "wall", ""),
    ("lawn", "night", "whole", (650, 280, 750, 320), None, "other", ""),
    ("cloud", "night", "whole", (40, 500, 200, 650), None, "other", ""),
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


def diff(a, b):
    if not a or not b:
        return None
    return round(max(abs(x - y) for x, y in zip(a["median"], b["median"])), 3)


def main():
    rows = []
    for name, hour, view, ref_box, run_box, group, change in BOXES:
        run_box = run_box or ref_box
        run = RUNS[hour]
        ref_rel = f"../20261122_g1/godot_baseline/{hour}/small/{view}.png"
        run_rel = f"final2/{run}/small/{run}_{view}.png"
        before_rel = f"final/{run}/small/{run}_{view}.png"
        row = {"name": name, "hour": hour, "view": view, "group": group, "change": change,
               "box": list(run_box), "reference_box": list(ref_box),
               "reference_frame": ref_rel, "runtime_frame": run_rel}
        p = os.path.join(PKG, ref_rel)
        row["reference"] = measure(p, ref_box) if os.path.isfile(p) else None
        p = os.path.join(PKG, run_rel)
        row["runtime"] = measure(p, run_box) if os.path.isfile(p) else None
        if group in ("wall", "pond"):
            row["before_frame"] = before_rel
            p = os.path.join(PKG, before_rel)
            row["before"] = measure(p, run_box) if os.path.isfile(p) else None
            d = diff(row["reference"], row["before"])
            if d is not None:
                row["before_max_channel_difference"] = d
        d = diff(row["reference"], row["runtime"])
        if d is not None:
            row["max_channel_difference"] = d
        rows.append(row)
        get = lambda k: row[k]["median"] if row.get(k) else None
        print(f"{hour:5} {view:13} {name:12} ref {get('reference')} before {get('before')} "
              f"after {get('runtime')} diff {row.get('max_channel_difference')}")
    with open(os.path.join(HERE, "boxes.json"), "w", encoding="utf-8") as fh:
        json.dump({"note": "Median display colour (0..1) and luma p10/p90 of each box on the 1300 px reduced "
                           "frames: Godot reference, first review (before, walls and ponds), second review (runtime).",
                   "boxes": rows}, fh, indent=1)
        fh.write("\n")


if __name__ == "__main__":
    main()
