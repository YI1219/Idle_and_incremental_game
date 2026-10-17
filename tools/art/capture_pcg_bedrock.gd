extends 'res://tools/art/capture_pcg_cliff.gd'
## Keep all existing production/default material and scene files unchanged.
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/pcg_bedrock/round2/'
 WORK='res://art/work/pcg_bedrock/2026-10-18/round2/'
 DirAccess.make_dir_recursive_absolute(OUT);DirAccess.make_dir_recursive_absolute(WORK)
 setup();grass.visible=false
 var old_compiler=preload('res://tools/art/pcg_cliff_field.gd').new()
 var bedrock=preload('res://tools/art/pcg_bedrock_field.gd').new()
 var data=bedrock.generate(7301)
 var old_data=old_compiler.generate(7301)
 for stage:String in ['ring_neutral','bedrock_neutral','bedrock_stone']:
  compiler=old_compiler if stage=='ring_neutral' else bedrock
  var current=old_data if stage=='ring_neutral' else data
  body.mesh=mesh(current,false)
  material.set_shader_parameter('contact_finish',false)
  if stage.ends_with('neutral'):
   var neutral:=StandardMaterial3D.new();neutral.albedo_color=Color(.60,.60,.57);neutral.roughness=.95;body.material_override=neutral
  else:body.material_override=material
  var vertices:PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  FileAccess.open(WORK+stage+'.bin',FileAccess.WRITE).store_buffer(vertices.to_byte_array())
  FileAccess.open(WORK+stage+'.layout',FileAccess.WRITE).store_string(JSON.stringify(current.serialize(),'\t',true,true))
  reports[stage]={'triangles':vertices.size()/3,'records':current.rocks.samples.size(),'cells':current.cells.size(),'save_hash':JSON.stringify(current.serialize()).sha256_text()}
  await capture(stage,'close',Vector3(9,7.6,15),Vector3(-.5,.8,.6),11.8)
  await capture(stage,'whole',Vector3(13,13,19),Vector3(-.3,.0,.0),18.5)
  await capture(stage,'reverse',Vector3(-13,8,-14),Vector3(-.5,.4,.0),16)
  await capture(stage,'bottom',Vector3(9,-8,15),Vector3(-.5,-1,.0),15.5)
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'frames':frames,'stages':reports,'scope':'Goal structural round2. Identical cameras/light/material on old ring and new 3D-domain volume; no leaves or production integration.'},'\t',true,true))
 print('BEDROCK ROUND2 NATIVE: ',frames.size(),' frames');quit()
