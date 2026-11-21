#!/usr/bin/env python3
"""Draw the cliff layout in plan and measure how regimented each outer wall is.

Input: JSON from plan_dump.gd. Output: a PNG plan and a JSON/terminal metric.
Usage: python3 plan_metric.py plan.json out.png [--label TEXT]

Metric. Outer slabs are chained to their neighbours along the rim. A joint
between two neighbours is "flush" when their faces stand within FLUSH metres of
the same offset from the heightmap contour, and "alike" when their widths are within ALIKE of each
other. A wall is a maximal chain of slabs whose facing turns by less than
WALL_TURN degrees joint to joint. For each wall:
  slabs, length, flush_alike_run (longest run of consecutive flush+alike
  joints, in slabs), depth_range (max-min face offset from the wall's own best
  fit line), width_cv, lowered (shoulder masses in front of the wall).
A "palisade" is a flush+alike run of 3 or more slabs, none of which carries a
lowered mass in front of it.

Headline number, "longest plain row": the longest chain of neighbouring outer
slabs in which no slab carries a lowered mass and every joint is flush,
whatever the widths and levels. It is the row the eye picks out.
"""
from __future__ import annotations

import json
import math
import sys
from PIL import Image, ImageDraw

FLUSH = 0.30
ALIKE = 1.30
WALL_TURN = 28.0


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1]


def length(a):
    return math.hypot(a[0], a[1])


def proud(c):
    return dot(sub(c["face"][1], c["edge"]), c["out"])


