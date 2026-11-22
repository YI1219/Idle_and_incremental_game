#!/usr/bin/env python3
"""Port of time_solar_system.gd current_blended_preset(): parses KEYFRAMES from the GDScript,
blends them at a day_progress and checks against captures.json."""
import json, re, sys

SRC = "scripts/gameplay/systems/time_solar_system.gd"
text = open(SRC, encoding="utf-8").read()
block = text[text.index("const KEYFRAMES"):text.index("var day_progress")]
frames = []
for chunk in re.split(r"\n\t\{", block)[1:]:
    entry = {}
    for key, val in re.findall(r'"(\w+)":\s*([^\n]+?),?\s*$', chunk, re.M):
        m = re.match(r"(Color|Vector3)\(([^)]*)\)", val)
        if m:
            entry[key] = [float(x) for x in m.group(2).split(",")]
        elif re.match(r"^-?[\d.]+$", val):
            entry[key] = float(val)
        else:
            entry[key] = val.strip('"')
    frames.append(entry)

def blend(p):
    p = p % 1.0
    n = len(frames)
    for i in range(n):
        cur = frames[i]["at"]; ni = (i + 1) % n; nxt = frames[ni]["at"] + (1.0 if ni == 0 else 0.0)
        tp = p + (1.0 if (p < cur and ni == 0) else 0.0)
        if cur <= tp <= nxt:
            r = min(max((tp - cur) / max(1e-4, nxt - cur), 0.0), 1.0)
            t = r * r * (3 - 2 * r)
            a, b = frames[i], frames[ni]
            out = {}
            for k, va in a.items():
                if k in ("at", "mood"):
                    continue
                vb = b[k]
                if isinstance(va, list):
                    out[k] = [x + (y - x) * t for x, y in zip(va, vb)]
                elif isinstance(va, float):
                    out[k] = va + (vb - va) * t
            out["_from"] = (i, ni, round(t, 4))
            return out

for name in sys.argv[1:]:
    cap = json.load(open(f"art/lookdev/20261122_g1/godot_baseline/{name}/captures.json"))
    if isinstance(cap, dict) and "captures" in cap:
        cap = cap["captures"]
    first = cap[0] if isinstance(cap, list) else cap
    p = blend(first["day_progress"])
    print(f"== {name} day_progress {first['day_progress']} keyframes {p['_from']}")
    checks = {"sun_color": "sun_color", "sun_energy": "sun_energy", "sun_rot": "sun_rotation", "fill_energy": "fill_energy",
              "fill_rot": "fill_rotation", "ambient_energy": "ambient_energy", "fog_color": "fog_color", "fog_density": "fog_density",
              "grass_base": "grass_base", "grass_highlight": "grass_highlight", "shadow_opacity": "shadow_opacity", "ssao_intensity": "ssao_intensity"}
    worst = 0.0
    for k, ck in checks.items():
        a = p[k]; b = first[ck]
        a = a if isinstance(a, list) else [a]
        b = b if isinstance(b, list) else [b]
        d = max(abs(x - y) for x, y in zip(a, b))
        worst = max(worst, d)
    print(f"CHECK max abs difference vs captures.json over {len(checks)} entries: {worst:.2e}")
    for k, v in p.items():
        if k.startswith("_"):
            continue
        s = ", ".join(f"{x:.4f}" for x in v) if isinstance(v, list) else f"{v:.5f}"
        print(f"  {k}: {s}")
