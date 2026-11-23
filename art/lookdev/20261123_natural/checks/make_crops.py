#!/usr/bin/env python3
"""Cut the native-pixel crops of the package into final/crops/ (run from the repo root, needs PIL).

For game, cliff_close and terrace_close: ref_<view>.png from the Godot day frame, rest_<view>.png
from final/n_7301 (resting camera, 2x) and moving_<view>.png from final/n_moving (1x, FXAA).
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
BOXES = {"game": (950, 700, 2250, 1550), "cliff_close": (1500, 800, 2800, 1650), "terrace_close": (900, 600, 2200, 1450)}
SOURCES = {
    "ref": "../20261122_g1/godot_baseline/day/{view}.png",
    "rest": "final/n_7301/n_7301_{view}.png",
    "moving": "final/n_moving/n_moving_{view}.png",
}

os.makedirs(os.path.join(PKG, "final", "crops"), exist_ok=True)
for view, box in BOXES.items():
    for prefix, pattern in SOURCES.items():
        src = os.path.join(PKG, pattern.format(view=view))
        out = os.path.join(PKG, "final", "crops", f"{prefix}_{view}.png")
        Image.open(src).convert("RGB").crop(box).save(out)
        print("crop", os.path.relpath(out, PKG), box)
