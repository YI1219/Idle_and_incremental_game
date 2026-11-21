#!/usr/bin/env python3
"""Builds 1:1 matched A/B visual superiority comparison strips for the artifact report."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

BRAIN = Path("/Users/yi/.gemini/antigravity/brain/7cca7761-a06c-4739-8b66-4738e527a9c8")
AUDIT_OLD = BRAIN / "scratch/audit_old"
AUDIT_V2 = BRAIN / "scratch/audit_v2"
GODOT_V2 = BRAIN / "scratch/verify_godot_v2"


def load_font(size: int):
    for p in [
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
    ]:
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def build_terrace_ab() -> None:
    old_img = Image.open(GODOT_V2 / "old_box_terrace_bench_lantern.png").convert("RGB")
    new_img = Image.open(GODOT_V2 / "v2_terrace_bench_lantern.png").convert("RGB")
    # Crop around the bench & lantern terrace for 1:1 pixel clarity, plus full side-by-side
    crop_box = (420, 0, 1080, 480)
    old_crop = old_img.crop(crop_box)
    new_crop = new_img.crop(crop_box)

    w, h = old_crop.size
    header_h = 56
    canvas = Image.new("RGB", (w * 2 + 16, h + header_h), (26, 30, 34))
    draw = ImageDraw.Draw(canvas)
    font = load_font(20)

    draw.text(
        (18, 16),
        "Before: 12 BoxMesh Placeholders (711 Frame Draw Calls)",
        fill=(235, 195, 165),
        font=font,
    )
    draw.text(
        (w + 30, 16),
        "After (V2): 2 Merged Meshes (681 Draw Calls, -83.3% Prop Calls)",
        fill=(165, 235, 195),
        font=font,
    )
    canvas.paste(old_crop, (0, header_h))
    canvas.paste(new_crop, (w + 16, header_h))
    canvas.save(BRAIN / "ab_godot_terrace_bench_lantern.png")


def build_turntable_audit_comparison() -> None:
    old_tt = Image.open(AUDIT_OLD / "courtyard_pavilion_refined_turntable.png").convert("RGB")
    new_tt = Image.open(AUDIT_V2 / "courtyard_pavilion_v2_turntable.png").convert("RGB")
    w, h = new_tt.size
    header_h = 48
    canvas = Image.new("RGB", (w, (h + header_h) * 2 + 12), (26, 30, 34))
    draw = ImageDraw.Draw(canvas)
    font = load_font(20)

    draw.text(
        (20, 12),
        "FAIL [Old Tripo Triangle-Soup Coloring]: 92 Coplanar Color-Bleed Pairs (6.53%), 2257 Tris, Blocked Porch",
        fill=(255, 150, 150),
        font=font,
    )
    canvas.paste(old_tt, (0, header_h))

    y2 = h + header_h + 12
    draw.text(
        (20, y2 + 12),
        "PASS [New Discrete-Component V2]: 0 Coplanar Color-Bleed Pairs (0.00%), 1 Draw Call, 0 Unseen Bottom Caps",
        fill=(155, 240, 185),
        font=font,
    )
    canvas.paste(new_tt, (0, y2 + header_h))
    canvas.save(BRAIN / "ab_blender_pavilion_turntable_audit.png")


def build_all_v2_turntables() -> None:
    t1 = Image.open(AUDIT_V2 / "stone_bench_v2_turntable.png").convert("RGB")
    t2 = Image.open(AUDIT_V2 / "hanging_lantern_v2_turntable.png").convert("RGB")
    t3 = Image.open(AUDIT_V2 / "courtyard_pavilion_v2_turntable.png").convert("RGB")
    w, h = t1.size
    header_h = 44
    canvas = Image.new("RGB", (w, (h + header_h) * 3), (28, 32, 36))
    draw = ImageDraw.Draw(canvas)
    font = load_font(19)

    items = [
        ("1. StoneBenchV2 (古风抱鼓青石木榻) — 764 Tris | 1 Mesh / 1 Material | 0 Unseen Bottom Caps | 0.00% Bleed", t1),
        ("2. HangingLanternV2 (古风挑杆六角宫灯) — 520 Tris | 1 Mesh / 1 Material | 0 Unseen Bottom Caps | 0.00% Bleed", t2),
        ("3. CourtyardPavilionV2 (古风宋韵歇山青瓦草堂) — 2304 Tris | 1 Mesh / 1 Material | 0 Unseen Bottom Caps | 0.00% Bleed", t3),
    ]
    for idx, (label, img) in enumerate(items):
        y0 = idx * (h + header_h)
        draw.text((20, y0 + 10), label, fill=(225, 235, 225), font=font)
        canvas.paste(img, (0, y0 + header_h))
    canvas.save(BRAIN / "v2_props_4angle_turntables.png")


if __name__ == "__main__":
    build_terrace_ab()
    build_turntable_audit_comparison()
    build_all_v2_turntables()
    print("Saved A/B comparison artifacts to", BRAIN)
