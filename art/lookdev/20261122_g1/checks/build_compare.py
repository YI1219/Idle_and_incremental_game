#!/usr/bin/env python3
"""Regenerate art/lookdev/20261122_g1/compare.html from whatever is on disk.

Run from the repo root:
    python3 art/lookdev/20261122_g1/checks/build_compare.py

Standard library only. Safe to re-run after frames are re-rendered: the page
refers to frames by run and view name, never by content. Prints one summary
line, then one line per missing image or metrics file.
"""

import html
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
G1 = os.path.dirname(HERE)
OUT = os.path.join(G1, "compare.html")

GODOT_TAG = "godot-freeze-20261122"

NOTICE = (
    "Checkpoint G1 of the purpose-built runtime. Left-hand frames are the Godot "
    "project frozen at tag godot-freeze-20261122 (native tier, 4x MSAA). Runtime "
    "frames come from throwaway study code on procedural stand-in content. Nothing "
    "on this page is art-accepted, and the runtime frames are a study of direction, "
    "not a finished look."
)

COST_NOTE = (
    "Measured off screen on the M4 Pro at 3024x1964. The 2x runs render four "
    "samples per pixel and filter down; scale1 renders one. Budgets in the plan: "
    "12 ms moving, 4 ms still. Nothing here says anything about a thin laptop."
)

SEEDS = ["2104", "4242", "913"]

# Frame statistics: preferred key, then accepted aliases (the tool has used both).
FRAME_STATS = [
    ("luma p05", ["luma_p05", "p05"]),
    ("luma p50", ["luma_p50", "p50"]),
    ("luma p95", ["luma_p95", "p95"]),
    ("near white", ["near_white", "white"]),
    ("near black", ["near_black", "black"]),
    ("saturation mean", ["saturation_mean", "sat_mean"]),
    ("saturation p99", ["saturation_p99", "sat_p99"]),
    ("quiet share", ["quiet_share", "quiet"]),
]

KNOWN_EDIT_KEYS = {"stroke", "at", "faces_before", "faces_after",
                   "faces_changed", "farthest_change_m"}

esc = html.escape

missing_images = []    # expected relative paths with nothing on disk
missing_small = []     # full frame exists but its small copy does not
missing_metrics = []
img_count = 0
placeholder_count = 0
_metrics_cache = {}


def exists(rel):
    return os.path.isfile(os.path.join(G1, rel))


# ---------------------------------------------------------------- frames

def godot_paths(gset, view):
    return (f"godot_baseline/{gset}/{view}.png",
            f"godot_baseline/{gset}/small/{view}.png")


def study_paths(run, view):
    return (f"study/{run}/{run}_{view}.png",
            f"study/{run}/small/{run}_{view}.png")


def godot(gset, view):
    full, small = godot_paths(gset, view)
    cap = f"Godot ({GODOT_TAG}) &middot; set <b>{esc(gset)}</b> &middot; view {esc(view)}"
    return full, small, cap


def study(run, view):
    full, small = study_paths(run, view)
    cap = f"Runtime study &middot; run <b>{esc(run)}</b> &middot; view {esc(view)}"
    return full, small, cap


def figure(spec):
    global img_count, placeholder_count
    full, small, cap = spec
    has_full, has_small = exists(full), exists(small)
    if not has_full and not has_small:
        placeholder_count += 1
        missing_images.append(full)
        return (f'<figure><div class="missing">missing<br><code>{esc(full)}</code>'
                f'</div><figcaption>{cap}</figcaption></figure>')
    img_count += 1
    src = small if has_small else full
    href = full if has_full else small
    note = ""
    if not has_small:
        missing_small.append(small)
        note = " &middot; <i>no small copy, full frame shown</i>"
    elif not has_full:
        missing_images.append(full)
        note = " &middot; <i>full frame missing</i>"
    return (f'<figure><a href="{esc(href)}"><img src="{esc(src)}" loading="lazy" '
            f'alt="{esc(src)}"></a><figcaption>{cap}{note}</figcaption></figure>')


def row(specs, label=None):
    n = len(specs)
    head = f'<h4>{esc(label)}</h4>' if label else ""
    body = "".join(figure(s) for s in specs)
    return f'{head}<div class="row n{n}">{body}</div>'


# ---------------------------------------------------------------- metrics

def metrics(run):
    if run in _metrics_cache:
        return _metrics_cache[run]
    rel = f"study/{run}/metrics.json"
    data = None
    try:
        with open(os.path.join(G1, rel), encoding="utf-8") as fh:
            data = json.load(fh)
        if not isinstance(data, dict):
            data = None
    except FileNotFoundError:
        missing_metrics.append(rel)
    except (ValueError, OSError) as exc:
        missing_metrics.append(f"{rel} (unreadable: {exc})")
    _metrics_cache[run] = data
    return data


def fmt(v, nd=3):
    if v is None:
        return "&ndash;"
    if isinstance(v, bool):
        return str(v)
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return f"{v:.{nd}f}"
    return esc(str(v))


def pick(d, keys):
    for k in keys:
        if isinstance(d, dict) and k in d:
            return d[k]
    return None


