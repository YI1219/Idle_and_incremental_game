"""Blender refinement of selected retained cliff skins, preserving the upper cap.

Run with Blender --factory-startup --background --python this_file -- v1.
This edits copies of accepted main_v4/tall_v2; it does not create a new rock.
"""
import bpy,bmesh,sys,json,hashlib
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
VERSION=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'v1'
assert VERSION in ['v1','v2','v3']
AMOUNT={'v1':.32,'v2':.32,'v3':.46}[VERSION]
OUT=ROOT/'art/work/cliff_connection/2026-10-15/output'
REVIEW=ROOT/'art/review/terrain_fidelity/2026-10-15/cliff_connection'
OUT.mkdir(parents=True,exist_ok=True);REVIEW.mkdir(parents=True,exist_ok=True)
def ease(t):
 t=max(0,min(1,t));return t*t*(3-2*t)
reports=[]
for kind,source_name in [('main','cliff_main_v4.glb'),('tall','cliff_tall_v2.glb')]:
 source=ROOT/'assets/nature/refined'/source_name;source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(source))
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(objects)==1
 obj=objects[0];bpy.context.view_layer.objects.active=obj;obj.select_set(True)
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
 low=Vector(tuple(min(v.co[k] for v in bm.verts) for k in range(3)));high=Vector(tuple(max(v.co[k] for v in bm.verts) for k in range(3)));size=high-low
 before_volume=bm.calc_volume(signed=True);original_triangles=len(bm.faces);protected=0;max_shift=0
 # Stop deformed lower edges at a section below every runtime cap. Without
 # this, a long edge can move its cap intersection although upper verts stay.
 if VERSION!='v1':
  bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-7,plane_co=Vector((0,0,low.z+size.z*.55)),plane_no=Vector((0,0,1)),clear_inner=False,clear_outer=False)
  bmesh.ops.triangulate(bm,faces=list(bm.faces))
 triangles=len(bm.faces)
 # glTF Y-up becomes Blender Z-up, with glTF forward(+Z) = Blender -Y.
 # Translate the lower cross-sections inward without narrowing them to teeth.
 for vertex in bm.verts:
  h=(vertex.co.z-low.z)/size.z
  shift=size.y*AMOUNT*(1-ease((h-.04)/.48))
  if h>=.52:
   assert shift==0;protected+=1
  vertex.co.y+=shift;max_shift=max(max_shift,shift)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.normal_update()
 nonmanifold=sum(not e.is_manifold for e in bm.edges);degenerate=sum(f.calc_area()<1e-10 for f in bm.faces)
 volume=bm.calc_volume(signed=True)
 assert len(bm.faces)==triangles and nonmanifold==0 and degenerate==0 and volume>0
 bm.to_mesh(obj.data);bm.free();obj.data.update();obj.name='Cliff_Wall_'+kind+'_'+VERSION
 # Preserve neutral material; runtime owns texturing/shading and normals.
 stem='cliff_wall_'+kind+'_'+VERSION;blend=OUT/(stem+'.blend');glb=OUT/(stem+'.glb')
 bpy.ops.wm.save_as_mainfile(filepath=str(blend))
 bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_materials='EXPORT',export_animations=False,export_cameras=False,export_lights=False)
 assert hashlib.sha256(source.read_bytes()).hexdigest()==source_hash
 reports.append({'source':str(source.relative_to(ROOT)),'source_sha256':source_hash,'kind':kind,'variant':VERSION,'inward_fraction_of_source_depth':AMOUNT,'upper_normalized_height_protected':.52,'protected_vertices':protected,'maximum_shift':max_shift,'original_triangles':original_triangles,'triangles':triangles,'nonmanifold_edges':nonmanifold,'degenerate_faces':degenerate,'signed_volume_before':before_volume,'signed_volume_after':volume,'blend':str(blend.relative_to(ROOT)),'glb':str(glb.relative_to(ROOT)),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'blender_version':bpy.app.version_string,'protection_section_height':None if VERSION=='v1' else .55,'operation':'Translate lower retained-source cross-sections inward by a smooth height profile. Upper vertices untouched; v2+ adds a protection section below runtime caps, no detached pieces or replacement body.'})
(REVIEW/('refined_connection_'+VERSION+'.json')).write_text(json.dumps(reports,indent=2)+'\n')
print('REFINED CLIFF CONNECTION:',json.dumps(reports))