def analyse(plan):
    cols = [c for c in plan["columns"] if not c["step"]]
    n = len(cols)
    # Neighbour on the +tangent side: nearest slab whose near face end is close.
    links = {}
    for i, a in enumerate(cols):
        best = None
        for j, b in enumerate(cols):
            if i == j or abs(a["top"] - b["top"]) > 3.6:
                continue
            off = sub(b["edge"], a["edge"])
            along = dot(off, a["tan"])
            if along <= 0.2:
                continue
            d = length(off)
            if d > 0.80 * (a["w"] + b["w"]):
                continue
            if dot(a["out"], b["out"]) < math.cos(math.radians(75)):
                continue
            if best is None or d < best[0]:
                best = (d, j)
        if best:
            links[i] = best[1]
    joints = []
    for i, j in links.items():
        a, b = cols[i], cols[j]
        out = ((a["out"][0] + b["out"][0]), (a["out"][1] + b["out"][1]))
        ln = length(out) or 1.0
        out = (out[0] / ln, out[1] / ln)
        # Front-back offset of each face from the heightmap contour it stands on
        # ("proud"). Neighbours that follow a bowed rim at the same offset are
        # flush; a deliberate inset or outset shows as a difference.
        step = proud(b) - proud(a)
        mid_step = step
        turn = math.degrees(math.acos(max(-1.0, min(1.0, dot(a["out"], b["out"])))))
        ratio = max(a["w"], b["w"]) / max(0.01, min(a["w"], b["w"]))
        joints.append({"a": i, "b": j, "step": round(step, 2), "mid_step": round(mid_step, 2), "turn": round(turn, 1), "ratio": round(ratio, 2),
                       "flush": abs(step) < FLUSH, "alike": ratio < ALIKE, "level": abs(a["top"] - b["top"]) < 0.01})
    nxt = {j["a"]: j for j in joints}
    has_prev = {j["b"] for j in joints}
    walls = []
    seen = set()
    starts = [i for i in range(n) if i not in has_prev] or list(range(n))
    for s in starts + list(range(n)):
        if s in seen:
            continue
        chain = [s]
        seen.add(s)
        cur = s
        chain_j = []
        while cur in nxt:
            j = nxt[cur]
            if j["b"] in seen:
                break
            if j["turn"] > WALL_TURN:
                # wall ends; next slab starts another wall
                break
            chain.append(j["b"])
            chain_j.append(j)
            seen.add(j["b"])
            cur = j["b"]
        walls.append((chain, chain_j))
    report = []
    hosts = [m for m in plan["masses"] if not m["interior"]]

    def lowered_at(c):
        return any(length(sub(m["host"], c["edge"])) < 0.05 for m in hosts)

    for chain, chain_j in walls:
        slabs = [cols[i] for i in chain]
        total = sum(length(sub(cols[j["b"]]["edge"], cols[j["a"]]["edge"])) for j in chain_j)
        run = best = 1
        for j in chain_j:
            if j["flush"] and j["alike"] and j["level"] and not (lowered_at(cols[j["a"]]) or lowered_at(cols[j["b"]])):
                run += 1
            else:
                run = 1
            best = max(best, run)
        # Face offsets against the chord through the first and last slab face.
        depth_range = 0.0
        if len(slabs) >= 2:
            p0 = slabs[0]["face"][1]
            p1 = slabs[-1]["face"][1]
            chord = sub(p1, p0)
            cl = length(chord) or 1.0
            normal = (chord[1] / cl, -chord[0] / cl)
            if dot(normal, slabs[0]["out"]) < 0:
                normal = (-normal[0], -normal[1])
            # Remove the smooth bow of the rim: compare each face with the mean of its neighbours.
            offs = [dot(sub(s["face"][1], p0), normal) for s in slabs]
            local = [offs[k] - 0.5 * (offs[k - 1] + offs[k + 1]) for k in range(1, len(offs) - 1)]
            depth_range = (max(local) - min(local)) if local else abs(offs[-1] - offs[0])
        widths = [s["w"] for s in slabs]
        mean_w = sum(widths) / len(widths)
        cv = (sum((w - mean_w) ** 2 for w in widths) / len(widths)) ** 0.5 / mean_w
        lowered = 0
        for m in hosts:
            if any(length(sub(m["host"], s["edge"])) < 0.05 for s in slabs):
                lowered += 1
        cx = sum(s["edge"][0] for s in slabs) / len(slabs)
        cz = sum(s["edge"][1] for s in slabs) / len(slabs)
        ox = sum(s["out"][0] for s in slabs)
        oz = sum(s["out"][1] for s in slabs)
        facing = (math.degrees(math.atan2(oz, ox)) + 360.0) % 360.0
        report.append({"slabs": len(slabs), "length_m": round(total + mean_w, 1), "flush_alike_run": best, "local_depth_range_m": round(depth_range, 2),
                       "width_cv": round(cv, 2), "widths": [round(w, 1) for w in widths], "lowered": lowered,
                       "centre": [round(cx, 1), round(cz, 1)], "facing_deg": round(facing), "tops": sorted({s["top"] for s in slabs}),
                       "proud": [round(proud(x), 2) for x in slabs],
                       "joints": [{k: j[k] for k in ("step", "turn", "ratio")} for j in chain_j], "members": chain})
    # The plain row the eye picks out: neighbours in a chain, none carrying a
    # lowered mass, every joint flush. Width and level are ignored here.
    plain_best = {"slabs": 1, "length_m": 0.0, "from": None, "to": None}
    for start in range(n):
        if lowered_at(cols[start]):
            continue
        chain = [start]
        cur = start
        dist = 0.0
        while cur in nxt:
            j = nxt[cur]
            if j["b"] in chain or not j["flush"] or lowered_at(cols[j["b"]]):
                break
            dist += length(sub(cols[j["b"]]["edge"], cols[cur]["edge"]))
            cur = j["b"]
            chain.append(cur)
        span = dist + 0.5 * (cols[chain[0]]["w"] + cols[chain[-1]]["w"])
        if len(chain) > plain_best["slabs"] or (len(chain) == plain_best["slabs"] and span > plain_best["length_m"]):
            plain_best = {"slabs": len(chain), "length_m": round(span, 1), "from": cols[chain[0]]["edge"], "to": cols[chain[-1]]["edge"]}
    analyse.plain_best = plain_best
    report.sort(key=lambda r: -r["slabs"])
    palisades = [r for r in report if r["flush_alike_run"] >= 3]
    return cols, joints, report, palisades


