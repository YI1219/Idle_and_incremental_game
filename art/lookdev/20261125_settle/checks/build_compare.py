#!/usr/bin/env python3
"""Builds compare.html for the round k2 package (art/lookdev/20261125_settle).

Run from the repository root after render_settle.sh:
    python3 art/lookdev/20261125_settle/checks/build_compare.py [OUT]

Writes web copies (JPEG, 1000 px wide) of the flipbook frames to OUT/web/, a regression
report to OUT/regress.txt, and OUT/compare.html, which plays the sequences in the browser.
"""
import html
import json
import os
import re
import sys

from PIL import Image, ImageChops

OUT = sys.argv[1] if len(sys.argv) > 1 else "art/lookdev/20261125_settle"
SEQ = [
    ("raise", "Raise a 3 x 3 patch of lawn by 1 m"),
    ("lower", "Lower a 3 x 3 patch of lawn by 1 m"),
    ("expand", "Add 4 x 3 cells of land at the rim"),
    ("place", "Place a tree, two bushes, two stones and a flower"),
    ("ramp", "Draw a ramp (width 2) across a 1 m terrace wall"),
]
KEYS = [0, 100, 200, 350, 600, 1500]
ROCK_VIEWS = ["cliff_close", "foot_front", "outer_hull", "terrace_close", "game"]
WEB = os.path.join(OUT, "web")
os.makedirs(WEB, exist_ok=True)


def web_copy(src, name, width=1000, quality=86):
    dst = os.path.join(WEB, name)
    if not os.path.exists(dst) and os.path.exists(src):
        im = Image.open(src).convert("RGB")
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
        im.save(dst, quality=quality)
    return "web/" + name


def lines(path, prefix):
    if not os.path.exists(path):
        return []
    return [l.rstrip() for l in open(path) if l.startswith(prefix)]


# Regression: with no edit running, this build against the k1 commit's stills.
regress = []
for view in ["game", "terrace_close", "outer_hull"]:
    a = f"/tmp/tsw_k2/base/base_{view}.png"
    b = os.path.join(OUT, "regress", f"regress_{view}.png")
    if os.path.exists(a) and os.path.exists(b):
        d = ImageChops.difference(Image.open(a).convert("RGB"), Image.open(b).convert("RGB"))
        hist = d.convert("L").histogram()
        changed = sum(hist[1:])
        regress.append(f"{view}: max channel difference {max(e[1] for e in d.getextrema())}/255, pixels differing {changed}")
    else:
        regress.append(f"{view}: missing ({'no baseline' if not os.path.exists(a) else 'no render'})")
open(os.path.join(OUT, "regress.txt"), "w").write("\n".join(regress) + "\n")

# Latency and bench lines.
latency = {}
for l in lines(os.path.join(OUT, "flip.log"), "SETTLE") + lines(os.path.join(OUT, "keys.log"), "SETTLE"):
    m = re.match(r"SETTLE (\w+) latency: (.*)", l)
    if m and m.group(1) not in latency:
        latency[m.group(1)] = m.group(2)
bench = {}
for b in ["bench_a", "bench_b"]:
    for l in lines(os.path.join(OUT, f"{b}.log"), "BENCH"):
        m = re.match(r"BENCH settle_(\w+): settled ([\d.]+) ms \(shadow cached\), ([\d.]+) ms \(shadow redrawn\), during the motion ([\d.]+) ms", l)
        if m:
            bench.setdefault(m.group(1), []).append((float(m.group(2)), float(m.group(3)), float(m.group(4))))
loads = []
for b in ["bench_a", "bench_b"]:
    p = os.path.join(OUT, f"{b}.load")
    if os.path.exists(p):
        loads.append(f"{b}: " + " / ".join(re.sub(r".*load averages?: ", "", l.strip()) for l in open(p)))
edit = lines(os.path.join(OUT, "edit.log"), "EDIT ")

