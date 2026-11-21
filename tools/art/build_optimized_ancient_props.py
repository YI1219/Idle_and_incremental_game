#!/usr/bin/env python3
"""Headless Blender 5.x builder for Journey/Oriental-Minimalism Floating Island props:
1. taihu_scholar_rock.glb — Smooth, perforated Taihu scholar's rock (瘦皱漏透) on stone plinth
2. ink_stone_daybed.glb   — Sleek rounded-bevel dark ink-celadon monolithic stone daybed (乌石琴榻)
3. song_stone_lantern.glb — Low carved hexagonal Song-style garden stone lantern (宋式青石灯笼)
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

REPO = Path("/Users/yi/Projects/games/the-scroll-within")
OUT_DIR = REPO / "assets/props"
PREVIEW_DIR = Path("/Users/yi/.gemini/antigravity-cli/brain/44b851a7-0b14-49b7-ac4b-fee3c216d9c3/scratch")


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def export_glb(obj: bpy.types.Object, out_path: Path) -> dict:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        use_selection=True,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_normals=True,
        export_attributes=True,
        export_materials="EXPORT",
    )
    mesh = obj.data
    mesh.calc_loop_triangles()
    dims = obj.dimensions.copy()
    return {
        "name": obj.name,
        "path": str(out_path),
        "vertices": len(mesh.vertices),
        "triangles": len(mesh.loop_triangles),
        "dimensions_blender_xyz": [round(dims.x, 3), round(dims.y, 3), round(dims.z, 3)],
    }


def add_chiseled_lobe(name: str, loc: tuple[float, float, float], rad: tuple[float, float, float], rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0), seed: int = 1) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0.0, 0.0, 0.0))
    obj = bpy.context.active_object
    obj.name = name
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # Plane-scrape / chisel vertices so lobes have natural flat limestone facets rather than smooth rubber spheres
    dirs = [
        Vector((0.86, -0.42, 0.28)).normalized(),
        Vector((-0.82, -0.48, -0.31)).normalized(),
        Vector((0.25, -0.92, 0.29)).normalized(),
        Vector((-0.32, 0.88, 0.34)).normalized(),
        Vector((0.64, 0.68, -0.35)).normalized(),
        Vector((-0.18, -0.22, 0.96)).normalized(),
    ]
    for v in bm.verts:
        p = v.co.copy()
        for di, d in enumerate(dirs):
            cut = 0.76 + 0.10 * math.sin(seed * 3.7 + di * 2.1)
            proj = p.dot(d)
            if proj > cut:
                p -= d * (proj - cut) * 0.85
        v.co = Vector((p.x * rad[0], p.y * rad[1], p.z * rad[2]))
    bm.to_mesh(obj.data)
    bm.free()
    obj.rotation_euler = Euler([math.radians(a) for a in rot_deg], "XYZ")
    obj.location = Vector(loc)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def build_taihu_scholar_rock() -> dict:
    clear_scene()

    # 1. Sculptural angular S-curved Taihu monolith (瘦、皱、漏、透) with chiseled limestone facets
    positive_parts: list[bpy.types.Object] = [
        # Narrower, asymmetric eroded root column rising from plinth
        add_chiseled_lobe("LowerRoot", (-0.03, 0.01, 0.50), (0.39, 0.29, 0.44), (5, -12, 8), 11),
        # Bold overhanging left crag shoulder
        add_chiseled_lobe("LeftCrag", (-0.21, -0.02, 1.06), (0.46, 0.32, 0.44), (6, -18, 14), 23),
        # Slender counter-arch pillar on right
        add_chiseled_lobe("RightArch", (0.19, 0.02, 0.96), (0.31, 0.26, 0.42), (-4, 15, -10), 37),
        # Sculpted upper waist bridge
        add_chiseled_lobe("UpperBridge", (-0.07, 0.0, 1.48), (0.37, 0.27, 0.37), (4, 12, 6), 53),
        # Tapered craggy Suzhou Taihu summit spire + secondary side crag (嶙峋奇峰, never a bulbous round knob!)
        add_chiseled_lobe("SummitShoulder", (0.08, -0.02, 1.84), (0.32, 0.24, 0.30), (-6, -18, -9), 71),
        add_chiseled_lobe("SummitSpire", (0.02, -0.03, 2.12), (0.19, 0.16, 0.29), (-4, 22, -12), 79),
        add_chiseled_lobe("SideSpur", (-0.28, 0.01, 1.42), (0.24, 0.21, 0.28), (8, -22, 12), 89),
    ]

    bpy.ops.object.select_all(action="DESELECT")
    for p in positive_parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = positive_parts[0]
    bpy.ops.object.join()
    rock = bpy.context.active_object
    rock.name = "TaihuScholarRock"

    rem1 = rock.modifiers.new("FuseVoxel", "REMESH")
    rem1.mode = "VOXEL"
    rem1.voxel_size = 0.028
    bpy.ops.object.modifier_apply(modifier=rem1.name)

    # Carve 2 asymmetric angular limestone caverns + 3 deep oblique erosion furrows (皱/漏, NOT 4 round circles!)
    cutters_spec = [
        # Main asymmetric diagonal lower cavern (瘦漏主洞)
        ((0.06, 0.0, 0.68), (0.17, 0.68, 0.26), (12, 24, 9), 101),
        # Secondary smaller upper-left aperture under the summit overhang
        ((-0.09, 0.0, 1.46), (0.12, 0.68, 0.16), (-10, -22, -8), 103),
        # Deep oblique front-left geological furrow (瘦皱竖壑)
        ((-0.20, -0.30, 1.08), (0.18, 0.22, 0.34), (8, -18, 12), 107),
        # Deep front-right under-crest shadow hollow
        ((0.15, -0.28, 1.70), (0.20, 0.20, 0.22), (-6, 16, -10), 109),
        # Back-side sculptural hollow
        ((-0.05, 0.30, 1.18), (0.22, 0.20, 0.32), (0, 14, 6), 113),
    ]
    cutters: list[bpy.types.Object] = []
    for idx, (loc, rad, rot, sd) in enumerate(cutters_spec):
        cutters.append(add_chiseled_lobe(f"Cutter_{idx}", loc, rad, rot, sd))

    bpy.ops.object.select_all(action="DESELECT")
    for c in cutters:
        c.select_set(True)
    bpy.context.view_layer.objects.active = cutters[0]
    bpy.ops.object.join()
    cutter_union = bpy.context.active_object
    crem = cutter_union.modifiers.new("FuseCutters", "REMESH")
    crem.mode = "VOXEL"
    crem.voxel_size = 0.028
    bpy.ops.object.modifier_apply(modifier=crem.name)

    bpy.ops.object.select_all(action="DESELECT")
    rock.select_set(True)
    bpy.context.view_layer.objects.active = rock
    bool_mod = rock.modifiers.new("TaihuHoles", "BOOLEAN")
    bool_mod.operation = "DIFFERENCE"
    bool_mod.solver = "EXACT"
    bool_mod.object = cutter_union
    bpy.ops.object.modifier_apply(modifier=bool_mod.name)
    bpy.data.objects.remove(cutter_union, do_unlink=True)

    rem2 = rock.modifiers.new("ChiselVoxel", "REMESH")
    rem2.mode = "VOXEL"
    rem2.voxel_size = 0.026
    bpy.ops.object.modifier_apply(modifier=rem2.name)

    # Light 2-pass fillet only, then planar-favoring decimation so crisp chiseled limestone facets emerge!
    sm = rock.modifiers.new("LightFillet", "SMOOTH")
    sm.factor = 0.32
    sm.iterations = 2
    bpy.ops.object.modifier_apply(modifier=sm.name)

    dec = rock.modifiers.new("ChiselDecimate", "DECIMATE")
    dec.ratio = 0.065
    bpy.ops.object.modifier_apply(modifier=dec.name)

    # Build a crisp carved octagonal garden stone plinth (须弥青石底座) and join cleanly
    bm = bmesh.new()
    bm.from_mesh(rock.data)
    bm.verts.ensure_lookup_table()
    min_z = min(v.co.z for v in bm.verts)
    max_z = max(v.co.z for v in bm.verts)
    span_z = max(0.1, max_z - min_z)
    scale_f = 2.16 / span_z
    for v in bm.verts:
        v.co.z = 0.16 + (v.co.z - min_z) * scale_f
        v.co.x *= scale_f
        v.co.y *= scale_f

    # Add stepped carved octagonal stone pedestal (0.0 -> 0.20m)
    plinth_rings = [
        (0.62, 0.44, 0.00),
        (0.60, 0.42, 0.08),
        (0.51, 0.36, 0.12),
        (0.54, 0.38, 0.18),
        (0.44, 0.31, 0.21),
    ]
    sides = 10
    p_rings = []
    for rx, ry, pz in plinth_rings:
        ring = []
        for s in range(sides):
            a = math.tau * s / sides + 0.15
            ring.append(bm.verts.new((math.cos(a) * rx, math.sin(a) * ry, pz)))
        p_rings.append(ring)
    plinth_faces = []
    for ri in range(len(p_rings) - 1):
        r0, r1 = p_rings[ri], p_rings[ri + 1]
        for s in range(sides):
            ns = (s + 1) % sides
            plinth_faces.append(bm.faces.new((r0[s], r0[ns], r1[ns], r1[s])))
    plinth_faces.append(bm.faces.new(p_rings[-1]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    plinth_set = set(plinth_faces)
    # Use crisp flat/bevel shading on steep rock facets and plinth steps so light catches chiseled stone planes!
    for f in bm.faces:
        f.smooth = False if f in plinth_set else False

    color_layer = bm.loops.layers.color.get("Color") or bm.loops.layers.color.new("Color")
    for f in bm.faces:
        fn = f.normal
        is_plinth = f in plinth_set
        for loop in f.loops:
            v = loop.vert
            radial = math.hypot(v.co.x, v.co.y * 1.25)
            cavity_ao = 0.68 + 0.32 * min(1.0, radial / 0.38)
            under_ao = 0.84 + 0.16 * max(0.0, fn.z * 0.5 + 0.5)
            h_lift = 0.90 + 0.14 * min(1.0, v.co.z / 2.32)
            base_g = 0.48 if is_plinth else 0.58
            val = max(0.32, min(0.72, base_g * cavity_ao * under_ao * h_lift))
            # Cool celadon-slate limestone tint in cavities, warm pale stone on upper crests
            r_c = val * (0.94 + 0.08 * min(1.0, v.co.z / 2.2))
            g_c = val * 0.99
            b_c = val * (1.03 - 0.05 * min(1.0, v.co.z / 2.2))
            loop[color_layer] = (r_c, g_c, b_c, 1.0)

    bm.to_mesh(rock.data)
    bm.free()
    rock.data.update()

    # Slight bevel + weighted normals for museum-grade chiseled stone planes (not sharp paper, not melted putty!)
    bev = rock.modifiers.new("StoneBevel", "BEVEL")
    bev.width = 0.012
    bev.segments = 1
    bev.limit_method = "ANGLE"
    bev.angle_limit = math.radians(28.0)
    bpy.ops.object.modifier_apply(modifier=bev.name)

    bm2 = bmesh.new()
    bm2.from_mesh(rock.data)
    for f in bm2.faces:
        f.smooth = True
    bm2.to_mesh(rock.data)
    bm2.free()

    wn = rock.modifiers.new("ChiselWeighted", "WEIGHTED_NORMAL")
    wn.weight = 75
    wn.keep_sharp = False
    bpy.ops.object.modifier_apply(modifier=wn.name)

    mat = bpy.data.materials.new("TaihuStoneMat")
    rock.data.materials.append(mat)

    return export_glb(rock, OUT_DIR / "taihu_scholar_rock.glb")


def build_ink_stone_daybed() -> dict:
    clear_scene()
    bm = bmesh.new()
    color_layer = bm.loops.layers.color.new("Color")
    uv_layer = bm.loops.layers.uv.new("UVMap")

    def add_rounded_slab(
        center: tuple[float, float, float],
        size: tuple[float, float, float],
        bevel_xy: float,
        bevel_z: float,
        col: tuple[float, float, float],
        cavity: float = 0.08,
    ) -> None:
        existing = set(bm.faces)
        ret = bmesh.ops.create_cube(bm, size=1.0)
        verts = ret["verts"]
        for v in verts:
            v.co.x *= size[0]
            v.co.y *= size[1]
            v.co.z *= size[2]
        p_faces = [f for f in bm.faces if f not in existing]
        # Vertical corner rounding first
        v_edges = [e for e in {e for f in p_faces for e in f.edges} if abs(e.verts[0].co.z - e.verts[1].co.z) > size[2] * 0.5]
        bmesh.ops.bevel(bm, geom=v_edges, offset=bevel_xy, offset_type="OFFSET", segments=4, profile=0.52, affect="EDGES")
        p_faces = [f for f in bm.faces if f not in existing]
        # Top & bottom carved stone chamfer
        h_edges = [e for e in {e for f in p_faces for e in f.edges} if abs(e.verts[0].co.z - e.verts[1].co.z) < 0.01]
        bmesh.ops.bevel(bm, geom=h_edges, offset=bevel_z, offset_type="OFFSET", segments=2, profile=0.58, affect="EDGES")
        p_faces = [f for f in bm.faces if f not in existing]
        p_verts = {v for f in p_faces for v in f.verts}
        for v in p_verts:
            v.co += Vector(center)
        bmesh.ops.recalc_face_normals(bm, faces=p_faces)
        for f in p_faces:
            f.smooth = True
            nz = f.normal.z
            shade = 0.88 + 0.18 * (nz * 0.5 + 0.5)
            c = (col[0] * shade, col[1] * shade, col[2] * shade, 1.0)
            for loop in f.loops:
                loop[color_layer] = c
                h_norm = max(0.0, min(1.0, loop.vert.co.z / 0.52))
                cav = cavity + (0.20 if nz < -0.35 else 0.0)
                loop[uv_layer].uv = (h_norm, min(0.85, cav))

    # Song-dynasty carved celadon-limestone garden bench palette (宋式青白石琴榻)
    slab_col = (0.62, 0.63, 0.59)
    waist_col = (0.48, 0.50, 0.48)
    pier_col = (0.54, 0.56, 0.53)
    foot_col = (0.45, 0.48, 0.45)

    # Two carved stepped stone pier legs with open daylight span between them
    for sx in (-0.65, 0.65):
        add_rounded_slab((sx, 0.0, 0.048), (0.40, 0.58, 0.096), 0.045, 0.016, foot_col, cavity=0.26)
        add_rounded_slab((sx, 0.0, 0.210), (0.28, 0.46, 0.235), 0.040, 0.015, pier_col, cavity=0.18)
        add_rounded_slab((sx, 0.0, 0.348), (0.35, 0.53, 0.068), 0.042, 0.014, waist_col, cavity=0.30)

    # Recessed carved stone apron/waist beam under the top slab
    add_rounded_slab((0.0, 0.0, 0.352), (1.52, 0.38, 0.066), 0.040, 0.014, waist_col, cavity=0.34)
    # Thick beveled pale celadon-limestone bench top slab (~0.50m tall)
    add_rounded_slab((0.0, 0.0, 0.438), (1.90, 0.62, 0.128), 0.072, 0.026, slab_col, cavity=0.04)

    mesh = bpy.data.meshes.new("InkStoneDaybed")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("InkStoneDaybed", mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    wn = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.weight = 75
    wn.keep_sharp = False
    bpy.ops.object.modifier_apply(modifier=wn.name)

    mat = bpy.data.materials.new("InkStoneMat")
    mat.use_nodes = True
    obj.data.materials.append(mat)
    return export_glb(obj, OUT_DIR / "ink_stone_daybed.glb")


def build_song_stone_lantern() -> dict:
    clear_scene()
    bm = bmesh.new()
    color_layer = bm.loops.layers.color.new("Color")
    uv_layer = bm.loops.layers.uv.new("UVMap")

    stone_col = (0.25, 0.28, 0.27)
    dark_stone = (0.17, 0.20, 0.20)
    glow_col = (0.98, 0.78, 0.42)

    def add_lathe_hex(profile_rz: list[tuple[float, float]], sides: int, col: tuple[float, float, float], z_rot: float = 0.0, is_glow: bool = False, smooth_rings: bool = False) -> None:
        rings = []
        for r, z in profile_rz:
            ring = []
            for s in range(sides):
                a = z_rot + math.tau * s / sides
                v = bm.verts.new((math.cos(a) * r, math.sin(a) * r, z))
                ring.append(v)
            rings.append(ring)
        new_faces = []
        for ri in range(len(rings) - 1):
            r0, r1 = rings[ri], rings[ri + 1]
            for s in range(sides):
                ns = (s + 1) % sides
                f = bm.faces.new((r0[s], r0[ns], r1[ns], r1[s]))
                new_faces.append(f)
        # Top cap if non-degenerate
        if profile_rz[-1][0] > 0.005:
            new_faces.append(bm.faces.new(rings[-1]))
        bmesh.ops.recalc_face_normals(bm, faces=new_faces)
        for f in new_faces:
            f.smooth = smooth_rings
            nz = f.normal.z
            shade = 1.0 if is_glow else (0.84 + 0.22 * (nz * 0.5 + 0.5))
            c = (col[0] * shade, col[1] * shade, col[2] * shade, 1.0)
            for loop in f.loops:
                loop[color_layer] = c
                h_norm = max(0.0, min(1.0, loop.vert.co.z / 1.08))
                loop[uv_layer].uv = (h_norm, 0.95 if is_glow else 0.05)

    # 1. Carved hexagonal base pad + 4 splayed stone legs
    add_lathe_hex([(0.29, 0.0), (0.27, 0.07), (0.21, 0.11)], 6, dark_stone, math.pi / 6)
    for leg_i in range(4):
        la = math.pi * 0.25 + math.tau * leg_i / 4.0
        lx, ly = math.cos(la) * 0.14, math.sin(la) * 0.14
        existing = set(bm.faces)
        ret = bmesh.ops.create_cube(bm, size=1.0)
        for v in ret["verts"]:
            v.co = Vector((v.co.x * 0.085, v.co.y * 0.085, v.co.z * 0.22))
            t_z = (v.co.z + 0.11) / 0.22
            splay = 1.0 - 0.36 * t_z
            v.co.x = v.co.x + lx * splay
            v.co.y = v.co.y + ly * splay
            v.co.z += 0.19
        l_faces = [f for f in bm.faces if f not in existing]
        bmesh.ops.recalc_face_normals(bm, faces=l_faces)
        for f in l_faces:
            f.smooth = False
            c = (stone_col[0] * 0.90, stone_col[1] * 0.90, stone_col[2] * 0.90, 1.0)
            for loop in f.loops:
                loop[color_layer] = c
                loop[uv_layer].uv = (loop.vert.co.z / 1.08, 0.05)

    # 2. Middle lotus pedestal table (中台莲座)
    add_lathe_hex([(0.13, 0.28), (0.25, 0.34), (0.26, 0.39), (0.20, 0.41)], 6, stone_col, math.pi / 6)

    # 3. Warm glowing hexagonal inner jade/paper lamp core + 6 carved stone corner mullions
    add_lathe_hex([(0.135, 0.41), (0.142, 0.63)], 6, glow_col, math.pi / 6, is_glow=True)
    for m_i in range(6):
        ma = math.pi / 6 + math.tau * m_i / 6.0
        mx, my = math.cos(ma) * 0.156, math.sin(ma) * 0.156
        existing = set(bm.faces)
        ret = bmesh.ops.create_cube(bm, size=1.0)
        rot_z = Matrix.Rotation(ma, 3, "Z")
        for v in ret["verts"]:
            local = rot_z @ Vector((v.co.x * 0.032, v.co.y * 0.036, v.co.z * 0.23))
            v.co = local + Vector((mx, my, 0.52))
        m_faces = [f for f in bm.faces if f not in existing]
        bmesh.ops.recalc_face_normals(bm, faces=m_faces)
        for f in m_faces:
            f.smooth = False
            for loop in f.loops:
                loop[color_layer] = (dark_stone[0], dark_stone[1], dark_stone[2], 1.0)
                loop[uv_layer].uv = (loop.vert.co.z / 1.08, 0.05)

    # 4. Sweeping curved hexagonal Song pagoda umbrella roof (伞盖飞檐) + lotus bud finial (宝珠)
    add_lathe_hex(
        [
            (0.21, 0.62),
            (0.36, 0.65),
            (0.375, 0.685),
            (0.27, 0.74),
            (0.16, 0.82),
            (0.08, 0.88),
        ],
        6,
        stone_col,
        math.pi / 6,
        smooth_rings=False,
    )
    add_lathe_hex(
        [
            (0.085, 0.88),
            (0.065, 0.91),
            (0.082, 0.96),
            (0.052, 1.02),
            (0.008, 1.07),
        ],
        10,
        stone_col,
        smooth_rings=True,
    )

    mesh = bpy.data.meshes.new("SongStoneLantern")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("SongStoneLantern", mesh)
    bpy.context.collection.objects.link(obj)
    mat = bpy.data.materials.new("SongLanternMat")
    mat.use_nodes = True
    obj.data.materials.append(mat)
    return export_glb(obj, OUT_DIR / "song_stone_lantern.glb")


def render_contact_sheet() -> str:
    clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 560
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "VERTEX"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_shadows = True

    placements = [
        (OUT_DIR / "taihu_scholar_rock.glb", (-2.1, 0.0, 0.0)),
        (OUT_DIR / "ink_stone_daybed.glb", (0.2, 0.0, 0.0)),
        (OUT_DIR / "song_stone_lantern.glb", (2.1, 0.0, 0.0)),
    ]
    for glb_path, loc in placements:
        bpy.ops.import_scene.gltf(filepath=str(glb_path))
        for obj in bpy.context.selected_objects:
            if obj.parent is None:
                obj.location += Vector(loc)

    bpy.ops.mesh.primitive_plane_add(size=14.0, location=(0.0, 0.0, -0.005))
    ground = bpy.context.active_object
    bm = bmesh.new()
    bm.from_mesh(ground.data)
    cl = bm.loops.layers.color.new("Color")
    for f in bm.faces:
        for lp in f.loops:
            lp[cl] = (0.34, 0.42, 0.30, 1.0)
    bm.to_mesh(ground.data)
    bm.free()

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 36.0
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = Vector((0.0, -6.6, 2.55))
    direction = Vector((0.0, 0.0, 1.05)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam

    light_data = bpy.data.lights.new("Sun", type="SUN")
    light = bpy.data.objects.new("Sun", light_data)
    bpy.context.collection.objects.link(light)
    light.rotation_euler = Euler((math.radians(48), 0.0, math.radians(36)), "XYZ")

    out_png = PREVIEW_DIR / "props_preview.png"
    scene.render.filepath = str(out_png)
    bpy.ops.render.render(write_still=True)
    return str(out_png)


def main() -> None:
    report = [
        build_taihu_scholar_rock(),
        build_ink_stone_daybed(),
        build_song_stone_lantern(),
    ]
    preview_png = render_contact_sheet()
    report_path = PREVIEW_DIR / "journey_props_report.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps({"props": report, "preview": preview_png}, indent=2, ensure_ascii=False))
    print("JOURNEY PROPS BUILT:", json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
