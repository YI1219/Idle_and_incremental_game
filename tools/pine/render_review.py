"""Review renders at the game camera (pitch 50 deg, yaw 45 deg, FOV 42) with soft warm sun + cool sky.
Run: blender -b --python tools/pine/render_review.py
Out: art/review/pine/2026-10-02/{review.png, compare.png}
"""
import bpy, json, math
from pathlib import Path
from mathutils import Vector, Matrix
R = Path(__file__).resolve().parents[2]
REV = R / 'art/review/pine/2026-10-02'; REV.mkdir(parents=True, exist_ok=True)
rep = json.loads((R / 'art/work/pine/refine_report.json').read_text())

def srgb(h):
    h = h.lstrip('#'); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (1.0,)

def imp(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    return [o for o in new if o.type == 'MESH'], new

def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = 'CYCLES'; s.cycles.device = 'CPU'; s.cycles.samples = 64; s.cycles.use_denoising = True
    s.render.resolution_x, s.render.resolution_y = 1600, 1000
    s.view_settings.view_transform = 'AgX'; s.view_settings.look = 'AgX - Base Contrast' if False else 'None'
    w = bpy.data.worlds.new('Sky'); s.world = w; w.use_nodes = True
    bg = w.node_tree.nodes['Background']; bg.inputs[0].default_value = srgb('#c9d6dc'); bg.inputs[1].default_value = 1.1
    sd = bpy.data.lights.new('Sun', 'SUN'); sd.energy = 3.2; sd.angle = math.radians(12); sd.color = (1.0, 0.94, 0.84)
    sun = bpy.data.objects.new('Sun', sd); s.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(42), 0, math.radians(-35))
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=14, fill_type='NGON')
    g = bpy.context.object; gm = bpy.data.materials.new('Ground'); gm.use_nodes = True
    gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = srgb('#9aa98a')
    gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 1
    g.data.materials.append(gm)
    cd = bpy.data.cameras.new('Cam'); cd.lens_unit = 'FOV'; cd.angle = math.radians(42)
    cam = bpy.data.objects.new('Cam', cd); s.collection.objects.link(cam); s.camera = cam
    return s, cam

def aim(cam, target, dist, pitch=50, yaw=45):
    p, y = math.radians(pitch), math.radians(yaw)
    d = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p)))
    cam.location = target + d * dist
    cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()

def wire_vertex_color(objs):
    # Blender's glTF importer does not wire COLOR_0 into the material; Godot does (albedo from vertex colour)
    for o in objs:
        for m in o.data.materials:
            nt = m.node_tree; b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
            vc = nt.nodes.new('ShaderNodeVertexColor'); vc.layer_name = o.data.color_attributes[0].name
            nt.links.new(vc.outputs['Color'], b.inputs['Base Color']); b.inputs['Roughness'].default_value = 1

def flat_mat(name, hexc):
    m = bpy.data.materials.new(name); m.use_nodes = True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = srgb(hexc)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 1
    return m

def raw_pine(offset):
    ms, _ = imp(R / rep['source'])
    o = ms[0]
    bpy.context.view_layer.objects.active = o
    vs = [v.co for v in o.data.vertices]; zmin = min(v.z for v in vs); zmax = max(v.z for v in vs)
    low = [v for v in vs if v.z < zmin + 0.03 * (zmax - zmin)]
    cx = sum(v.x for v in low) / len(low); cy = sum(v.y for v in low) / len(low)
    s = rep['height_m'] / (zmax - zmin)
    M = Matrix.Translation(offset) @ Matrix.Rotation(math.radians(rep['yaw_fix_deg']), 4, 'Z') @ Matrix.Scale(s, 4) @ Matrix.Translation((-cx, -cy, -zmin))
    o.data.transform(M); o.matrix_world = Matrix()
    o.data.materials.clear(); o.data.materials.append(flat_mat('RawGrey', '#b8b8b4'))
    return o

def blockout(offset):
    with bpy.data.libraries.load(str(R / 'art/work/pine/refviews_b/pine_blockout.blend')) as (src, dst):
        dst.objects = [n for n in src.objects if n in ('Trunk', 'Canopy')]
    zs = []
    for o in dst.objects:
        bpy.context.scene.collection.objects.link(o)
    allz = [(o.matrix_world @ v.co).z for o in dst.objects for v in o.data.vertices]
    s = rep['height_m'] / (max(allz) - min(allz))
    for o in dst.objects:
        o.data = o.data.copy(); o.data.transform(Matrix.Translation(offset) @ Matrix.Scale(s, 4) @ Matrix.Translation((0, 0, -min(allz))))
    return dst.objects

# ---------- review: refined pine in context (cottage + 1.7 m figure) ----------
s, cam = setup()
pine, _ = imp(R / rep['output_glb']); wire_vertex_color(pine)
cot, cot_all = imp(R / 'assets/buildings/cottage/cottage_tripo.glb')
for o in cot_all:
    if o.parent is None: o.location = Vector((-5.2, 3.2, 0)); o.rotation_euler = (0, 0, math.radians(-90))
bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.22, depth=1.7, location=(1.6, -1.4, 0.85))
fig = bpy.context.object; fig.data.materials.append(flat_mat('Figure', '#e8e4da'))
aim(cam, Vector((-1.6, 1.2, 1.6)), 14.0)
s.render.filepath = str(REV / 'review.png'); bpy.ops.render.render(write_still=True)
aim(cam, Vector((0, 0, 1.5)), 8.5)
s.render.filepath = str(REV / 'review_close.png'); bpy.ops.render.render(write_still=True)

# ---------- compare: blockout | raw Tripo | refined ----------
s, cam = setup()
blockout(Vector((-3.0, -3.0, 0)))
raw_pine(Vector((0, 0, 0)))
ms, _ = imp(R / rep['output_glb'])
wire_vertex_color(ms)
for o in ms: o.location = Vector((3.0, 3.0, 0))
aim(cam, Vector((0, 0, 1.3)), 18.0)
s.render.filepath = str(REV / 'compare.png'); bpy.ops.render.render(write_still=True)
print('DONE')
