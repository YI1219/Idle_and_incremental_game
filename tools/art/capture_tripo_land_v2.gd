extends 'res://tools/art/capture_pcg_cliff.gd'
## Matched native source inspection, no deformation or default promotion.
func collect(node:Node,result:Array):
 if node is MeshInstance3D:result.append(node)
 for child:Node in node.get_children():collect(child,result)
func views(stage:String):
 await capture(stage,'front',Vector3(0,0,12),Vector3.ZERO,6.8)
 await capture(stage,'back',Vector3(0,0,-12),Vector3.ZERO,6.8)
 await capture(stage,'left',Vector3(-12,0,0),Vector3.ZERO,6.8)
 await capture(stage,'right',Vector3(12,0,0),Vector3.ZERO,6.8)
 await capture(stage,'close',Vector3(9,7.6,15),Vector3.ZERO,7.2)
 await capture(stage,'whole',Vector3(13,13,19),Vector3.ZERO,11)
 await capture(stage,'reverse',Vector3(-13,8,-14),Vector3.ZERO,7.2)
 await capture(stage,'bottom',Vector3(9,-8,15),Vector3.ZERO,7.2)
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/tripo_land_v2/'
 WORK='res://art/work/cliff_land_v2/2026-10-18/'
 DirAccess.make_dir_recursive_absolute(OUT);DirAccess.make_dir_recursive_absolute(WORK)
 setup();grass.visible=false
 var stages:Dictionary={}
 var paths:Dictionary={'old':'res://art/source/cliff_master/2026-10-18/tripo/cliff_master_white_v1.glb','new':'res://art/source/cliff_master_v2/2026-10-18/tripo/cliff_land_master_v2_white.glb'}
 var neutral:=StandardMaterial3D.new();neutral.albedo_color=Color(.60,.60,.57);neutral.roughness=.95
 for label:String in paths:
  body.visible=false
  var document:=GLTFDocument.new();var state:=GLTFState.new()
  assert(document.append_from_file(paths[label],state)==OK)
  var original:Node3D=document.generate_scene(state);viewport.add_child(original)
  original.rotation.y=-PI/2.0
  var parts:Array=[];collect(original,parts);assert(not parts.is_empty())
  var bounds:=AABB();var first:=true
  for part:MeshInstance3D in parts:
   for p:Vector3 in part.mesh.get_faces():
    p=part.global_transform*p
    if first:bounds=AABB(p,Vector3.ZERO);first=false
    else:bounds=bounds.expand(p)
  var scale_value:float=6.5/bounds.size.x
  original.scale=Vector3.ONE*scale_value;original.position=-bounds.get_center()*scale_value
  var points:=PackedVector3Array()
  for part:MeshInstance3D in parts:
   part.material_override=neutral
   for p:Vector3 in part.mesh.get_faces():points.append(part.global_transform*p)
  FileAccess.open(WORK+label+'.bin',FileAccess.WRITE).store_buffer(points.to_byte_array())
  await views(label+'_white')
  var surface=Surface.new()
  for i:int in range(0,points.size(),3):
   var normal:Vector3=-(points[i+1]-points[i]).cross(points[i+2]-points[i]).normalized()
   for j:int in 3:
    surface.vertices.append(points[i+j]);surface.normals.append(normal);surface.colors.append(Color.WHITE);surface.uv.append(Vector2.ZERO)
  body.mesh=preload('res://scripts/terrain_editor/stone_normals.gd').soften(surface.mesh(),42.0,1.0)
  assert(body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==points)
  body.material_override=neutral;body.visible=true;original.visible=false
  await views(label+'_crease')
  stages[label]={'source':paths[label],'source_sha256':FileAccess.get_sha256(paths[label]),'triangles':points.size()/3,'parts':parts.size(),'front_alignment_y_degrees':-90,'uniform_scale':scale_value,'normalized_bounds_size':str(bounds.size*scale_value),'triangle_bytes_sha256':FileAccess.get_sha256(WORK+label+'.bin'),'crease_positions_exact':true}
  original.queue_free();await process_frame
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'frames':frames,'stages':stages,'resolution':[1671,941],'scope':'Actual old/new GLB rigid front alignment and uniform6.5m width, identical cameras/light/neutral material; imported versus42degree unchanged-position normal control. No density conversion, grass, build data, editor or art acceptance.'},'\t',true,true))
 print('TRIPO LAND V2: ',frames.size(),' native frames');quit()
