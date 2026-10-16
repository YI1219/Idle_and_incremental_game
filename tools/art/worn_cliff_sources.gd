extends RefCounted
## Tool-only source-refinement comparison. Never substitutes production assets.
static func install(decoration,version:String='v1',smooth_wear:bool=false)->Dictionary:
 var library=decoration.model_library
 var meshes:Dictionary={}
 for kind in ['main','tall']:
  var state:=GLTFState.new();var document:=GLTFDocument.new()
  var path:String='res://art/work/cliff_worn/2026-10-16/cliff_worn_'+kind+'_'+version+'.glb'
  assert(document.append_from_file(path,state)==OK)
  var root:=document.generate_scene(state);var nodes:Array=[root];var faces:=PackedVector3Array()
  while not nodes.is_empty():
   var node:Node=nodes.pop_back();nodes.append_array(node.get_children())
   if node is MeshInstance3D:
    var pose:Transform3D=library._global_pose(node,root)
    for p:Vector3 in node.mesh.get_faces():faces.append(pose*p)
  root.free()
  var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=faces
  var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  meshes[kind]=mesh
 var reports:Array=[]
 for spec in [['cliff_column','tall',.72,'cliff_tall_v2.glb'],['cliff_column_b','main',.72,'cliff_main_v4.glb'],['cliff_column_c','tall',.86,'cliff_tall_v2.glb'],['cliff_column_d','main',.62,'cliff_main_v4.glb']]:
  var reference:Dictionary=library._merge(library._load('res://assets/nature/refined/'+spec[3],'cliff_rock'))
  var built:Dictionary=preload('res://scripts/terrain_editor/source_stone_crown.gd').build(meshes[spec[1]],.68,spec[2],reference.mesh.get_aabb())
  var old:Dictionary=decoration.assets[spec[0]][0]
  var material:Material=old.mesh.surface_get_material(0)
  built.mesh.surface_set_material(0,material);built.render_mesh.surface_set_material(0,material)
  built.mesh=preload('res://scripts/terrain_editor/stone_normals.gd').soften(built.mesh,42.0,1.0 if smooth_wear else .28)
  built.render_mesh=preload('res://scripts/terrain_editor/stone_normals.gd').soften(built.render_mesh,42.0,1.0 if smooth_wear else .28)
  built.pose=Transform3D.IDENTITY;built.body_height=built.height;built.integrated_foot=true
  decoration.assets[spec[0]]=[built]
  var edges:Dictionary={};var invalid:=0;var faces:PackedVector3Array=built.mesh.get_faces()
  for i in range(0,faces.size(),3):
   for j in 3:
    var a:Vector3=faces[i+j].snapped(Vector3.ONE*.000001);var b:Vector3=faces[i+(j+1)%3].snapped(Vector3.ONE*.000001)
    var key:Array=[a,b] if a<b else [b,a];edges[key]=edges.get(key,0)+1
  for count:int in edges.values():
   if count!=2:invalid+=1
  reports.append({'kind':spec[0],'vertices':faces.size(),'invalid_edges':invalid,'geometry_height':built.geometry_height,'original_geometry_height':old.geometry_height,'smooth_wear':smooth_wear,'vertices_sha256':faces.to_byte_array().hex_encode().sha256_text()})
 decoration._column_key=Vector2i(-1,-1)
 decoration._run_cache.clear()
 return {'reports':reports,'stage':'Unaccepted physical corner wear; cells/layout/material remain production; cap shape follows refined source.'}
