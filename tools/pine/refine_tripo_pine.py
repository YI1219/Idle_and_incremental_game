"""Quick cleanup of the raw Tripo pine: orient/scale, merge, decimate, normals, palette vertex colors + vertex AO.

Run: blender -b --python tools/pine/refine_tripo_pine.py -- [target_tris]
In : art/source/pine/2026-10-02/tripo/pine_raw_v01.glb   (+ art/work/pine/refviews_b/pine_blockout.blend for orientation check)
Out: art/work/pine/pine_refined_v01.{glb,blend}, art/work/pine/refine_report.json
Style: shared palette (bark grey-brown, canopy teal-green 3-step by height inside each pad), AO in vertex color,
no textures. Ideas reused from tools/cottage/refine_tripo.py (import, bmesh cleanup, weighted normals, report).
"""
import bpy, bmesh, json, hashlib, math, sys, random
from pathlib import Path
from mathutils import Vector, Matrix, Color
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

R = Path(__file__).resolve().parents[2]
SRC = R / 'art/source/pine/2026-10-02/tripo/pine_raw_v01.glb'
REF = R / 'art/work/pine/refviews_b/pine_blockout.blend'
OUT = R / 'art/work/pine'
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
TARGET_TRIS = int(argv[0]) if argv else 1200
HEIGHT_M = 3.0

def srgb(h):
    h = h.lstrip('#'); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return Vector([(x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c])

PAL = {  # shared palette candidates (sRGB hex) - keep in sync with a future palette.png
    'bark_dark': '#4f4640', 'bark': '#6e6258', 'bark_light': '#8a7d70',
    'leaf_dark': '#3e5f57', 'leaf': '#5d8273', 'leaf_light': '#8fb09c',
}
P = {k: srgb(v) for k, v in PAL.items()}

# ---------- reference blockout points (orientation check only) ----------
bpy.ops.wm.open_mainfile(filepath=str(REF))
ref_pts = []
for o in bpy.data.objects:
    if o.type == 'MESH':
        ref_pts += [o.matrix_world @ v.co for v in o.data.vertices]
random.seed(1); ref_pts = random.sample(ref_pts, min(4000, len(ref_pts)))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SRC))
o = next(x for x in bpy.context.scene.objects if x.type == 'MESH')
o.name = 'PineTripo'
bpy.context.view_layer.objects.active = o; o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
raw_faces = len(o.data.polygons)
# ---------- materials (created before bmesh so material_index survives): flat palette colour x vertex colour (no textures) ----------
o.data.materials.clear()
for name in ('PinePalette',):  # ONE material: colour lives in COLOR_0 (one draw call; Godot enables albedo-from-vertex-colour)
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    b.inputs['Roughness'].default_value = 1.0
    vc = nt.nodes.new('ShaderNodeVertexColor'); vc.layer_name = 'Col'
    nt.links.new(vc.outputs['Color'], b.inputs['Base Color'])
    o.data.materials.append(m)
for a in list(o.data.color_attributes): o.data.color_attributes.remove(a)

bm = bmesh.new(); bm.from_mesh(o.data)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-4)
# scale to target height, origin = trunk base centre
zs = [v.co.z for v in bm.verts]; zmin, zmax = min(zs), max(zs)
s = HEIGHT_M / (zmax - zmin)
low = [v.co for v in bm.verts if v.co.z < zmin + 0.03 * (zmax - zmin)]
cx = sum(c.x for c in low) / len(low); cy = sum(c.y for c in low) / len(low)
for v in bm.verts:
    v.co = Vector(((v.co.x - cx) * s, (v.co.y - cy) * s, (v.co.z - zmin) * s))

# orientation: try 4 yaw rotations, compare with blockout (scaled to same height) by mean NN distance
rz = [p.z for p in ref_pts]; rs = HEIGHT_M / (max(rz) - min(rz))
kd = KDTree(len(ref_pts))
for i, p in enumerate(ref_pts): kd.insert(Vector((p.x * rs, p.y * rs, (p.z - min(rz)) * rs)), i)
kd.balance()
sample = random.sample(list(bm.verts), min(800, len(bm.verts)))
scores = {}
for deg in (0, 90, 180, 270):
    M = Matrix.Rotation(math.radians(deg), 3, 'Z')
    scores[deg] = sum(kd.find(M @ v.co)[2] for v in sample) / len(sample)
best = min(scores, key=scores.get)
bmesh.ops.rotate(bm, verts=list(bm.verts), cent=Vector(), matrix=Matrix.Rotation(math.radians(best), 3, 'Z'))
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.to_mesh(o.data); bm.free()

# ---------- decimate to target ----------
if raw_faces > TARGET_TRIS:
    m = o.modifiers.new('Decimate', 'DECIMATE'); m.ratio = TARGET_TRIS / raw_faces; m.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=m.name)
bm = bmesh.new(); bm.from_mesh(o.data)
bmesh.ops.triangulate(bm, faces=list(bm.faces))
bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
bm.normal_update()

# ---------- classify canopy vs bark (generic tree heuristic: thick blobs above the clear trunk) ----------
bvh = BVHTree.FromBMesh(bm)
def thickness(f):
    c = f.calc_center_median(); n = f.normal
    hit = bvh.ray_cast(c - n * 1e-3, -n, 3.0)
    return (hit[3] if hit[0] is not None else 3.0)
