"""
云露村 floating-island underside prototype: procedural top + rule-based assembly of CC0 rock kit.
Run:  blender -b -P rockkit_island.py -- --seed 7 --tag seed7 --views side,overview [--contact] [--cone] [--glb]
"""
import bpy, bmesh, math, random, sys, os, json, argparse
from mathutils import Vector, Matrix, Color

ROOT = '/workspace/notes/rockkit-test'
KAY = ROOT + '/assets/kaykit_forest/KayKit_Forest_Nature_Pack_1.0_FREE/Assets/gltf/'
QUA = ROOT + '/assets/quaternius_stylized_nature_megakit/glTF/'
RENDERS = ROOT + '/renders/'
EXPORT = ROOT + '/export/'

# ---------------------------------------------------------------- parameters
P = dict(
    R0=6.0,                         # mean coastline radius (island ~12 m wide)
    harmonics=[(2, 0.10), (3, 0.08), (5, 0.035), (7, 0.015)],   # (k, amplitude) of polar sine terms
    coast_samples=256,
    slab_bottom=-0.55,               # top slab thickness under rim
    # ring table: s = radial scale of coastline about centroid, top = z of piece top,
    # width = target piece footprint (m), spacing = centre distance as fraction of width (<1 => overlap)
    rings=[
        dict(s=0.985, top=-0.15, width=2.6, scale=(0.8, 1.3), zs=(0.9, 1.15), tilt=10, spacing=0.62, pool='rim', protrude=0.05),
        dict(s=0.80,  top=-1.25, width=2.3, scale=(0.8, 1.2), zs=(1.0, 1.25), tilt=16, spacing=0.66, pool='rim+mid', protrude=0.0),
        dict(s=0.58,  top=-2.35, width=2.0, scale=(0.8, 1.15), zs=(1.0, 1.3), tilt=20, spacing=0.70, pool='mid+rim', protrude=0.0),
        dict(s=0.35,  top=-3.40, width=1.7, scale=(0.8, 1.1), zs=(1.05, 1.35), tilt=24, spacing=0.75, pool='mid', protrude=0.0),
    ],
    tips=dict(count=(1, 3), top=-3.7, width=(2.3, 2.9), zs=(0.65, 0.85), spread=0.9, tilt=8),
    jitter=dict(arc=0.25, radial=0.18, z=0.15),
    core=dict(s=0.9, top=-0.7, bottom=-4.6, segments=28),     # hidden occluder cone so ring gaps show rock, not sky
    roots=dict(count=10, length=(1.0, 2.6)),
)

# shared palette (sRGB hex)
PAL = dict(
    grass='#9cbf7a', grass_dark='#7fa565', earth='#9a7656',
    rock_warm='#9b7d64', rock_mid='#86796f', rock_cool='#6f7279',
    root='#6b5140', cloud='#ffffff', sky='#dde8ee',
)

KIT = [  # name, file, role   (all pieces are flipped upside-down on load)
    ('K_Rock_2_H', KAY + 'Rock_2_H_Color1.gltf', 'rim'),      # flat-topped trapezoid cliff block
    ('K_Rock_2_E', KAY + 'Rock_2_E_Color1.gltf', 'rim'),      # tall trapezoid cliff block
    ('K_Rock_3_Q', KAY + 'Rock_3_Q_Color1.gltf', 'rim'),      # wide faceted boulder
    ('Q_Rock_Medium_1', QUA + 'Rock_Medium_1.gltf', 'rim'),   # Quaternius lumpy slab
    ('Q_Rock_Medium_3', QUA + 'Rock_Medium_3.gltf', 'rim'),
    ('K_Rock_3_O', KAY + 'Rock_3_O_Color1.gltf', 'mid'),      # faceted boulder, tapers down when flipped
    ('K_Rock_3_K', KAY + 'Rock_3_K_Color1.gltf', 'mid'),
    ('K_Rock_3_G', KAY + 'Rock_3_G_Color1.gltf', 'mid'),
    ('K_Rock_1_O', KAY + 'Rock_1_O_Color1.gltf', 'tip'),      # stepped column -> stalactite
    ('K_Rock_1_K', KAY + 'Rock_1_K_Color1.gltf', 'tip'),      # stepped taper -> stalactite
]