def frame_entry(run, view):
    m = metrics(run)
    if not m:
        return None
    for fr in m.get("frames") or []:
        if isinstance(fr, dict) and fr.get("view") == view:
            return fr
    return None


def table(headers, rows, cls=""):
    th = "".join(f"<th>{h}</th>" for h in headers)
    trs = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>" for r in rows)
    return f'<table class="{cls}"><thead><tr>{th}</tr></thead><tbody>{trs}</tbody></table>'


def frames_table(runs, view):
    rows = []
    for label, run in runs:
        fr = frame_entry(run, view)
        cells = [f"{esc(label)} <span class=dim>({esc(run)})</span>"]
        for _, keys in FRAME_STATS:
            v = pick(fr, keys) if fr else None
            cells.append(fmt(float(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else v, 3))
        rows.append(cells)
    return table(["run"] + [n for n, _ in FRAME_STATS], rows, "num")


def edit_cell(e):
    if not isinstance(e, dict):
        return "&ndash;"
    ch = e.get("faces_changed")
    far = e.get("farthest_change_m")
    s = f"{fmt(ch)} / {fmt(far, 1) if isinstance(far, (int, float)) else fmt(far)} m"
    extras = [f"{esc(str(k))} {fmt(v, 2) if not isinstance(v, (list, dict)) else esc(json.dumps(v))}"
              for k, v in e.items() if k not in KNOWN_EDIT_KEYS]
    if extras:
        s += "<br><span class=dim>" + ", ".join(extras) + "</span>"
    return s


def generator_table():
    expected = ["s4_karst_7301"] + [f"s4_karst_{s}" for s in SEEDS] + ["s4_karst_syn4096"]
    study_dir = os.path.join(G1, "study")
    found = []
    if os.path.isdir(study_dir):
        found = sorted(d for d in os.listdir(study_dir)
                       if d.startswith("s4_karst_") and os.path.isdir(os.path.join(study_dir, d)))
    runs = expected + [r for r in found if r not in expected]

    strokes = []
    for r in runs:
        m = metrics(r) or {}
        for e in m.get("edit_locality") or []:
            st = e.get("stroke") if isinstance(e, dict) else None
            if st and st not in strokes:
                strokes.append(st)
    if not strokes:
        strokes = ["expand", "contract", "raise"]

    rows = []
    for r in runs:
        m = metrics(r)
        if m is None:
            rows.append([esc(r)] + ["&ndash;"] * (8 + len(strokes)))
            continue
        wmin, wmax = m.get("width_min_m"), m.get("width_max_m")
        width = (f"{fmt(wmin, 1)} &ndash; {fmt(wmax, 1)} m"
                 if wmin is not None or wmax is not None else "&ndash;")
        run_len, run_m = m.get("longest_alike_run"), m.get("longest_alike_run_m")
        alike = f"{fmt(run_len)} / {fmt(run_m, 1)} m"
        bms = m.get("build_ms")
        cells = [esc(r), fmt(m.get("cells")), fmt(m.get("faces")), fmt(m.get("columns")),
                 fmt(m.get("triangles")), fmt(bms, 1) if bms is not None else "&ndash;",
                 width, fmt(m.get("width_spread"), 3), alike]
        by_stroke = {}
        for e in m.get("edit_locality") or []:
            if isinstance(e, dict) and e.get("stroke") not in by_stroke:
                by_stroke[e.get("stroke")] = e
        for st in strokes:
            cells.append(edit_cell(by_stroke.get(st)))
        rows.append(cells)
    headers = (["run", "cells", "faces", "columns", "triangles", "build ms",
                "width min &ndash; max", "width spread", "longest alike run (faces / m)"]
               + [f"edit: {esc(s)}<br><span class=dim>changed / farthest</span>" for s in strokes])
    return table(headers, rows, "num")


def bench_table():
    rows = []
    for r in ["bench_single", "bench_single_scale1", "bench_trio", "bench_syn4096"]:
        m = metrics(r)
        entries = (m or {}).get("bench") or []
        if not entries:
            rows.append([esc(r), "&ndash;", "&ndash;", "&ndash;"])
            continue
        for b in entries:
            if not isinstance(b, dict):
                continue
            ms = b.get("ms")
            fps = (f"{1000.0 / ms:.1f}" if isinstance(ms, (int, float)) and ms > 0
                   else "&ndash;")
            rows.append([esc(r), esc(str(b.get("view", "?"))),
                         fmt(float(ms), 3) if isinstance(ms, (int, float)) else "&ndash;", fps])
    return table(["run", "view", "ms per frame", "frames per second"], rows, "num")


# ---------------------------------------------------------------- page

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
.missing{width:100%;aspect-ratio:3024/1964;display:flex;flex-direction:column;
 align-items:center;justify-content:center;background:repeating-linear-gradient(45deg,#f3dede,#f3dede 10px,#fbeaea 10px,#fbeaea 20px);
 border:2px dashed #b00;color:#900;font-weight:600;text-align:center;font-size:.9em;word-break:break-all;padding:8px;box-sizing:border-box}
.missing code{font-weight:400}
table{border-collapse:collapse;margin:10px 0;font-size:.88em;background:#fff}
th,td{border:1px solid #ccc;padding:4px 8px;vertical-align:top}
th{background:#eee;text-align:left}
table.num td{text-align:right}
table.num td:first-child{text-align:left}
.dim{color:#777;font-size:.9em}
.note{font-size:.9em;color:#333}
"""


def section(sid, title, body):
    return f'<section id="{sid}"><h2>{esc(title)}</h2>{body}</section>'


def build():
    sections = []

    # A
    body = []
    for v in ["game", "whole", "reverse", "cliff_close", "foot_reverse", "terrace_close"]:
        body.append(row([godot("day", v), study("s3_look_b", v)], v))
    body.append(row([godot("day", "outer_hull"), study("s4_karst_7301", "outer_hull")], "outer_hull"))
    sections.append(("a", "A. Against the Godot baseline, same cells and cameras (day).", "".join(body)))

    # B
    body = []
    for v in ["whole", "game"]:
        body.append(row([godot("dusk", v), study("s3_dusk_b", v)], f"dusk · {v}"))
        body.append(row([godot("night", v), study("s3_night_b", v)], f"night · {v}"))
    sections.append(("b", "B. Dusk and night.", "".join(body)))

    # C
    body = []
    for s in SEEDS:
        body.append(f"<h3>Layout {s}</h3>")
        for v in ["whole", "reverse", "foot_reverse"]:
            body.append(row([godot(f"held{s}", v), study(f"s4_karst_{s}", v)], f"{s} · {v}"))
    sections.append(("c", "C. Other layouts.", "".join(body)))

    # D
    body = []
    for v in ["game", "whole", "reverse", "cliff_close", "foot_reverse", "terrace_close"]:
        body.append(row([study("s3_look_a", v), study("s3_look_b", v), study("s3_look_c", v)], v))
    body.append("<h3>Frame statistics, view whole</h3>")
    body.append(frames_table([("look A", "s3_look_a"), ("look B", "s3_look_b"),
                              ("look C", "s3_look_c"), ("dusk B", "s3_dusk_b"),
                              ("night B", "s3_night_b")], "whole"))
    sections.append(("d", "D. Look study: A (no line), B (line and flat wash), C (B with brushwork).",
                     "".join(body)))

    # E
    body = []
    for v in ["whole", "game", "reverse", "foot_reverse", "cliff_close", "outer_hull", "below"]:
        body.append(row([study("s4_hull_7301", v), study("s4_karst_7301", v)], f"7301 · {v}"))
    for s in SEEDS:
        for v in ["reverse", "foot_reverse"]:
            body.append(row([study(f"s4_hull_{s}", v), study(f"s4_karst_{s}", v)], f"{s} · {v}"))
    for v in ["whole", "game"]:
        body.append(row([study("s4_hull_syn4096", v), study("s4_karst_syn4096", v)], f"syn4096 · {v}"))
    body.append("<h3>Hanging-rock generator metrics</h3>")
    body.append(generator_table())
    sections.append(("e", "E. Generator study: faceted hull beside hanging rock.", "".join(body)))

    # F
    body = [row([study("s3_trio_b_day", "wallpaper")], "trio B · day"),
            row([study("s3_trio_b_dusk", "wallpaper")], "trio B · dusk"),
            row([study("s3_trio_c_day", "wallpaper")], "trio C · day"),
            row([study("s3_dusk_c", "whole"), study("s3_night_c", "whole")], "look C · dusk and night · whole")]
    sections.append(("f", "F. Several islands and other hours.", "".join(body)))

    # G
    body = [bench_table(), f'<p class="note">{esc(COST_NOTE)}</p>']
    sections.append(("g", "G. Cost.", "".join(body)))

    toc = "".join(f'<li><a href="#{sid}">{esc(t)}</a></li>' for sid, t, _ in sections)
    content = "".join(section(sid, t, b) for sid, t, b in sections)

    page = (
        "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        "<title>G1 compare: Godot baseline and runtime study</title>\n"
        f"<style>{CSS}</style>\n</head>\n<body>\n"
        f'<div class="notice">{esc(NOTICE)}</div>\n'
        "<h1>G1 compare: Godot baseline and runtime study</h1>\n"
        "<p class=dim>Generated by checks/build_compare.py. Click a frame for the full-size image.</p>\n"
        f"<nav><b>Contents</b><ol>{toc}</ol></nav>\n"
        f"{content}\n</body>\n</html>\n"
    )
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(page)
    os.replace(tmp, OUT)


def main():
    build()
    rel_out = os.path.relpath(OUT, os.getcwd())
    print(f"wrote {rel_out}: {img_count} images, {placeholder_count} missing placeholders, "
          f"{len(missing_small)} without small copy, {len(missing_metrics)} missing metrics files")
    for p in sorted(set(missing_images)):
        print(f"missing image: {p}")
    for p in sorted(set(missing_small)):
        print(f"missing small copy: {p}")
    for p in sorted(set(missing_metrics)):
        print(f"missing metrics: {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
