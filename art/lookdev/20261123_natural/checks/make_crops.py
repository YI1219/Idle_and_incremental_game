#!/usr/bin/env python3
"""Cut the native-pixel crops of the second review into crops2/ (run from the repo root, needs PIL).

Same rectangle from three full 3024x1964 frames:
  ref_<name>.png     the Godot reference frame (day)
  before_<name>.png  the first review's frame, final/n_7301
  after_<name>.png   the second review's frame, final2/n_7301
for the owner's hollow joint in game, the cliff in foot_front and outer_hull, and the pond in
terrace_close. Also moving_game_joint.png (the joint from final2/n_moving, one sample per pixel and
FXAA) and, for each ramp view, <view>_plain.png / <view>_ramp.png: the plain layout and the layout
with ramps, about 1500x1000 px centred on the frame.
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
OUT = os.path.join(PKG, "crops2")

# name: (view, rectangle on the full frame)
CROPS = {
    "game_joint": ("game", (963, 735, 1715, 1424)),
    "foot_front_cliff": ("foot_front", (300, 500, 1600, 1350)),
    "outer_hull_cliff": ("outer_hull", (200, 900, 1500, 1750)),
    "terrace_close_pond": ("terrace_close", (700, 400, 2000, 1250)),
}
SOURCES = {
    "ref": "../20261122_g1/godot_baseline/day/{view}.png",
    "before": "final/n_7301/n_7301_{view}.png",
    "after": "final2/n_7301/n_7301_{view}.png",
}
MOVING = ("moving_game_joint", "final2/n_moving/n_moving_game.png", CROPS["game_joint"][1])

# ramp view: (plain run, ramps run)
RAMP_VIEWS = {
    "ramp1": ("n_7301", "n_7301_ramps"),
    "ramp2": ("n_7301", "n_7301_ramps"),
    "ramp3": ("n_7301", "n_7301_ramps"),
    "diag1": ("n_2104", "n_diag"),
    "diag2": ("n_2104", "n_diag"),
    "slope": ("n_4242", "n_slope"),
}
CENTRE = (762, 482, 2262, 1482)  # 1500x1000 round the centre of a 3024x1964 frame


def cut(src_rel, box, name):
    src = os.path.join(PKG, src_rel)
    out = os.path.join(OUT, name + ".png")
    if not os.path.isfile(src):
        print("missing source", src_rel)
        return
    Image.open(src).convert("RGB").crop(box).save(out)
    print("crop", os.path.relpath(out, PKG), box)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (view, box) in CROPS.items():
        for prefix, pattern in SOURCES.items():
            cut(pattern.format(view=view), box, f"{prefix}_{name}")
    cut(MOVING[1], MOVING[2], MOVING[0])
    for view, (plain, ramps) in RAMP_VIEWS.items():
        cut(f"final2/{plain}/{plain}_{view}.png", CENTRE, f"{view}_plain")
        cut(f"final2/{ramps}/{ramps}_{view}.png", CENTRE, f"{view}_ramp")


if __name__ == "__main__":
    main()