LIGHT_SCALE = 0.6   # Blender sun W/m2 -> diffuse radiance is E/pi; scale lit faces (~1.5) into 0..1 before the toon ramp

if os.environ.get('KIT_CANDIDATES'):   # dev helper: preview alternative pieces on the contact sheet
    KIT = [(n, KAY + n[2:] + '_Color1.gltf', 'cand') for n in os.environ['KIT_CANDIDATES'].split(',')]

def srgb(h):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return (*lin, 1.0)

# ---------------------------------------------------------------- materials
def toon_material(name, color_src, ramp=((0.15, 0.45), (0.45, 0.74), (0.85, 1.0)), ambient='#c9d6e3', amb=0.12):
    """Diffuse -> ShaderToRGB -> soft 3-stop light ramp, multiplied by base colour; emission out.
    color_src: hex string or ('zgrad', [(z, hex),...]) for world-Z gradient (shared rock palette)."""
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; N = nt.nodes; L = nt.links; N.clear()
    out = N.new('ShaderNodeOutputMaterial')
    if isinstance(color_src, str):
        base = N.new('ShaderNodeRGB'); base.outputs[0].default_value = srgb(color_src); base_out = base.outputs[0]
    else:
        geo = N.new('ShaderNodeNewGeometry'); sep = N.new('ShaderNodeSeparateXYZ'); L.new(geo.outputs['Position'], sep.inputs[0])
        stops = color_src[1]; z0, z1 = stops[0][0], stops[-1][0]
        mr = N.new('ShaderNodeMapRange'); mr.inputs['From Min'].default_value = z0; mr.inputs['From Max'].default_value = z1
        L.new(sep.outputs['Z'], mr.inputs['Value'])
        # small per-object value jitter so instances don't read as copies
        oi = N.new('ShaderNodeObjectInfo'); jit = N.new('ShaderNodeMath'); jit.operation = 'MULTIPLY_ADD'
        L.new(oi.outputs['Random'], jit.inputs[0]); jit.inputs[1].default_value = 0.12; jit.inputs[2].default_value = -0.06
        add = N.new('ShaderNodeMath'); add.operation = 'ADD'; add.use_clamp = True
        L.new(mr.outputs[0], add.inputs[0]); L.new(jit.outputs[0], add.inputs[1])
        cr = N.new('ShaderNodeValToRGB'); cr.color_ramp.interpolation = 'EASE'
        els = cr.color_ramp.elements
        while len(els) < len(stops): els.new(0.5)
        for e, (z, hx) in zip(els, stops):
            e.position = (z - z0) / (z1 - z0); e.color = srgb(hx)
        L.new(add.outputs[0], cr.inputs[0]); base_out = cr.outputs[0]
    dif = N.new('ShaderNodeBsdfDiffuse'); dif.inputs['Color'].default_value = (1, 1, 1, 1)
    s2r = N.new('ShaderNodeShaderToRGB'); L.new(dif.outputs[0], s2r.inputs[0])
    bw = N.new('ShaderNodeRGBToBW'); L.new(s2r.outputs[0], bw.inputs[0])
    sc = N.new('ShaderNodeMath'); sc.operation = 'MULTIPLY'; sc.use_clamp = True; sc.inputs[1].default_value = LIGHT_SCALE
    L.new(bw.outputs[0], sc.inputs[0]); bw = sc
    lr = N.new('ShaderNodeValToRGB'); lr.color_ramp.interpolation = 'EASE'
    els = lr.color_ramp.elements
    while len(els) < len(ramp): els.new(0.5)
    for e, (p, v) in zip(els, ramp): e.position = p; e.color = (v, v, v, 1)
    L.new(bw.outputs[0], lr.inputs[0])
    mul = N.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'; mul.inputs['Factor'].default_value = 1
    L.new(base_out, mul.inputs['A']); L.new(lr.outputs[0], mul.inputs['B'])
    amb_n = N.new('ShaderNodeMix'); amb_n.data_type = 'RGBA'; amb_n.blend_type = 'SCREEN'; amb_n.inputs['Factor'].default_value = amb
    L.new(mul.outputs['Result'], amb_n.inputs['A']); amb_n.inputs['B'].default_value = srgb(ambient)
    em = N.new('ShaderNodeEmission'); L.new(amb_n.outputs['Result'], em.inputs[0])
    L.new(em.outputs[0], out.inputs[0])
    return m

