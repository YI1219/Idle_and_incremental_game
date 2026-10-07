"""Procedural stylized xianxia pine blockout -> four orthographic reference views for Tripo multiview.

Run:  blender -b --python tools/pine/render_pine_refviews.py -- OUT_DIR
Outputs OUT_DIR/{front,left,right,back}_rgba.png (transparent), concept_34.png, pine_blockout.blend
View convention follows art/source/cottage: tree front faces -Y; 'left' camera sits on +X
(the tree's own left), so in the left view the front is at image-left.
"""
import bpy, bmesh, math, sys
from mathutils import Vector, Matrix
from pathlib import Path

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = Path(argv[0] if argv else '/tmp/pine_refviews').expanduser()
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene

def srgb(h):
    h = h.lstrip('#'); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c) + (1.0,)

# ---------------- trunk + branches as tubes ----------------
def tube(bm, pts, radii, sides=10, ridges=0, twist=0.0, ridge_amp=0.0, cap_bottom=True):
    rings = []
    ref = Vector((0, 0, 1))
    acc = 0.0
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = ref.cross(t)
        if a.length < 1e-4: a = Vector((1, 0, 0)).cross(t)
        a.normalize(); b = t.cross(a).normalized()
        if i: acc += (pts[i] - pts[i - 1]).length
        ring = []
        for k in range(sides):
            ang = 2 * math.pi * k / sides
            r = radii[i] * (1 + ridge_amp * math.cos(ridges * ang + twist * acc)) if ridges else radii[i]
            ring.append(bm.verts.new(p + (a * math.cos(ang) + b * math.sin(ang)) * r))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
    tip = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1] * 0.6)
    for k in range(sides):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], tip))
    if cap_bottom:
        bm.faces.new(list(reversed(rings[0])))

def spine(f, n, t0=0.0, t1=1.0):
    return [f(t0 + (t1 - t0) * i / (n - 1)) for i in range(n)]

def trunk_f(t):
    z = 2.55 * t
    x = 0.32 * math.sin(t * 3.4 + 0.3) - 0.10 - 0.18 * t
    y = 0.16 * math.sin(t * 4.6 + 1.2) * (0.4 + t)
    return Vector((x, y, z))

bm = bmesh.new()
tp = spine(trunk_f, 34)
tr = []
for i in range(34):
    t = i / 33
    r = 0.075 + 0.13 * (1 - t) ** 1.3
    if t < 0.12: r *= 1 + 0.9 * ((0.12 - t) / 0.12) ** 2  # root flare
    tr.append(r)
tube(bm, tp, tr, sides=12, ridges=4, twist=2.2, ridge_amp=0.16)

# branches: (start t on trunk, list of offsets) -> end positions near pads
branches = [
    (0.50, Vector((-1.10, 0.15, 1.58)), 0.080),   # long low branch to the left (signature pine reach)
    (0.66, Vector((0.95, -0.20, 1.98)), 0.068),   # right
    (0.74, Vector((0.12, 0.78, 2.12)), 0.058),    # back
    (0.42, Vector((0.50, -0.62, 1.28)), 0.052),   # front-right low
]
for t0, end, r0 in branches:
    s = trunk_f(t0)
    mid = s.lerp(end, 0.55) + Vector((0, 0, 0.18))
    pts = []
    for i in range(9):
        u = i / 8
        p = (1 - u) ** 2 * s + 2 * (1 - u) * u * mid + u * u * end
        pts.append(p)
    tube(bm, pts, [r0 * (1 - 0.55 * i / 8) for i in range(9)], sides=8, cap_bottom=False)

me = bpy.data.meshes.new('Trunk'); bm.to_mesh(me); bm.free()
trunk = bpy.data.objects.new('Trunk', me); scn.collection.objects.link(trunk)
for p in me.polygons: p.use_smooth = True

# ---------------- canopy pads (metaballs -> soft cloud clumps) ----------------
mb = bpy.data.metaballs.new('Canopy'); mb.resolution = 0.045; mb.threshold = 0.6
canopy_mb = bpy.data.objects.new('CanopyMB', mb); scn.collection.objects.link(canopy_mb)
top = trunk_f(1.0)
pads = [  # center, radius (xy), flatness, n sub-blobs
    (top + Vector((0.05, 0.0, 0.22)), 0.78, 0.46, 5),
    (Vector((-1.20, 0.15, 1.68)), 0.86, 0.40, 6),
    (Vector((1.05, -0.20, 2.08)), 0.76, 0.42, 5),
    (Vector((0.15, 0.85, 2.24)), 0.64, 0.44, 4),
    (Vector((0.55, -0.70, 1.38)), 0.56, 0.46, 4),
]
import random
random.seed(7)
for c, r, flat, n in pads:
    # domed pad: one wide flat base blob + smaller lumps on top
    e = mb.elements.new(); e.type = 'ELLIPSOID'; e.co = c; e.radius = r
    e.size_x, e.size_y, e.size_z = 1.0, 0.85, flat
    for k in range(n):
        ang = 2 * math.pi * k / n + random.uniform(-0.4, 0.4)
        d = r * random.uniform(0.35, 0.55)
        e = mb.elements.new(); e.type = 'BALL'
        e.co = c + Vector((math.cos(ang) * d, math.sin(ang) * d * 0.85, r * flat * random.uniform(0.25, 0.5)))
        e.radius = r * random.uniform(0.42, 0.55)
