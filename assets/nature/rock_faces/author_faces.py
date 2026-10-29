"""Author separate cliff-face pieces. Each file is one cropped face, not an island.

Local frame: origin on the grass lip, +X along the wall, +Y up, +Z outward.
The mesh hangs below Y=0 so it can bury into the heightmap shell.
"""
import json
import os

import bpy
import bmesh

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__)))
REPORT = os.path.join(OUT, "author_report.json")


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def new_mesh(name: str, verts: list, faces: list):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.from_pydata(verts, [], faces)
    mesh.validate(verbose=False)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for face in bm.faces:
        face.smooth = False
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return obj


def _vert(along: float, up: float, outward: float) -> tuple:
    # Blender is Z-up. glTF export maps (x, y, z) to (x, z, -y).
    return (along, -outward, up)


def loft(name: str, length: float, rings: list):
    count = len(rings[0])
    if len(rings) < 2 or any(len(ring) != count or count < 3 for ring in rings):
        raise RuntimeError(name)
    verts = []
    for index, ring in enumerate(rings):
        along = length * float(index) / float(len(rings) - 1)
        verts += [_vert(along, y, z) for y, z in ring]
    faces = [list(range(count - 1, -1, -1))]
    faces.append(list(range((len(rings) - 1) * count, len(rings) * count)))
    for band in range(len(rings) - 1):
        base = band * count
        nxt_base = base + count
        for index in range(count):
            nxt = (index + 1) % count
            faces.append([base + index, base + nxt, nxt_base + nxt, nxt_base + index])
    return new_mesh(name, verts, faces)


def prism(name: str, poly: list, y0: float, y1: float):
    count = len(poly)
    verts = [_vert(x, y0, z) for x, z in poly]
    verts += [_vert(x, y1, z) for x, z in poly]
    faces = [list(range(count - 1, -1, -1))]
    faces.append(list(range(count, count * 2)))
    for index in range(count):
        nxt = (index + 1) % count
        faces.append([index, nxt, count + nxt, count + index])
    return new_mesh(name, verts, faces)


def shade(obj) -> None:
    mat = bpy.data.materials.new(obj.name + "_matte")
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (0.62, 0.63, 0.61, 1.0)
    principled.inputs["Roughness"].default_value = 0.94
    principled.inputs["Specular IOR Level"].default_value = 0.12
    obj.data.materials.append(mat)


def export_obj(obj, path: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_normals=True,
        export_texcoords=True,
        export_cameras=False,
        export_lights=False,
    )


def stats(obj) -> dict:
    mesh = obj.data
    mesh.calc_loop_triangles()
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    zs = [v.co.z for v in mesh.vertices]
    return {
        "name": obj.name,
        "triangles": len(mesh.loop_triangles),
        "vertices": len(mesh.vertices),
        "bounds_min": [min(xs), min(ys), min(zs)],
        "bounds_max": [max(xs), max(ys), max(zs)],
    }


def build() -> list:
    pieces = []
    # Wide quiet face. One end sits further out than the other.
    # up, outward. Front planes stay outside the lip. A mid ring kinks the face.
    pieces.append(loft("face_broad", 2.15, [
        [(0.04, -0.62), (0.02, 0.10), (-0.20, 0.28), (-1.15, 0.36), (-2.15, 0.16), (-2.55, -0.28), (-2.62, -0.72)],
        [(0.04, -0.62), (0.00, 0.06), (-0.24, 0.16), (-1.20, 0.20), (-2.10, 0.04), (-2.50, -0.40), (-2.58, -0.72)],
        [(0.04, -0.62), (0.01, 0.12), (-0.16, 0.34), (-1.10, 0.42), (-2.18, 0.22), (-2.58, -0.18), (-2.64, -0.72)],
    ]))
    pieces.append(loft("face_proud", 1.45, [
        [(0.05, -0.48), (0.03, 0.16), (-0.12, 0.58), (-1.25, 0.66), (-2.20, 0.40), (-2.58, -0.05), (-2.64, -0.55)],
        [(0.05, -0.48), (0.01, 0.12), (-0.18, 0.46), (-1.30, 0.50), (-2.15, 0.28), (-2.52, -0.16), (-2.60, -0.55)],
    ]))
    pieces.append(loft("face_setback", 1.85, [
        [(0.03, -0.58), (0.00, 0.08), (-0.22, 0.14), (-1.20, 0.12), (-2.10, 0.02), (-2.48, -0.36), (-2.55, -0.68)],
        [(0.03, -0.58), (-0.02, 0.05), (-0.26, 0.08), (-1.25, 0.06), (-2.05, -0.06), (-2.45, -0.46), (-2.52, -0.68)],
    ]))
    pieces.append(loft("lip_out", 1.45, [
        [(0.06, -0.20), (0.02, 0.14), (-0.28, 0.32), (-0.40, 0.02), (-0.08, -0.24)],
        [(0.06, -0.20), (0.00, 0.08), (-0.32, 0.20), (-0.42, -0.06), (-0.08, -0.24)],
    ]))
    pieces.append(loft("lip_in", 1.45, [
        [(0.05, -0.28), (0.00, 0.06), (-0.30, 0.10), (-0.42, -0.12), (-0.06, -0.32)],
        [(0.05, -0.28), (-0.02, 0.02), (-0.34, 0.04), (-0.44, -0.18), (-0.06, -0.32)],
    ]))
    pieces.append(loft("tuck_long", 2.60, [
        [(-1.90, 0.22), (-2.25, 0.08), (-2.75, -0.28), (-3.15, -0.70), (-1.85, -0.48)],
        [(-1.92, 0.08), (-2.30, -0.08), (-2.82, -0.48), (-3.18, -0.78), (-1.88, -0.48)],
    ]))
    pieces.append(loft("tuck_short", 1.40, [
        [(-1.85, 0.28), (-2.15, 0.12), (-2.60, -0.08), (-2.95, -0.40), (-1.80, -0.36)],
        [(-1.88, 0.12), (-2.20, -0.02), (-2.68, -0.24), (-3.00, -0.46), (-1.82, -0.36)],
    ]))
    pieces.append(loft("cheek_high", 0.62, [
        [(0.03, -0.28), (0.00, 0.18), (-1.15, 0.24), (-1.28, -0.30)],
        [(0.03, -0.24), (-0.02, 0.10), (-1.18, 0.12), (-1.26, -0.32)],
    ]))
    pieces.append(loft("cheek_low", 0.58, [
        [(-0.95, -0.18), (-1.00, 0.16), (-2.45, 0.10), (-2.62, -0.42)],
        [(-0.98, -0.22), (-1.05, 0.06), (-2.50, -0.04), (-2.60, -0.44)],
    ]))
    # Thick folded corner. The nose is one piece; the walls beside it are others.
    pieces.append(prism("corner_plug", [
        (0.08, -0.28),
        (0.02, 0.22),
        (0.70, 0.55),
        (1.05, 0.78),
        (0.62, 0.18),
        (0.48, -0.22),
    ], -2.85, 0.02))
    for obj in pieces:
        shade(obj)
    return pieces


def main() -> None:
    reset()
    pieces = build()
    report = []
    for obj in pieces:
        path = os.path.join(OUT, obj.name + ".glb")
        export_obj(obj, path)
        item = stats(obj)
        item["file"] = os.path.basename(path)
        report.append(item)
        print(json.dumps(item))
    with open(REPORT, "w", encoding="utf-8") as handle:
        json.dump({"blender": bpy.app.version_string, "pieces": report}, handle, indent=2)
    print("WROTE", len(report), "pieces")


if __name__ == "__main__":
    main()
