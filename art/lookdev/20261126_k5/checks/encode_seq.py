#!/usr/bin/env python3
"""encode_seq.py DIR TAG OUTDIR: the settle sequences' half-size frames (DIR/TAG_<name>_before.png,
DIR/TAG_<name>_tMMMM.png) as video: one MP4 per sequence and all of them in one file, each opening
on the island before the edit (0.7 s), then the motion at 30 frames a second and a short hold."""
import glob, os, re, sys
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

d, tag, out = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
CAPTION = {
    "raise": "raise: a lawn patch rises 1 m and settles",
    "lower": "lower: a lawn patch sinks 1 m and settles",
    "expand": "expand: new land rises at the rim",
    "place": "place: items grow in",
    "ramp": "ramp: a wall leans into a ramp",
    "erase": "erase (contract): land at the rim falls away, the new edge settles",
    "remove": "remove: a tree and a bush shrink away",
    "unraise": "lower a raised plinth by 0.5 m",
    "fill": "water: a pond fills from its bed",
    "drain": "dry: a pond drains to its bed",
}

def frames(name):
    files = glob.glob(os.path.join(d, f"{tag}_{name}_t*.png"))
    files.sort(key=lambda f: int(re.search(r"_t(\d+)\.png$", f).group(1)))
    return files

def label(im, text):
    dr = ImageDraw.Draw(im, "RGBA")
    tw = dr.textlength(text, font=font)
    h = im.size[1]
    dr.rectangle([18, h - 64, 18 + tw + 28, h - 22], fill=(20, 26, 24, 150))
    dr.text((32, h - 58), text, font=font, fill=(245, 245, 238, 255))
    return im

def writer(path, size):
    w = imageio_ffmpeg.write_frames(path, size, fps=30, codec="libx264", output_params=["-crf", "18", "-movflags", "+faststart"], macro_block_size=2)
    w.send(None)
    return w

names = sorted({re.search(rf"{tag}_(\w+?)_before\.png$", f).group(1) for f in glob.glob(os.path.join(d, f"{tag}_*_before.png"))}, key=lambda n: list(CAPTION).index(n) if n in CAPTION else 99)
allw = None
for name in names:
    seq = frames(name)
    if not seq:
        continue
    before = Image.open(os.path.join(d, f"{tag}_{name}_before.png")).convert("RGB")
    size = before.size
    one = writer(os.path.join(out, f"{name}.mp4"), size)
    if allw is None:
        allw = writer(os.path.join(out, "all_sequences.mp4"), size)
    text = CAPTION.get(name, name)
    shots = [label(before.copy(), "before: " + text)] * 21 + [label(Image.open(f).convert("RGB"), text) for f in seq]
    shots += [shots[-1]] * 20
    for im in shots:
        b = im.tobytes()
        one.send(b)
        allw.send(b)
    one.close()
    print("ENCODED", name, len(shots))
if allw is not None:
    allw.close()