def build_materials():
    M = {}
    M['rock'] = toon_material('M_Rock', ('zgrad', [(-7.5, PAL['rock_cool']), (-3.0, PAL['rock_mid']), (-0.2, PAL['rock_warm'])]))
    M['grass'] = toon_material('M_Grass', PAL['grass'], ramp=((0.0, 0.62), (0.45, 0.85), (1.0, 1.0)))
    M['earth'] = toon_material('M_Earth', PAL['earth'])
    M['root'] = toon_material('M_Root', PAL['root'])
    M['cloud'] = toon_material('M_Cloud', PAL['cloud'], ramp=((0.0, 0.80), (0.5, 0.93), (1.0, 1.0)), ambient='#dfe9f2', amb=0.25)
    return M

# ---------------------------------------------------------------- coastline
def coastline(rng, P):
    n = 1024
    phases = [(k, a * rng.uniform(0.7, 1.3), rng.uniform(0, 2 * math.pi)) for k, a in P['harmonics']]
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        r = P['R0'] * (1 + sum(a * math.sin(k * t + ph) for k, a, ph in phases))
        pts.append(Vector((r * math.cos(t), r * math.sin(t), 0)))
    return resample(pts, P['coast_samples'])

def resample(pts, m):
    seg = [(pts[(i + 1) % len(pts)] - pts[i]).length for i in range(len(pts))]
    total = sum(seg); out = []; i = 0; acc = 0.0
    for j in range(m):
        d = total * j / m
        while acc + seg[i] < d: acc += seg[i]; i += 1
        f = (d - acc) / seg[i]; out.append(pts[i].lerp(pts[(i + 1) % len(pts)], f))
    return out

def centroid(pts):
    return sum(pts, Vector()) / len(pts)

def perimeter(pts):
    return sum((pts[(i + 1) % len(pts)] - pts[i]).length for i in range(len(pts)))

def sample_at(pts, d):
    """point, outward normal, tangent at arclength d along closed polyline (CCW)."""
    total = perimeter(pts); d %= total; acc = 0.0
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]; L = (b - a).length
        if acc + L >= d:
            t = (b - a).normalized(); p = a.lerp(b, (d - acc) / L)
            n = Vector((t.y, -t.x, 0))         # CCW polygon -> right-hand normal points outward
            return p, n, t, i
        acc += L
    return pts[0], Vector((1, 0, 0)), Vector((0, 1, 0)), 0

def scaled(pts, c, s):
    return [c + (p - c) * s for p in pts]

