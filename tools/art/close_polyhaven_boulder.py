"""Close the retained CC0 scan's open base, never the original files."""
import bpy
import bmesh
import json
import hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/work/polyhaven_rocks/2026-10-17/namaqualand_boulder_02'
source=OUT/'namaqualand_boulder_02_geometry.gltf'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(objects)==1
obj=objects[0];bpy.context.view_layer.objects.active=obj;obj.select_set(True)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bm=bmesh.new();bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
before=sum(not e.is_manifold for e in bm.edges)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=1e-6,plane_co=(0,0,.10),plane_no=(0,0,1),clear_inner=True,clear_outer=False)
boundary=[e for e in bm.edges if e.is_boundary]
filled=bmesh.ops.holes_fill(bm,edges=boundary,sides=0)['faces']
bmesh.ops.triangulate(bm,faces=list(bm.faces))
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
bad=sum(not e.is_manifold for e in bm.edges);tiny=sum(f.calc_area()<1e-12 for f in bm.faces)
if bad:
 print('CLOSE DIAGNOSTIC:',json.dumps([{'faces':len(e.link_faces),'ends':[list(v.co) for v in e.verts]} for e in bm.edges if not e.is_manifold]))
assert bad==tiny==0,(bad,tiny)
unseen=set(bm.verts);components=[]
while unseen:
 start=unseen.pop();stack=[start];count=1
 while stack:
  for edge in stack.pop().link_edges:
   for vertex in edge.verts:
    if vertex in unseen:unseen.remove(vertex);stack.append(vertex);count+=1
 components.append(count)
report=dict(source=str(source.relative_to(ROOT)),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
    before_nonmanifold_edges=before,filled_polygon_count=len(filled),nonmanifold_edges=bad,degenerate_faces=tiny,
    component_vertex_counts=sorted(components,reverse=True),triangles=len(bm.faces),signed_volume=bm.calc_volume(signed=True),
    operation='Crop scanned floor/skirt below Blender Z=.10m, close boundary loops, triangulate and recalculate outward normals; then collapse closed source toward4000triangles. Retained outer source surfaces above cut; no new rock primitive or source overwrite.',
    stage='Unaccepted closed source for small editable-volume/normal-material test; closure is not art acceptance.')
bm.to_mesh(obj.data);bm.free();obj.data.update()
decimate=obj.modifiers.new('Closed source silhouette reduction','DECIMATE');decimate.ratio=min(1,4000/report['triangles']);decimate.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier=decimate.name)
bm=bmesh.new();bm.from_mesh(obj.data)
report['reduced_triangles']=len(bm.faces);report['reduced_nonmanifold_edges']=sum(not e.is_manifold for e in bm.edges)
assert report['reduced_nonmanifold_edges']==0
bm.free()
for polygon in obj.data.polygons:polygon.use_smooth=True
obj.name='namaqualand_boulder_02_closed_study'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'namaqualand_boulder_02_closed_study.blend'))
glb=OUT/'namaqualand_boulder_02_closed_study.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_materials='NONE',export_animations=False)
report['glb_sha256']=hashlib.sha256(glb.read_bytes()).hexdigest()
(OUT/'closed_report.json').write_text(json.dumps(report,indent=2)+'\n')
print('CLOSED POLY HAVEN SOURCE:',json.dumps(report))
