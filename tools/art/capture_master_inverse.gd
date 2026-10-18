extends 'res://tools/art/capture_pcg_cliff.gd'
## Second bounded rule: inverse-map the VALID original scalar field.
## Never samples or repairs the crossed direct-mesh candidate.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const ANCHOR:=-1.4
func load_source():
 var data=Data.new()
 assert(data.rocks.load_records(JSON.parse_string(FileAccess.get_file_as_string('res://art/work/master_mantle/2026-10-18/samples.json'))))
 return data
func generate(source_data):
 var candidate=Data.new();var mapped:=0;var unchanged:=0
 var maximum_lift:=0.0;var roof_columns:=0
 for z:int in range(-23,24):
  for x:int in range(-25,26):
   var at:=Vector2(x,z)*.25
   var roof:float=source_data.rocks.height_at(at)
   var upper:float=roof
   if is_finite(roof):
    upper=lerpf(roof,3.25,smoothstep(-1.25,.5,roof))
    maximum_lift=maxf(maximum_lift,upper-roof);roof_columns+=1
   for y:int in range(-20,17):
    var p:=Vector3(x,y,z)*.25;var q:=p
    var lower:=1.0-smoothstep(-4.14,ANCHOR,p.y)
    q.x=p.x/(1.0-.18*lower)
    q.z=.55+(p.z-.55)/(1.0-.30*lower)
    if p.y>ANCHOR and is_finite(roof) and roof> -1.25:
     q.y=ANCHOR+(p.y-ANCHOR)*(roof-ANCHOR)/(upper-ANCHOR)
    if q==p:unchanged+=1
    else:mapped+=1
    var value:float=roundf(clampf(source_data.rocks.value_at(q),-.5,.5)*100000.0)/100000.0
    if absf(value)<.00001:value=.00002
    if value<.5:candidate.rocks.samples[Vector3i(x,y,z)]=value
 candidate.rocks._height_bounds_dirty=true
 assert(candidate.rocks.samples.size()<candidate.rocks.MAX_SAMPLES)
 reports['inverse_operation']={'source_layout':'Valid original explicit field from master_mantle samples, NOT rejected candidate.bin','source_records':source_data.rocks.samples.size(),'records':candidate.rocks.samples.size(),'anchor_y':ANCHOR,'flat_interior_cap':3.25,'max_column_lift':maximum_lift,'roof_columns':roof_columns,'mapped_grid_queries':mapped,'unchanged_grid_queries':unchanged,'scope':'Source-derived inverse scalar resampling, not metric-exact SDF, not arbitrary-contour PCG/editor. Source topology and new finite geometry checked separately.'}
 return candidate
func views(stage:String):
 await capture(stage,'close',Vector3(9,7.6,15),Vector3(0,-.2,0),11.8)
 await capture(stage,'grass',Vector3(5,8,12),Vector3(0,1.5,1),8.0)
 await capture(stage,'whole',Vector3(13,13,19),Vector3(0,-.2,0),18.5)
 await capture(stage,'reverse',Vector3(-13,8,-14),Vector3(0,-.2,0),14.0)
 await capture(stage,'bottom',Vector3(9,-8,15),Vector3(0,-.8,0),13.0)
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/master_landform/inverse/'
 WORK='res://art/work/master_landform/2026-10-18/inverse/'
 DirAccess.make_dir_recursive_absolute(OUT);DirAccess.make_dir_recursive_absolute(WORK)
 setup();grass.visible=false;compiler.prepare(compiler.fixture(),7301)
 var source_data=load_source();var candidate=generate(source_data)
 var neutral:=StandardMaterial3D.new();neutral.albedo_color=Color(.60,.60,.57);neutral.roughness=.95;body.material_override=neutral
 for stage:String in ['source_field','candidate_field']:
  var data=source_data if stage=='source_field' else candidate
  body.mesh=mesh(data,true)
  var values:PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  FileAccess.open(WORK+stage+'.bin',FileAccess.WRITE).store_buffer(values.to_byte_array())
  FileAccess.open(WORK+stage+'.layout',FileAccess.WRITE).store_string(JSON.stringify(data.serialize(),'\t',true,true))
  reports[stage]={'triangles':values.size()/3,'records':data.rocks.samples.size(),'mesh_sha256':FileAccess.get_sha256(WORK+stage+'.bin')}
  await views(stage)
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'frames':frames,'stages':reports,'valid_original_samples_sha256':FileAccess.get_sha256('res://art/work/master_mantle/2026-10-18/samples.json'),'scope':'Source-field comparison, same neutral material/normals/cameras. No crossed mesh input, texture, grass, official default or full art claim.'},'\t',true,true))
 print('MASTER INVERSE NATIVE: ',frames.size(),' frames');quit()
