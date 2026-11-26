#!/usr/bin/env python3
"""Builds compare.html for round k5b (art/lookdev/20261127_k5b). Run from the repository root:
    python3 art/lookdev/20261127_k5b/checks/build_compare.py [OUT]
"""
import glob, html, json, os, re, sys
from PIL import Image, ImageChops
import numpy as np

OUT = sys.argv[1] if len(sys.argv) > 1 else "art/lookdev/20261127_k5b"
WEB = os.path.join(OUT, "web")
os.makedirs(WEB, exist_ok=True)

def web(src, name, width):
    dst = os.path.join(WEB, name)
    if not os.path.exists(dst) and os.path.exists(src):
        im = Image.open(src).convert("RGB")
        im.resize((width, round(im.height * width / im.width)), Image.LANCZOS).save(dst, quality=87)
    return "web/" + name if os.path.exists(dst) else None

def crop(src, name, box, width):
    dst = os.path.join(WEB, name)
    if not os.path.exists(dst) and os.path.exists(src):
        im = Image.open(src).convert("RGB").crop(box)
        im.resize((width, round(im.height * width / im.width)), Image.LANCZOS).save(dst, quality=88)
    return "web/" + name if os.path.exists(dst) else None

def heat(before, after, name, width):
    """The settled frame with every pixel that changed by more than 12/255 tinted magenta; the
    share of changed pixels."""
    dst = os.path.join(WEB, name)
    if not (os.path.exists(before) and os.path.exists(after)):
        return None, None
    a = np.asarray(Image.open(before).convert("RGB")).astype(int)
    b = np.asarray(Image.open(after).convert("RGB")).astype(int)
    m = np.abs(a - b).max(axis=2) > 12
    out = b.copy()
    out[m] = (out[m] * 0.35 + np.array([235, 40, 200]) * 0.65).astype(int)
    im = Image.fromarray(out.astype(np.uint8))
    im.resize((width, round(im.height * width / im.width)), Image.LANCZOS).save(dst, quality=87)
    return "web/" + name, m.mean()

def lines(path, prefix):
    return [l.rstrip("\n") for l in open(path, errors="replace") if l.startswith(prefix)] if os.path.exists(path) else []

def fig(src, cap, link=None):
    if not src:
        return f"<figure><figcaption>{html.escape(cap)}: missing</figcaption></figure>"
    a = f"<a href='{link}'>" if link else ""
    return f"<figure>{a}<img src='{src}'>{'</a>' if link else ''}<figcaption>{html.escape(cap)}</figcaption></figure>"

def video(path, cap):
    return f"<figure><video src='{path}' controls loop muted preload=metadata></video><figcaption>{html.escape(cap)}</figcaption></figure>" if os.path.exists(os.path.join(OUT, path)) else f"<figure><figcaption>{html.escape(cap)}: missing</figcaption></figure>"

css = """body{font:15px/1.45 -apple-system,Helvetica,sans-serif;margin:24px auto;max-width:1320px;color:#222;background:#f6f5f1}
h1{font-size:24px}h2{margin-top:38px;border-bottom:1px solid #ccc;padding-bottom:4px}h3{margin:18px 0 6px}
.row{display:grid;gap:6px;margin-bottom:10px}.r3{grid-template-columns:1fr 1fr 1fr}.r2{grid-template-columns:1fr 1fr}
figure{margin:0}img,video{width:100%;border-radius:3px;display:block}figcaption{font-size:12px;color:#555}
table{border-collapse:collapse;font-size:13px;margin:8px 0}td,th{border:1px solid #ccc;padding:3px 7px;text-align:right}th{background:#ebe9e2}td.l,th.l{text-align:left}
pre{white-space:pre-wrap;background:#ebe9e2;padding:8px;font-size:12px}.note{color:#555;font-size:13px}.answer{background:#fff;border:1px solid #ccc;padding:10px 14px}"""
P = [f"<!doctype html><meta charset=utf-8><title>Round k5b</title><style>{css}</style>",
     "<h1>Round k5b: local edits, unloading as retract-then-merge, rock walls without stripes</h1>",
     "<p class=note>Owner review of 2026-11-26. Layout 7301 unless noted. Before = build dd9a597 (the round-k5 package); after = this round. Videos play in the browser (H.264). README.md has the details.</p>"]
