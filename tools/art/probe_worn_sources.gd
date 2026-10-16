extends SceneTree
## Diagnose rejected sources. A rejected geometry report is not a passing test.
func _initialize():call_deferred('run')
func edges_for(faces:PackedVector3Array)->Dictionary:
 var edges:Dictionary={}
 for i in range(0,faces.size(),3):
  for j in 3:
   var a:Vector3=faces[i+j].snapped(Vector3.ONE*.000001);var b:Vector3=faces[i+(j+1)%3].snapped(Vector3.ONE*.000001)
   var key:Array=[a,b] if a<b else [b,a];edges[key]=edges.get(key,0)+1
 var bad:=0;var collapsed:=0
 for key:Array in edges:
  if edges[key]!=2:bad+=1
  if key[0]==key[1]:collapsed+=1
 return {'non_two_edges':bad,'collapsed_edges':collapsed}
func inspect(mesh:Mesh)->Dictionary:
 var arrays:Array=mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array();var faces:=PackedVector3Array()
 if indices.is_empty():faces=vertices
 else:
  for i in indices:faces.append(vertices[i])
 var invalid:=0;var minimum:=INF
 for p:Vector3 in faces:
  if not p.is_finite():invalid+=1
 for i in range(0,faces.size(),3):minimum=minf(minimum,(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length()*.5)
 return {'uploaded_triangle_count':faces.size()/3,'uploaded_edges':edges_for(faces),'rounded_get_faces_edges':edges_for(mesh.get_faces()),'nonfinite_vertices':invalid,'minimum_triangle_area':minimum}
func run():
 var reports:Dictionary={}
 for version in ['default','v1','v2','v3']:
  var decoration=preload('res://scripts/terrain_editor/terrain_decoration.gd').new();decoration.load_assets()
  if version!='default':preload('res://tools/art/worn_cliff_sources.gd').install(decoration,version,true)
  var report:Dictionary={}
  for kind in ['cliff_column','cliff_column_b','cliff_column_c','cliff_column_d']:
   report[kind]=inspect(decoration.assets[kind][0].mesh)
  reports[version]=report
 var result:Dictionary={'reports':reports,'stage':'Rejected-source diagnostics; no runtime promotion or whole-scene closure claim','edge_tolerance':.000001,'rounded_mesh_faces_warning':'get_faces rounds coordinates; actual uploaded arrays are reported separately'}
 FileAccess.open('res://art/review/terrain_fidelity/2026-10-16/cliff_connection/source_diagnostics.json',FileAccess.WRITE).store_string(JSON.stringify(result,'\t'))
 print('WORN SOURCE DIAGNOSTICS: ',JSON.stringify(result));quit()
