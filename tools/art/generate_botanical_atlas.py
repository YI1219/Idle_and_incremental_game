#!/usr/bin/env python3
"""Generate hand-painted gouache stone & 3D sub-bouquet botanical foliage textures:
1. assets/terrain_editor/gouache_stone_wash.png (512x512 seamless tileable):
   Subtle stratified warm ivory-parchment & cool slate-celadon limestone wash.
2. assets/nature/trees/botanical_foliage_atlas.png (1024x1024, 2x2 cells):
   - R channel: Multi-cluster gouache botanical leaf-tuft brushwork (7-8 internal mini-bouquets
     with tactile leaf-dab contrast, while keeping neutral perimeter luminance so overlapping cards
     NEVER show dark sticker rings!)
   - G, B channels: Crisp-yet-smooth 3D mini-bouquet dome normals (nx, ny encoded in 0..255, 128 = flat)
   - A channel: Opaque velvety interior + airy botanical compound-leaflets (Row 0: Huai/Sophora)
     and radiating Oriental pine-needle fans (Row 1: Pine) with natural breathable rim!
"""

import math
import os
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def generate_gouache_stone_wash(out_path: str) -> None:
    rng = random.Random(20261106)
    S = 512
    img = Image.new("RGB", (S, S), (186, 187, 181))
    draw = ImageDraw.Draw(img, "RGBA")

    def draw_wrapped_stroke(cx: float, cy: float, rx: float, ry: float, angle: float, col: tuple[int, int, int, int]) -> None:
        ca, sa = math.cos(angle), math.sin(angle)
        pts_base = []
        steps = 18
        for i in range(steps):
            a = math.tau * i / steps
            wob = 1.0 + 0.10 * math.sin(a * 3.0 + cx * 0.04) + 0.05 * math.cos(a * 5.0 + cy * 0.04)
            lx = math.cos(a) * rx * wob
            ly = math.sin(a) * ry * wob
            pts_base.append((lx * ca - ly * sa, lx * sa + ly * ca))
        for ox in (-S, 0, S):
            for oy in (-S, 0, S):
                if abs(cx + ox - S * 0.5) > S * 0.5 + max(rx, ry) * 1.35:
                    continue
                if abs(cy + oy - S * 0.5) > S * 0.5 + max(rx, ry) * 1.35:
                    continue
                pts = [(cx + ox + px, cy + oy + py) for (px, py) in pts_base]
                draw.polygon(pts, fill=col)

    palette = [
        (222, 215, 198, 66),
        (208, 202, 186, 60),
        (158, 174, 179, 62),
        (172, 185, 183, 56),
        (198, 192, 174, 54),
        (146, 165, 171, 48),
    ]

    for _ in range(130):
        cx = rng.uniform(0, S)
        cy = rng.uniform(0, S)
        rx = rng.uniform(62, 148)
        ry = rng.uniform(18, 46)
        ang = rng.uniform(-0.14, 0.14)
        col = palette[rng.randrange(len(palette))]
        draw_wrapped_stroke(cx, cy, rx, ry, ang, col)

    tiled = Image.new("RGB", (S * 3, S * 3))
    for ix in range(3):
        for iy in range(3):
            tiled.paste(img, (ix * S, iy * S))
    tiled = tiled.filter(ImageFilter.GaussianBlur(radius=11))
    img = tiled.crop((S, S, S * 2, S * 2))
    draw = ImageDraw.Draw(img, "RGBA")

    for _ in range(85):
        cx = rng.uniform(0, S)
        cy = rng.uniform(0, S)
        rx = rng.uniform(48, 120)
        ry = rng.uniform(5, 13)
        ang = rng.uniform(-0.07, 0.07)
        col = palette[rng.randrange(len(palette))]
        draw_wrapped_stroke(cx, cy, rx, ry, ang, (col[0], col[1], col[2], 38))

    tiled2 = Image.new("RGB", (S * 3, S * 3))
    for ix in range(3):
        for iy in range(3):
            tiled2.paste(img, (ix * S, iy * S))
    tiled2 = tiled2.filter(ImageFilter.GaussianBlur(radius=3.2))
    img = tiled2.crop((S, S, S * 2, S * 2))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path, optimize=True)
    print("Saved gouache stone wash:", out_path, img.size)


