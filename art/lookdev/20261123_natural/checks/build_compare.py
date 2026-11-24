#!/usr/bin/env python3
"""Regenerate art/lookdev/20261123_natural/compare.html (second review) from what is on disk.

Run from the repo root:
    python3 art/lookdev/20261123_natural/checks/build_compare.py

Standard library only. Safe to re-run after frames are re-rendered: the page refers to frames by
run and view name, never by content. Prints one summary line, then one line per missing file.
Frames: final2/ (second review, "after"), final/ (first review, "before"), crops2/ (native-pixel
crops, checks/make_crops.py), colour boxes from checks/boxes.json (checks/measure_boxes.py).
"""

import html
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.dirname(HERE)
OUT = os.path.join(PKG, "compare.html")

GODOT_TAG = "godot-freeze-20261122"
REF = "../20261122_g1/godot_baseline"
NEW = "final2"
OLD = "final"

VIEWS = ["whole", "game", "close", "overview", "reverse", "cliff_close", "terrace_close",
         "side_106", "side_286", "foot_front", "foot_reverse", "outer_hull"]
LAYOUT_VIEWS = ["whole", "game", "reverse", "overview"]
LAYOUTS = [("2104", "n_2104"), ("4242", "n_4242"), ("913", "n_913")]
RAMP_VIEWS = [
    ("ramp1", "n_7301", "n_7301_ramps", "layout 7301, three ramps joining the four lawn levels"),
    ("ramp2", "n_7301", "n_7301_ramps", "layout 7301"),
    ("ramp3", "n_7301", "n_7301_ramps", "layout 7301"),
    ("slope", "n_4242", "n_slope", "layout 4242, a broad hillside"),
    ("diag1", "n_2104", "n_diag", "layout 2104, two diagonal ramps"),
    ("diag2", "n_2104", "n_diag", "layout 2104"),
]
WALL_VIEWS = ["foot_front", "outer_hull", "cliff_close", "reverse", "foot_reverse", "side_106"]
WATER_VIEWS = ["terrace_close", "close", "outer_hull"]

# Godot's own cost at 3024x1964 on the same Mac (art/lookdev/20261122_freeze/README.md:
# tools/perf/bench_presets.gd, default 623-cell island, one island in view, single viewport).
GODOT_BENCH = [
    ("native (4x MSAA, the reference frames' tier)", {"whole": 30.62, "game": 38.36, "reverse": 29.28}),
    ("balanced (Godot's default)", {"whole": 23.68, "game": 29.42, "reverse": 22.39}),
    ("light", {"whole": 14.64, "game": 18.91, "reverse": 13.70}),
]

BENCHES = [
    ("bench_moving", "moving camera: one island, layout 7301, twelve views"),
    ("bench_moving_ramps", "moving camera: layout 7301 with three ramps, twelve views"),
    ("bench_moving_trio", "moving camera: three islands, wallpaper view"),
    ("bench_moving_syn4096", "moving camera: the 4,096-cell island"),
    ("bench_moving_syn4096_ramps", "moving camera: the 4,096-cell island with ramps"),
    ("bench_rest", "resting camera: 2x supersampling, one island"),
]
BUILD_RUNS = [
    ("n_7301", "layout 7301"), ("n_7301_ramps", "layout 7301 with three ramps"),
    ("n_2104", "layout 2104"), ("n_diag", "layout 2104 with two diagonal ramps"),
    ("n_4242", "layout 4242"), ("n_slope", "layout 4242 with a hillside"),
    ("n_913", "layout 913"), ("n_syn4096", "the 4,096-cell island"),
    ("n_syn4096_ramps", "the 4,096-cell island with ramps"),
]

