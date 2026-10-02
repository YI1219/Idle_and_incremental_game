"""Build the approved low-poly cottage, export it, and render a review image.

Run with:
  /opt/homebrew/bin/blender --background --python tools/cottage/build_cottage.py
"""
from __future__ import annotations

import bpy
import json
import math
from pathlib import Path
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
BLEND_PATH = ROOT / "art/work/cottage/cottage_demo.blend"
GLB_PATH = ROOT / "assets/buildings/cottage/cottage_demo.glb"
REVIEW_DIR = ROOT / "art/review/cottage"
RENDER_PATH = REVIEW_DIR / "cottage_front.png"
REPORT_PATH = REVIEW_DIR / "dimensions.json"


def material(name: str, srgb: tuple[float, float, float, float], roughness: float = 0.82):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = srgb
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = srgb
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def box(name, location, scale, mat, collection=None, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(mat)
    if collection and obj.name not in collection.objects:
        for coll in list(obj.users_collection):
            coll.objects.unlink(obj)
        collection.objects.link(obj)
    return obj


def mesh_obj(name, verts, faces, mat, collection=None):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    (collection or bpy.context.scene.collection).objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def roof_half(name, sign, roof_mat, collection):
    # Cross-section remains intentionally sparse and smooth: one continuous plane.
    xs = [0.0, 0.65, 1.35, 2.05, 2.65, 3.15, 3.45]
    zs = [3.02, 2.94, 2.75, 2.48, 2.20, 2.02, 2.12]
    ys = [-2.55, 2.35]
    thickness = 0.10
    verts = []
    for dz in (0.0, -thickness):
        for y in ys:
            for x, z in zip(xs, zs):
                verts.append((sign * x, y, z + dz))
    n = len(xs)
    faces = []
    for layer in range(2):
        off = layer * 2 * n
        for yi in range(1):
            row = off + yi * n
            nextrow = off + (yi + 1) * n
            for i in range(n - 1):
                face = (row+i, row+i+1, nextrow+i+1, nextrow+i)
                faces.append(face if layer == 0 else tuple(reversed(face)))
    # Seal front/back and the ridge/eave boundaries.
    for yi in (0, 1):
        row = yi * n
        under = 2*n + yi*n
        for i in range(n-1):
            q = (row+i, under+i, under+i+1, row+i+1)
            faces.append(q if yi == 0 else tuple(reversed(q)))
    for i in (0, n-1):
        faces.append((i, n+i, 3*n+i, 2*n+i))
    obj = mesh_obj(name, verts, faces, roof_mat, collection)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def gable(name, y, wall_mat, collection):
    # Triangle below the roof, with front/back winding selected by sign.
    verts = [(-2.88, y, 2.0), (2.88, y, 2.0), (0.0, y, 2.90)]
    face = (0, 1, 2) if y < 0 else (2, 1, 0)
    return mesh_obj(name, verts, [face], wall_mat, collection)


def setup_camera(target):
    bpy.ops.object.camera_add(location=(7.7, -9.7, 5.7))
    cam = bpy.context.object
    cam.name = "ReviewCamera"
    bpy.context.scene.camera = cam
    direction = Vector(target) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 52


def build():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        pass

    for p in (BLEND_PATH.parent, GLB_PATH.parent, REVIEW_DIR):
        p.mkdir(parents=True, exist_ok=True)

    ivory = material("Ivory plaster", (0.82, 0.78, 0.67, 1.0), 0.9)
    wood = material("Warm brown timber", (0.23, 0.13, 0.085, 1.0), 0.84)
    roof = material("Blue-grey roof", (0.25, 0.37, 0.48, 1.0), 0.78)
    roof_edge = material("Blue-grey roof edge", (0.17, 0.27, 0.36, 1.0), 0.78)
    dark = material("Interior shadow", (0.025, 0.035, 0.04, 1.0), 1.0)
    stone = material("Warm pale stone", (0.52, 0.50, 0.45, 1.0), 0.95)

    shell = bpy.data.collections.new("CottageShell")
    roof_coll = bpy.data.collections.new("Roof")
    details = bpy.data.collections.new("TimberDetails")
    bpy.context.scene.collection.children.link(shell)
    bpy.context.scene.collection.children.link(roof_coll)
    bpy.context.scene.collection.children.link(details)

    # Wall top is 2.0 m. Front is Blender -Y, exported as Godot +Z.
    box("BackWall", (0, 1.91, 1.0), (6.0, .18, 2.0), ivory, shell)
    box("LeftWall", (-2.91, -.10, 1.0), (.18, 4.2, 2.0), ivory, shell)
    box("RightWall", (2.91, -.10, 1.0), (.18, 4.2, 2.0), ivory, shell)
    # The central doorway is a true 1.60 x 1.80 m absence in the wall.
    box("FrontWallLeft", (-1.90, -2.11, 1.0), (2.20, .18, 2.0), ivory, shell)
    box("FrontWallRight", (1.90, -2.11, 1.0), (2.20, .18, 2.0), ivory, shell)
    box("FrontWallHeader", (0, -2.11, 1.90), (1.60, .18, .20), ivory, shell)
    gable("FrontGable", -2.205, ivory, shell)
    gable("BackGable", 2.005, ivory, shell)

    # Shadow panel is recessed well behind the opening, so the doorway remains passable.
    box("InteriorShadow", (0, -1.82, .90), (1.56, .04, 1.78), dark, shell)

    # Sparse framing, kept clear of the passage.
    for x in (-2.72, 2.72):
        box("FrontPost", (x, -2.24, 1.03), (.20, .22, 2.06), wood, details, .025)
    box("FrontTieBeam", (0, -2.24, 1.91), (5.55, .22, .18), wood, details, .025)
    for x in (-.92, .92):
        box("DoorJamb", (x, -2.26, .91), (.18, .20, 1.82), wood, details, .02)
    box("DoorLintel", (0, -2.26, 1.88), (2.02, .20, .18), wood, details, .02)

    # Simple left window: shallow dark recess with a wood surround and one mullion.
    wx, wy, wz = -1.78, -2.25, 1.17
    box("WindowShadow", (wx, wy + .02, wz), (.78, .035, .82), dark, details)
    box("WindowTop", (wx, wy, wz + .48), (1.02, .16, .13), wood, details, .015)
    box("WindowBottom", (wx, wy, wz - .48), (1.02, .16, .13), wood, details, .015)
    for dx in (-.45, .45, 0.0):
        box("WindowFrame", (wx + dx, wy, wz), (.12, .16, .84), wood, details, .012)

    roof_half("RoofLeft", -1, roof, roof_coll)
    roof_half("RoofRight", 1, roof, roof_coll)
    # Single ridge and thin boundary rims emphasize the silhouette without roof tiles.
    box("RidgeCap", (0, 0, 3.05), (.18, 5.02, .18), roof_edge, roof_coll, .06)
    for sign in (-1, 1):
        box("EaveRim", (sign * 3.34, 0, 2.08), (.18, 5.02, .18), roof_edge, roof_coll, .06)

    # Base is decorative and fully below the controller plane (z=0).
    box("SunkenPlinth", (0, -.10, -.12), (6.18, 4.35, .24), stone, shell, .04)

    # Ground and lighting only belong to the review scene; excluded from export by selection.
    review = bpy.data.collections.new("ReviewOnly")
    bpy.context.scene.collection.children.link(review)
    ground = box("ReviewGround", (0, 0, -.27), (18, 18, .20), material("Ground", (.74, .71, .64, 1), 1), review)
    setup_camera((0, 0, 1.25))
    bpy.ops.object.light_add(type="AREA", location=(-4.5, -5.5, 7.5))
    key = bpy.context.object
    key.name = "KeyLight"
    key.data.energy = 1050
    key.data.shape = "DISK"
    key.data.size = 5.0
    bpy.ops.object.light_add(type="AREA", location=(5.0, -1.0, 4.0))
    fill = bpy.context.object
    fill.name = "FillLight"
    fill.data.energy = 550
    fill.data.size = 4.0

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(RENDER_PATH)
    scene.render.film_transparent = False
    scene.world.color = (0.055, 0.065, 0.08)
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.render.render(write_still=True)

    # Export only gameplay geometry.
    bpy.ops.object.select_all(action="DESELECT")
    export_objects = []
    for coll in (shell, roof_coll, details):
        for obj in coll.objects:
            if obj.type == "MESH":
                obj.select_set(True)
                export_objects.append(obj)
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH), export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True, export_materials="EXPORT")

    report = {
        "units": "metres",
        "footprint": {"width": 6.0, "depth": 4.2},
        "wall_top": 2.0,
        "roof": {"ridge_height": 3.05, "eave_height": 2.02, "overhang_width": 6.9},
        "door_clear_opening": {"width": 1.60, "height": 1.80, "front_local_z_after_export": 2.20},
        "player_reference": {"height": 1.12, "capsule_diameter": 0.40},
        "clearance_ratios": {"door_to_player_height": round(1.80/1.12, 3), "door_to_capsule_width": 4.0},
        "walk_plane": 0.0,
        "plinth_top": 0.0,
        "exported_mesh_count": len(export_objects),
        "notes": ["Front faces Godot +Z after glTF Y-up conversion.", "Doorway contains no wall mesh or curtain."],
    }
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    build()