# Flipbook frames.
flip = {}
for name, _ in SEQ:
    frames = []
    times = sorted(int(f.split("_t")[1][:4]) for f in os.listdir(os.path.join(OUT, "flip")) if f.startswith(f"flip_{name}_t") and f.endswith(".png")) if os.path.isdir(os.path.join(OUT, "flip")) else []
    for ms in times:
        frames.append(web_copy(os.path.join(OUT, "flip", f"flip_{name}_t{ms:04d}.png"), f"flip_{name}_t{ms:04d}.jpg"))
    before = web_copy(os.path.join(OUT, "flip", f"flip_{name}_before.png"), f"flip_{name}_before.jpg")
    flip[name] = {"before": before, "frames": frames, "times": times}

css = """
body { font: 15px/1.45 -apple-system, Helvetica, sans-serif; margin: 24px auto; max-width: 1280px; color: #222; background: #f6f5f1; }
h1 { font-size: 24px; } h2 { margin-top: 36px; border-bottom: 1px solid #ccc; padding-bottom: 4px; }
.player img { width: 100%; display: block; border-radius: 4px; }
.controls { margin: 8px 0 4px; display: flex; gap: 10px; align-items: center; }
.controls input[type=range] { flex: 1; }
.grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.grid figure, .pair figure { margin: 0; } .grid img, .pair img { width: 100%; border-radius: 3px; }
figcaption { font-size: 12px; color: #555; }
.pair { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 14px; }
table { border-collapse: collapse; font-size: 13px; } td, th { border: 1px solid #ccc; padding: 3px 8px; text-align: right; } th { background: #ebe9e2; }
td.l, th.l { text-align: left; } code, pre { font-size: 12px; } pre { white-space: pre-wrap; background: #ebe9e2; padding: 8px; }
.note { color: #555; font-size: 13px; }
"""

parts = [f"<!doctype html><meta charset=utf-8><title>Round k2: appear and settle; round k1: rounded rock</title><style>{css}</style>",
         "<h1>Appear-and-settle after an edit (k2), rounded rock edges (k1)</h1>",
         "<p>Layout 7301, day. Each sequence: the island before the edit, then the motion from the moment the edit lands (t = 0) to 1.5 s, 30 frames a second, "
         "rendered off screen at 1512 x 982 (shown at 1000 px). Use the slider to scrub; <b>Slow</b> plays at a quarter speed. "
         "Full-size key frames (3024 x 1964) are in <code>keys/</code>. Read <code>README.md</code> for what moves and how.</p>"]

for name, title in SEQ:
    f = flip[name]
    parts.append(f"<h2>{html.escape(title)} <span class=note>({name})</span></h2>")
    if not f["frames"]:
        parts.append("<p class=note>Frames missing.</p>")
        continue
    data = json.dumps(f["frames"])
    times = json.dumps(f["times"])
    parts.append(f"""<div class=player id=p_{name}><img id=i_{name} src="{f['frames'][0]}">
<div class=controls><button onclick="go('{name}',1)">Play</button><button onclick="go('{name}',0.25)">Slow</button><button onclick="beforeShot('{name}')">Before</button>
<input type=range min=0 max={len(f['frames']) - 1} value=0 id=r_{name} oninput="show('{name}',this.value)"><span id=t_{name}>t = 0 ms</span></div></div>
<script>F['{name}']={{frames:{data},times:{times},before:"{f['before']}"}};</script>""")
    lat = latency.get(name)
    if lat:
        parts.append(f"<p class=note>Edit latency (this tool, one full rebuild): {html.escape(lat)}</p>")

parts.insert(1, "<script>var F={}, T={};function show(n,k){var f=F[n];document.getElementById('i_'+n).src=f.frames[k];document.getElementById('r_'+n).value=k;document.getElementById('t_'+n).textContent='t = '+f.times[k]+' ms';}"
             "function beforeShot(n){clearInterval(T[n]);document.getElementById('i_'+n).src=F[n].before;document.getElementById('t_'+n).textContent='before the edit';}"
             "function go(n,speed){clearInterval(T[n]);var f=F[n],k=-8;document.getElementById('i_'+n).src=f.before;"
             "T[n]=setInterval(function(){k++;if(k<0)return;if(k>=f.frames.length){clearInterval(T[n]);return;}show(n,k);},1000/30/speed);}"
             "window.onload=function(){for(var n in F){F[n].frames.forEach(function(s){new Image().src=s;});}};</script>")

