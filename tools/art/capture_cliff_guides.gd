extends 'res://tools/art/capture_master_mantle.gd'
## Actual family comparison plus independent same-model orthographic inputs.
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/cliff_guides/'
 WORK='res://art/work/cliff_guides/2026-10-18/'
 DirAccess.make_dir_recursive_absolute(OUT);DirAccess.make_dir_recursive_absolute(OUT+'white/')
 setup();grass.visible=false
 var neutral:=StandardMaterial3D.new();neutral.albedo_color=Color(.60,.60,.57);neutral.roughness=.95;body.material_override=neutral
 var sources:Dictionary={'tripo_source':'res://art/work/cliff_lower/2026-10-18/source.bin','tripo_refined':'res://art/work/cliff_lower/2026-10-18/refined.bin'}
 var family:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK+'guide_family.json'))
 for stage:String in family.stages:sources[stage]=WORK+stage+'.bin'
 for stage:String in sources:
  var values:PackedVector3Array=preload('res://tools/art/probe_cliff_manifold.gd').read_points(sources[stage])
  var surface=Surface.new()
  for i:int in range(0,values.size(),3):
   var normal:Vector3=-(values[i+1]-values[i]).cross(values[i+2]-values[i]).normalized()
   for j:int in 3:surface.vertices.append(values[i+j]);surface.normals.append(normal);surface.colors.append(Color.WHITE);surface.uv.append(Vector2.ZERO)
  body.mesh=preload('res://scripts/terrain_editor/stone_normals.gd').soften(surface.mesh(),42.0,1.0)
  assert(body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==values)
  reports[stage]={'triangles':values.size()/3,'source':sources[stage],'sha256':FileAccess.get_sha256(sources[stage]),'vertices_unchanged_by_normals':true}
  await capture_views(stage)
  if stage.begins_with('tripo'):continue
  var environment:WorldEnvironment
  for child:Node in viewport.get_children():
   if child is WorldEnvironment:environment=child
  var previous:Color=environment.environment.background_color;environment.environment.background_color=Color.WHITE
  var prior_out:=OUT;OUT+='white/'
  await capture(stage,'front',Vector3(0,.5,20),Vector3(0,.5,0),8)
  await capture(stage,'left',Vector3(-20,.5,0),Vector3(0,.5,0),8)
  await capture(stage,'right',Vector3(20,.5,0),Vector3(0,.5,0),8)
  await capture(stage,'back',Vector3(0,.5,-20),Vector3(0,.5,0),8)
  for f:Dictionary in frames.slice(-4):f['folder']='white'
  OUT=prior_out;environment.environment.background_color=previous
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'frames':frames,'stages':reports,'scope':'8actual complete meshes,40matched neutral scene views+24same-mesh white orthographic guide views. New code guides explicitly authorized; Tripo views soft guidance only. No paid job or art/editor/default promotion.'},'\t',true,true))
 print('CLIFF GUIDE NATIVE: ',frames.size(),' frames');quit()