KNOWN = [
    "Rock at native pixels: the painted brushwork on the cliff faces is blotchier and less "
    "vertically streaked than Godot's, and the tops of the buttress slabs show a faint crease.",
    "Ramps read gently in the general views because grass covers them like any lawn; that is why "
    "each has its own camera view.",
    "A ramp is a flat plane per cell with rounded creases between cells, not yet a free-form hill "
    "tool.",
    "The 4,096-cell island with real props is close to the 12 ms budget while moving (an estimated 10 to 11 ms "
    "on an idle machine; 13.4 to 14.2 ms as measured on the busy machine, over the budget): cut-out leaf "
    "cards are drawn over each other many times and props have no simpler distance versions yet.",
    "The three-island wallpaper view still uses a simpler cloud sea and no far hills.",
    "Godot's far depth-of-field blur is not ported; distant things are paler, not blurred.",
    "No sparkle glints on the water.",
    "Nothing moves in these stills: wind, water and the falls are built to move and are shown frozen.",
    "All of this is study-tool code, to be rebuilt in the real renderer.",
]

esc = html.escape
missing = []
img_count = 0


def exists(rel):
    return os.path.isfile(os.path.join(PKG, rel))


def ref(hour_or_set, view):
    return (f"{REF}/{hour_or_set}/{view}.png", f"{REF}/{hour_or_set}/small/{view}.png",
            f"Godot ({GODOT_TAG}) &middot; {esc(hour_or_set)} &middot; {esc(view)}")


def run(name, view, label="after", root=NEW):
    return (f"{root}/{name}/{name}_{view}.png", f"{root}/{name}/small/{name}_{view}.png",
            f"{esc(label)} &middot; {esc(root)}/<b>{esc(name)}</b> &middot; {esc(view)}")


def before(name, view):
    return run(name, view, "before (first review)", OLD)


def single(path, cap):
    return path, path, cap


def crop(name, cap):
    return single(f"crops2/{name}.png", f"{cap} &middot; native pixels")


def figure(spec):
    global img_count
    full, small, cap = spec
    has_full, has_small = exists(full), exists(small)
    if not has_full and not has_small:
        missing.append(full)
        return (f'<figure><div class="missing">missing<br><code>{esc(full)}</code></div>'
                f'<figcaption>{cap}</figcaption></figure>')
    if not has_full:
        missing.append(full)
    if not has_small:
        missing.append(small)
    img_count += 1
    src = small if has_small else full
    href = full if has_full else small
    return (f'<figure><a href="{esc(href)}"><img src="{esc(src)}" loading="lazy" alt="{esc(src)}"></a>'
            f'<figcaption>{cap}</figcaption></figure>')


def row(specs, label=None, cols=None):
    head = f"<h4>{esc(label)}</h4>" if label else ""
    return f'{head}<div class="row n{cols or len(specs)}">{"".join(figure(s) for s in specs)}</div>'


def table(headers, rows, cls="num"):
    th = "".join(f"<th>{h}</th>" for h in headers)
    trs = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>" for r in rows)
    return f'<table class="{cls}"><thead><tr>{th}</tr></thead><tbody>{trs}</tbody></table>'


