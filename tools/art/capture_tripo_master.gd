extends 'res://tools/art/capture_pcg_cliff.gd'
## Inspect the downloaded original in native Godot; no art/default promotion.
func collect(node:Node,result:Array):
 if node is MeshInstance3D:result.append(node)
 for child:Node in node.get_children():collect(child,result)
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/tripo_master/'
 WORK='res://art/work/cliff_master/2026-10-18/'
 DirAccess.make_dir_recursive_absolute(OUT);DirAccess.make_dir_recursive_absolute(WORK)
 setup();grass.visible=false
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 var source_path:='res://art/source/cliff_master/2026-10-18/tripo/cliff_master_white_v1.glb'
 assert(document.append_from_file(source_path,state)==OK)
 var original:Node3D=document.generate_scene(state);viewport.add_child(original)
 # Tripo export faces +X. Rigidly align that observed front to Godot +Z.
 original.rotation.y=-PI/2.0
 var parts:Array=[];collect(original,parts);assert(not parts.is_empty())
 var bounds:=AABB();var first:=true
 for part:MeshInstance3D in parts:
  for p:Vector3 in part.mesh.get_faces():
   p=part.global_transform*p
   if first:bounds=AABB(p,Vector3.ZERO);first=false
   else:bounds=bounds.expand(p)
 var original_bounds:=bounds
 var scale_value:float=5.5/bounds.size.x
 original.scale=Vector3.ONE*scale_value;original.position=-bounds.get_center()*scale_value
 var points:=PackedVector3Array();var triangle_count:=0
 var neutral:=StandardMaterial3D.new();neutral.albedo_color=Color(.60,.60,.57);neutral.roughness=.95
 for part:MeshInstance3D in parts:
  part.material_override=neutral
  for p:Vector3 in part.mesh.get_faces():points.append(part.global_transform*p)
  triangle_count+=part.mesh.get_faces().size()/3
 FileAccess.open(WORK+'tripo_original.bin',FileAccess.WRITE).store_buffer(points.to_byte_array())
 await capture('white','front',Vector3(0,0,12),Vector3.ZERO,4.8)
 await capture('white','back',Vector3(0,0,-12),Vector3.ZERO,4.8)
 await capture('white','left',Vector3(-12,0,0),Vector3.ZERO,5.0)
 await capture('white','right',Vector3(12,0,0),Vector3.ZERO,5.0)
 await capture('white','close',Vector3(9,7.6,15),Vector3.ZERO,4.8)
 await capture('white','whole',Vector3(13,13,19),Vector3.ZERO,9.0)
 await capture('white','bottom',Vector3(9,-8,15),Vector3.ZERO,4.8)
 await capture('white','reverse',Vector3(-13,8,-14),Vector3.ZERO,4.8)
 # Same triangle positions; isolate imported smooth normals from major planes.
 var surface=Surface.new()
 for i:int in range(0,points.size(),3):
  var normal:Vector3=-(points[i+1]-points[i]).cross(points[i+2]-points[i]).normalized()
  for j:int in 3:
   surface.vertices.append(points[i+j]);surface.normals.append(normal);surface.colors.append(Color.WHITE);surface.uv.append(Vector2.ZERO)
 body.mesh=preload('res://scripts/terrain_editor/stone_normals.gd').soften(surface.mesh(),42.0,1.0)
 assert(body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==points)
 body.material_override=neutral;original.visible=false
 for view:Dictionary in frames.duplicate(true):
  await capture('crease',view.view,str_to_var('Vector3'+view.position),Vector3.ZERO,view.size)
 var conversion:Dictionary={}
 if FileAccess.file_exists(WORK+'samples.json'):
  compiler.prepare(compiler.fixture(),7301)
  var data=preload('res://scripts/terrain_editor/terrain_data.gd').new()
  var records:Array=JSON.parse_string(FileAccess.get_file_as_string(WORK+'samples.json'))
  for record:Dictionary in records:data.rocks.samples[Vector3i(record.x,record.y,record.z)]=record.density
  data.rocks._height_bounds_dirty=true
  body.mesh=mesh(data,true)
  var sampled:PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  FileAccess.open(WORK+'tripo_sampled.bin',FileAccess.WRITE).store_buffer(sampled.to_byte_array())
  FileAccess.open(WORK+'tripo_sampled.layout',FileAccess.WRITE).store_string(JSON.stringify(data.serialize(),'\t',true,true))
  var views:Array=frames.slice(0,8).duplicate(true)
  for view:Dictionary in views:
   await capture('sampled',view.view,str_to_var('Vector3'+view.position),Vector3.ZERO,view.size)
  conversion={'triangles':sampled.size()/3,'density_records':records.size(),'samples_sha256':FileAccess.get_sha256(WORK+'samples.json'),'layout':'res://'+WORK.trim_prefix('res://')+'tripo_sampled.layout','scope':'Bounded explicit rock data with empty build cells; no turf/ground/editor integration.'}
 var report:Dictionary={'frames':frames,'triangles':triangle_count,'mesh_parts':parts.size(),'source':source_path,'source_sha256':FileAccess.get_sha256(source_path),'front_alignment_y_degrees':-90,'aligned_original_bounds_position':str(original_bounds.position),'aligned_original_bounds_size':str(original_bounds.size),'uniform_scale':scale_value,'normalized_bounds_size':str(original_bounds.size*scale_value),'points_sha256':FileAccess.get_sha256(WORK+'tripo_original.bin'),'crease_control':{'degrees':42,'vertex_positions_exact':true}}
 report['conversion']=conversion
 report['scope']='Original GLB versus unchanged-position crease control and optional production .25m explicit-density conversion, same cameras/neutral material. No ground/grass/editor/performance/full-art acceptance.'
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t',true,true))
 print('TRIPO WHITE NATIVE: ',triangle_count,' triangles, ',frames.size(),' frames');quit()
