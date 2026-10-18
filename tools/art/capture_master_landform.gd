extends 'res://tools/art/capture_pcg_cliff.gd'
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/master_landform/'
 WORK='res://art/work/master_landform/2026-10-18/'
 DirAccess.make_dir_recursive_absolute(OUT);setup();grass.visible=false
 var neutral:=StandardMaterial3D.new();neutral.albedo_color=Color(.60,.60,.57);neutral.roughness=.95;body.material_override=neutral
 for stage:String in ['source','candidate']:
  var values:PackedVector3Array=preload('res://tools/art/probe_cliff_manifold.gd').read_points(WORK+stage+'.bin')
  var surface=Surface.new()
  for i:int in range(0,values.size(),3):
   var normal:Vector3=-(values[i+1]-values[i]).cross(values[i+2]-values[i]).normalized()
   for j:int in 3:surface.vertices.append(values[i+j]);surface.normals.append(normal);surface.colors.append(Color.WHITE);surface.uv.append(Vector2.ZERO)
  body.mesh=preload('res://scripts/terrain_editor/stone_normals.gd').soften(surface.mesh(),42.0,1.0)
  assert(body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==values)
  reports[stage]={'triangles':values.size()/3,'sha256':FileAccess.get_sha256(WORK+stage+'.bin')}
  await capture(stage,'close',Vector3(9,7.6,15),Vector3(0,-.2,0),11.8)
  await capture(stage,'grass',Vector3(5,8,12),Vector3(0,1.5,1),8.0)
  await capture(stage,'whole',Vector3(13,13,19),Vector3(0,-.2,0),18.5)
  await capture(stage,'reverse',Vector3(-13,8,-14),Vector3(0,-.2,0),14.0)
  await capture(stage,'bottom',Vector3(9,-8,15),Vector3(0,-.8,0),13.0)
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'frames':frames,'stages':reports,'scope':'Actual unchanged-position direct source/candidate neutral geometry with same42degree normals and five cameras. No sampling/grass/editor/art/performance acceptance.'},'\t',true,true))
 print('MASTER LANDFORM NATIVE: ',frames.size(),' frames');quit()