# Key frames at full size (reduced copies).
parts.append("<h2>Key frames (3024 x 1964, reduced)</h2>")
for name, title in SEQ:
    cells = [("before", os.path.join(OUT, "keys", f"keys_{name}_before.png"))] + [(f"t = {ms} ms", os.path.join(OUT, "keys", f"keys_{name}_t{ms:04d}.png")) for ms in KEYS]
    figs = []
    for cap, src in cells:
        if os.path.exists(src):
            figs.append(f"<figure><a href='{os.path.relpath(src, OUT)}'><img src='{web_copy(src, os.path.basename(src)[:-4] + '.jpg', 640)}'></a><figcaption>{name}, {cap}</figcaption></figure>")
    parts.append("<div class=grid>" + "".join(figs) + "</div>")

# Frame cost.
parts.append("<h2>Frame cost at 3024 x 1964, moving camera (scale 1, FXAA)</h2>")
parts.append("<p class=note>Each sequence's camera orbiting, 120 frames, two runs (a / b). <i>Settled</i>: the edited island at rest, shadow map cached (as all earlier benches). "
             "<i>Shadow redrawn</i>: the same with the sun's shadow map redrawn every frame, which moving geometry needs. <i>During the motion</i>: the settle clock running over the whole motion, shadow map redrawn. "
             "Load averages at the start and end of each run: " + html.escape("; ".join(loads)) + "</p>")
parts.append("<table><tr><th class=l>sequence</th><th>settled ms</th><th>shadow redrawn ms</th><th>during the motion ms</th><th>motion cost over settled</th></tr>")
for name, _ in SEQ:
    rows = bench.get(name, [])
    if not rows:
        continue
    s = [f"{r[0]:.2f}" for r in rows]
    w = [f"{r[1]:.2f}" for r in rows]
    m = [f"{r[2]:.2f}" for r in rows]
    extra = [f"{r[2] - r[0]:+.2f}" for r in rows]
    parts.append(f"<tr><td class=l>{name}</td><td>{' / '.join(s)}</td><td>{' / '.join(w)}</td><td>{' / '.join(m)}</td><td>{' / '.join(extra)}</td></tr>")
parts.append("</table>")

# Rocks (k1).
parts.append("<h2>Rounded rock edges (round k1, commit f0a77fe): before / after</h2>")
parts.append("<p class=note>Before: the k1 round's render of 81d1f12. After: this build (identical island geometry to f0a77fe; see the regression line below). 3024 x 1964 stills, click for full size.</p>")
for view in ROCK_VIEWS:
    a = os.path.join(OUT, "rocks_before", f"study_{view}.png")
    b = os.path.join(OUT, "rocks", f"rocks_{view}.png")
    if os.path.exists(a) and os.path.exists(b):
        parts.append(f"<div class=pair><figure><a href='{os.path.relpath(a, OUT)}'><img src='{web_copy(a, 'rock_before_' + view + '.jpg', 900)}'></a><figcaption>{view}, before (81d1f12)</figcaption></figure>"
                     f"<figure><a href='{os.path.relpath(b, OUT)}'><img src='{web_copy(b, 'rock_after_' + view + '.jpg', 900)}'></a><figcaption>{view}, after (f0a77fe)</figcaption></figure></div>")

parts.append("<h2>Checks</h2><pre>" + html.escape("Regression with no edit running (this build against the f0a77fe stills):\n" + "\n".join(regress) + "\n\nEdit locality:\n" + "\n".join(edit)) + "</pre>")
open(os.path.join(OUT, "compare.html"), "w").write("\n".join(parts))
print("compare.html written;", sum(len(f["frames"]) for f in flip.values()), "flipbook frames;", len(bench), "benched sequences")
print("\n".join(regress))
