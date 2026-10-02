"""Copy-safe repair of Qinglan body+clothes Tripo meshes.

Raises hanging sleeves toward the body's T-pose, solidifies the open
robe shell, welds tiny body islands, then saves a new blend/glb.

Run:
  blender --background --python tools/qinglan/fix_tripo_regen.py
"""

from __future__ import annotations

import json
from collections import deque
from pathlib import Path

import bmesh
import bpy
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art/source/qinglan/generation_ref/11-regen/tripo-fix"
OUT = SRC / "inspect"


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.12, 0.12, 0.14, 1.0)
    bg.inputs[1].default_value = 1.0


def import_fbx(path: Path, name: str) -> bpy.types.Object:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(path), automatic_bone_orientation=True)
    objs = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in objs if o.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"no mesh in {path}")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def world_bbox(obj: bpy.types.Object):
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    xs = [c.x for c in corners]
    ys = [c.y for c in corners]
    zs = [c.z for c in corners]
    return (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))


def combined_bbox(objs):
    boxes = [world_bbox(o) for o in objs]
    return (
        min(b[0] for b in boxes),
        max(b[1] for b in boxes),
        min(b[2] for b in boxes),
        max(b[3] for b in boxes),
        min(b[4] for b in boxes),
        max(b[5] for b in boxes),
    )


def island_vert_groups(mesh: bpy.types.Mesh) -> list[list[int]]:
    adj = {i: set() for i in range(len(mesh.vertices))}
    for poly in mesh.polygons:
        vs = list(poly.vertices)
        for a, b in zip(vs, vs[1:] + vs[:1]):
            adj[a].add(b)
            adj[b].add(a)
    seen: set[int] = set()
    groups: list[list[int]] = []
    for start in adj:
        if start in seen:
            continue
        q = deque([start])
        seen.add(start)
        g = [start]
        while q:
            v = q.popleft()
            for w in adj[v]:
                if w not in seen:
                    seen.add(w)
                    q.append(w)
                    g.append(w)
        groups.append(g)
    groups.sort(key=len, reverse=True)
    return groups


