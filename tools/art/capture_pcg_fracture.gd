extends 'res://tools/art/capture_pcg_cliff.gd'
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/pcg_fracture/route1/'
 WORK='res://art/work/pcg_fracture/2026-10-18/route1/'
 DirAccess.make_dir_recursive_absolute(OUT);DirAccess.make_dir_recursive_absolute(WORK)
 setup();grass.visible=false
 compiler=preload('res://tools/art/pcg_fracture_field.gd').new()
 var data=compiler.generate(7301)
 FileAccess.open(OUT+'construction.json',FileAccess.WRITE).store_string(JSON.stringify(compiler.construction,'\t',true,true))
 for stage:String in ['fracture_neutral','fracture_stone']:
  body.mesh=mesh(data,false)
  if stage.ends_with('neutral'):
   var neutral:=StandardMaterial3D.new();neutral.albedo_color=Color(.60,.60,.57);neutral.roughness=.95;body.material_override=neutral
  else:body.material_override=material
  var vertices:PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  FileAccess.open(WORK+stage+'.bin',FileAccess.WRITE).store_buffer(vertices.to_byte_array())
  FileAccess.open(WORK+stage+'.layout',FileAccess.WRITE).store_string(JSON.stringify(data.serialize(),'\t',true,true))
  reports[stage]={'triangles':vertices.size()/3,'records':data.rocks.samples.size(),'cells':data.cells.size(),'save_hash':JSON.stringify(data.serialize()).sha256_text()}
  await capture(stage,'close',Vector3(9,7.6,15),Vector3(-.5,.8,.6),11.8)
  await capture(stage,'whole',Vector3(13,13,19),Vector3(-.3,.0,.0),18.5)
  await capture(stage,'reverse',Vector3(-13,8,-14),Vector3(-.5,.4,.0),16)
  await capture(stage,'bottom',Vector3(9,-8,15),Vector3(-.5,-1,.0),15.5)
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'frames':frames,'stages':reports,'scope':'Route1 full3D shared fracture planes. Ordinary editable density; no leaves, native editor or default promotion.'},'\t',true,true))
 print('FRACTURE NATIVE: ',frames.size(),' frames');quit()
