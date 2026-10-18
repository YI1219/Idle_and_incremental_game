extends 'res://tools/art/capture_pcg_cliff.gd'
const Probe=preload('res://tools/art/probe_cliff_manifold.gd')
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/pcg_fracture/route2/'
 WORK='res://art/work/pcg_fracture/2026-10-18/route2/'
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with('--input='):WORK=arg.trim_prefix('--input=')
  if arg.begins_with('--output='):OUT=arg.trim_prefix('--output=')
 DirAccess.make_dir_recursive_absolute(OUT)
 setup();grass.visible=false
 compiler.prepare(compiler.fixture(),7301)
 var data=preload('res://scripts/terrain_editor/terrain_data.gd').new();data.cells.assign(compiler.fixture())
 var samples:Array=JSON.parse_string(FileAccess.get_file_as_string(WORK+'samples.json'))
 for record:Dictionary in samples:data.rocks.samples[Vector3i(record.x,record.y,record.z)]=record.density
 data.rocks._height_bounds_dirty=true
 for shape:String in ['master_source','master_warp','master_sampled']:
  var geometry:ArrayMesh
  # Direct source and sampled controls both have the actual Y3.5 cap.
  # The unrelated81cell guide must not change sampled material ownership.
  if shape=='master_sampled':geometry=mesh(data,true)
  else:
   var surface=Surface.new();var points:PackedVector3Array=Probe.read_points(WORK+shape+'.bin')
   for i:int in range(0,points.size(),3):
    var normal:Vector3=-(points[i+1]-points[i]).cross(points[i+2]-points[i]).normalized()
    for j:int in 3:
     surface.vertices.append(points[i+j]);surface.normals.append(normal);surface.colors.append(Color(clampf(3.5-points[i+j].y,0,1),0,0,1));surface.uv.append(Vector2.ZERO)
   geometry=preload('res://scripts/terrain_editor/stone_normals.gd').soften(surface.mesh(),42.0,1.0)
  FileAccess.open(WORK+shape+'.bin',FileAccess.WRITE).store_buffer(geometry.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].to_byte_array())
  if shape=='master_sampled':FileAccess.open(WORK+shape+'.layout',FileAccess.WRITE).store_string(JSON.stringify(data.serialize(),'\t',true,true))
  for finish:String in ['neutral','stone']:
   body.mesh=geometry
   if finish=='neutral':
    var neutral:=StandardMaterial3D.new();neutral.albedo_color=Color(.60,.60,.57);neutral.roughness=.95;body.material_override=neutral
   else:body.material_override=material
   var stage:String=shape+'_'+finish
   reports[stage]={'triangles':geometry.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()/3,'records':data.rocks.samples.size(),'scope':'Existing-source strip, different footprint from route1; direct source/warp and sampled body use identical views/material.'}
   await capture(stage,'close',Vector3(9,7.6,15),Vector3(-.5,.8,.6),11.8)
   await capture(stage,'whole',Vector3(13,13,19),Vector3(-.3,.0,.0),18.5)
   await capture(stage,'reverse',Vector3(-13,8,-14),Vector3(-.5,.4,.0),16)
   await capture(stage,'bottom',Vector3(9,-8,15),Vector3(-.5,-1,.0),15.5)
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'frames':frames,'stages':reports,'scope':'Route2 existing-source master candidate and density conversion. Not an accepted master, asset replacement or complete PCG workflow.'},'\t',true,true))
 print('MASTER NATIVE: ',frames.size(),' frames');quit()