def read_text(rel):
    path = os.path.join(PKG, rel)
    if not os.path.isfile(path):
        missing.append(rel)
        return None
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def load_json(rel, required=True):
    try:
        with open(os.path.join(PKG, rel), encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        if required:
            missing.append(rel)
    except ValueError as exc:
        missing.append(f"{rel} (unreadable: {exc})")
    return None


def fmt_ms(v):
    return f"{v:.2f}" if isinstance(v, (int, float)) else "&ndash;"


def bench_table():
    rows = []
    for name, what in BENCHES:
        new = load_json(f"{NEW}/{name}/metrics.json") or {}
        old = {b.get("view"): b.get("ms") for b in (load_json(f"{OLD}/{name}/metrics.json", False) or {}).get("bench") or []}
        for b in new.get("bench") or []:
            ms = b.get("ms")
            rows.append([esc(name), esc(what), esc(str(b.get("view"))), fmt_ms(ms),
                         f"{1000.0 / ms:.0f}" if isinstance(ms, (int, float)) and ms > 0 else "&ndash;",
                         fmt_ms(old.get(b.get("view"))),
                         "12" if name != "bench_rest" else "paid once when the camera stops"])
    return table(["run", "what", "view", "ms per frame (this review, machine busy)", "frames per second",
                  "first review ms (idle machine)", "budget ms"], rows)


CONTROL = f"{NEW}/control"
BENCH_RE = re.compile(r"^BENCH (\w+): ([\d.]+) ms", re.M)


def bench_log(rel):
    path = os.path.join(PKG, rel)
    if not os.path.isfile(path):
        missing.append(rel)
        return {}
    with open(path, encoding="utf-8", errors="replace") as fh:
        return {v: float(ms) for v, ms in BENCH_RE.findall(fh.read())}


def mean(xs):
    xs = [x for x in xs if isinstance(x, (int, float))]
    return sum(xs) / len(xs) if xs else None


def control_block():
    """Like-for-like control: first package build (e32b851) and current build, same load, twice."""
    if not exists(f"{CONTROL}/DONE"):
        return ("<p><b>Control bench not available:</b> the like-for-like run of the first package's build "
                "against the current build under the same load had not finished when this page was built "
                f"({CONTROL}/DONE missing). Only the numbers below, taken on a busy machine, are shown.</p>"), None
    idle = {}
    for name in ("bench_moving", "bench_moving_syn4096"):
        idle[name] = {b.get("view"): b.get("ms") for b in (load_json(f"{OLD}/{name}/metrics.json") or {}).get("bench") or []}
    rows, ratios, est = [], {"one": [], "big": []}, {"one": [], "big": [], "now_big": []}
    for key, label, idle_run in (("7301", "one island, layout 7301", "bench_moving"),
                                 ("syn", "the 4,096-cell island", "bench_moving_syn4096")):
        fa, fb = bench_log(f"{CONTROL}/first_{key}.log"), bench_log(f"{CONTROL}/first_{key}_b.log")
        na, nb = bench_log(f"{CONTROL}/now_{key}.log"), bench_log(f"{CONTROL}/now_{key}_b.log")
        for view in [v for v in VIEWS if v in fa or v in na]:
            f, n = mean([fa.get(view), fb.get(view)]), mean([na.get(view), nb.get(view)])
            ratio = n / f if f and n else None
            idle_ms = idle[idle_run].get(view)
            e = idle_ms * ratio if ratio and isinstance(idle_ms, (int, float)) else None
            group = "one" if key == "7301" else "big"
            if ratio:
                ratios[group].append(ratio)
            if e:
                est[group].append(e)
            if n and group == "big":
                est["now_big"].append(n)
            rows.append([esc(label), esc(view), fmt_ms(fa.get(view)), fmt_ms(fb.get(view)), fmt_ms(na.get(view)),
                         fmt_ms(nb.get(view)), f"{ratio:.2f}" if ratio else "&ndash;", fmt_ms(idle_ms),
                         fmt_ms(e)])
    loads = []
    for name in ("first_7301", "now_7301", "first_syn", "now_syn", "first_7301_b", "now_7301_b", "first_syn_b", "now_syn_b"):
        text = read_text(f"{CONTROL}/{name}.load") or ""
        m = re.search(r"load averages?: ([\d., ]+)", text)
        loads.append([esc(name), esc(m.group(1).strip() if m else "?")])
    rng = lambda xs: (f"{min(xs):.2f} to {max(xs):.2f}" if xs else "&ndash;")
    summary = {"ratio_one": rng(ratios["one"]), "ratio_big": rng(ratios["big"]),
               "est_one": rng(est["one"]), "est_big": rng(est["big"]), "now_big": rng(est["now_big"]),
               "big_over": bool(est["now_big"]) and max(est["now_big"]) > 12.0}
    html_ = ["<h3>Like-for-like control: the first package's build against the current build, same load</h3>",
             '<p class="note">Because the machine was busy, the build of the first owner package (commit e32b851) '
             "and the current build were benchmarked back to back under the same load, twice (passes a and b), "
             "moving camera, 3024x1964, 120 frames per view. The ratio is current over first (mean of both "
             "passes): it is what the four changes cost, independent of the load.</p>",
             table(["island", "view", "first build a ms", "first build b ms", "current build a ms",
                    "current build b ms", "ratio current / first", "first package, idle machine ms",
                    "<b>estimate</b>: current build, idle machine ms"], rows),
             f"<p>Ratio current / first: one island {summary['ratio_one']}, the 4,096-cell island {summary['ratio_big']}. "
             "The first package measured 5.2 to 7.0 ms for one island and 10.4 to 11.1 ms for the 4,096-cell island "
             "on an idle machine. Applying the ratio gives an <b>estimate</b> for the current build on an idle machine "
             f"of {summary['est_one']} ms for one island and {summary['est_big']} ms for the 4,096-cell island. "
             "These are estimates until the benches are repeated on an idle machine.</p>"]
    if summary["big_over"]:
        html_.append(f"<p><b>Measured under load, the current build's 4,096-cell island exceeds the 12 ms budget</b> "
                     f"({summary['now_big']} ms in this control).</p>")
    html_ += ["<h4>Load average at the start of each control run (1, 5 and 15 minutes)</h4>",
              table(["run", "load average"], loads)]
    return "".join(html_), summary


def load_block():
    text = read_text(f"{NEW}/load_at_benches.txt")
    if text is None:
        return "<p>Machine load file missing.</p>"
    lines = [ln.rstrip()[:160] for ln in text.splitlines()[:12]]
    return "<pre>" + esc("\n".join(lines)) + "</pre>"


def build_table():
    rows = []
    for name, what in BUILD_RUNS:
        text = read_text(f"{NEW}/{name}.log")
        if text is None:
            continue
        for m in re.finditer(r"^island: (\d+) cells.*?built in ([\d.]+) ms", text, re.M):
            rows.append([esc(name), esc(what), m.group(1), f"{float(m.group(2)):.0f}"])
            break
    return table(["run", "island", "cells", "build ms (from scratch)"], rows)


EDIT_RE = re.compile(r"EDIT\s+(\w+)\s+(.*?): (\d+) faces changed, farthest ([\d.]+) m from the stroke, (\d+) beyond 12 m"
                     r"(?:; top surface (\d+) of (\d+) vertices changed, farthest ([\d.]+) m, (\d+) beyond 12 m)?")


def edit_results():
    text = read_text(f"{NEW}/edit_test.log")
    if text is None:
        return "edit test log missing", ""
    island = None
    strokes, beyond, farthest = 0, 0, 0.0
    ramp_rows = []
    for line in text.splitlines():
        if line.startswith("== "):
            island = line[3:].strip()
            continue
        m = EDIT_RE.match(line)
        if not m:
            continue
        strokes += 1
        beyond += int(m.group(5))
        farthest = max(farthest, float(m.group(4)))
        if m.group(1) in ("ramp", "diag"):
            top_b = int(m.group(9) or 0)
            beyond += top_b
            ramp_rows.append([esc(island or ""), esc(("diagonal " if m.group(1) == "diag" else "") + m.group(2)), m.group(3), m.group(4),
                              f"{m.group(6)} of {m.group(7)}" if m.group(6) else "&ndash;",
                              m.group(8) or "&ndash;", str(int(m.group(5)) + top_b)])
    rel = f"{NEW}/edit_test.log"
    summary = (f"{strokes} strokes on five islands (layouts 7301, 2104, 4242, 913 and the 4,096-cell island), "
               f"of them {len(ramp_rows)} ramp strokes (one straight and one diagonal per island; layouts 7301 and 2104 share the same cells, so their results agree): {beyond} changes farther than 12 m from a stroke; "
               f"the farthest rim change was {farthest:.1f} m away. Full lines: <a href=\"{rel}\">{rel}</a>.")
    ramp_table = table(["island", "ramp stroke (from, to; width 2)", "rim faces changed", "farthest rim change m",
                        "lawn surface vertices changed", "farthest surface change m", "changes beyond 12 m"],
                       ramp_rows)
    return summary, ramp_table


def box_rows(pred):
    data = load_json("checks/boxes.json") or {}
    fmt = lambda m: "(" + ", ".join(f"{v:.3f}" for v in m["median"]) + ")" if m else "&ndash;"
    num = lambda v: f"{v:.3f}" if isinstance(v, (int, float)) else "&ndash;"
    rows = []
    for b in data.get("boxes") or []:
        if not pred(b):
            continue
        rb, ob = b.get("reference_box", b.get("box", [])), b.get("box", [])
        boxes = ",".join(map(str, ob)) if rb == ob else f"Godot {','.join(map(str, rb))}<br>ours {','.join(map(str, ob))}"
        rows.append([esc(b.get("hour", "")), esc(b.get("view", "")), esc(b.get("name", "")), boxes,
                     fmt(b.get("reference")), fmt(b.get("before")), fmt(b.get("runtime")),
                     num(b.get("before_max_channel_difference")), num(b.get("max_channel_difference"))])
    return table(["hour", "view", "box", "x0,y0,x1,y1 (1300 px copy)", "Godot median", "before median",
                  "after median", "before: largest channel difference", "after: largest channel difference"], rows)


CSS = """
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;
 margin:0 auto;max-width:1800px;padding:16px 24px 64px;color:#1c1c1c;background:#fafafa;line-height:1.4}
h1{font-size:1.5em;margin:.4em 0}
h2{font-size:1.25em;margin-top:2.2em;border-bottom:1px solid #ccc;padding-bottom:.2em}
h3{font-size:1.05em;margin-top:1.6em}
h4{font-size:.95em;margin:1.2em 0 .3em;color:#444}
.notice{border:2px solid #b07a00;background:#fff6dc;padding:12px 16px;border-radius:4px}
.change{border-left:4px solid #4a7a3a;padding-left:14px;margin-top:1.2em}
nav ol{margin:.3em 0 0 1.2em;padding:0}
.row{display:grid;gap:10px;margin:4px 0 14px}
.row.n1{grid-template-columns:minmax(0,1fr)}
.row.n2{grid-template-columns:repeat(2,minmax(0,1fr))}
.row.n3{grid-template-columns:repeat(3,minmax(0,1fr))}
figure{margin:0}
figure img{display:block;width:100%;height:auto;background:#ddd}
figcaption{font-size:.82em;color:#333;margin-top:3px}
.missing{width:100%;aspect-ratio:3024/1964;display:flex;flex-direction:column;align-items:center;
 justify-content:center;background:#fbeaea;border:2px dashed #b00;color:#900;font-weight:600;
 text-align:center;font-size:.9em;word-break:break-all;padding:8px;box-sizing:border-box}
table{border-collapse:collapse;margin:10px 0;font-size:.88em;background:#fff}
th,td{border:1px solid #ccc;padding:4px 8px;vertical-align:top}
th{background:#eee;text-align:left}
table.num td{text-align:right}
table.num td:first-child,table.num td:nth-child(2),table.num td:nth-child(3){text-align:left}
pre{background:#fff;border:1px solid #ccc;padding:8px;font-size:.82em;overflow-x:auto}
.note{font-size:.9em;color:#333}
"""

NOTICE = (
    "<b>Second review.</b> You asked for four changes after the first review: close the hollow "
    "joint in the terrace wall, make slopes and ramps buildable, bring the rock walls in line with the "
    "Godot baseline, and make the water clearer. Those four are at the top of this page, each with "
    "before, after and the Godot reference. Nothing else was changed on purpose; the rest of the "
    "page is the full set again so you can check that. "
    f"Godot columns: the Godot project frozen at tag {GODOT_TAG}, native tier, 4x MSAA. "
    "Runtime columns: the runtime study tool in its resting-camera mode, 2x supersampling (four "
    "samples per pixel, filtered down); same island cells, same cameras, same hour. "
    "Nothing on this page is art-accepted until you say so, and the next phase has not started."
)


def change_joint():
    b = ['<div class="change"><h3>1. The hollow joint in the terrace wall (day, game view)</h3>',
         "<p>Left of the waterfall, a joint in the middle terrace wall read as a hollow cavity. The dark "
         "patch was lower lawn wrongly painted as pond bed, and the slit was the wall's backing seen "
         "through a corner where three steps meet. Both are fixed: the lawn is lawn, and terrace walls "
         "now turn corners as one continuous piece of stone with their feet planted in the ground.</p>",
         row([single("owner_notes/hollow_joint_day_game.png", "your crop from the first review")],
             "Your note", cols=2),
         row([crop("before_game_joint", "before (first review)"), crop("after_game_joint", "after"),
              crop("ref_game_joint", f"Godot ({GODOT_TAG})")],
             "Same rectangle (963,735 to 1715,1424 of the full game frame)"),
         row([crop("moving_game_joint", "after, moving-camera mode (one sample per pixel, FXAA)")],
             "The same joint while the camera moves", cols=2),
         "</div>"]
    return "".join(b)


def change_ramps():
    edit_summary, ramp_table = edit_results()
    b = ['<div class="change"><h3>2. Slopes and ramps</h3>',
         "<p>You asked for slopes and ramps to be buildable. The island format now lets a cell carry a "
         "slope, and a ramp stroke joins two terraces; the generator then joins the surfaces, makes a "
         "soft grassy bank for small rises and a wedge of cut rock for large ones. Ramps work in any "
         "direction, including diagonals.</p>",
         "<p><b>The ramp stroke rule.</b> A ramp is drawn from a point on one terrace to a point on another, "
         "with a width; every cell whose centre lies inside that strip becomes part of one inclined plane "
         "running from the first height to the second. It is refused if either end is water or off the "
         "island, if it is shorter than 2 m, steeper than 0.6 (about 31 degrees), joins two equal heights, "
         "or would cover water.</p>",
         "<h4>Each ramp view: plain layout (left) and the layout with ramps (right). Click for the full frame.</h4>"]
    for view, plain, ramps, what in RAMP_VIEWS:
        b.append(row([run(plain, view, "plain layout"), run(ramps, view, "with ramps")], f"{view} · {what}"))
    b.append("<h4>Close up at native pixels, the middle 1500x1000 px of each ramp view (plain, with ramps)</h4>")
    for view, _, _, _ in RAMP_VIEWS:
        b.append(row([crop(f"{view}_plain", f"{view}, plain"), crop(f"{view}_ramp", f"{view}, with ramps")]))
    b.append("<h4>Layout 7301 with three ramps in the review views (plain left, ramps right)</h4>")
    for v in ("game", "terrace_close", "close"):
        b.append(row([run("n_7301", v, "plain layout"), run("n_7301_ramps", v, "with ramps")], v))
    b.append("<h4>The ramps layout at dusk and night, and in moving-camera mode</h4>")
    b.append(row([run("n_dusk_ramps", v, "dusk") for v in ("game", "ramp1", "ramp2")]))
    b.append(row([run("n_night_ramps", v, "night") for v in ("game", "ramp1", "ramp2")]))
    b.append(row([run("n_moving_ramps", v, "moving camera") for v in ("ramp1", "ramp2", "ramp3")]))
    b.append("<h4>Edits stay local</h4>")
    b.append(f"<p>Scripted edit test: {edit_summary} The ramp strokes:</p>")
    b.append(ramp_table)
    b.append("</div>")
    return "".join(b)


def change_walls():
    b = ['<div class="change"><h3>3. Rock walls: rendering, block size and arrangement</h3>',
         "<p>You asked for the rock walls and the size and arrangement of their blocks to align with the "
         "Godot baseline. The cliff is now tall full-height faces with a few large wedge-topped buttress "
         "slabs, sized after Godot's cliff scripts, painted in the reference's warm beige with its strong "
         "sun and shade contrast. The hanging columns under the island are fewer and fade into the cloud "
         "behind them, and rock faces facing the camera carry a lawn cap and grass fringe instead of a "
         "bare ledge.</p>",
         "<h4>Godot (left), before (middle), after (right)</h4>"]
    for v in WALL_VIEWS:
        b.append(row([ref("day", v), before("n_7301", v), run("n_7301", v)], v))
    b.append("<h4>Native pixels, same rectangle: Godot, before, after</h4>")
    for name, view, rect in (("foot_front_cliff", "foot_front", "300,500 to 1600,1350"),
                             ("outer_hull_cliff", "outer_hull", "200,900 to 1500,1750")):
        b.append(row([crop(f"ref_{name}", "Godot"), crop(f"before_{name}", "before"), crop(f"after_{name}", "after")],
                     f"{view} ({rect})"))
    b.append('<h4>Measured wall colour (median of each box on the 1300 px copies)</h4>')
    b.append(box_rows(lambda x: x.get("group") == "wall" and x.get("hour") == "day"))
    b.append("</div>")
    return "".join(b)


def change_water():
    b = ['<div class="change"><h3>4. Clearer water</h3>',
         "<p>You asked for clearer, more limpid water. Ponds are now a clear layer over a visible pale bed "
         "with pebbles, with refraction (the bed shifts as seen through the surface), colour deepening "
         "with depth, a clearer margin at the shore and light lines on the bed; the mirror image of the "
         "sky and banks now sits lightly on top instead of covering it.</p>",
         "<h4>Godot (left), before (middle), after (right)</h4>"]
    for v in WATER_VIEWS:
        b.append(row([ref("day", v), before("n_7301", v), run("n_7301", v)], v))
    b.append(row([crop("ref_terrace_close_pond", "Godot"), crop("before_terrace_close_pond", "before"),
                  crop("after_terrace_close_pond", "after")],
                 "Native pixels, terrace_close pond (700,400 to 2000,1250)"))
    b.append('<h4>Measured pond colour</h4>')
    b.append(box_rows(lambda x: x.get("group") == "pond"))
    b.append("</div>")
    return "".join(b)


def build():
    sections = [("changes", "The four changes", change_joint() + change_ramps() + change_walls() + change_water())]

    body = [row([ref("day", v), run("n_7301", v)], v) for v in VIEWS]
    sections.append(("day", "Day, layout 7301: the twelve review views (Godot left, after right)", "".join(body)))

    body = []
    for hour, name in (("dusk", "n_dusk"), ("night", "n_night")):
        body.append(f"<h3>{hour.capitalize()}</h3>")
        body += [row([ref(hour, v), run(name, v)], f"{hour} · {v}") for v in VIEWS]
    sections.append(("hours", "Dusk and night, layout 7301", "".join(body)))

    body = []
    for seed, name in LAYOUTS:
        body.append(f"<h3>Layout {seed}</h3>")
        body += [row([ref(f"held{seed}", v), run(name, v)], f"{seed} · {v}") for v in LAYOUT_VIEWS]
    sections.append(("layouts", "The other three layouts", "".join(body)))

    body = ["<h3>Three islands, wallpaper view</h3>",
            row([run("n_trio", "wallpaper", "day")], "day"),
            row([run("n_trio_dusk", "wallpaper", "dusk")], "dusk"),
            row([run("n_trio_night", "wallpaper", "night")], "night"),
            "<h3>The 4,096-cell island (generated cells, the 7301 scene's props scattered over it): "
            "without ramps (left) and with one ramp across each long terrace wall (right)</h3>"]
    body += [row([run("n_syn4096", v, "no ramps"), run("n_syn4096_ramps", v, "with ramps")], v)
             for v in ("whole", "game", "overview")]
    sections.append(("runtime", "Runtime only: no Godot counterpart", "".join(body)))

    edit_summary, _ = edit_results()
    godot_rows = [[esc(t), f"{d['whole']:.2f}", f"{d['game']:.2f}", f"{d['reverse']:.2f}"] for t, d in GODOT_BENCH]
    control_html, _ = control_block()
    body = [control_html,
            "<h3>The review benches: frame cost at 3024x1964 (M4 Pro, mains power, off screen, 120 frames with the camera orbiting)</h3>",
            '<p class="note"><b>The machine was busy during these benches</b> (load average about 6.5: a VPN '
            "process near 100% of one core and several other applications; recorded below), so these "
            "numbers are not comparable with the first review's idle-machine numbers shown beside them "
            "(5.2 to 7.0 ms for one island, 10.4 to 11.1 ms for the 4,096-cell island). They are as "
            "measured; the control above is the fair comparison.</p>",
            bench_table(),
            "<h4>Machine load when the benches started (load_at_benches.txt)</h4>",
            load_block(),
            '<p class="note">The plan\'s budget is 12 ms a frame for a moving camera at 3024x1964 (60 frames '
            "a second with headroom). The resting mode (2x supersampling) is what the stills on this page "
            "use; it is paid once when the camera stops, not every frame.</p>",
            "<h3>Godot at the same resolution (freeze bench, <a href=\"../20261122_freeze/README.md\">../20261122_freeze/README.md</a>)</h3>",
            table(["Godot tier", "whole ms", "game ms", "reverse ms"], godot_rows),
            '<p class="note">tools/perf/bench_presets.gd on the default 623-cell island, one island in view, '
            "single viewport, at the freeze tag.</p>",
            "<h3>Island build (cells to drawable meshes, props and grass, from scratch)</h3>",
            build_table(),
            f"<h3>Edit locality</h3><p>{edit_summary}</p>"]
    sections.append(("cost", "Cost", "".join(body)))

    body = ['<p class="note">Median display colour of each box on the 1300 px reduced frames, measured by '
            "checks/measure_boxes.py (numbers in checks/boxes.json): Godot, the first review (before; walls "
            "and ponds only) and this review (after). Where the framing differs slightly the Godot box is "
            "given separately. The rounds worked to 0.02 per channel. The cliffs are a different "
            "construction, so a cliff box compares the tone of the stone, not the same block.</p>",
            box_rows(lambda x: True)]
    sections.append(("boxes", "All measured colour boxes", "".join(body)))

    body = ["<ul>" + "".join(f"<li>{esc(k)}</li>" for k in KNOWN) + "</ul>"]
    sections.append(("limits", "Known differences and limits", "".join(body)))

    toc = "".join(f'<li><a href="#{sid}">{esc(t)}</a></li>' for sid, t, _ in sections)
    content = "".join(f'<section id="{sid}"><h2>{esc(t)}</h2>{b}</section>' for sid, t, b in sections)
    page = (
        "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        "<title>Natural look, second review: Godot baseline and runtime</title>\n"
        f"<style>{CSS}</style>\n</head>\n<body>\n"
        f'<div class="notice">{NOTICE}</div>\n'
        "<h1>Natural look, second review: Godot baseline and runtime</h1>\n"
        "<p class=note>Generated by checks/build_compare.py. Click a frame for the full-size image. "
        "What to look for and what is asked of you: README.md beside this page.</p>\n"
        f"<nav><b>Contents</b><ol>{toc}</ol></nav>\n{content}\n</body>\n</html>\n"
    )
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(page)
    os.replace(tmp, OUT)


def main():
    build()
    uniq = sorted(set(missing))
    print(f"wrote {os.path.relpath(OUT, os.getcwd())}: {img_count} images, {len(uniq)} missing files")
    for p in uniq:
        print(f"missing: {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
