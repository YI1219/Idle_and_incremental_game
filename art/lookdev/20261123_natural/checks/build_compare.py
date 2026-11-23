#!/usr/bin/env python3
"""Regenerate art/lookdev/20261123_natural/compare.html from whatever is on disk.

Run from the repo root:
    python3 art/lookdev/20261123_natural/checks/build_compare.py

Standard library only. Safe to re-run after frames are re-rendered: the page refers to frames by
run and view name, never by content. Prints one summary line, then one line per missing file.
Colour boxes come from checks/boxes.json (written by checks/measure_boxes.py).
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

VIEWS = ["whole", "game", "close", "overview", "reverse", "cliff_close", "terrace_close",
         "side_106", "side_286", "foot_front", "foot_reverse", "outer_hull"]
LAYOUT_VIEWS = ["whole", "game", "reverse", "overview"]
CROP_VIEWS = ["game", "cliff_close", "terrace_close"]
LAYOUTS = [("2104", "n_2104"), ("4242", "n_4242"), ("913", "n_913")]

# Godot's own cost at 3024x1964 on the same Mac (art/lookdev/20261122_freeze/README.md:
# tools/perf/bench_presets.gd, default 623-cell island, one island in view, single viewport).
GODOT_BENCH = [
    ("native (4x MSAA, the reference frames' tier)", {"whole": 30.62, "game": 38.36, "reverse": 29.28}),
    ("balanced (Godot's default)", {"whole": 23.68, "game": 29.42, "reverse": 22.39}),
    ("light", {"whole": 14.64, "game": 18.91, "reverse": 13.70}),
]

NOTICE = (
    "Left column: the Godot project frozen at tag godot-freeze-20261122, native tier, 4x MSAA. "
    "Right column: the runtime study tool in its default resting-camera mode (2x supersampling: "
    "four samples per pixel, filtered down), same island cells, same cameras, same hour. "
    "The island body on the right is the hanging-rock construction kept from G1. "
    "Nothing on this page is art-accepted until the owner says so."
)

KNOWN = [
    "The three-island wallpaper view still uses a simpler cloud sea and no far hills: Godot's far "
    "field (cloud decks and mountain rings) was authored for its steep review cameras and thins out "
    "toward the horizon at the wallpaper's low camera.",
    "The far hills at the top left of the whole view sit differently from Godot's.",
    "Godot's far depth-of-field blur is not ported; distant things are paler, not blurred.",
    "No sparkle glints on the water.",
    "The 4,096-cell island with real props costs 10 to 11 ms a frame while moving, close to the "
    "12 ms budget: cut-out leaf cards overdraw, and props have no distance levels yet.",
    "Nothing is animated in these stills. Wind, water motion and the falls are built to move and "
    "are shown frozen.",
    "The island cliffs differ from Godot's on purpose: the body is the new hanging-rock "
    "construction from the same cells.",
    "Thin shaded joints remain where three terrace steps meet; they show rock, not the inside.",
    "All of this is study-tool code, to be rebuilt in the real renderer.",
]

esc = html.escape
missing = []
img_count = 0


def exists(rel):
    return os.path.isfile(os.path.join(PKG, rel))


def ref(hour_or_set, view):
    full = f"{REF}/{hour_or_set}/{view}.png"
    small = f"{REF}/{hour_or_set}/small/{view}.png"
    return full, small, f"Godot ({GODOT_TAG}) &middot; {esc(hour_or_set)} &middot; {esc(view)}"


def run(name, view, label="runtime"):
    full = f"final/{name}/{name}_{view}.png"
    small = f"final/{name}/small/{name}_{view}.png"
    return full, small, f"{esc(label)} &middot; run <b>{esc(name)}</b> &middot; {esc(view)}"


def crop(prefix, view, label):
    path = f"final/crops/{prefix}_{view}.png"
    return path, path, f"{esc(label)} &middot; {esc(view)} &middot; native pixels"


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


def row(specs, label=None):
    head = f"<h4>{esc(label)}</h4>" if label else ""
    return f'{head}<div class="row n{len(specs)}">{"".join(figure(s) for s in specs)}</div>'


def table(headers, rows, cls="num"):
    th = "".join(f"<th>{h}</th>" for h in headers)
    trs = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>" for r in rows)
    return f'<table class="{cls}"><thead><tr>{th}</tr></thead><tbody>{trs}</tbody></table>'


def load_json(rel):
    try:
        with open(os.path.join(PKG, rel), encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        missing.append(rel)
    except ValueError as exc:
        missing.append(f"{rel} (unreadable: {exc})")
    return None


def bench_rows():
    runs = [
        ("bench_moving", "moving camera: 1x, FXAA, one island (layout 7301)"),
        ("bench_moving_trio", "moving camera: three islands, wallpaper view"),
        ("bench_moving_syn4096", "moving camera: the 4,096-cell island"),
        ("bench_rest", "resting camera: 2x supersampling, one island"),
    ]
    rows = []
    for name, what in runs:
        m = load_json(f"final/{name}/metrics.json") or {}
        for b in m.get("bench") or []:
            ms = b.get("ms")
            rows.append([esc(name), esc(what), esc(str(b.get("view"))),
                         f"{ms:.2f}" if isinstance(ms, (int, float)) else "&ndash;",
                         f"{1000.0 / ms:.0f}" if isinstance(ms, (int, float)) and ms > 0 else "&ndash;",
                         "12" if name != "bench_rest" else "(one-off while still)"])
    return rows


def edit_summary():
    rel = "final/edit_test.log"
    path = os.path.join(PKG, rel)
    if not os.path.isfile(path):
        missing.append(rel)
        return "edit test log missing"
    strokes, beyond, farthest = 0, 0, 0.0
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r"EDIT\s+\S+\s+at .*?: (\d+) faces changed, farthest ([\d.]+) m from the stroke, (\d+) beyond 12 m", line)
            if m:
                strokes += 1
                farthest = max(farthest, float(m.group(2)))
                beyond += int(m.group(3))
    return (f"{strokes} strokes on five islands (layouts 7301, 2104, 4242, 913 and the 4,096-cell island): "
            f"{beyond} rim faces changed farther than 12 m from a stroke; the farthest change was "
            f"{farthest:.1f} m away. Full lines: <a href=\"{rel}\">{rel}</a>.")


def build_ms(name):
    m = load_json(f"final/{name}/metrics.json") or {}
    v = m.get("build_ms")
    return f"{v:.0f} ms" if isinstance(v, (int, float)) else "&ndash;"


def boxes_table():
    data = load_json("checks/boxes.json") or {}
    rows = []
    for b in data.get("boxes") or []:
        r, t = b.get("reference"), b.get("runtime")
        fmt = lambda m: "(" + ", ".join(f"{v:.3f}" for v in m["median"]) + ")" if m else "&ndash;"
        rows.append([esc(b.get("hour", "")), esc(b.get("view", "")), esc(b.get("name", "")),
                     esc(",".join(str(v) for v in b.get("box", []))), fmt(r), fmt(t),
                     f"{b['max_channel_difference']:.3f}" if "max_channel_difference" in b else "&ndash;"])
    return table(["hour", "view", "box", "x0,y0,x1,y1 (1300 px copy)", "Godot median", "runtime median",
                  "largest channel difference"], rows)


CSS = """
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;
 margin:0 auto;max-width:1800px;padding:16px 24px 64px;color:#1c1c1c;background:#fafafa;line-height:1.4}