bpy.context.view_layer.objects.active = canopy_mb; canopy_mb.select_set(True)
bpy.ops.object.convert(target='MESH')
canopy = bpy.context.object; canopy.name = 'Canopy'
# soften/flatten the underside of each pad (layered cloud shelves), continuous so no vertical walls
for v in canopy.data.vertices:
    c, r, flat, n = min(pads, key=lambda q: ((v.co.x - q[0].x) ** 2 + (v.co.y - q[0].y) ** 2) / q[1] ** 2 + ((v.co.z - q[0].z) / q[1]) ** 2)
    if v.co.z < c.z:
        v.co.z = c.z - (c.z - v.co.z) * 0.55
for p in canopy.data.polygons: p.use_smooth = True

# ---------------- materials ----------------
def mat(name, base):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value = base; b.inputs['Roughness'].default_value = 0.9
    return m, b
mt, _ = mat('Bark', srgb('#6e6258'))
mc, bc = mat('Pine', srgb('#4d7466'))
nt = mc.node_tree
geo = nt.nodes.new('ShaderNodeNewGeometry'); sep = nt.nodes.new('ShaderNodeSeparateXYZ')
ramp = nt.nodes.new('ShaderNodeValToRGB')
ramp.color_ramp.elements[0].position = 0.25; ramp.color_ramp.elements[0].color = srgb('#3e5f57')
ramp.color_ramp.elements[1].position = 0.95; ramp.color_ramp.elements[1].color = srgb('#86a896')
mr = nt.nodes.new('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = -1; mr.inputs['From Max'].default_value = 1
nt.links.new(geo.outputs['Normal'], sep.inputs[0]); nt.links.new(sep.outputs['Z'], mr.inputs['Value'])
nt.links.new(mr.outputs['Result'], ramp.inputs['Fac']); nt.links.new(ramp.outputs['Color'], bc.inputs['Base Color'])
trunk.data.materials.append(mt); canopy.data.materials.append(mc)

# ---------------- render setup ----------------
scn.render.engine = 'CYCLES'; scn.cycles.device = 'CPU'; scn.cycles.samples = 48; scn.cycles.use_denoising = True
scn.render.resolution_x = scn.render.resolution_y = 1024; scn.render.film_transparent = True
scn.view_settings.view_transform = 'Standard'
w = bpy.data.worlds.new('W'); scn.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs[0].default_value = (0.82, 0.85, 0.88, 1); w.node_tree.nodes['Background'].inputs[1].default_value = 0.9
sun_d = bpy.data.lights.new('Sun', 'SUN'); sun_d.energy = 2.6; sun_d.angle = math.radians(25); sun_d.color = (1.0, 0.96, 0.9)
sun = bpy.data.objects.new('Sun', sun_d); scn.collection.objects.link(sun)
cam_d = bpy.data.cameras.new('Cam'); cam_d.type = 'ORTHO'; cam_d.ortho_scale = 4.8
cam = bpy.data.objects.new('Cam', cam_d); scn.collection.objects.link(cam); scn.camera = cam
CENTER = Vector((0, 0, 1.6))

def aim(obj, pos, target):
    obj.location = pos
    obj.rotation_euler = (target - pos).to_track_quat('-Z', 'Y').to_euler()

views = {  # camera direction from the tree
    'front': Vector((0, -1, 0)),
    'left': Vector((1, 0, 0)),
    'right': Vector((-1, 0, 0)),
    'back': Vector((0, 1, 0)),
}
for name, d in views.items():
    aim(cam, CENTER + d * 12, CENTER)
    side = d.cross(Vector((0, 0, 1)))  # light from upper-left of the camera, same relative lighting per view
    aim(sun, CENTER + d * 6 - side * 4 + Vector((0, 0, 8)), CENTER)
    scn.render.filepath = str(OUT / f'{name}_rgba.png'); bpy.ops.render.render(write_still=True)

# 3/4 concept view at the game camera (~45deg yaw, 50deg pitch), perspective-free
d = Vector((0.7071, -0.7071, 0)) * math.cos(math.radians(50)) + Vector((0, 0, math.sin(math.radians(50))))
cam_d.ortho_scale = 5.6
aim(cam, CENTER + d * 14, CENTER); aim(sun, CENTER + Vector((-3, -6, 9)), CENTER)
scn.render.filepath = str(OUT / 'concept_34_rgba.png'); bpy.ops.render.render(write_still=True)

dims = {o.name: list(o.dimensions) for o in (trunk, canopy)}
print('TRIS', sum(len(p.vertices) - 2 for o in (trunk, canopy) for p in o.data.polygons), dims)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'pine_blockout.blend'))