answer = open(os.path.join(OUT, "answer_q4.html")).read() if os.path.exists(os.path.join(OUT, "answer_q4.html")) else "<p>(see README.md)</p>"
P.append("<h2>Question 4: is the original procedural generation at fault?</h2><div class=answer>" + answer + "</div>")

# (a) Unload.
P.append("<h2>(a) Unloading a raised block: retract, then merge</h2>")
P.append("<p class=note>After: the old block (top, walls, grass) sinks straight into the lawn by the height it loses, settles with a small overshoot and merges; the lawn under it stays where it is. Before: the new lawn was pulled up to the block's old height and released, so for a moment it spanned from the block's top to the ground as stretched faces, then flattened.</p>")
P.append("<div class='row r2'>" + video("motion_mp4/unload.mp4", "after: unload a block raised 1 m (two lower strokes, one edit)") + video("motion_before_mp4/unraise.mp4", "before: lower a raised block by 0.5 m (the case the owner saw)") + "</div>")
P.append("<div class='row r2'>" + video("motion_mp4/unraise.mp4", "after: lower a raised block by 0.5 m") + video("motion_mp4/lower.mp4", "after: lower a lawn patch by 1 m (the lawn sinks to become the pit floor)") + "</div>")
P.append("<div class='row r2'>" + video("motion_before_mp4/lower.mp4", "before: lower a lawn patch by 1 m") + video("motion_mp4/ramp.mp4", "after: a ramp (its lower half lowers: the old terrace edge retracts)") + "</div>")
for name, src, tag in [("after: unload", "motion", "motion_unload"), ("before: unraise", "motion_before", "motion_before_unraise")]:
    figs = []
    for t in ["before", "t0000", "t0100", "t0200", "t0333", "t0567"]:
        p = web(os.path.join(OUT, src, f"{tag}_{t}.png"), f"{tag}_{t}.jpg", 420)
        figs.append(fig(p, f"{name} {t}"))
    P.append("<div class='row' style='grid-template-columns:repeat(6,1fr)'>" + "".join(figs) + "</div>")

# (b) Coupling.
P.append("<h2>(b) Edits stay local: no coupled changes, no restart</h2>")
P.append("<p class=note>Each pair: the whole island from the front (and from behind) before the edit and after it has settled, with every pixel that changed tinted magenta. Before this round, erasing or adding land at the rim changed rock 10 to 22 m away (rim blocks re-planned, the hanging columns and the liner moved), all at the moment the edit landed; now only the rock at the edit and its immediate neighbours changes.</p>")
for seq in ["erase", "expand"]:
    for side in ["front", "back"]:
        row = []
        for b in ["before", "after"]:
            src_b = os.path.join(OUT, f"couple_{b}", f"{side}_{seq}_before.png")
            src_a = os.path.join(OUT, f"couple_{b}", f"{side}_{seq}_t1500.png")
            p, share = heat(src_b, src_a, f"heat_{b}_{side}_{seq}.jpg", 640)
            row.append(fig(p, f"{seq}, {side}, {'before this round' if b == 'before' else 'after'}: {share * 100:.2f} % of pixels changed" if share is not None else f"{seq} {side} {b}"))
        P.append("<div class='row r2'>" + "".join(row) + "</div>")
P.append("<h3>Triangles the edit changed (this build), and how far from the edit</h3>")
P.append("<pre>" + html.escape("\n".join(l.replace("; decor 0 of 0 triangles new, farthest 0.00 m from the edit, 0 beyond 3 m, 0 beyond 6 m", "") for l in lines(os.path.join(OUT, "diff.log"), "DIFF"))) + "</pre>")
figs = [fig(web(os.path.join(OUT, "diff", f"diffwhole_{s}_diff.png"), f"diffwhole_{s}.jpg", 640), f"{s}: triangles new after the edit, magenta") for s in ["erase", "expand"]]
P.append("<div class='row r2'>" + "".join(figs) + "</div>")
# Real time.
P.append("<h3>On the Mac's display with an erase every 2.5 s (3600 x 2338, 120 Hz), before and after</h3>")
P.append("<table><tr><th class=l>build</th><th class=l>scenario</th><th>fps on glass</th><th>interval p50 / p95 / p99 / max ms</th><th>intervals over 25 ms</th><th>GPU p50 / p95 ms</th><th>edit to glass ms</th><th>rebuild ms</th></tr>")
for r in ["before", "after"]:
    p = os.path.join(OUT, "window", f"win_{r}_summary.json")
    if not os.path.exists(p):
        continue
    for s in json.load(open(p)):
        e = s.get("edits", [])
        iv = " / ".join("%.2f" % x for x in s["glass_interval_ms"])
        gpu = " / ".join("%.2f" % x for x in s["gpu_ms"])
        eg = ", ".join("%.0f" % x["to_glass_ms"] for x in e if x.get("to_glass_ms"))
        rb = ", ".join("%.0f" % x["rebuild_ms"] for x in e)
        P.append(f"<tr><td class=l>{r}</td><td class=l>{s['scenario']}</td><td>{s['glass_fps']:.2f}</td><td>{iv}</td><td>{s['over_25ms']}</td><td>{gpu}</td><td>{eg}</td><td>{rb}</td></tr>")