h1{font-size:1.5em;margin:.4em 0}
h2{font-size:1.25em;margin-top:2.2em;border-bottom:1px solid #ccc;padding-bottom:.2em}
h3{font-size:1.05em;margin-top:1.6em}
h4{font-size:.95em;margin:1.2em 0 .3em;color:#444}
.notice{border:2px solid #b07a00;background:#fff6dc;padding:12px 16px;border-radius:4px}
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
.note{font-size:.9em;color:#333}
"""


def build():
    sections = []
    body = [row([ref("day", v), run("n_7301", v)], v) for v in VIEWS]
    sections.append(("day", "Day, layout 7301: the twelve review views", "".join(body)))

    body = ['<p class="note">The same rectangle cut from the full 3024x1964 frames, not scaled: '
            'Godot (left), the runtime resting camera (middle, 2x supersampling), the runtime moving '
            'camera (right, one sample per pixel and FXAA, the mode the frame budget applies to).</p>']
    for v in CROP_VIEWS:
        body.append(row([crop("ref", v, "Godot"), crop("rest", v, "runtime, resting"),
                         crop("moving", v, "runtime, moving")], v))
    sections.append(("crops", "Native-pixel crops", "".join(body)))

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
            "<h3>The 4,096-cell island (generated cells, the 7301 scene's props scattered over it)</h3>"]
    body += [row([run("n_syn4096", v)], v) for v in ("whole", "game", "overview")]
    sections.append(("runtime", "Runtime only: no Godot counterpart", "".join(body)))

    godot_rows = [[esc(t), f"{d['whole']:.2f}", f"{d['game']:.2f}", f"{d['reverse']:.2f}"] for t, d in GODOT_BENCH]
    body = ["<h3>Runtime frame cost at 3024x1964 (M4 Pro, mains power, off screen, 120 frames with the camera orbiting)</h3>",
            table(["run", "what", "view", "ms per frame", "frames per second", "budget ms"], bench_rows()),
            "<h3>Godot at the same resolution (freeze bench, <a href=\"../20261122_freeze/README.md\">../20261122_freeze/README.md</a>)</h3>",
            table(["Godot tier", "whole ms", "game ms", "reverse ms"], godot_rows),
            '<p class="note">Godot figures: tools/perf/bench_presets.gd on the default 623-cell island, '
            'one island in view, single viewport, at the freeze tag. The plan\'s budget is 12 ms for a moving '
            'camera at 3024x1964 (60 frames a second with headroom). The resting mode (2x supersampling) is '
            'what the stills on this page use; it is paid once when the camera stops, not every frame.</p>',
            "<h3>Island build and edit locality</h3>",
            f"<p>Whole-island build, cells to drawable meshes, props and grass: layout 7301 {build_ms('n_7301')}, "
            f"the 4,096-cell island {build_ms('n_syn4096')} (no incremental update yet).</p>",
            f"<p>Edit test: {edit_summary()}</p>"]
    sections.append(("cost", "Cost", "".join(body)))

    body = ['<p class="note">Median display colour of each box on the 1300 px reduced frames, Godot '
            'against runtime, measured fresh on the final frames by checks/measure_boxes.py '
            '(numbers in checks/boxes.json). The rounds worked to 0.02 per channel. The cliffs are a '
            'different construction, so a cliff box compares the tone of the stone, not the same block.</p>',
            boxes_table()]
    sections.append(("boxes", "Measured colour boxes", "".join(body)))

    body = ["<ul>" + "".join(f"<li>{esc(k)}</li>" for k in KNOWN) + "</ul>"]
    sections.append(("limits", "Known differences and limits", "".join(body)))

    toc = "".join(f'<li><a href="#{sid}">{esc(t)}</a></li>' for sid, t, _ in sections)
    content = "".join(f'<section id="{sid}"><h2>{esc(t)}</h2>{b}</section>' for sid, t, b in sections)
    page = (
        "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        "<title>Natural look: Godot baseline and runtime</title>\n"
        f"<style>{CSS}</style>\n</head>\n<body>\n"
        f'<div class="notice">{esc(NOTICE)}</div>\n'
        "<h1>Natural look: Godot baseline and runtime</h1>\n"
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
