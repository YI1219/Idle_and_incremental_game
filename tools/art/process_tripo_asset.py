"""Process a Tripo geometry-only GLB into a game asset (Blender background).

Usage:
  blender -b --python tools/art/process_tripo_asset.py -- \
      --input art/source/.../tripo/original_white.glb \
      --image art/source/.../inputs/single.jpg \
      --kind tree|rock --out assets/nature/.../name.glb \
      [--target-tris 4000] [--preview /tmp/name_preview.png]

Rock: normalise (base on z=0, centred on XY), optional decimate, flat facets,
uniform grey vertex colour (game shaders own the stone palette).
Tree: normalise to the trunk base, decimate, smooth shading, vertex colours
projected from the concept image (front view) and split into bark / foliage
families with a calm palette. The original Tripo file is never modified.
"""
import argparse
import json
import math
import sys

import bpy
import bmesh
from mathutils import Vector


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--image")
    p.add_argument("--kind", choices=["tree", "rock"], required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--target-tris", type=int, default=0)
    p.add_argument("--preview")
    p.add_argument("--report")
    p.add_argument("--painted", action="store_true", help="rock: bake AO + per-facet painted value steps")
    p.add_argument("--planar", type=float, default=0.0, help="rock: dissolve near-coplanar faces (degrees) for broad angular facets")
    p.add_argument("--flatten-sides", type=float, default=0.0, help="rock: clamp both X sides inward by this fraction of width")
    p.add_argument("--palette", default="", help="tree: foliage_lo;foliage_hi;bark_lo;bark_hi as r,g,b triples")
    p.add_argument("--flatten-back", type=float, default=0.0, help="rock: clamp the back (+Y) to this fraction of depth, hiding hallucinated rear detail")
    p.add_argument("--front-rot", type=float, default=None, help="manual Z rotation (deg) instead of auto front")
    return p.parse_args(argv)


def import_joined(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in bpy.context.scene.objects:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o != obj:
            bpy.data.objects.remove(o, do_unlink=True)
    obj.name = "asset"
    return obj


def bounds(obj):
    vs = [v.co for v in obj.data.vertices]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return lo, hi


def normalise(obj, kind):
    lo, hi = bounds(obj)
    if kind == "tree":
        # Trunk base: centroid of the lowest 3% of vertices.
        h = hi.z - lo.z
        base = [v.co for v in obj.data.vertices if v.co.z < lo.z + h * 0.03]
        cx = sum(v.x for v in base) / len(base)
        cy = sum(v.y for v in base) / len(base)
        shift = Vector((-cx, -cy, -lo.z))
    else:
        shift = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    for v in obj.data.vertices:
        v.co += shift
    lo, hi = bounds(obj)
    s = 1.0 / max(hi.z - lo.z, 1e-6)
    for v in obj.data.vertices:
        v.co *= s


def decimate(obj, target):
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if target <= 0 or tris <= target:
        return tris
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = target / tris
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def clean(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-6)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


def load_pixels(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = list(img.pixels[:])
    bg = px[0:3]
    def at(x, y):
        x = min(max(int(x), 0), w - 1)
        y = min(max(int(y), 0), h - 1)
        i = (y * w + x) * 4
        return px[i:i + 3]
    # Foreground bounds: pixels clearly different from the corner background.
    xs, ys = [], []
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            c = at(x, y)
            if abs(c[0] - bg[0]) + abs(c[1] - bg[1]) + abs(c[2] - bg[2]) > 0.12:
                xs.append(x)
                ys.append(y)
    return at, (min(xs), min(ys), max(xs), max(ys)), w, h


def tree_colors(obj, image, palette=""):
    """Bark vs foliage from geometry (thickness along -normal + height),
    tie-broken by the concept image projection, smoothed over neighbours."""
    from mathutils.bvhtree import BVHTree
    at, (x0, y0, x1, y1), w, h = load_pixels(image) if image else (None, (0, 0, 1, 1), 1, 1)
    lo, hi = bounds(obj)
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    score = {}
    for v in bm.verts:
        n = v.normal
        origin = v.co - n * 1e-4
        hit = tree.ray_cast(origin, -n, 1.0)
        thick = (hit[3] if hit[0] is not None else 0.0)
        z = (v.co.z - lo.z) / max(hi.z - lo.z, 1e-6)
        green = 0.0
        if at is not None:
            u = (v.co.x - lo.x) / max(hi.x - lo.x, 1e-6)
            c = Vector(at(x0 + u * (x1 - x0), y0 + z * (y1 - y0)))
            green = 1.0 if (c.y > c.x * 1.04 and c.y > c.z * 0.95) else 0.0
        s = 0.0
        if z > 0.30:
            s += min(1.0, max(0.0, (thick - 0.05) / 0.06))
            s += 0.35 * green
            s += 0.25 * min(1.0, max(0.0, (z - 0.45) / 0.3))
        score[v.index] = s
    # Neighbour smoothing (3 passes) removes speckle at clump/branch joins.
    for _ in range(3):
        nxt = {}
        for v in bm.verts:
            vals = [score[v.index]] + [score[e.other_vert(v).index] for e in v.link_edges]
            nxt[v.index] = sum(vals) / len(vals)
        score = nxt
    foliage = {i: s > 0.62 for i, s in score.items()}
    # Per-clump hue jitter: connected foliage regions.
    region = {}
    rid = 0
    for v in bm.verts:
        if not foliage[v.index] or v.index in region:
            continue
        stack = [v]
        region[v.index] = rid
        while stack:
            cur = stack.pop()
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if foliage[o.index] and o.index not in region:
                    region[o.index] = rid
                    stack.append(o)
        rid += 1
    layer = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    shade_lo = Vector((0.22, 0.33, 0.25))
    shade_hi = Vector((0.47, 0.60, 0.42))
    bark_dark = Vector((0.20, 0.17, 0.15))
    bark_lit = Vector((0.40, 0.35, 0.30))
    if palette:
        vals = [Vector([float(x) for x in part.split(",")]) for part in palette.split(";")]
        shade_lo, shade_hi, bark_dark, bark_lit = vals
    vert_col = {}
    for v in bm.verts:
        z = (v.co.z - lo.z) / max(hi.z - lo.z, 1e-6)
        if foliage[v.index]:
            r = region.get(v.index, 0)
            jit = ((r * 0.6180339) % 1.0 - 0.5) * 0.10
            up = v.normal.z * 0.5 + 0.5
            col = shade_lo.lerp(shade_hi, min(1.0, max(0.0, 0.15 + 0.75 * up + 0.15 * z)))
            col = Vector((col.x * (1.0 + jit * 0.6), col.y * (1.0 + jit * 0.3), col.z * (1.0 - jit * 0.4)))
            vert_col[v.index] = (col.x, col.y, col.z, 1.0)
        else:
            col = bark_dark.lerp(bark_lit, min(1.0, 0.25 + 0.6 * (v.normal.z * 0.5 + 0.5) + 0.15 * z))
            vert_col[v.index] = (col.x, col.y, col.z, 0.0)
    bm.free()
    for loop in mesh.loops:
        layer.data[loop.index].color = vert_col[loop.vertex_index]
    return sum(1 for f in foliage.values() if f) / max(1, len(foliage))


def keep_largest_part(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    seen = set()
    parts = []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack = [v]
        seen.add(v.index)
        comp = []
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        parts.append(comp)
    parts.sort(key=len, reverse=True)
    removed = 0
    for comp in parts[1:]:
        # Drop slivers only; keep real secondary pieces (>8% of the largest).
        if len(comp) < len(parts[0]) * 0.08:
            removed += len(comp)
            bmesh.ops.delete(bm, geom=comp, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    return removed


def orient_rock_front(obj):
    """Rotate about Z so the most sculpted side faces -Y (glTF +Z, Godot +Z)."""
    rough = {}
    for name, axis in (("+x", Vector((1, 0, 0))), ("-x", Vector((-1, 0, 0))), ("+y", Vector((0, 1, 0))), ("-y", Vector((0, -1, 0)))):
        total = 0.0
        for p in obj.data.polygons:
            d = p.normal.dot(axis)
            if d > 0.2:
                total += p.area * (1.0 - d)
        rough[name] = total
    best = max(rough, key=rough.get)
    angle = {"-y": 0.0, "+x": -math.pi / 2, "+y": math.pi, "-x": math.pi / 2}[best]
    from mathutils import Matrix
    m = Matrix.Rotation(angle, 4, "Z")
    for v in obj.data.vertices:
        v.co = m @ v.co
    return best, rough


def rock_colors(obj, painted=False):
    """Neutral .66 grey (shaders own the palette). Painted: baked ambient
    occlusion darkens crevices and each facet gets its own value/temperature
    step, like hand-painted flat facets (Dredge-style), not clay."""
    mesh = obj.data
    layer = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    for loop in mesh.loops:
        layer.data[loop.index].color = (0.66, 0.66, 0.66, 1.0)
    if not painted:
        return {}
    ao = bake_vertex_ao(obj)
    for poly in mesh.polygons:
        h = math.sin(poly.center.x * 41.3 + poly.center.y * 17.1 + poly.center.z * 29.7) * 43758.5453
        j = (h - math.floor(h)) - 0.5
        up = poly.normal.z
        value = 0.66 * (1.0 + j * 0.16) * (1.0 + 0.05 * up)
        warm = 1.0 + j * 0.05
        for li in poly.loop_indices:
            occ = ao[mesh.loops[li].vertex_index]
            v = value * (0.50 + 0.50 * occ)
            layer.data[li].color = (v * warm, v, v / warm, 1.0)
    return {"ao_min": min(ao.values()), "ao_mean": sum(ao.values()) / len(ao)}


def bake_vertex_ao(obj):
    """Hemisphere occlusion per vertex by ray casting (deterministic, no Cycles)."""
    from mathutils.bvhtree import BVHTree
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    dirs = []
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(48):
        z = 1.0 - (i + 0.5) / 48.0
        r = math.sqrt(max(0.0, 1.0 - z * z))
        a = golden * i
        dirs.append(Vector((math.cos(a) * r, math.sin(a) * r, z)))
    ao = {}
    for v in bm.verts:
        n = v.normal
        t1 = n.orthogonal().normalized()
        t2 = n.cross(t1)
        hits = 0
        for d in dirs:
            w = t1 * d.x + t2 * d.y + n * d.z
            hit = tree.ray_cast(v.co + n * 1e-3, w, 0.35)
            if hit[0] is not None:
                hits += 1
        ao[v.index] = 1.0 - hits / len(dirs)
    bm.free()
    return ao


def planar_simplify(obj, angle_deg):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(angle_deg), verts=bm.verts, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()


def shade(obj, kind):
    mesh = obj.data
    if kind == "rock":
        for p in mesh.polygons:
            p.use_smooth = False
    else:
        for p in mesh.polygons:
            p.use_smooth = True
        bpy.context.view_layer.objects.active = obj
        try:
            bpy.ops.object.shade_auto_smooth(angle=math.radians(50))
        except Exception:
            pass


def preview(obj, path):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.light = "STUDIO"
    scene.render.resolution_x = 2048
    scene.render.resolution_y = 512
    scene.render.film_transparent = False
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 1.35
    lo, hi = bounds(obj)
    centre = (lo + hi) / 2
    shots = []
    for i, yaw in enumerate((0, 90, 180, 270)):
        cam = bpy.data.objects.new("cam%d" % i, cam_data)
        scene.collection.objects.link(cam)
        a = math.radians(yaw)
        cam.location = centre + Vector((math.sin(a) * -3, math.cos(a) * -3, 0.9))
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        shots.append(cam)
    # Render three views into one strip.
    import tempfile, os
    tmp = []
    scene.render.resolution_x = 512
    for i, cam in enumerate(shots):
        scene.camera = cam
        f = os.path.join(tempfile.gettempdir(), "tripo_prev_%d.png" % i)
        scene.render.filepath = f
        bpy.ops.render.render(write_still=True)
        tmp.append(f)
    imgs = [bpy.data.images.load(f) for f in tmp]
    out = bpy.data.images.new("strip", 2048, 512)
    pix = [0.0] * (2048 * 512 * 4)
    for k, im in enumerate(imgs):
        p = im.pixels[:]
        for y in range(512):
            row = p[y * 512 * 4:(y + 1) * 512 * 4]
            start = (y * 2048 + k * 512) * 4
            pix[start:start + 512 * 4] = row
    out.pixels = pix
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()


def main():
    a = args()
    obj = import_joined(a.input)
    tris_in = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    report_extra = {}
    report_extra["removed_sliver_verts"] = keep_largest_part(obj)
    if a.kind == "rock" and a.front_rot is None:
        front, rough = orient_rock_front(obj)
        report_extra["front_side"] = front
    elif a.front_rot is not None:
        from mathutils import Matrix
        m = Matrix.Rotation(math.radians(a.front_rot), 4, "Z")
        for v in obj.data.vertices:
            v.co = m @ v.co
        report_extra["front_rot"] = a.front_rot
    if a.flatten_back > 0.0:
        lo, hi = bounds(obj)
        cut = hi.y - (hi.y - lo.y) * a.flatten_back
        for v in obj.data.vertices:
            if v.co.y > cut:
                v.co.y = cut
        report_extra["flatten_back"] = a.flatten_back
    if a.flatten_sides > 0.0:
        lo, hi = bounds(obj)
        inset = (hi.x - lo.x) * a.flatten_sides
        for v in obj.data.vertices:
            v.co.x = min(max(v.co.x, lo.x + inset), hi.x - inset)
        report_extra["flatten_sides"] = a.flatten_sides
    normalise(obj, a.kind)
    clean(obj)
    tris = decimate(obj, a.target_tris)
    clean(obj)
    if a.planar > 0.0:
        planar_simplify(obj, a.planar)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    report = {"input": a.input, "tris_in": tris_in, "tris_out": tris}
    report.update(report_extra)
    if a.kind == "tree":
        report["foliage_vertex_share"] = tree_colors(obj, a.image, a.palette)
        report["palette"] = a.palette
    else:
        report.update(rock_colors(obj, a.painted))
    shade(obj, a.kind)
    lo, hi = bounds(obj)
    report["bounds"] = [list(lo), list(hi)]
    obj.data.materials.clear()
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=a.out, use_selection=True, export_format="GLB",
                              export_vertex_color="ACTIVE", export_normals=True, export_apply=True)
    if a.preview:
        preview(obj, a.preview)
    print("PROCESS_REPORT " + json.dumps(report))
    if a.report:
        with open(a.report, "w") as f:
            json.dump(report, f, indent=2)


main()
