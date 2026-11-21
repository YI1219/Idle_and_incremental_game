#!/usr/bin/env python3
"""Count thin slivers and small chips in the ID stills written by id_render.gd.

Every cliff piece has one flat colour, so each connected region of one colour
is one visible piece of one rock. A region is reported as
  sliver: at least SLIVER_LEN m long but nowhere wider than SLIVER_WIDE m
  chip:   smaller than CHIP_AREA m2 (and larger than a speck)
Widths come from the distance transform (largest inscribed circle), lengths
from the bounding box diagonal. Metres use the per-view pixels-per-metre at the
island centre, so they are approximate away from it.
Usage: python3 fragment_metric.py DIR [--overlay]
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import cv2
import numpy as np

SLIVER_WIDE = 0.55
SLIVER_LEN = 1.2
CHIP_AREA = 0.9
STRIP_WIDE = 1.7
STRIP_LEN = 3.0
SPECK_AREA = 0.03


def main() -> int:
    folder = Path(sys.argv[1])
    overlay = "--overlay" in sys.argv
    meta = json.loads((folder / "views.json").read_text())
    totals = {"sliver": 0, "strip": 0, "chip": 0, "pieces": 0, "sliver_area_m2": 0.0, "strip_area_m2": 0.0, "chip_area_m2": 0.0, "hull_fragments": 0, "hull_visible_m2": 0.0, "rock_visible_m2": 0.0}
    rows = []
    for view in meta["views"]:
        image = cv2.imread(str(folder / view["file"]), cv2.IMREAD_COLOR)
        scale = float(view["px_per_m"])
        packed = (image[:, :, 0].astype(np.uint32) << 16) | (image[:, :, 1].astype(np.uint32) << 8) | image[:, :, 2].astype(np.uint32)
        colours, inverse = np.unique(packed, return_inverse=True)
        inverse = inverse.reshape(packed.shape)
        marks = image.copy() if overlay else None
        counts = {"sliver": 0, "strip": 0, "chip": 0, "pieces": 0, "hull_fragments": 0}
        for index, colour in enumerate(colours):
            if colour == 0:
                continue
            b, g, r = (int(colour) >> 16) & 255, (int(colour) >> 8) & 255, int(colour) & 255
            is_hull = r > 200 and g < 40 and b < 40
            is_mantle = b > 200 and r < 40 and g < 40
            mask = (inverse == index).astype(np.uint8)
            n, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
            if n <= 1:
                continue
            distance = cv2.distanceTransform(mask, cv2.DIST_L2, 3)
            for label in range(1, n):
                area_px = int(stats[label, cv2.CC_STAT_AREA])
                area = area_px / (scale * scale)
                if area < SPECK_AREA:
                    continue
                w = stats[label, cv2.CC_STAT_WIDTH]
                h = stats[label, cv2.CC_STAT_HEIGHT]
                x = stats[label, cv2.CC_STAT_LEFT]
                y = stats[label, cv2.CC_STAT_TOP]
                region = labels[y:y + h, x:x + w] == label
                widest = 2.0 * float(distance[y:y + h, x:x + w][region].max()) / scale
                length = float(np.hypot(w, h)) / scale
                counts["pieces"] += 1
                totals["hull_visible_m2" if is_hull else "rock_visible_m2"] += area
                kind = None
                if area < CHIP_AREA:
                    kind = "chip"
                elif widest <= SLIVER_WIDE and length >= SLIVER_LEN:
                    kind = "sliver"
                elif widest <= STRIP_WIDE and length >= STRIP_LEN:
                    kind = "strip"
                if kind is None:
                    continue
                counts[kind] += 1
                totals[kind + "_area_m2"] += area
                if is_hull:
                    counts["hull_fragments"] += 1
                if marks is not None:
                    cv2.rectangle(marks, (int(x) - 3, int(y) - 3), (int(x + w) + 3, int(y + h) + 3), (255, 255, 255) if kind == "sliver" else (0, 255, 255), 2)
                rows.append({"view": view["file"], "kind": kind, "class": "hull" if is_hull else ("mantle" if is_mantle else "rock"), "area_m2": round(area, 3), "widest_m": round(widest, 3), "length_m": round(length, 3), "x": int(x), "y": int(y), "w": int(w), "h": int(h)})
        if marks is not None:
            cv2.imwrite(str(folder / (Path(view["file"]).stem + "_marked.jpg")), marks, [cv2.IMWRITE_JPEG_QUALITY, 85])
        for key, value in counts.items():
            totals[key] += value
        print(f"{view['file']:16s} pieces={counts['pieces']:3d} slivers={counts['sliver']:2d} strips={counts['strip']:2d} chips={counts['chip']:2d} hull_fragments={counts['hull_fragments']:2d}")
    for key in ("sliver_area_m2", "strip_area_m2", "chip_area_m2", "hull_visible_m2", "rock_visible_m2"):
        totals[key] = round(totals[key], 2)
    report = {"thresholds_m": {"sliver_max_width": SLIVER_WIDE, "sliver_min_length": SLIVER_LEN, "strip_max_width": STRIP_WIDE, "strip_min_length": STRIP_LEN, "chip_max_area_m2": CHIP_AREA, "speck_min_area_m2": SPECK_AREA}, "seed": meta.get("seed"), "preset": meta.get("preset"), "totals": totals, "fragments": rows}
    (folder / "fragment_metric.json").write_text(json.dumps(report, indent=1) + "\n")
    print("TOTAL", json.dumps(totals))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