def draw_leaf_dab(
    draw_lum: ImageDraw.ImageDraw,
    draw_h: ImageDraw.ImageDraw,
    cx: float,
    cy: float,
    rx: float,
    ry: float,
    angle: float,
    lum: int,
    h_val: int,
    alpha: int,
    rng: random.Random,
    pointed: float = 0.0,
) -> None:
    """Draw a miniature botanical gouache leaf/sponge dab into both luminance+alpha and height maps."""
    ca, sa = math.cos(angle), math.sin(angle)
    pts = []
    steps = 10
    ph1 = rng.uniform(0, math.tau)
    ph2 = rng.uniform(0, math.tau)
    for i in range(steps):
        a = math.tau * i / steps
        scallop = 1.0 + 0.14 * math.sin(a * 3.0 + ph1) + 0.08 * math.cos(a * 5.0 + ph2)
        taper = 1.0 - pointed * (0.45 * abs(math.sin(a))) * (0.5 + 0.5 * math.cos(a))
        lx = math.cos(a) * rx * scallop
        ly = math.sin(a) * ry * scallop * taper
        pts.append((cx + lx * ca - ly * sa, cy + lx * sa + ly * ca))
    draw_lum.polygon(pts, fill=(lum, lum, lum, alpha))
    draw_h.polygon(pts, fill=h_val)