# ---------------------------------------------------------------- island top slab
def build_top(pts, M):
    c = centroid(pts)
    # (radial offset m, z, material) loops from inner grass to under-rim earth: rounded shoulder
    loops = [(-2.2, 0.10, 'g'), (-0.9, 0.04, 'g'), (-0.35, 0.0, 'g'), (-0.1, -0.06, 'g'), (0.05, -0.16, 'g'),
             (0.08, -0.28, 'e'), (-0.15, P['slab_bottom'], 'e')]
    bm = bmesh.new(); rings = []
    for off, z, _ in loops:
        ring = []
        for p in pts[::2]:
            d = (p - c); r = d.length
            q = c + d * ((r + off) / r); q.z = z
            ring.append(bm.verts.new(q))
        rings.append(ring)
    top = bm.verts.new((c.x, c.y, 0.18)); bot = bm.verts.new((c.x, c.y, P['slab_bottom']))
    n = len(rings[0])
    for i in range(n):
        f = bm.faces.new((top, rings[0][i], rings[0][(i + 1) % n])); f.material_index = 0
        f = bm.faces.new((bot, rings[-1][(i + 1) % n], rings[-1][i])); f.material_index = 1
    for k in range(len(rings) - 1):
        for i in range(n):
            f = bm.faces.new((rings[k][i], rings[k + 1][i], rings[k + 1][(i + 1) % n], rings[k][(i + 1) % n]))
            f.material_index = 0 if loops[k + 1][2] == 'g' else 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('IslandTop'); bm.to_mesh(me); bm.free()
    for poly in me.polygons: poly.use_smooth = True
    me.materials.append(M['grass']); me.materials.append(M['earth'])
    ob = bpy.data.objects.new('IslandTop', me); bpy.context.scene.collection.objects.link(ob)
    return ob

