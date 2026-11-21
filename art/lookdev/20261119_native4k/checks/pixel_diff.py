#!/usr/bin/env python3
"""Compare <camera>_before / _after / _before_repeat stills in one directory.

Writes pixel_comparison.json and, per camera, a 1:1 crop strip
(before | after | abs diff x8) around the largest local difference.
Usage: python3 pixel_diff.py DIR
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def load(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)


def stats(a: np.ndarray, b: np.ndarray) -> dict:
    d = np.abs(a - b)
    worst = d.max(axis=2)
    total = worst.size
    return {
        "mean_abs_rgb": float(d.mean()),
        "max": int(worst.max()),
        "pixels_differ_percent": float((worst > 0).sum() * 100.0 / total),
        "pixels_over_2_percent": float((worst > 2).sum() * 100.0 / total),
        "pixels_over_8_percent": float((worst > 8).sum() * 100.0 / total),
        "pixels_over_24_percent": float((worst > 24).sum() * 100.0 / total),
    }


def main() -> int:
    folder = Path(sys.argv[1])
    report: dict = {}
    for before_path in sorted(folder.glob("*_before.png")):
        name = before_path.name[: -len("_before.png")]
        before = load(before_path)
        after = load(folder / f"{name}_after.png")
        row = {"after_vs_before": stats(after, before)}
        repeat_path = folder / f"{name}_before_repeat.png"
        if repeat_path.exists():
            row["repeat_vs_before_noise_floor"] = stats(load(repeat_path), before)
        diff = np.abs(after - before).max(axis=2).astype(np.float32)
        # Box-filter the difference to find the densest 96px neighbourhood.
        k = 96
        integral = np.pad(diff, ((1, 0), (1, 0))).cumsum(0).cumsum(1)
        window = integral[k:, k:] - integral[:-k, k:] - integral[k:, :-k] + integral[:-k, :-k]
        y, x = np.unravel_index(int(window.argmax()), window.shape)
        cy, cx = y + k // 2, x + k // 2
        h, w = 360, 480
        top = int(np.clip(cy - h // 2, 0, before.shape[0] - h))
        left = int(np.clip(cx - w // 2, 0, before.shape[1] - w))
        crop_before = before[top:top + h, left:left + w].astype(np.uint8)
        crop_after = after[top:top + h, left:left + w].astype(np.uint8)
        crop_diff = np.clip(np.abs(after - before)[top:top + h, left:left + w] * 8, 0, 255).astype(np.uint8)
        strip = np.concatenate([crop_before, crop_after, crop_diff], axis=1)
        Image.fromarray(strip).save(folder / f"{name}_crop_before_after_diff8.png")
        row["densest_difference_crop"] = {"left": left, "top": top, "width": w, "height": h, "file": f"{name}_crop_before_after_diff8.png", "window_mean_diff": float(window.max() / (k * k))}
        report[name] = row
    (folder / "pixel_comparison.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for name, row in report.items():
        a = row["after_vs_before"]
        n = row.get("repeat_vs_before_noise_floor", {})
        print(f"{name:16s} mean={a['mean_abs_rgb']:.4f} max={a['max']:3d} differ={a['pixels_differ_percent']:.3f}% >2={a['pixels_over_2_percent']:.3f}% >8={a['pixels_over_8_percent']:.4f}% >24={a['pixels_over_24_percent']:.4f}% | noise max={n.get('max')} differ={n.get('pixels_differ_percent')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
