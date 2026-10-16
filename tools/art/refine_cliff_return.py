"""Existing-source study: bend long lower panels into a shouldered return.
Keep every active cap section unchanged; never edit original runtime sources.
Blender --background --factory-startup --python this_file -- v1|v2
"""
import bpy, bmesh, sys, json, hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
VERSION = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'v1'
assert VERSION in ['v1', 'v2']
RIDGE, RETURN, WIDTH = {'v1': (.10, .20, .76), 'v2': (.16, .32, .68)}[VERSION]
OUT = ROOT / 'art/work/cliff_return/2026-10-16'
REVIEW = ROOT / 'art/review/terrain_fidelity/2026-10-16/cliff_return'
OUT.mkdir(parents=True, exist_ok=True); REVIEW.mkdir(parents=True, exist_ok=True)

def ease(t):
    t = max(0., min(1., t)); return t*t*(3.-2.*t)

def load(stem):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/nature/refined' / (stem+'.glb')))
    objects = [o for o in bpy.context.scene.objects if o not in before and o.type == 'MESH']
    assert len(objects) == 1
    obj = objects[0]; bpy.context.view_layer.objects.active = obj; obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj

reports = []
for kind, refstem in [('main', 'cliff_main_v4'), ('tall', 'cliff_tall_v2')]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ref = load(refstem)
    rlo = min(v.co.z for v in ref.data.vertices); rhi = max(v.co.z for v in ref.data.vertices)
    bpy.data.objects.remove(ref, do_unlink=True)
    stem = 'cliff_integrated_'+kind+'_v1'
    source = ROOT / 'assets/nature/refined' / (stem+'.glb')
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    obj = load(stem); bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.dissolve_limit(bm, angle_limit=.001, verts=list(bm.verts), edges=list(bm.edges), delimit=set())
    lo = Vector(tuple(min(v.co[k] for v in bm.verts) for k in range(3)))
    hi = Vector(tuple(max(v.co[k] for v in bm.verts) for k in range(3)))
    size = hi-lo; center = (hi+lo)*.5
    # Split exactly below the lowest active cap (.62) before changing vertices.
    # Protecting only upper vertices of crossing faces would move cap intersections.
    guard = rlo+(rhi-rlo)*.58
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts)+list(bm.edges)+list(bm.faces),
                          plane_co=Vector((0,0,guard)), plane_no=Vector((0,0,1)),
                          dist=1e-7, clear_inner=False, clear_outer=False)
    protected = {v: v.co.copy() for v in bm.verts if v.co.z >= guard-1e-6}
    shifted = 0
    for v in bm.verts:
        if v in protected: continue
        t = (guard-v.co.z)/(guard-lo.z)
        # One off-center ridge and a broader inward foot. Front/back both
        # follow the bend, preserving thickness rather than cutting a thin lip.
        shoulder = max(0., 1.-abs(t-.36)/.36)
        foot = ease((t-.36)/.64)
        across = (v.co.x-center.x)/size.x
        v.co.y += size.y*(-RIDGE*shoulder*(1.+.30*across)+RETURN*foot)
        v.co.x = center.x+(v.co.x-center.x)*(1.-(1.-WIDTH)*foot)+size.x*.045*foot
        shifted += 1
    assert all((v.co-old).length < 1e-8 for v, old in protected.items())
    bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method='BEAUTY', ngon_method='BEAUTY')
    # Source cuts can create slivers that the runtime terrain merger drops.
    # Clean only below the protected cap region, without changing its section.
    for _ in range(8):
        tiny = [f for f in bm.faces if f.calc_area() < .00012 and max(v.co.z for v in f.verts) <= guard+.000001]
        if not tiny: break
        edges = set(min(f.edges, key=lambda e:e.calc_length()) for f in tiny)
        bmesh.ops.collapse(bm, edges=list(edges), uvs=False)
        bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method='BEAUTY', ngon_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.normal_update()
    bad = sum(not e.is_manifold for e in bm.edges)
    degenerate = sum(f.calc_area() < 1e-12 for f in bm.faces)
    volume = bm.calc_volume(signed=True)
    assert bad == degenerate == 0 and volume > 0, (bad, degenerate, volume)
    triangles = len(bm.faces); bm.to_mesh(obj.data); bm.free(); obj.data.update()
    obj.name = 'cliff_return_'+kind+'_'+VERSION
    blend = OUT/(obj.name+'.blend'); glb = OUT/(obj.name+'.glb')
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True,
                             export_animations=False, export_materials='EXPORT', export_cameras=False, export_lights=False)
    assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
    reports.append({'kind':kind, 'source':str(source.relative_to(ROOT)), 'source_sha256':source_hash,
                    'variant':VERSION, 'ridge_fraction':RIDGE, 'inward_return_fraction':RETURN,
                    'lower_width_fraction':WIDTH, 'unchanged_above_reference_fraction':.58,
                    'protected_vertices':len(protected), 'shifted_vertices':shifted,
                    'triangles':triangles, 'nonmanifold_edges':bad, 'degenerate_faces':degenerate,
                    'signed_volume':volume, 'blend':str(blend.relative_to(ROOT)), 'glb':str(glb.relative_to(ROOT)),
                    'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(), 'blender_version':bpy.app.version_string,
                    'stage':'Unaccepted existing-source refinement; Godot section/closure/capture checks required'})
(REVIEW/('source_'+VERSION+'.json')).write_text(json.dumps(reports, indent=2))
print('CLIFF RETURN SOURCES:', json.dumps(reports))