P.append("</table>")
loads = [open(f).read().splitlines()[2] if len(open(f).read().splitlines()) > 2 else "" for f in sorted(glob.glob(os.path.join(OUT, "window", "*.load")))]
P.append("<p class=note>Load at the runs: " + html.escape(" | ".join(loads)) + "</p>")

# (c) Walls.
P.append("<h2>(c) Rock walls without the vertical stripes</h2>")
P.append("<p class=note>The stripes were thin pieces round k5 added where two rim blocks meet: a 3.5 cm corner arc that caught the light, a 0.22 m overlap that left a sliver of each block's end showing, and a backing plate behind every joint. Now two blocks that meet nearly flush (or at an inside turn of the rim) share one sharp corner, a single crease; the plates are gone; folds are fewer and softer. Larger steps keep the accepted rounded edge.</p>")
for v, box in [("foot_front", (500, 400, 3000, 1900)), ("cliff_close", (300, 400, 2300, 1700)), ("reverse", (700, 900, 2400, 1800)), ("side_286", (700, 900, 2600, 1900))]:
    b = crop(os.path.join(OUT, "walls_before", f"walls_before_{v}.png"), f"walls_before_{v}.jpg", box, 640)
    a = crop(os.path.join(OUT, "walls", f"walls_{v}.png"), f"walls_{v}.jpg", box, 640)
    P.append("<div class='row r2'>" + fig(b, f"{v}, before", f"walls_before/walls_before_{v}.png") + fig(a, f"{v}, after", f"walls/walls_{v}.png") + "</div>")
for v in ["wide", "low", "top"]:
    b = web(os.path.join(OUT, "demo_before", f"demo_before_after_{v}.png"), f"demo_before_{v}.jpg", 640)
    a = web(os.path.join(OUT, "demo_after", f"demo_after_after_{v}.png"), f"demo_after_{v}.jpg", 640)
    P.append("<div class='row r2'>" + fig(b, f"island built from one mound, {v}, before") + fig(a, f"the same strokes, {v}, after") + "</div>")

# Construction.
P.append("<h2>Built from one mound with the brush tools (this build)</h2>")
P.append("<p class=note>The same script as the k5 package (runtime/spikes/s34_study/data/demo_mound_build.json), replayed through the edit path (brush.rs), 30 frames a second of scene time. Unloading (lower strokes over raised ground) now retracts; erasing no longer moves rock away from the stroke.</p>")
P.append("<video src='construction.mp4' controls preload=metadata></video>" if os.path.exists(os.path.join(OUT, "construction.mp4")) else "<p>construction.mp4 missing</p>")
P.append("<pre>" + html.escape("\n".join(lines(os.path.join(OUT, "construction.log"), "DEMO"))) + "</pre>")

# Checks.
holes = []
for f in sorted(glob.glob(os.path.join(OUT, "parts", "parts_*.png"))):
    a = np.asarray(Image.open(f).convert("RGB")).astype(int)
    holes.append(f"{os.path.basename(f)}: {int(((a[:, :, 0] > 200) & (a[:, :, 1] < 60) & (a[:, :, 2] > 200)).sum())} back-facing island pixels")
P.append("<h2>Checks</h2><pre>" + html.escape("Hole check (--debug=parts, twelve views):\n" + "\n".join(holes) + "\n\nEdit locality test:\n" + "\n".join(lines(os.path.join(OUT, "edit.log"), "EDIT "))) + "</pre>")
open(os.path.join(OUT, "compare.html"), "w").write("\n".join(P))
print("compare.html written")