def build_core(pts, M, P):
    c = centroid(pts); cp = P['core']
    ring = scaled(pts, c, cp['s'])[:: max(1, len(pts) // cp['segments'])]
    bm = bmesh.new()
    vs = [bm.verts.new((p.x, p.y, cp['top'])) for p in ring]
    mid = [bm.verts.new((c.x + (p.x - c.x) * 0.5, c.y + (p.y - c.y) * 0.5, (cp['top'] + cp['bottom']) * 0.45)) for p in ring]
    tip = bm.verts.new((c.x, c.y, cp['bottom']))
    n = len(vs)
    for i in range(n):
        bm.faces.new((vs[i], vs[(i + 1) % n], mid[(i + 1) % n], mid[i]))
        bm.faces.new((mid[i], mid[(i + 1) % n], tip))
    bm.faces.new(vs[::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('Core'); bm.to_mesh(me); bm.free(); me.materials.append(M['rock'])
    ob = bpy.data.objects.new('UndersideCore', me); bpy.context.scene.collection.objects.link(ob)
    return ob

def build_cone(pts, M, depth=6.5):
    """baseline: the current smooth inverted cone, for comparison."""
    c = centroid(pts); bm = bmesh.new()
    rings = []
    for k, (s, z) in enumerate([(1.0, P['slab_bottom']), (0.85, -1.6), (0.62, -3.0), (0.36, -4.6), (0.12, -5.9)]):
        rings.append([bm.verts.new((c.x + (p.x - c.x) * s, c.y + (p.y - c.y) * s, z)) for p in pts[::4]])
    tip = bm.verts.new((c.x, c.y, -depth)); n = len(rings[0])
    for k in range(len(rings) - 1):
        for i in range(n):
            bm.faces.new((rings[k][i], rings[k][(i + 1) % n], rings[k + 1][(i + 1) % n], rings[k + 1][i]))
    for i in range(n): bm.faces.new((rings[-1][i], rings[-1][(i + 1) % n], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('Cone'); bm.to_mesh(me); bm.free()
    for poly in me.polygons: poly.use_smooth = True
    me.materials.append(M['rock'])
    ob = bpy.data.objects.new('SmoothCone', me); bpy.context.scene.collection.objects.link(ob)

# ---------------------------------------------------------------- kit loading
def load_kit(M):
    kit = {}
    col = bpy.data.collections.new('Kit')   # not linked to scene => hidden library
    for name, path, role in KIT:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=path)
        new = [o for o in bpy.data.objects if o not in before]
        meshes = [o for o in new if o.type == 'MESH']
        bm = bmesh.new()
        for o in meshes:
            tmp = o.data.copy(); tmp.transform(o.matrix_world); bm.from_mesh(tmp); bpy.data.meshes.remove(tmp)
        for o in new: bpy.data.objects.remove(o, do_unlink=True)
        # flip upside-down: flat base goes up against the slab, rounded crown points down
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi, 3, 'X'))
        xs = [v.co.x for v in bm.verts]; ys = [v.co.y for v in bm.verts]; zs = [v.co.z for v in bm.verts]
        off = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, max(zs)))   # origin = top-centre
        bmesh.ops.translate(bm, verts=bm.verts, vec=-off)
        me = bpy.data.meshes.new('KIT_' + name); bm.to_mesh(me); bm.free()
        for poly in me.polygons: poly.use_smooth = False       # faceted low-poly read
        me.materials.clear(); me.materials.append(M['rock'])
        w = max(max(xs) - min(xs), max(ys) - min(ys)); h = max(zs) - min(zs)
        kit[name] = dict(mesh=me, role=role, width=w, height=h, tris=sum(len(p.vertices) - 2 for p in me.polygons))
    return kit

def pool(kit, spec):
    names = []
    for part in spec.split('+'):
        names += [n for n, k in kit.items() if k['role'] == part]
    return names

# ---------------------------------------------------------------- assembly rules
def place(kit, name, pos, yaw, s, zs, tilt_axis=None, tilt=0.0, inward=None, coll=None, tag=''):
    k = kit[name]
    R_yaw = Matrix.Rotation(yaw, 4, 'Z')
    R_tilt = Matrix.Identity(4)
    if tilt_axis is not None and tilt:
        R_tilt = Matrix.Rotation(math.radians(tilt), 4, tilt_axis)
        if inward is not None and (R_tilt.to_3x3() @ Vector((0, 0, -1))).dot(inward) < 0:
            R_tilt = Matrix.Rotation(-math.radians(tilt), 4, tilt_axis)
    S = Matrix.Diagonal((s, s, s * zs, 1))
    ob = bpy.data.objects.new(f'{tag}_{name}', k['mesh'])
    Mw = R_tilt @ R_yaw @ S
    top = max((Mw @ v.co).z for v in k['mesh'].vertices)   # tilt lifts one edge; keep true top at pos.z
    ob.matrix_world = Matrix.Translation(pos - Vector((0, 0, top))) @ Mw
    (coll or bpy.context.scene.collection).objects.link(ob)
    return ob

def assemble(pts, kit, rng, P):
    coll = bpy.data.collections.new('Underside'); bpy.context.scene.collection.children.link(coll)
    c = centroid(pts); J = P['jitter']; placed = []
    for ri, R in enumerate(P['rings']):
        ring = scaled(pts, c, R['s']); per = perimeter(ring)
        step = R['width'] * R['spacing']; n = max(3, round(per / step)); step = per / n
        start = rng.uniform(0, step); names = pool(kit, R['pool'])
        for i in range(n):
            d = start + i * step + rng.uniform(-J['arc'], J['arc']) * step
            p, nrm, tan, seg = sample_at(ring, d)
            name = rng.choice(names); k = kit[name]
            s = R['width'] / k['width'] * rng.uniform(*R['scale'])
            zs = rng.uniform(*R['zs'])
            half = k['width'] * s * 0.5
            # push centre inward so outer face sits at (coast + protrude)
            pos = p - nrm * (half * 0.75 - R['protrude']) + nrm * rng.uniform(-J['radial'], J['radial'])
            pos.z = R['top'] + rng.uniform(-J['z'], J['z']) + (0.08 if ri == 0 else 0.0)
            ob = place(kit, name, pos, rng.uniform(0, 2 * math.pi), s, zs, tan, R['tilt'] * rng.uniform(0.7, 1.2), -nrm, coll, f'R{ri}')
            placed.append(dict(obj=ob, ring=ri, piece=name, coast_seg=seg, arclen=d))
    T = P['tips']; ntip = rng.randint(*T['count']); tips = pool(kit, 'tip')
    for i in range(ntip):
        a = rng.uniform(0, 2 * math.pi); rr = 0 if i == 0 else rng.uniform(0.5, 1.0) * T['spread'] * 1.4
        pos = c + Vector((math.cos(a) * rr, math.sin(a) * rr, 0)); pos.z = T['top'] + (0 if i == 0 else rng.uniform(0.3, 0.9))
        name = rng.choice(tips); k = kit[name]
        w = rng.uniform(*T['width']) * (1.0 if i == 0 else 0.75)
        s = w / k['width']; zs = rng.uniform(*T['zs']) * (1.0 if i == 0 else 0.7)
        out = Vector((math.cos(a), math.sin(a), 0)); axis = out.cross(Vector((0, 0, 1)))
        ob = place(kit, name, pos, rng.uniform(0, 2 * math.pi), s, zs, axis, T['tilt'] * (0.5 if i == 0 else 1.5), out, coll, 'TIP')
        placed.append(dict(obj=ob, ring='tip', piece=name, coast_seg=None, arclen=None))
    return placed

def build_roots(placed, rng, P, M):
    rim = [p for p in placed if p['ring'] in (0, 1)]
    for j in range(P['roots']['count']):
        src = rng.choice(rim)['obj']; base = src.matrix_world.translation.copy()
        base.z -= rng.uniform(0.6, 1.2)
        L = rng.uniform(*P['roots']['length'])
        cu = bpy.data.curves.new(f'Root{j}', 'CURVE'); cu.dimensions = '3D'
        cu.bevel_depth = 0.10; cu.bevel_resolution = 1; cu.resolution_u = 3
        sp = cu.splines.new('BEZIER'); sp.bezier_points.add(3)
        sway = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized() * 0.35
        for i, bp in enumerate(sp.bezier_points):
            t = i / 3; q = base + Vector((0, 0, -L * t)) + sway * math.sin(t * 2.5) * t
            bp.co = q; bp.handle_left_type = bp.handle_right_type = 'AUTO'; bp.radius = 1.0 - 0.85 * t
        ob = bpy.data.objects.new(f'Root{j}', cu); bpy.context.scene.collection.objects.link(ob)
        cu.materials.append(M['root'])

def build_clouds(rng, M, n=9, zc=-9.5, spread=26):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1)
    proto = bpy.context.active_object; proto_me = proto.data; bpy.data.objects.remove(proto)
    for poly in proto_me.polygons: poly.use_smooth = True
    proto_me.materials.append(M['cloud'])
    for i in range(n):
        a = rng.uniform(0, 2 * math.pi); r = rng.uniform(6, spread)
        cc = Vector((math.cos(a) * r, math.sin(a) * r, zc + rng.uniform(-1.5, 1.5)))
        for b in range(rng.randint(4, 7)):
            ob = bpy.data.objects.new('Cloud', proto_me)
            sz = rng.uniform(1.4, 3.0)
            ob.location = cc + Vector((rng.uniform(-3, 3), rng.uniform(-1.5, 1.5), rng.uniform(-0.3, 0.6)))
            ob.scale = (sz * 1.4, sz, sz * 0.6)
            bpy.context.scene.collection.objects.link(ob)

