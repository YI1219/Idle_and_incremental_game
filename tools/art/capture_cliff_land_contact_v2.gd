extends 'res://tools/art/capture_master_mantle.gd'
## Bounded source-defined proof; raw occupied-cell edges clip physical soil.
var exposed_edges:Array=[]
const CAP_FLOOR:=2.65
func owner(p:Vector3)->bool:
 if p.y<CAP_FLOOR or not original_data.cells.has(Vector2i(Vector2(p.x,p.z).floor())):return false
 var h:=original_roof(Vector2(p.x,p.z))
 return is_finite(h) and h>=CAP_FLOOR and p.y>=h-.105 and dry_distance(Vector2(p.x,p.z))<.02
func dry_distance(p:Vector2)->float:
 var distance_value:=INF
 for edge:Array in exposed_edges:
  var a:Vector2=edge[0];var delta:Vector2=edge[1]-a
  distance_value=minf(distance_value,p.distance_to(a+delta*clampf((p-a).dot(delta)/delta.length_squared(),0,1)))
 return -distance_value if original_data.cells.has(Vector2i(p.floor())) else distance_value
func fields()->Dictionary:
 original_data=load_source()
 for z:int in range(-5,5):
  for x:int in range(-6,6):
   var h:float=original_data.rocks.height_at(Vector2(x+.5,z+.5))
   if is_finite(h) and h>2.65:original_data.cells[Vector2i(x,z)]={'height':roundf((h+.25)*2.0)*.5,'water':-1}
 for key:Vector2i in original_data.cells:
  var p:=Vector2(key)
  for side:Array in [[Vector2i.LEFT,p,p+Vector2.DOWN],[Vector2i.RIGHT,p+Vector2.RIGHT,p+Vector2.ONE],[Vector2i.UP,p,p+Vector2.RIGHT],[Vector2i.DOWN,p+Vector2.DOWN,p+Vector2.ONE]]:
   if not original_data.cells.has(key+side[0]):exposed_edges.append([side[1],side[2]])
 assert(not exposed_edges.is_empty())
 var candidate=Data.new();assert(candidate.deserialize(original_data.serialize()))
 var changed:=0;var added:=0
 for z:int in range(-18,19):
  for x:int in range(-25,26):
   var at:=Vector2(x,z)*.25;var roof:=original_roof(at)
   if not is_finite(roof) or roof<CAP_FLOOR:continue
   var horizontal:=dry_distance(at)
   if horizontal>=0:continue
   for y:int in range(floori((roof-.65)*4),ceili((roof+.8)*4)+1):
    var key:=Vector3i(x,y,z);var old:float=original_data.rocks.node_value(key)
    var soil:=maxf(maxf(original_data.rocks.node_value(key-Vector3i.UP),maxf(roof-.10,CAP_FLOOR)-y*.25),horizontal+.015)
    var value:=roundf(clampf(minf(old,soil),-.5,.5)*100000.0)/100000.0
    if absf(value)<.00001:value=.00002
    if value==old:continue
    assert(original_data.cells.has(Vector2i(at.floor())))
    changed+=1
    if old>=0 and value<0:added+=1
    if value<.5:candidate.rocks.samples[key]=value
    else:candidate.rocks.samples.erase(key)
 candidate.rocks._height_bounds_dirty=true
 reports['mantle_operation']={'changed_records':changed,'air_to_solid':added,'soil_vertical_shift':.25,'cells':candidate.cells.size(),'outside_cell_changed_nodes':0,'contour':'Exact exterior edges of occupied authoring cells, not smoothed contour','construction':'Union in ordinary saved densities; same one skin, no decorative backing or separate soil surface.'}
 return {'source':original_data,'candidate':candidate}
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/tripo_land_v2/contact/'
 WORK='res://art/work/cliff_land_v2/2026-10-18/contact/'
 DirAccess.make_dir_recursive_absolute(OUT);setup();grass.visible=false;compiler.prepare(compiler.fixture(),7301)
 var variants:=fields();var candidate=variants.candidate
 var neutral:=StandardMaterial3D.new();neutral.albedo_color=Color(.60,.60,.57);neutral.roughness=.95
 var finish:=ShaderMaterial.new();finish.shader=preload('res://tools/art/master_mantle_surface.gdshader');preload('res://scripts/terrain_editor/material_detail.gd').bind(finish);finish.set_shader_parameter('footpath_count',0)
 var points:PackedVector3Array=preload('res://tools/art/probe_cliff_manifold.gd').read_points(WORK+'master_source.bin')
 var raw=Surface.new()
 for i:int in range(0,points.size(),3):
  var n:=-(points[i+1]-points[i]).cross(points[i+2]-points[i]).normalized()
  for j:int in 3:raw.vertices.append(points[i+j]);raw.normals.append(n);raw.colors.append(Color.WHITE);raw.uv.append(Vector2.ZERO)
 body.mesh=preload('res://scripts/terrain_editor/stone_normals.gd').soften(raw.mesh(),42.0,1.0);body.material_override=neutral
 await capture_views('source_neutral')
 for stage:String in ['sampled_neutral','soil_neutral','contact','carved']:
  var data=variants.source if stage=='sampled_neutral' else candidate
  var before:Dictionary=data.serialize()
  if stage=='carved':
   var at:=Vector3.ZERO;var front:=-INF
   for key:Vector3i in data.rocks.samples:
    if key.y== -2 and data.rocks.samples[key]<0 and key.z>front:at=Vector3(key)*.25;front=key.z
   assert(is_finite(front));data.begin_stroke();var count:int=data.apply_rock_brush(at,1.1,'rock_cut',Vector3.FORWARD);data.end_stroke();assert(count>0)
   reports['carve_operation']={'center':str(at),'changed':count,'radius':1.1}
  body.mesh=tagged_mesh(data);body.material_override=finish if stage in ['contact','carved'] else neutral
  grass.visible=stage in ['contact','carved'];var leaves_report:Dictionary=contact_leaves(data) if grass.visible else {}
  var values:PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  FileAccess.open(WORK+stage+'.bin',FileAccess.WRITE).store_buffer(values.to_byte_array())
  FileAccess.open(WORK+stage+'.layout',FileAccess.WRITE).store_string(JSON.stringify(data.serialize(),'\t',true,true))
  reports[stage]={'triangles':values.size()/3,'records':data.rocks.samples.size(),'cells':data.cells.size(),'contact':leaves_report,'layout_hash':JSON.stringify(data.serialize()).sha256_text()}
  await capture_views(stage)
  if stage=='carved':
   var edited:Dictionary=data.serialize();assert(data.undo() and data.serialize()==before);assert(data.redo() and data.serialize()==edited)
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'frames':frames,'stages':reports,'source_points_sha256':FileAccess.get_sha256(WORK+'master_source.bin'),'scope':'Second-source bounded11m strip, production .25m densities, exact occupied-cell soil clip, complete source grass with actual root support. Source-defined cells, not arbitrary cell regeneration/editor/contour-seed/performance or full art acceptance.'},'\t',true,true))
 print('LAND CONTACT V2: ',frames.size(),' native frames');quit()
