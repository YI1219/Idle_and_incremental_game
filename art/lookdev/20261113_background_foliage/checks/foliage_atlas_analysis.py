#!/usr/bin/env python3
"""Read-only atlas analysis. Counts base-level texels, never screen fragments."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


def analyze(root: Path) -> dict:
    atlas = root / "assets/nature/trees/botanical_foliage_atlas.png"
    rgba = np.asarray(Image.open(atlas).convert("RGBA"))
    cells = []
    for y in range(2):
        for x in range(2):
            alpha = rgba[y * 512 : (y + 1) * 512, x * 512 : (x + 1) * 512, 3]
            ys, xs = np.nonzero(alpha)
            cells.append({
                "cell": [x, y],
                "kind": "pine" if y else "huai/shrub",
                "base_texels": int(alpha.size),
                "zero_alpha_texels": int(np.count_nonzero(alpha == 0)),
                "zero_alpha_fraction": float(np.mean(alpha == 0)),
                "below_point23_texels": int(np.count_nonzero(alpha / 255.0 < 0.23)),
                "below_point23_fraction": float(np.mean(alpha / 255.0 < 0.23)),
                "nonzero_bbox_xyxy_inclusive": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
                "mean_alpha": float(alpha.mean() / 255.0),
            })
    originals = [
        "assets/nature/trees/botanical_foliage_atlas.png",
        "scripts/terrain_editor/terrain_models.gd",
        "shaders/terrain_editor/foliage_cards.gdshader",
    ]
    return {
        "atlas_dimensions": [int(rgba.shape[1]), int(rgba.shape[0])],
        "original_sha256": {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in originals},
        "cells": cells,
        "each_curved_card": {
            "triangles_before": 4,
            "triangles_after_index": 4,
            "vertices_before": 12,
            "vertices_after_index": 5,
            "vertex_reduction_fraction": 7 / 12,
            "geometry_area_ratio": 1.0,
            "index_count_after": 12,
            "indexing_changes_raster_area": False,
        },
        "shrub_from_source": {
            "card_count": 11 + 9 + 9 + 8 + 8,
            "collar_triangles": 8,
            "vertices_before": 45 * 12 + 8 * 3,
            "expected_exact_index_vertices": 45 * 5 + 8 + 1,
            "triangles_unchanged": 45 * 4 + 8,
            "note": "Source-derived expected count; native helper reports actual unique vertices.",
        },
        "limits": [
            "Fractions count nearest samples of base-level texels, not bilinear/mipmap samples or screen-space overdraw.",
            "Runtime uses Image.generate_mipmaps on the full atlas; import-file mipmaps=false does not disable those runtime mipmaps.",
            "No shape clipping: inserted/moved vertices would change nonlinear flutter and normalized vertex normals before interpolation.",
            "No GPU timing, frame capture, or target hardware performance was measured by this analysis.",
        ],
    }


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[4]
    report = analyze(root)
    target = Path(__file__).with_suffix(".json")
    target.write_text(json.dumps(report, indent=2) + "\n")
    print(target.relative_to(root))