# ---------------------------------------------------------------- scene / render
def setup_scene(w=1280, h=720):
    s = bpy.context.scene
    s.render.engine = 'BLENDER_EEVEE_NEXT'
    s.render.resolution_x, s.render.resolution_y = w, h
    s.eevee.taa_render_samples = 32
    s.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new('W'); s.world = world; world.use_nodes = True
    wn = world.node_tree.nodes; wl = world.node_tree.links
    bg = wn['Background']; bg.inputs[0].default_value = srgb(PAL['sky']); bg.inputs[1].default_value = 1.0
    fill = wn.new('ShaderNodeBackground'); fill.inputs[0].default_value = srgb(PAL['sky']); fill.inputs[1].default_value = 0.35
    lp = wn.new('ShaderNodeLightPath'); mix = wn.new('ShaderNodeMixShader')
    wl.new(lp.outputs['Is Camera Ray'], mix.inputs[0]); wl.new(fill.outputs[0], mix.inputs[1]); wl.new(bg.outputs[0], mix.inputs[2])
    wl.new(mix.outputs[0], wn['World Output'].inputs[0])
    sun = bpy.data.lights.new('Sun', 'SUN'); sun.energy = 4.0; sun.angle = math.radians(8); sun.color = (1.0, 0.95, 0.88)
    so = bpy.data.objects.new('Sun', sun); so.rotation_euler = (math.radians(62), 0, math.radians(-38))   # ~28 deg elevation, from front-left
    s.collection.objects.link(so)
    # cool bounce from the cloud layer below, so the underside isn't one flat shadow tone
    b = bpy.data.lights.new('Bounce', 'SUN'); b.energy = 1.0; b.angle = math.radians(30); b.color = (0.85, 0.92, 1.0)
    bo = bpy.data.objects.new('Bounce', b); bo.rotation_euler = (math.radians(160), 0, math.radians(20)); s.collection.objects.link(bo)
    return s