def isolate_main_island(obj: bpy.types.Object) -> list[bpy.types.Object]:
    """Keep the largest island; return extra island objects (ribbons / debris)."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(obj.name)]
    parts.sort(key=lambda o: len(o.data.vertices), reverse=True)
    main = parts[0]
    main.name = obj.name.split(".")[0]
    extras = parts[1:]
    for i, extra in enumerate(extras):
        extra.name = f"{main.name}_island{i+1}"
    return extras


def fill_small_holes(obj: bpy.types.Object, sides: int = 8) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.fill_holes(sides=sides)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def _smoothstep(edge0: float, edge1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - edge0) / max(edge1 - edge0, 1e-6)))
    return t * t * (3.0 - 2.0 * t)


def body_arm_targets(body: bpy.types.Object) -> dict:
    """Character faces +X, T-pose arms along ±Y, height Z."""
    mesh = body.data
    left = []
    right = []
    for v in mesh.vertices:
        p = body.matrix_world @ v.co
        if p.y > 0.18:
            left.append(p)
        elif p.y < -0.18:
            right.append(p)
    def axis(pts, sign: float):
        if not pts:
            return Vector((0.0, sign, 0.0)), Vector((0.0, sign * 0.12, 0.22))
        pts = sorted(pts, key=lambda p: p.z, reverse=True)
        shoulder = min(pts, key=lambda p: abs(p.y) + abs(p.z - 0.22) * 0.3)
        tip = max(pts, key=lambda p: abs(p.y))
        d = tip - shoulder
        if d.length < 1e-5:
            d = Vector((0.0, sign, 0.0))
        return d.normalized(), shoulder
    ldir, lpiv = axis(left, 1.0)
    rdir, rpiv = axis(right, -1.0)
    return {
        "left_dir": ldir,
        "right_dir": rdir,
        "left_pivot": lpiv,
        "right_pivot": rpiv,
    }


def lift_sleeves(clothes: bpy.types.Object, arms: dict) -> dict:
    """Raise hanging sleeves toward T-pose without spinning the whole robe."""
    bm = bmesh.new()
    bm.from_mesh(clothes.data)
    bm.verts.ensure_lookup_table()
    stats = {"moved": 0}

    def weight(p: Vector, sign: float) -> float:
        if p.y * sign <= 0.16:
            return 0.0
        if p.z < -0.08:
            return 0.0
        if p.z > 0.38:
            return 0.0
        w = _smoothstep(0.16, 0.32, abs(p.y))
        w *= _smoothstep(-0.08, 0.12, p.z)
        w *= 1.0 - _smoothstep(0.30, 0.40, p.z)
        return w

    for v in bm.verts:
        for sign, pivot, target in (
            (1.0, arms["left_pivot"], arms["left_dir"]),
            (-1.0, arms["right_pivot"], arms["right_dir"]),
        ):
            w = weight(v.co, sign)
            if w <= 0.01:
                continue
            local = v.co - pivot
            current = Vector((0.0, local.y, local.z))
            if current.length < 1e-5:
                continue
            mixed = (current.normalized() * 0.42 + target.normalized() * 0.58).normalized()
            rot = current.normalized().rotation_difference(mixed)
            q = Quaternion((1.0, 0.0, 0.0, 0.0)).slerp(rot, w * 0.9)
            v.co = pivot + q @ local
            v.co.y += 0.04 * w * sign
            v.co.z += 0.03 * w
            stats["moved"] += 1
            break
    bm.to_mesh(clothes.data)
    bm.free()
    clothes.data.update()
    return stats


def wrap_sleeves_around_arms(clothes: bpy.types.Object, arms: dict) -> int:
    """Keep sleeve cloth outside a cylinder around each T-pose arm."""
    bm = bmesh.new()
    bm.from_mesh(clothes.data)
    bm.verts.ensure_lookup_table()
    moved = 0
    for pivot, axis in (
        (arms["left_pivot"], arms["left_dir"]),
        (arms["right_pivot"], arms["right_dir"]),
    ):
        axis = axis.normalized()
        for v in bm.verts:
            rel = v.co - pivot
            t = rel.dot(axis)
            if t < 0.02 or t > 0.40:
                continue
            radial = rel - axis * t
            # Ignore hanging ribbons far below the arm.
            if radial.z < -0.08:
                continue
            r = radial.length
            if r > 0.16:
                continue
            min_r = 0.048 + 0.06 * (t / 0.40)
            if r < min_r:
                n = radial if r > 1e-5 else Vector((1.0, 0.0, 0.0))
                v.co = pivot + axis * t + n.normalized() * min_r
                moved += 1
    bm.to_mesh(clothes.data)
    bm.free()
    clothes.data.update()
    return moved


def drop_collar_off_skull(clothes: bpy.types.Object) -> int:
    """Keep the back collar at the neck, not covering the bun."""
    moved = 0
    bm = bmesh.new()
    bm.from_mesh(clothes.data)
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        if abs(v.co.y) > 0.13:
            continue
        if v.co.z < 0.30:
            continue
        if v.co.x > 0.04:
            continue
        w = _smoothstep(0.30, 0.40, v.co.z)
        target_z = 0.30
        if v.co.z > target_z:
            v.co.z = v.co.z * (1.0 - 0.65 * w) + target_z * (0.65 * w)
            v.co.x = min(v.co.x, 0.02)
            moved += 1
    bm.to_mesh(clothes.data)
    bm.free()
    clothes.data.update()
    return moved


def solidify(obj: bpy.types.Object, thickness: float = 0.006) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new(name="Solidify", type="SOLIDIFY")
    mod.thickness = thickness
    mod.offset = 1.0
    mod.use_even_offset = True
    mod.use_quality_normals = True
    if hasattr(mod, "thickness_clamp"):
        mod.thickness_clamp = 0.04
    bpy.ops.object.modifier_apply(modifier=mod.name)
    corr = obj.modifiers.new(name="CorrSmooth", type="CORRECTIVE_SMOOTH")
    corr.factor = 0.5
    corr.iterations = 12
    corr.use_only_smooth = True
    bpy.ops.object.modifier_apply(modifier=corr.name)


def push_outside_body(clothes: bpy.types.Object, body: bpy.types.Object, margin: float = 0.014) -> int:
    """Push torso/sleeve verts off the body. Skip collar and hem rims."""
    deps = bpy.context.evaluated_depsgraph_get()
    body_eval = body.evaluated_get(deps)
    moved = 0
    bm = bmesh.new()
    bm.from_mesh(clothes.data)
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        if v.co.z > 0.27 or v.co.z < -0.38:
            continue
        ok, loc, normal, _idx = body_eval.closest_point_on_mesh(v.co)
        if not ok or normal.length < 1e-8:
            continue
        side = (v.co - loc).dot(normal)
        if side < margin:
            v.co = loc + normal.normalized() * margin
            moved += 1
    bm.to_mesh(clothes.data)
    bm.free()
    clothes.data.update()
    return moved


def smooth_collar(obj: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for v in obj.data.vertices:
        v.select = v.co.z > 0.26 and abs(v.co.y) < 0.16
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.vertices_smooth(factor=0.7, repeat=12)
    bpy.ops.object.mode_set(mode="OBJECT")


def smooth_object(obj: bpy.types.Object, factor: float = 0.35, repeat: int = 4) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.vertices_smooth(factor=factor, repeat=repeat)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def mat(name: str, rgba: tuple[float, float, float, float], alpha: float = 1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    color = (rgba[0], rgba[1], rgba[2], alpha)
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.55
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    return m


def look_at(cam, target: Vector) -> None:
    direction = target - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def add_light() -> None:
    bpy.ops.object.light_add(type="AREA", location=(1.8, -1.6, 2.4))
    bpy.context.object.data.energy = 260
    bpy.context.object.data.size = 3.0
    bpy.ops.object.light_add(type="AREA", location=(-2.0, 1.2, 1.8))
    bpy.context.object.data.energy = 90
    bpy.context.object.data.size = 2.0


def render_views(objs, prefix: str) -> list[str]:
    xmin, xmax, ymin, ymax, zmin, zmax = combined_bbox(objs)
    cx = (xmin + xmax) / 2
    cy = (ymin + ymax) / 2
    cz = (zmin + zmax) / 2
    span = max(xmax - xmin, ymax - ymin, zmax - zmin, 0.2)
    target = Vector((cx, cy, cz))
    cam_data = bpy.data.cameras.new(f"Cam_{prefix}")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = span * 1.4
    cam = bpy.data.objects.new(f"Cam_{prefix}", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    # Character faces +X; arms along Y.
    views = {
        "front": Vector((cx + span * 2.2, cy, cz)),
        "side": Vector((cx, cy - span * 2.2, cz)),
        "threequarter": Vector((cx + span * 1.6, cy - span * 1.6, cz + span * 0.3)),
    }
    paths = []
    for name, loc in views.items():
        cam.location = loc
        look_at(cam, target)
        path = OUT / f"{prefix}-{name}.png"
        bpy.context.scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        paths.append(str(path))
    return paths


def inspect(obj: bpy.types.Object) -> dict:
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.edges.ensure_lookup_table()
    boundary = sum(1 for e in bm.edges if e.is_boundary)
    nonman = sum(1 for e in bm.edges if not e.is_manifold)
    quads = sum(1 for f in bm.faces if len(f.verts) == 4)
    tris = sum(1 for f in bm.faces if len(f.verts) == 3)
    bm.free()
    xmin, xmax, ymin, ymax, zmin, zmax = world_bbox(obj)
    return {
        "name": obj.name,
        "verts": len(mesh.vertices),
        "faces": len(mesh.polygons),
        "tris": tris,
        "quads": quads,
        "islands": len(island_vert_groups(mesh)),
        "boundary_edges": boundary,
        "nonmanifold_edges": nonman,
        "size": [round(xmax - xmin, 4), round(ymax - ymin, 4), round(zmax - zmin, 4)],
    }


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    reset_scene()
    body = import_fbx(SRC / "body.fbx", "body")
    clothes = import_fbx(SRC / "clothes.fbx", "clothes")

    body_before = inspect(body)
    clothes_before = inspect(clothes)
    print("BODY before", json.dumps(body_before))
    print("CLOTHES before", json.dumps(clothes_before))

    fill_small_holes(body, sides=8)

    extras = isolate_main_island(clothes)
    debris = []
    ribbon_objs = []
    for extra in extras:
        if len(extra.data.vertices) < 120:
            debris.append(extra)
        else:
            ribbon_objs.append(extra)
    bpy.ops.object.select_all(action="DESELECT")
    for extra in debris:
        extra.select_set(True)
    if debris:
        bpy.ops.object.delete()

    arms = body_arm_targets(body)
    print(
        "ARM targets",
        {k: [round(x, 4) for x in v] for k, v in arms.items()},
    )
    lift = lift_sleeves(clothes, arms)
    print("SLEEVE verts rotated", lift)
    wrapped = wrap_sleeves_around_arms(clothes, arms)
    print("SLEEVE verts wrapped around arms", wrapped)
    collar = drop_collar_off_skull(clothes)
    print("COLLAR verts dropped", collar)
    solidify(clothes, thickness=0.006)
    wrapped2 = wrap_sleeves_around_arms(clothes, arms)
    print("SLEEVE verts rewrapped after solidify", wrapped2)
    moved = push_outside_body(clothes, body, margin=0.012)
    print("CLOTHES verts pushed out of body", moved)
    smooth_collar(clothes)
    smooth_object(clothes, factor=0.12, repeat=2)

    body_mat = mat("body_mat", (0.42, 0.48, 0.55, 1.0))
    clothes_mat = mat("clothes_mat", (0.62, 0.72, 0.78, 1.0))
    ribbon_mat = mat("ribbon_mat", (0.55, 0.66, 0.70, 1.0))
    overlay_mat = mat("clothes_overlay", (0.62, 0.72, 0.78, 1.0), alpha=0.52)
    body.data.materials.clear()
    body.data.materials.append(body_mat)
    clothes.data.materials.clear()
    clothes.data.materials.append(clothes_mat)
    for ribbon in ribbon_objs:
        ribbon.data.materials.clear()
        ribbon.data.materials.append(ribbon_mat)

    add_light()
    clothes_all = [clothes] + ribbon_objs
    report = {
        "body_before": body_before,
        "clothes_before": clothes_before,
        "body_after": inspect(body),
        "clothes_after": inspect(clothes),
        "ribbons": [inspect(o) for o in ribbon_objs],
        "sleeve_lift": lift,
        "clothes_pushed": moved,
        "previews": {},
    }

    clothes.hide_render = True
    for r in ribbon_objs:
        r.hide_render = True
    body.hide_render = False
    report["previews"]["body"] = render_views([body], "body")

    body.hide_render = True
    clothes.hide_render = False
    for r in ribbon_objs:
        r.hide_render = False
    report["previews"]["clothes"] = render_views(clothes_all, "clothes")

    body.hide_render = False
    clothes.data.materials.clear()
    clothes.data.materials.append(overlay_mat)
    report["previews"]["overlay"] = render_views([body] + clothes_all, "overlay")

    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False))
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC / "qinglan-regen-fix.blend"))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(SRC / "qinglan-regen-fix.glb"),
        export_format="GLB",
        use_selection=False,
    )
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