def encode_normal_and_pack(lum_rgba: Image.Image, height_l: Image.Image) -> Image.Image:
    """Pack R = multi-cluster leaf brush value, G/B = 3D mini-bouquet dome normal, A = silhouette."""
    lum_512 = lum_rgba.resize((512, 512), Image.Resampling.LANCZOS)
    # Multi-scale height: 14px captures rounded mini-bouquets, 4.5px captures individual leaf-cluster relief!
    h_broad = height_l.filter(ImageFilter.GaussianBlur(radius=14.0)).resize((512, 512), Image.Resampling.BILINEAR)
    h_med = height_l.filter(ImageFilter.GaussianBlur(radius=4.5)).resize((512, 512), Image.Resampling.BILINEAR)

    hb = np.asarray(h_broad, dtype=np.float32) / 255.0
    hm = np.asarray(h_med, dtype=np.float32) / 255.0
    h = hb * 0.55 + hm * 0.45

    dy, dx = np.gradient(h)
    yy, xx = np.mgrid[0:512, 0:512].astype(np.float32)
    rx = (xx - 255.5) / 238.0
    ry = (yy - 255.5) / 228.0
    radial = np.sqrt(rx * rx + ry * ry)
    rim_fade = np.clip(1.0 - np.clip((radial - 0.62) / 0.38, 0.0, 1.0) ** 1.5, 0.22, 1.0)

    strength = 8.5 * rim_fade
    nx = np.clip(-dx * strength, -0.90, 0.90)
    ny = np.clip(dy * strength, -0.90, 0.90)
    norm_len = np.sqrt(nx * nx + ny * ny + 1.0)
    nx /= norm_len
    ny /= norm_len

    rgba = np.asarray(lum_512, dtype=np.uint8).copy()
    r_chan = rgba[:, :, 0]
    a_chan = rgba[:, :, 3]
    g_chan = np.clip(np.round((nx * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    b_chan = np.clip(np.round((ny * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)

    packed = np.stack([r_chan, g_chan, b_chan, a_chan], axis=-1)
    return Image.fromarray(packed)


def render_huai_puff_cell(seed: int) -> Image.Image:
    """Sculpted Sophora/Huai botanical leaf-cluster bouquet:
    - 8 distinct internal mini-bouquets with rich internal leaf-crevice pockets + lit leaf-cluster tops
    - Neutral perimeter value so cards fuse seamlessly without sticker rings
    - Airy miniature compound-leaflet sprays around the outer silhouette!
    """
    rng = random.Random(seed)
    S = 1024
    lum_img = Image.new("RGBA", (S, S), (146, 146, 146, 0))
    h_img = Image.new("L", (S, S), 85)
    d_lum = ImageDraw.Draw(lum_img, "RGBA")
    d_h = ImageDraw.Draw(h_img, "L")

    lobes = [
        (S * 0.50, S * 0.56, 0.88, 0.66),
        (S * 0.25, S * 0.53, 0.70, 0.56),
        (S * 0.75, S * 0.51, 0.72, 0.56),
        (S * 0.34, S * 0.36, 0.72, 0.58),
        (S * 0.66, S * 0.35, 0.72, 0.56),
        (S * 0.50, S * 0.26, 0.60, 0.50),
    ]
    if seed % 2 == 1:
        lobes = [(S - x, y + rng.uniform(-14, 14), sx, sy) for (x, y, sx, sy) in lobes]

    # 1. Base cushion with recessed dark-moss internal crevices between lobes (NO dark outer border!)
    for (lx, ly, sx, sy) in lobes:
        draw_leaf_dab(d_lum, d_h, lx, ly + 4.0, 122.0 * sx, 114.0 * sy, rng.uniform(-0.2, 0.2), 144, 125, 255, rng)

    # Carve soft darker leaf-crevice pockets INSIDE the interior between mini-bouquets (r < 0.52)
    for _ in range(28):
        ang = rng.uniform(0.0, math.tau)
        rad = rng.uniform(0.08, 0.48) * 280.0
        cx = S * 0.50 + math.cos(ang) * rad
        cy = S * 0.46 + math.sin(ang) * rad * 0.82
        draw_leaf_dab(d_lum, d_h, cx, cy, rng.uniform(22.0, 38.0), rng.uniform(15.0, 26.0), rng.uniform(0, math.tau), rng.randint(104, 122), 92, 255, rng)

    # 2. Sculpt 16 plump internal miniature leaf-rosette clusters (each has shadow tuck + lit leaf spray!)
    for (lx, ly, sx, sy) in lobes:
        for sub_i in range(3):
            sa = sub_i * (math.tau / 3.0) + rng.uniform(-0.4, 0.4)
            sr = rng.uniform(22.0, 68.0)
            bx = lx + math.cos(sa) * sr * sx
            by = ly + math.sin(sa) * sr * sy
            # Subtle shadow pocket under this mini-rosette (kept inside cushion)
            draw_leaf_dab(d_lum, d_h, bx - 5.0, by + 9.0, 38.0, 28.0, rng.uniform(-0.3, 0.3), rng.randint(116, 130), 125, 255, rng)
            # 7 miniature pointed Sophora leaflets fanning across the mini-rosette!
            for lf in range(8):
                la = math.tau * lf / 8.0 + rng.uniform(-0.22, 0.22)
                lr = rng.uniform(8.0, 26.0)
                px = bx + math.cos(la) * lr
                py = by + math.sin(la) * lr * 0.82
                sun_bias = 0.5 + 0.5 * (math.cos(la) * 0.58 - math.sin(la) * 0.81)
                lum = int(128 + 54 * sun_bias + rng.uniform(-7, 7))
                hv = int(162 + 78 * sun_bias)
                draw_leaf_dab(d_lum, d_h, px, py, rng.uniform(11.0, 18.5), rng.uniform(6.5, 11.0), la, lum, hv, 255, rng, pointed=0.42)

    # 3. Delicate airy miniature compound-leaflet sprays feathering the outer silhouette!
    for (lx, ly, sx, sy) in lobes:
        for _ in range(145):
            ang = rng.uniform(0.0, math.tau)
            rad = rng.uniform(0.65, 1.08) * 154.0
            px = lx + math.cos(ang) * rad * sx
            py = ly + math.sin(ang) * rad * sy
            base_ang = math.atan2(math.sin(ang) * sy, math.cos(ang) * sx)
            lum_base = rng.randint(138, 166)
            hv = rng.randint(150, 212)
            for sub in (-0.44, -0.15, 0.15, 0.44):
                la = base_ang + sub + rng.uniform(-0.14, 0.14)
                ox = math.cos(la) * rng.uniform(3.5, 10.0)
                oy = math.sin(la) * rng.uniform(3.5, 10.0)
                lrx = rng.uniform(5.8, 11.2)
                lry = rng.uniform(3.2, 6.0)
                lum = max(128, min(178, lum_base + rng.randint(-6, 8)))
                draw_leaf_dab(d_lum, d_h, px + ox, py + oy, lrx, lry, la, lum, hv, 252, rng, pointed=0.52)

    lum_img = lum_img.filter(ImageFilter.GaussianBlur(radius=0.72))
    return encode_normal_and_pack(lum_img, h_img)


def render_pine_cloud_cell(seed: int) -> Image.Image:
    """Sculpted Oriental bonsai cloud-pine cushion:
    - Distinct overlapping pine-needle rosette clusters inside each cloud pad (rich dark-to-lit pine texture!)
    - Neutral perimeter luminance so overlapping cards never show sticker rings
    - Crisp radiating Oriental pine-needle fans along the perimeter!
    """
    rng = random.Random(seed)
    S = 1024
    lum_img = Image.new("RGBA", (S, S), (146, 146, 146, 0))
    h_img = Image.new("L", (S, S), 85)
    d_lum = ImageDraw.Draw(lum_img, "RGBA")
    d_h = ImageDraw.Draw(h_img, "L")

    pads = [
        (S * 0.25, S * 0.59, 0.90, 0.54),
        (S * 0.75, S * 0.57, 0.92, 0.54),
        (S * 0.50, S * 0.61, 1.12, 0.56),
        (S * 0.35, S * 0.44, 0.90, 0.52),
        (S * 0.65, S * 0.43, 0.90, 0.52),
        (S * 0.50, S * 0.32, 0.78, 0.50),
    ]
    if seed % 2 == 1:
        pads = [(S - x, y + rng.uniform(-10, 10), sx, sy) for (x, y, sx, sy) in pads]

    for (lx, ly, sx, sy) in pads:
        draw_leaf_dab(d_lum, d_h, lx, ly + 4.0, 134.0 * sx, 116.0 * sy, rng.uniform(-0.14, 0.14), 142, 124, 255, rng)

    # Interior deep pine-needle shadow pockets between needle rosettes (strictly interior!)
    for _ in range(26):
        ang = rng.uniform(0.0, math.tau)
        rad = rng.uniform(0.06, 0.46) * 290.0
        cx = S * 0.50 + math.cos(ang) * rad
        cy = S * 0.48 + math.sin(ang) * rad * 0.72
        draw_leaf_dab(d_lum, d_h, cx, cy, rng.uniform(24.0, 42.0), rng.uniform(13.0, 22.0), rng.uniform(-0.3, 0.3), rng.randint(102, 120), 90, 255, rng)

    # Sculpted Oriental pine-needle fan rosettes layered across the cushion!
    for (lx, ly, sx, sy) in pads:
        for sub_i in range(4):
            sa = sub_i * (math.tau / 4.0) + rng.uniform(-0.35, 0.35)
            sr = rng.uniform(20.0, 72.0)
            bx = lx + math.cos(sa) * sr * sx
            by = ly + math.sin(sa) * sr * sy
            draw_leaf_dab(d_lum, d_h, bx - 4.0, by + 8.0, 36.0, 22.0, 0.0, rng.randint(114, 128), 124, 255, rng)
            fan_center = -math.pi * 0.5 + ((bx - S * 0.5) / (S * 0.48)) * 0.70
            for n_idx in range(7):
                na = fan_center + (n_idx - 3.0) * 0.24 + rng.uniform(-0.08, 0.08)
                ox = math.cos(na) * rng.uniform(6.0, 18.0)
                oy = math.sin(na) * rng.uniform(6.0, 16.0)
                sun_bias = 0.5 + 0.5 * (math.cos(na) * 0.50 - math.sin(na) * 0.86)
                lum = int(128 + 54 * sun_bias + rng.uniform(-6, 6))
                hv = int(164 + 78 * sun_bias)
                draw_leaf_dab(d_lum, d_h, bx + ox, by + oy, rng.uniform(10.0, 17.5), rng.uniform(3.2, 5.4), na, lum, hv, 255, rng, pointed=0.62)

    # Radiating Oriental pine needle-fan tufts feathering the perimeter!
    for (lx, ly, sx, sy) in pads:
        for _ in range(155):
            ang = rng.uniform(0.0, math.tau)
            rad = rng.uniform(0.65, 1.08) * 160.0
            px = lx + math.cos(ang) * rad * sx
            py = ly + math.sin(ang) * rad * sy
            fan_center = -math.pi * 0.5 + ((px - S * 0.5) / (S * 0.48)) * 0.85
            lum_base = rng.randint(138, 166)
            hv = rng.randint(148, 210)
            for needle_off in (-0.46, -0.23, 0.0, 0.23, 0.46):
                na = fan_center + needle_off + rng.uniform(-0.08, 0.08)
                ox = math.cos(na) * rng.uniform(4.0, 10.5)
                oy = math.sin(na) * rng.uniform(4.0, 10.5)
                draw_leaf_dab(
                    d_lum, d_h, px + ox, py + oy,
                    rng.uniform(8.0, 14.2), rng.uniform(2.5, 4.4),
                    na, max(128, min(176, lum_base + rng.randint(-5, 7))), hv, 252, rng, pointed=0.70,
                )

    lum_img = lum_img.filter(ImageFilter.GaussianBlur(radius=0.68))
    return encode_normal_and_pack(lum_img, h_img)


def bleed_rgb_into_transparent(atlas: Image.Image) -> Image.Image:
    rgb = atlas.convert("RGB")
    a = atlas.getchannel("A")
    blurred_rgb = rgb.filter(ImageFilter.GaussianBlur(radius=10))
    neutral = Image.new("RGB", atlas.size, (146, 128, 128))
    soft_mask = a.point(lambda v: min(255, v * 3))
    padded_rgb = Image.composite(
        rgb,
        Image.composite(blurred_rgb, neutral, soft_mask.filter(ImageFilter.GaussianBlur(radius=12))),
        a.point(lambda v: 255 if v > 18 else 0),
    )
    out = padded_rgb.convert("RGBA")
    out.putalpha(a)
    return out


def main() -> None:
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    stone_out = os.path.join(root, "assets", "terrain_editor", "gouache_stone_wash.png")
    generate_gouache_stone_wash(stone_out)

    atlas = Image.new("RGBA", (1024, 1024), (146, 128, 128, 0))
    atlas.paste(render_huai_puff_cell(501), (0, 0))
    atlas.paste(render_huai_puff_cell(602), (512, 0))
    atlas.paste(render_pine_cloud_cell(703), (0, 512))
    atlas.paste(render_pine_cloud_cell(804), (512, 512))
    atlas = bleed_rgb_into_transparent(atlas)
    fol_out = os.path.join(root, "assets", "nature", "trees", "botanical_foliage_atlas.png")
    atlas.save(fol_out, optimize=True)
    print("Saved 3D sub-bouquet botanical foliage atlas:", fol_out)


if __name__ == "__main__":
    main()