def camera(name, loc, target, lens):
    cd = bpy.data.cameras.new(name); cd.lens = lens; cd.clip_end = 500
    ob = bpy.data.objects.new(name, cd); bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    return ob

def render(cam, path):
    s = bpy.context.scene; s.camera = cam; s.render.filepath = path
    bpy.ops.render.render(write_still=True); print('RENDERED', path)

VIEWS = {
    # name: (location, target, lens mm)  -- lens 57 mm ~ 35 deg horizontal FOV on 36 mm sensor
    'side': ((4.0, -27.0, -4.2), (0.0, 0.0, -2.6), 45),
    'overview': ((-17.0, -21.5, 15.5), (0.0, 0.0, -1.6), 57),
    'side34': ((-18.0, -20.0, -6.0), (0.0, 0.0, -2.6), 45),
}

# ---------------------------------------------------------------- export helpers
def bake_export(objs, path):
    """Join copies with transforms applied and bake shared palette (world-Z gradient) into vertex colours."""
    stops = [(-7.5, PAL['rock_cool']), (-3.0, PAL['rock_mid']), (-0.2, PAL['rock_warm'])]
    def grad(z):
        z = min(max(z, stops[0][0]), stops[-1][0])
        for (z0, c0), (z1, c1) in zip(stops, stops[1:]):
            if z <= z1:
                f = (z - z0) / (z1 - z0); f = f * f * (3 - 2 * f)
                a, b = srgb(c0), srgb(c1); return [a[i] + (b[i] - a[i]) * f for i in range(3)] + [1.0]
    mat = bpy.data.materials.new('Rock_VertexColor'); mat.use_nodes = True
    bsdf = mat.node_tree.nodes['Principled BSDF']; bsdf.inputs['Roughness'].default_value = 1.0
    ca = mat.node_tree.nodes.new('ShaderNodeVertexColor'); ca.layer_name = 'Col'
    mat.node_tree.links.new(ca.outputs[0], bsdf.inputs['Base Color'])
    bm = bmesh.new()
    for o in objs:
        me = o.data.copy(); me.transform(o.matrix_world); bm.from_mesh(me); bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new('UndersideRocks'); bm.to_mesh(me); bm.free()
    col = me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
    for poly in me.polygons:
        poly.use_smooth = False
        for li in poly.loop_indices:
            col.data[li].color = grad(me.vertices[me.loops[li].vertex_index].co.z)
    me.materials.clear(); me.materials.append(mat)
    ob = bpy.data.objects.new('UndersideRocks', me); bpy.context.scene.collection.objects.link(ob)
    return ob