is_leaf = {}
for f in bm.faces:
    c = f.calc_center_median()
    is_leaf[f.index] = c.z > 0.36 * HEIGHT_M and thickness(f) > 0.20
# smooth labels over neighbours (majority of 1-ring) twice
for _ in range(2):
    new = {}
    for f in bm.faces:
        nb = [g for e in f.edges for g in e.link_faces if g is not f]
        votes = sum(is_leaf[g.index] for g in nb) + is_leaf[f.index]
        new[f.index] = votes * 2 > len(nb) + 1
    is_leaf = new
# island vote: Tripo returned pads as separate islands, so a per-island majority removes stray patches
seen = set(); islands = 0
for f0 in bm.faces:
    if f0.index in seen: continue
    stack = [f0]; seen.add(f0.index); isl = []
    while stack:
        f = stack.pop(); isl.append(f)
        for e in f.edges:
            for g in e.link_faces:
                if g.index not in seen: seen.add(g.index); stack.append(g)
    islands += 1
    frac = sum(is_leaf[f.index] for f in isl) / len(isl)
    if frac >= 0.6 or frac <= 0.4:
        for f in isl: is_leaf[f.index] = frac >= 0.6
for f in bm.faces:
    f.material_index = 1 if is_leaf[f.index] else 0

# ---------- per-vertex AO (hemisphere rays) + palette colour ----------
dirs = []
for i in range(32):  # fibonacci hemisphere
    z = (i + 0.5) / 32; r = math.sqrt(1 - z * z); a = i * 2.39996
    dirs.append(Vector((r * math.cos(a), r * math.sin(a), z)))
def ao(v):
    n = v.normal
    if n.length < 1e-6: return 1.0
    T = n.to_track_quat('Z', 'Y').to_matrix()
    occ = 0
    for d in dirs:
        hit = bvh.ray_cast(v.co + n * 2e-3, T @ d, 0.9)
        if hit[0] is not None: occ += 1 - hit[3] / 0.9
    return 1 - occ / len(dirs)
ao_v = {v.index: ao(v) for v in bm.verts}
# leaf: light by local height inside its pad region (approx: by normal z + world height), bark: darker at base
col = bm.loops.layers.color.new('Col')
for f in bm.faces:
    for l in f.loops:
        v = l.vert; a = 0.55 + 0.45 * ao_v[v.index]
        if f.material_index == 1:
            t = max(0.0, min(1.0, 0.5 + 0.5 * v.normal.z))
            c = P['leaf_dark'].lerp(P['leaf'], min(1, t * 1.6)) if t < 0.62 else P['leaf'].lerp(P['leaf_light'], (t - 0.62) / 0.38)
        else:
            h = max(0.0, min(1.0, v.co.z / (0.5 * HEIGHT_M)))
            c = P['bark_dark'].lerp(P['bark'], h)
        c = c * a
        # bmesh byte-colour layers take display (sRGB) values; encode the linear result
        enc = [(12.92 * x) if x <= 0.0031308 else (1.055 * x ** (1 / 2.4) - 0.055) for x in c]
        l[col] = (enc[0], enc[1], enc[2], 1.0)
leaf_count = sum(1 for f in bm.faces if f.material_index == 1)
for f in bm.faces: f.material_index = 0
stats = {
    'islands': islands,
    'triangles': len(bm.faces), 'vertices': len(bm.verts),
    'leaf_faces': leaf_count,
    'boundary_edges': sum(e.is_boundary for e in bm.edges), 'nonmanifold_edges': sum(not e.is_manifold for e in bm.edges),
    'ao_mean': round(sum(ao_v.values()) / len(ao_v), 3),
}
bm.to_mesh(o.data); bm.free()
o.data.color_attributes.active_color = o.data.color_attributes['Col']

for p in o.data.polygons: p.use_smooth = True
o.data.set_sharp_from_angle(angle=math.radians(60))
wn = o.modifiers.new('WN', 'WEIGHTED_NORMAL'); wn.keep_sharp = True; wn.weight = 50
bpy.ops.object.modifier_apply(modifier=wn.name)

OUT.mkdir(parents=True, exist_ok=True)
glb = OUT / 'pine_refined_v01.glb'
bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True, export_vertex_color='NAME', export_vertex_color_name='Col', export_all_vertex_colors=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'pine_refined_v01.blend'))
report = {
    'source': str(SRC.relative_to(R)), 'source_sha256': hashlib.sha256(SRC.read_bytes()).hexdigest(),
    'raw_faces': raw_faces, 'target_tris': TARGET_TRIS, 'height_m': HEIGHT_M, 'scale_applied': round(s, 4),
    'yaw_fix_deg': best, 'yaw_scores_mean_nn_m': {k: round(v, 4) for k, v in scores.items()},
    'dimensions_m': [round(x, 3) for x in o.dimensions], 'palette': PAL, **stats,
    'output_glb': str(glb.relative_to(R)), 'output_glb_bytes': glb.stat().st_size,
    'notes': ['canopy/bark split = height>36% and ray thickness>0.20 m, 1-ring majority smoothed, then per connected island majority (>=60% -> all leaf, <=40% -> all bark)',
              'colour = palette ramp x hemisphere vertex AO (32 rays, 0.9 m), stored in COLOR_0; materials have no textures',
              'front faces -Y in Blender (= +Z in glTF/Godot)'],
}
(OUT / 'refine_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
print('REPORT', json.dumps(report, ensure_ascii=False))
