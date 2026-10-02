"""Tailor the preserved Qinglan garment for the authored human locomotion.

No primary animation tracks are modified. The source model remains untouched.
"""
from pathlib import Path
import bpy, json, math, hashlib
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/work/qinglan/qinglan_template_v03.blend'
WORK = ROOT / 'art/work/qinglan/qinglan_clothed_v04.blend'
OUTPUT = ROOT / 'assets/characters/qinglan/qinglan_clothed_v04.glb'
REVIEW = ROOT / 'art/review/running_cloth'

def smooth(a, b, x):
    t = max(0., min(1., (x-a)/(b-a)))
    return t*t*(3-2*t)

def set_weights(obj, index, weights):
    for group in obj.vertex_groups:
        group.remove([index])
    weights = dict(sorted(weights.items(), key=lambda pair: pair[1], reverse=True)[:4])
    total = sum(weights.values())
    for name, weight in weights.items():
        group = obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)
        group.add([index], weight/total, 'REPLACE')

def distance(point, a, b):
    segment = b-a
    at = max(0., min(1., (point-a).dot(segment)/segment.length_squared))
    return (point-a-segment*at).length

def tailor_trousers(obj, rig):
    """Extend the existing panels and add support loops around the knee bend."""
    old = [v.co.copy() for v in obj.data.vertices]
    side = 'L' if obj.name.endswith('.L') else 'R'
    sign = 1 if side == 'L' else -1
    # Retain the upper three source rings; extend the lower source ring and hem.
    coordinates = old[:48]
    for z, x, rx, ry in [(.302, .085, .050, .068), (.268, .086, .047, .065), (.240, .087, .045, .063), (.206, .088, .042, .060), (.097, .090, .035, .055)]:
        for index in range(16):
            angle = index/16*math.tau
            coordinates.append(Vector((sign*x + rx*math.cos(angle), .028+ry*math.sin(angle), z)))
    faces = []
    for row in range(len(coordinates)//16-1):
        for i in range(16):
            faces.append((row*16+i,row*16+(i+1)%16,(row+1)*16+(i+1)%16,(row+1)*16+i))
    materials = list(obj.data.materials)
    mesh = bpy.data.meshes.new(obj.name+'_Tailored')
    mesh.from_pydata(coordinates, [], faces)
    mesh.update()
    for mat in materials: mesh.materials.append(mat)
    obj.data = mesh
    obj.vertex_groups.clear()
    for vertex in mesh.vertices:
        names = ['Thigh.'+side,'Shin.'+side,'Foot.'+side] if vertex.co.z < .538 else ['Hips','Spine']
        nearest = sorted((distance(vertex.co,rig.data.bones[n].head_local,rig.data.bones[n].tail_local),n) for n in names)[:2]
        set_weights(obj, vertex.index, {n: 1/(d+.0134)**4 for d,n in nearest})
    for face in mesh.polygons: face.use_smooth = True
    import bmesh
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    return {'before_vertices':len(old),'after_vertices':len(mesh.vertices),'hem_z':.097}

def tailor_robe(robe):
    changed=0
    for vertex in robe.data.vertices:
        point=vertex.co
        if point.z>=.672: continue
        # Respect the existing sleeve mask: the loose cuff is not a skirt panel.
        original={robe.vertex_groups[g.group].name:g.weight for g in vertex.groups if robe.vertex_groups[g.group].name!='__Sleeve'}
        arm=sum(w for n,w in original.items() if n.startswith(('UpperArm.','Forearm.','Hand.')))
        if arm>.03:continue
        leg_fraction=.84*(1-smooth(.49,.65,point.z))
        if leg_fraction<.001:continue
        left=smooth(-.065,.065,point.x)
        # Lower panels flex at the knee; upper panels retain hip and thigh support.
        shin_fraction=.48*(1-smooth(.23,.37,point.z))
        weights={n:w*(1-leg_fraction) for n,w in original.items()}
        for side,amount in [('L',left),('R',1-left)]:
            weights['Thigh.'+side]=leg_fraction*amount*(1-shin_fraction)
            weights['Shin.'+side]=leg_fraction*amount*shin_fraction
        set_weights(robe,vertex.index,{n:w for n,w in weights.items() if w>.0001})
        changed+=1
    return {'reweighted_vertices':changed,'method':'leg-driven skirt with retained garment response and hip transition; at most four weights'}

def mask_covered_skin(body):
    """Omit only calf surfaces permanently enclosed by this outfit, retaining the source."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(body.data)
    hidden = [face for face in bm.faces
              if min(v.co.z for v in face.verts) > .112
              and max(v.co.z for v in face.verts) < .40
              and max(abs(v.co.x) for v in face.verts) < .18]
    count = len(hidden)
    bmesh.ops.delete(bm, geom=hidden, context='FACES')
    bm.to_mesh(body.data)
    bm.free()
    return {'covered_calf_faces_omitted':count, 'retained':'head, hands, feet and ankle boundary; all source body geometry remains in v03'}

def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    report={'source':str(SOURCE.relative_to(ROOT)),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest()}
    report['robe']=tailor_robe(bpy.data.objects['Robe'])
    report['trousers']={side:tailor_trousers(bpy.data.objects['WhiteTrousers.'+side],rig) for side in ['L','R']}
    report['outfit_mask']=mask_covered_skin(bpy.data.objects['Body'])
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK))
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True)
    report['runtime_sha256']=hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    (REVIEW/'clothing_refinement.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
if __name__=='__main__':main()