# ---------------------------------------------------------------- main
def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument('--seed', type=int, default=7); ap.add_argument('--tag', default=None)
    ap.add_argument('--views', default='side,overview'); ap.add_argument('--contact', action='store_true')
    ap.add_argument('--cone', action='store_true'); ap.add_argument('--glb', action='store_true')
    ap.add_argument('--res', default='1280x720')
    a = ap.parse_args(argv); tag = a.tag or f'seed{a.seed}'
    w, h = map(int, a.res.split('x'))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    setup_scene(w, h); M = build_materials()
    if a.contact:
        return contact_sheet(M)
    rng = random.Random(a.seed)
    pts = coastline(rng, P)
    top = build_top(pts, M)
    if a.cone:
        build_cone(pts, M); placed = []
    else:
        kit = load_kit(M)
        build_core(pts, M, P)
        placed = assemble(pts, kit, rng, P)
        build_roots(placed, rng, P, M)
        print('PLACED', len(placed), 'pieces;', 'tris', sum(kit[p['piece']]['tris'] for p in placed))
    build_clouds(random.Random(a.seed + 1000), M)
    for v in [x for x in a.views.split(',') if x]:
        loc, tgt, lens = VIEWS[v]
        render(camera('Cam_' + v, loc, tgt, lens), f'{RENDERS}{tag}_{v}.png')
    if a.glb and placed:
        for o in list(bpy.data.objects):
            if o.name.startswith('Cloud'): bpy.data.objects.remove(o)
        rocks = bake_export([p['obj'] for p in placed] + [bpy.data.objects['UndersideCore']], None)
        bpy.ops.object.select_all(action='DESELECT')
        for o in [rocks, top] + [o for o in bpy.data.objects if o.name.startswith('Root')]: o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=f'{EXPORT}island_{tag}.glb', use_selection=True, export_apply=True)
        layout = [dict(piece=p['piece'], ring=p['ring'], coast_seg=p['coast_seg'],
                       matrix=[list(r) for r in p['obj'].matrix_world]) for p in placed]
        json.dump(dict(seed=a.seed, params=P, coastline=[list(v[:2]) for v in pts], instances=layout),
                  open(f'{EXPORT}layout_{tag}.json', 'w'), indent=1, default=str)
        print('EXPORTED', f'{EXPORT}island_{tag}.glb')

def contact_sheet(M):
    kit = load_kit(M)
    s = bpy.context.scene
    # flat per-piece tint by role for readability; same rock material otherwise
    names = list(kit.keys()); cols = 5; gap = 5.2
    for i, n in enumerate(names):
        k = kit[n]; sc = 3.6 / max(k['width'], k['height'])
        x = (i % cols - (cols - 1) / 2) * gap; zrow = 0 if i < cols else -6.5
        ob = bpy.data.objects.new(n, k['mesh']); s.collection.objects.link(ob)
        ob.scale = (sc, sc, sc); ob.location = (x, 0, zrow + 0.0 + (k['height'] * sc) * 0.0 - 0.2 + 1.6)
        ob.rotation_euler = (0, 0, math.radians(25))
        cu = bpy.data.curves.new('T' + n, 'FONT'); cu.body = f"{n}\n{k['role']}  {k['tris']} tris"; cu.size = 0.42; cu.align_x = 'CENTER'
        t = bpy.data.objects.new('T' + n, cu); s.collection.objects.link(t)
        t.location = (x, -1.0, zrow - 2.6); t.rotation_euler = (math.radians(80), 0, 0)
        cu.materials.append(M['root'])
    # rock material uses world-Z gradient; for the sheet override with a plain mid-tone copy
    m2 = toon_material('M_RockSheet', PAL['rock_mid'])
    for k in kit.values(): k['mesh'].materials[0] = m2
    cam = camera('Cam_sheet', (0, -30, -2.4), (0, 0, -3.4), 50)
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = 27
    render(cam, os.environ.get('SHEET_OUT', RENDERS + 'kit_contact_sheet.png'))

main()
