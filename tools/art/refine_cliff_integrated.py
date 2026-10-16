"""Refine retained cliff copies into a single shoulder/foot wall module.
No new detached geometry; upper faces used by grass caps remain untouched.
Run Blender --factory-startup --background --python this_file -- v1.
"""
import bpy, bmesh, sys, json, hashlib
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[2]
VERSION = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'v1'
assert VERSION in ['v1', 'v2', 'v3']
EXTEND, RECESS = {'v1': (.60, .22), 'v2': (.42, .16), 'v3': (.78, .30)}[VERSION]
OUT = ROOT / 'art/work/cliff_integrated/2026-10-16/output'
REVIEW = ROOT / 'art/review/terrain_fidelity/2026-10-16/cliff_integrated'
OUT.mkdir(parents=True, exist_ok=True); REVIEW.mkdir(parents=True, exist_ok=True)
def ease(t):
 t = max(0, min(1, t)); return t*t*(3-2*t)
reports = []
for kind, source_name in [('main', 'cliff_main_v4.glb'), ('tall', 'cliff_tall_v2.glb')]:
 source = ROOT / 'assets/nature/refined' / source_name
 source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(source))
 objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']; assert len(objects) == 1
 obj = objects[0]; bpy.context.view_layer.objects.active = obj; obj.select_set(True)
 bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
 bm = bmesh.new(); bm.from_mesh(obj.data)
 bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
 low = Vector(tuple(min(v.co[k] for v in bm.verts) for k in range(3)))
 high = Vector(tuple(max(v.co[k] for v in bm.verts) for k in range(3)))
 size = high-low; center = (high+low)*.5
 before_volume = bm.calc_volume(signed=True); triangles = len(bm.faces)
 # Protect whole faces crossing any active cap, including their low endpoints.
 # This avoids new section slivers and preserves the original cut intersections.
 protected = set()
 for face in bm.faces:
  if max((v.co.z-low.z)/size.z for v in face.verts) >= .58:
   protected.update(face.verts)
 original_upper = {tuple(v.co) for v in protected}
 maximum_drop = 0.0; maximum_recession = 0.0
 for v in bm.verts:
  if v in protected: continue
  h = (v.co.z-low.z)/size.z
  weight = 1-ease((h-.015)/.47)
  across = (v.co.x-center.x)/size.x
  # A broad, diagonally ending foot instead of stretching the whole head.
  drop = size.z*EXTEND*weight*(1+.30*across)
  inward = size.y*RECESS*weight
  v.co.z -= drop; v.co.y += inward
  maximum_drop = max(maximum_drop, drop); maximum_recession = max(maximum_recession, inward)
 assert {tuple(v.co) for v in protected} == original_upper
 bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.normal_update()
 nonmanifold = sum(not e.is_manifold for e in bm.edges)
 degenerate = sum(f.calc_area() < 1e-10 for f in bm.faces)
 volume = bm.calc_volume(signed=True)
 assert len(bm.faces) == triangles and nonmanifold == degenerate == 0 and volume > 0
 bm.to_mesh(obj.data); bm.free(); obj.data.update()
 stem = 'cliff_integrated_'+kind+'_'+VERSION; obj.name = stem
 blend = OUT/(stem+'.blend'); glb = OUT/(stem+'.glb')
 bpy.ops.wm.save_as_mainfile(filepath=str(blend))
 bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True, export_materials='EXPORT', export_animations=False, export_cameras=False, export_lights=False)
 assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
 reports.append({'source': str(source.relative_to(ROOT)), 'source_sha256': source_hash, 'variant': VERSION, 'kind': kind, 'extension_fraction_of_source_height': EXTEND, 'inward_fraction_of_source_depth': RECESS, 'protected_crossing_faces_at_height': .58, 'protected_vertices': len(protected), 'maximum_drop': maximum_drop, 'maximum_recession': maximum_recession, 'triangles': triangles, 'nonmanifold_edges': nonmanifold, 'degenerate_faces': degenerate, 'signed_volume_before': before_volume, 'signed_volume_after': volume, 'blend': str(blend.relative_to(ROOT)), 'glb': str(glb.relative_to(ROOT)), 'glb_sha256': hashlib.sha256(glb.read_bytes()).hexdigest(), 'blender_version': bpy.app.version_string, 'operation': 'Lower retained-source foot continues the same shoulder into the base, with modest inward return and unequal diagonal ending. Whole upper crossing faces protected; identical topology. Runtime uses original source bounds for cap anchoring and omits the separate procedural root layer.'})
(REVIEW/('refined_'+VERSION+'.json')).write_text(json.dumps(reports, indent=2)+'\n')
print('INTEGRATED CLIFF:', json.dumps(reports))
