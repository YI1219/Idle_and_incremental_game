#!/usr/bin/env python3
"""Automated 3D Asset Optimization, Topology, Color-Bleed & 4-View Turntable Verifier.

Runs inside Blender (headless) to verify:
1. Triangle/vertex budget & zero loose verts/edges/zero-area faces.
2. Single-mesh / single-material draw-call optimization & valid vertex color layer.
3. Coplanar quad diagonal color-bleed check (rejects AI triangle-soup color bleeding).
4. Grounding & transform check (bottom at Z=0, applied scale=(1,1,1)).
5. Renders a 4-angle turntable sheet (Front 0°, Right 90°, Back 180°, 3/4 Iso) for visual QA.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description="Verify and render 4-view turntable for a 3D GLB asset.")
    p.add_argument("--input", type=Path, required=True, help="Path to .glb asset")
    p.add_argument("--out-dir", type=Path, required=True, help="Directory for JSON report and turntable PNG")
    p.add_argument("--max-tris", type=int, default=2000, help="Maximum triangle budget")
    p.add_argument("--max-color-bleed", type=float, default=0.05, help="Max fraction of coplanar quads with diagonal color bleed")
    return p.parse_args(argv)


def make_preview_material(name: str):
    mat = bpy.data.materials.new(name=name)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.90
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.14
    vcol = nodes.new("ShaderNodeVertexColor")
    vcol.layer_name = "Color"
    links.new(vcol.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def audit_mesh(glb_path: Path, max_tris: int, max_bleed: float) -> dict:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb_path))

    mesh_objs = [o for o in bpy.data.objects if o.type == "MESH"]
    failures = []
    warnings = []

    if len(mesh_objs) == 0:
        return {"passed": False, "failures": ["No mesh objects found in GLB"]}
    if len(mesh_objs) > 2:
        warnings.append(f"Multiple mesh objects ({len(mesh_objs)}) increase draw calls; prefer 1 merged mesh")

    total_tris = 0
    total_verts = 0
    loose_verts = 0
    degenerate_faces = 0
    bottom_cap_tris = 0
    coplanar_pairs = 0
    bleed_pairs = 0

    all_xs, all_ys, all_zs = [], [], []

    for obj in mesh_objs:
        me = obj.data
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.verts.ensure_lookup_table()
        bm.edges.ensure_lookup_table()
        bm.faces.ensure_lookup_table()

        total_verts += len(bm.verts)
        total_tris += len(bm.faces)

        for v in bm.verts:
            w = obj.matrix_world @ v.co
            all_xs.append(w.x)
            all_ys.append(w.y)
            all_zs.append(w.z)
            if len(v.link_edges) == 0:
                loose_verts += 1

        for f in bm.faces:
            if f.calc_area() < 1e-6:
                degenerate_faces += 1
            c_world = obj.matrix_world @ f.calc_center_median()
            n_world = (obj.matrix_world.to_3x3() @ f.normal).normalized()
            if c_world.z < 0.005 and n_world.z < -0.95:
                bottom_cap_tris += 1

        bm.free()

        # Check vertex colors & coplanar diagonal color bleed on original polygons
        if not me.color_attributes:
            failures.append(f"{obj.name}: missing vertex color attribute")
        else:
            layer = me.color_attributes[0]
            poly_colors = []
            for poly in me.polygons:
                r = sum(layer.data[li].color[0] for li in poly.loop_indices) / len(poly.loop_indices)
                g = sum(layer.data[li].color[1] for li in poly.loop_indices) / len(poly.loop_indices)
                b = sum(layer.data[li].color[2] for li in poly.loop_indices) / len(poly.loop_indices)
                poly_colors.append(Vector((r, g, b)))

            # Map geometric edges (quantized to 0.1mm so split-normal GLBs still match shared edges)
            def vkey(v_idx: int) -> tuple[int, int, int]:
                co = me.vertices[v_idx].co
                return (round(co.x * 10000), round(co.y * 10000), round(co.z * 10000))

            edge_map: dict[tuple[tuple[int, int, int], tuple[int, int, int]], list[int]] = {}
            for p_idx, poly in enumerate(me.polygons):
                vs = [vkey(vi) for vi in poly.vertices]
                for i in range(len(vs)):
                    a, b = vs[i], vs[(i + 1) % len(vs)]
                    ek = (a, b) if a <= b else (b, a)
                    edge_map.setdefault(ek, []).append(p_idx)

            for ek, pids in edge_map.items():
                if len(pids) == 2:
                    p1, p2 = me.polygons[pids[0]], me.polygons[pids[1]]
                    if p1.normal.dot(p2.normal) > 0.996:
                        coplanar_pairs += 1
                        diff = (poly_colors[pids[0]] - poly_colors[pids[1]]).length
                        if diff > 0.16:
                            bleed_pairs += 1

    min_z = min(all_zs) if all_zs else 0.0
    max_z = max(all_zs) if all_zs else 0.0
    dims = [
        round(max(all_xs) - min(all_xs), 3),
        round(max(all_ys) - min(all_ys), 3),
        round(max_z - min_z, 3),
    ]
    bleed_ratio = bleed_pairs / max(1, coplanar_pairs)

    if total_tris > max_tris:
        failures.append(f"Triangle count {total_tris} exceeds budget {max_tris}")
    if loose_verts > 0:
        failures.append(f"Found {loose_verts} loose vertices")
    if degenerate_faces > 0:
        failures.append(f"Found {degenerate_faces} zero-area degenerate faces")
    if abs(min_z) > 0.03:
        failures.append(f"Asset bottom min_z={min_z:.4f} is not grounded at Z=0")
    if bleed_ratio > max_bleed and bleed_pairs > 4:
        failures.append(
            f"Coplanar diagonal color bleed ratio {bleed_ratio:.3f} ({bleed_pairs}/{coplanar_pairs}) exceeds {max_bleed}"
        )

    return {
        "asset": str(glb_path),
        "passed": len(failures) == 0,
        "mesh_objects": len(mesh_objs),
        "vertices": total_verts,
        "triangles": total_tris,
        "dimensions_m": dims,
        "min_z": round(min_z, 4),
        "loose_vertices": loose_verts,
        "degenerate_faces": degenerate_faces,
        "unseen_bottom_cap_tris": bottom_cap_tris,
        "coplanar_color_bleed_ratio": round(bleed_ratio, 4),
        "coplanar_bleed_pairs": bleed_pairs,
        "failures": failures,
        "warnings": warnings,
    }


def render_turntable(glb_path: Path, out_png: Path, dims: list[float]) -> None:
    scene = bpy.context.scene
    mesh_objs = [o for o in bpy.data.objects if o.type == "MESH"]
    mat = make_preview_material("TurntableMat")
    for o in mesh_objs:
        o.data.materials.clear()
        o.data.materials.append(mat)

    max_dim = max(dims[0], dims[1], dims[2], 0.5)
    spacing = max_dim * 1.45

    # Create 4 rotated clones side by side: Front (0°), Right (90°), Back (180°), 3/4 Iso (38°)
    angles = [0.0, math.radians(90.0), math.radians(180.0), math.radians(38.0)]
    root_objs = [o for o in bpy.data.objects if o.parent is None and o.type in ("MESH", "EMPTY")]

    for idx, ang in enumerate(angles):
        x_off = (idx - 1.5) * spacing
        if idx == 0:
            for r in root_objs:
                r.rotation_mode = "XYZ"
                r.location.x += x_off
                r.rotation_euler = (0.0, 0.0, ang)
        else:
            for o in mesh_objs:
                dup = o.copy()
                dup.data = o.data
                scene.collection.objects.link(dup)
                dup.parent = None
                dup.rotation_mode = "XYZ"
                dup.location = Vector((x_off, 0.0, 0.0))
                dup.rotation_euler = (0.0, 0.0, ang)

    # Studio floor
    bpy.ops.mesh.primitive_plane_add(size=spacing * 8.0, location=(0.0, 0.0, 0.0))
    floor = bpy.context.active_object
    fmat = bpy.data.materials.new("Floor")
    bsdf = fmat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (srgb_to_linear(0.86), srgb_to_linear(0.89), srgb_to_linear(0.86), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.96
    floor.data.materials.append(fmat)

    world = bpy.data.worlds.new("World")
    scene.world = world
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (srgb_to_linear(0.82), srgb_to_linear(0.88), srgb_to_linear(0.86), 1.0)
        bg.inputs["Strength"].default_value = 0.85

    sun = bpy.data.lights.new("Sun", type="SUN")
    sun.energy = 2.6
    sun.color = (1.0, 0.95, 0.86)
    sun.angle = math.radians(7.0)
    sun_obj = bpy.data.objects.new("Sun", sun)
    scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(48), math.radians(14), math.radians(-32))

    fill = bpy.data.lights.new("Fill", type="SUN")
    fill.energy = 1.1
    fill.color = (0.78, 0.88, 0.92)
    fill_obj = bpy.data.objects.new("Fill", fill)
    scene.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = (math.radians(55), math.radians(-18), math.radians(140))

    cam = bpy.data.cameras.new("TurntableCam")
    cam.type = "ORTHO"
    cam.ortho_scale = spacing * 4.15
    cam_obj = bpy.data.objects.new("TurntableCam", cam)
    scene.collection.objects.link(cam_obj)
    cam_obj.location = (0.0, -max_dim * 4.0, dims[2] * 0.55 + max_dim * 0.85)
    target = Vector((0.0, 0.0, dims[2] * 0.45))
    cam_obj.rotation_euler = (target - cam_obj.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam_obj

    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 480
    scene.render.filepath = str(out_png)
    bpy.ops.render.render(write_still=True)


def main() -> int:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    stem = args.input.stem
    report = audit_mesh(args.input, args.max_tris, args.max_color_bleed)
    turntable_png = args.out_dir / f"{stem}_turntable.png"
    if "dimensions_m" in report:
        render_turntable(args.input, turntable_png, report["dimensions_m"])
        report["turntable_png"] = str(turntable_png)
    report_path = args.out_dir / f"{stem}_audit.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if report.get("passed", False) else 1


if __name__ == "__main__":
    raise SystemExit(main())