def draw(plan, cols, joints, report, path, label):
    pts = [p for loop in plan["land"] for p in loop["pts"]]
    for c in plan["columns"]:
        pts += c["cap"]
    for m in plan["masses"]:
        pts += m["corners"]
    lo = (min(p[0] for p in pts) - 2, min(p[1] for p in pts) - 2)
    hi = (max(p[0] for p in pts) + 2, max(p[1] for p in pts) + 2)
    s = 26.0
    size = (int((hi[0] - lo[0]) * s), int((hi[1] - lo[1]) * s) + 40)
    im = Image.new("RGB", size, (246, 244, 238))
    d = ImageDraw.Draw(im, "RGBA")

    def px(p):
        return ((p[0] - lo[0]) * s, (p[1] - lo[1]) * s + 40)

    for gx in range(int(lo[0]) // 5 * 5, int(hi[0]) + 1, 5):
        d.line([px((gx, lo[1])), px((gx, hi[1]))], fill=(225, 222, 214), width=1)
        d.text((px((gx, lo[1]))[0] + 2, 42), str(gx), fill=(150, 150, 150))
    for gz in range(int(lo[1]) // 5 * 5, int(hi[1]) + 1, 5):
        d.line([px((lo[0], gz)), px((hi[0], gz))], fill=(225, 222, 214), width=1)
        d.text((2, px((lo[0], gz))[1] + 2), str(gz), fill=(150, 150, 150))
    shades = {1.5: (176, 196, 150), 2.5: (160, 186, 136), 3.5: (146, 176, 124), 5.0: (128, 162, 108)}
    for loop in sorted(plan["rim"], key=lambda l: l["h"]):
        if len(loop["pts"]) >= 3:
            d.polygon([px(p) for p in loop["pts"]], fill=shades.get(loop["h"], (150, 180, 130)) + (255,), outline=(70, 100, 60, 255))
    for loop in plan["land"]:
        if len(loop["pts"]) >= 3:
            d.line([px(p) for p in loop["pts"]] + [px(loop["pts"][0])], fill=(40, 60, 160, 200), width=1)
    role_col = {"host": (200, 60, 50), "guest": (50, 90, 200), "": (110, 110, 110), "lean": (150, 80, 170), "plain": (110, 110, 110)}
    for c in plan["columns"]:
        col = role_col.get(c.get("role", ""), (110, 110, 110))
        if c["step"]:
            col = (150, 150, 110)
        if len(c["cap"]) >= 3:
            d.polygon([px(p) for p in c["cap"]], fill=col + (70,), outline=col + (255,))
        d.line([px(p) for p in c["face"]], fill=col + (255,), width=4)
    for m in plan["masses"]:
        d.polygon([px(p) for p in m["corners"]], fill=(235, 140, 30, 110), outline=(200, 100, 10, 255))
    for j in joints:
        a = cols[j["a"]]
        b = cols[j["b"]]
        mid = ((a["edge"][0] + b["edge"][0]) / 2 + (a["out"][0] + b["out"][0]) * 1.1, (a["edge"][1] + b["edge"][1]) / 2 + (a["out"][1] + b["out"][1]) * 1.1)
        bad = j["flush"] and j["alike"] and j["level"]
        d.text(px(mid), "%.1f" % abs(j["step"]), fill=(200, 0, 0) if bad else (0, 110, 0))
    pb = analyse.plain_best
    d.text((6, 4), "%s   seed %s preset %s   longest plain row: %d slabs, %.1f m   number at a joint = front-back step in metres (red: flush and alike)" % (label, plan["seed"], plan["preset"], pb["slabs"], pb["length_m"]), fill=(20, 20, 20))
    d.text((6, 20), "thick line = slab face, tinted = crown, orange = lowered shoulder mass, blue = heightmap contour, green = drawn top", fill=(90, 90, 90))
    im.save(path)


def main():
    args = sys.argv[1:]
    plan = json.load(open(args[0]))
    label = ""
    if "--label" in args:
        label = args[args.index("--label") + 1]
    cols, joints, report, palisades = analyse(plan)
    if len(args) > 1 and not args[1].startswith("--"):
        draw(plan, cols, joints, report, args[1], label)
    summary = {"seed": plan["seed"], "preset": plan["preset"], "outer_slabs": len(cols), "masses": len(plan["masses"]),
               "palisade_walls": len(palisades), "longest_flush_alike_run": max((r["flush_alike_run"] for r in report), default=0),
               "slabs_in_palisades": sum(r["flush_alike_run"] for r in palisades),
               "longest_plain_row": analyse.plain_best, "walls": report}
    if "--json" in args:
        json.dump(summary, open(args[args.index("--json") + 1], "w"), indent=1)
    pb = analyse.plain_best
    print("seed %s preset %s: outer slabs %d, lowered masses %d, longest plain row %d slabs / %.1f m (from %s to %s)" % (plan["seed"], plan["preset"], len(cols), len([m for m in plan["masses"] if not m["interior"]]), pb["slabs"], pb["length_m"], pb["from"], pb["to"]))
    for r in report:
        if r["slabs"] >= 2:
            print("  wall at %s facing %3d deg: %d slabs %.1f m, run %d, local depth range %.2f m, width cv %.2f, widths %s, lowered %d, tops %s" % (
                r["centre"], r["facing_deg"], r["slabs"], r["length_m"], r["flush_alike_run"], r["local_depth_range_m"], r["width_cv"], r["widths"], r["lowered"], r["tops"]))
            print("     proud %s  joints step/turn/ratio: %s" % (r["proud"], " ".join("%.2f/%.0f/%.2f" % (j["step"], j["turn"], j["ratio"]) for j in r["joints"])))


if __name__ == "__main__":
    main()
