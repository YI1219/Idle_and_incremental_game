#!/usr/bin/env python3
"""encode.py DIR TAG LOG OUT.mp4 [--keep-every N]: encodes the demo's frames as they are rendered.

Waits for DIR/TAG_00000.png, _00001.png, ... (the renderer writes them in order and prints an
OVERLAY line per frame to LOG), draws the brush outline and the caption on each, pipes it to
ffmpeg (H.264, imageio-ffmpeg's binary), deletes the PNG, and keeps every Nth frame as a JPEG
(DIR/keep/). Stops when LOG has its 'DEMO end' line and every frame has been taken.
"""
import os, sys, time
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

d, tag, log, out = sys.argv[1:5]
keep = int(sys.argv[6]) if len(sys.argv) > 6 else 30
os.makedirs(os.path.join(d, "keep"), exist_ok=True)
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 15)
NOTE = "Replay of brush strokes through the runtime's edit path (brush.rs). 30 frames per second of scene time (the ~90 ms rebuild at each release is not shown). Pointer drawn on top; not mouse input."
JADE = (120, 214, 178)

def overlays():
    out = {}
    if os.path.exists(log):
        for line in open(log, errors="replace"):
            if line.startswith("OVERLAY "):
                head, rest = line[8:].rstrip("\n").split(" ", 1)
                t, caption, shapes = rest.split("|", 2)
                out[int(head)] = (float(t), caption, shapes)
    return out

def done():
    return os.path.exists(log) and any(l.startswith("DEMO end") for l in open(log, errors="replace"))

writer = None
i = 0
info = {}
while True:
    path = os.path.join(d, f"{tag}_{i:05d}.png")
    if not os.path.exists(path) or i not in info:
        info = overlays()
        if os.path.exists(path) and i in info:
            continue
        if done() and not os.path.exists(path):
            break
        time.sleep(0.5)
        continue
    time.sleep(0.05)
    try:
        im = Image.open(path).convert("RGB")
    except Exception:
        time.sleep(0.3)
        continue
    t, caption, shapes = info[i]
    dr = ImageDraw.Draw(im, "RGBA")
    for shape in [s for s in shapes.split(";") if s.strip()]:
        pts = [tuple(map(float, p.split(","))) for p in shape.split()]
        if len(pts) > 1:
            dr.line(pts, fill=JADE + (235,), width=3, joint="curve")
    w, h = im.size
    if caption:
        tw = dr.textlength(caption, font=font)
        dr.rectangle([18, h - 64, 18 + tw + 28, h - 22], fill=(20, 26, 24, 150))
        dr.text((32, h - 58), caption, font=font, fill=(245, 245, 238, 255))
    dr.text((18, 14), NOTE, font=small, fill=(40, 46, 44, 200))
    dr.text((w - 90, 14), f"{t:5.2f} s", font=small, fill=(40, 46, 44, 220))
    if writer is None:
        writer = imageio_ffmpeg.write_frames(out, im.size, fps=30, codec="libx264", quality=None, bitrate=None, output_params=["-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart"], macro_block_size=2)
        writer.send(None)
    writer.send(im.tobytes())
    if i % keep == 0:
        im.save(os.path.join(d, "keep", f"{tag}_{i:05d}.jpg"), quality=88)
    os.remove(path)
    i += 1
if writer is not None:
    writer.close()
print("ENCODED", i, "frames to", out)
