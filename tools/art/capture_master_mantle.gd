extends 'res://tools/art/capture_pcg_cliff.gd'
## Disposable source-defined strip. Every visible top/side/bottom is one
## ordinary editable field. This is NOT an arbitrary-cell-contour compiler.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Base=preload('res://scripts/terrain_editor/rock_terrain_base.gd')
var original_data
var dry_loops:Array=[]
var roof_cache:Dictionary={}
func load_source():
 var data=Data.new()
 assert(data.rocks.load_records(JSON.parse_string(FileAccess.get_file_as_string(WORK+'samples.json'))))
 return data
func dry_distance(p:Vector2)->float:return Base._distance(dry_loops,p)
func original_roof(p:Vector2)->float:
 if not roof_cache.has(p):roof_cache[p]=original_data.rocks.height_at(p)
 return roof_cache[p]
func owner(p:Vector3)->bool:
 # Smoothed contour concavities may extend outside occupied authoring cells.
 # Material and roots share the strict cell test before the support assertion.
 if not original_data.cells.has(Vector2i(Vector2(p.x,p.z).floor())):return false
 var h:=original_roof(Vector2(p.x,p.z))
 return is_finite(h) and p.y>=h-.105 and dry_distance(Vector2(p.x,p.z))<.02
func fields()->Dictionary:
 original_data=load_source()
 # Cells and explicit samples live in the same TerrainData. This probe derives
 # cells from a source, so cell-driven regeneration is explicitly unaccepted.
 for z:int in range(-5,5):
  for x:int in range(-6,6):
   var h:float=original_data.rocks.height_at(Vector2(x+.5,z+.5))
   if not is_finite(h) or h<.8:continue
   original_data.cells[Vector2i(x,z)]={'height':roundf((h+.25)*2.0)*.5,'water':-1}
 dry_loops=preload('res://scripts/terrain_editor/contour_terrain.gd')._outlines(original_data.cells)
 assert(not dry_loops.is_empty())
 var candidate=Data.new();assert(candidate.deserialize(original_data.serialize()))
 var added:=0;var changed:=0
 for z:int in range(-22,23):
  for x:int in range(-25,26):
   var at:=Vector2(x,z)*.25;var roof:=original_roof(at)
   if not is_finite(roof):continue
   var horizontal:=dry_distance(at)
   if horizontal>.5:continue
   for y:int in range(floori((roof-.65)*4),ceili((roof+.8)*4)+1):
    var key:=Vector3i(x,y,z);var old:float=original_data.rocks.node_value(key)
    # Upper .25m translation, clipped to a shallow measured top layer and the
    # SMOOTHED cell contour. This can add soil outside actual occupied cells;
    # owner() separately restricts material vertices/roots to actual cells.
    # Lower body is read unchanged; no separate soil mesh.
    var soil:=maxf(maxf(original_data.rocks.node_value(key-Vector3i.UP),roof-.10-y*.25),horizontal+.015)
    var value:=roundf(clampf(minf(old,soil),-.5,.5)*100000.0)/100000.0
    if absf(value)<.00001:value=.00002
    if value==old:continue
    changed+=1
    if old>=0 and value<0:added+=1
    if value<.5:candidate.rocks.samples[key]=value
    else:candidate.rocks.samples.erase(key)
 candidate.rocks._height_bounds_dirty=true
 reports['mantle_operation']={'changed_records':changed,'air_to_solid':added,'soil_vertical_shift':.25,'lower_clip_below_original_top':.10,'cells':candidate.cells.size(),'construction':'Union in ordinary saved density samples; no extra surface or decorative backing.'}
 assert(candidate.rocks.samples.size()<candidate.rocks.MAX_SAMPLES)
 return {'source':original_data,'candidate':candidate}
func tagged_mesh(data)->ArrayMesh:
 var geometry:=mesh(data,true)
 var arrays:Array=geometry.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var colors:=PackedColorArray()
 for p:Vector3 in vertices:
  var h:float=data.rocks.height_at(Vector2(p.x,p.z))
  colors.append(Color(maxf(h-p.y,0.0) if is_finite(h) else 1.0,1.0 if owner(p) else 0.0,0,1))
 arrays[Mesh.ARRAY_COLOR]=colors
 var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return result
func contact_leaves(data)->Dictionary:
 var surface=Surface.new();var rng:=RandomNumberGenerator.new();rng.seed=9017
 var roots:Array=[];var skipped:=0;var maximum_error:=0.0
 for z:int in range(-18,19):
  for x:int in range(-21,22):
   var at:=Vector2(x,z)*.28+Vector2(rng.randf_range(-.06,.06),rng.randf_range(-.06,.06))
   var d:=dry_distance(at)
   if d>.0 or d<-.60 or rng.randf()>.72:continue
   var hit:=support(at)
   if hit.is_empty() or hit.normal.y<.50 or not owner(Vector3(at.x,hit.height,at.y)):skipped+=1;continue
   var h:float=data.rocks.height_at(at)
   var error:float=absf(h-hit.height);assert(error<.0001);maximum_error=maxf(maximum_error,error)
   assert(data.cells.has(Vector2i(at.floor())))
   var height:=rng.randf_range(.09,.19);var scale_value:float=height/source_box.size.y
   var basis:=Basis(Vector3.UP,rng.randf()*TAU)*Basis(Vector3.RIGHT,rng.randf_range(-.48,.48))
   basis=basis.scaled(Vector3(1.6,1,1.6)*scale_value)
   var pose:=Transform3D(basis,Vector3(at.x,h-.012,at.y)-basis*source_foot)
   roots.append({'xz':[at.x,at.y],'y':h,'field_mesh_error':error,'dry_cell':true,'normal_y':hit.normal.y})
   for i:int in range(0,source.size(),3):
    var a:=pose*source[i];var b:=pose*source[i+1];var c:=pose*source[i+2];var n:=-(b-a).cross(c-a).normalized()
    for p:Vector3 in [a,b,c]:
     surface.vertices.append(p);surface.normals.append(n);surface.colors.append(Color.WHITE);surface.uv.append(Vector2(h,0));surface.uv2.append(at)
 assert(surface.vertices.size()==roots.size()*source.size())
 grass.mesh=surface.mesh()
 return {'roots':roots,'uploaded_vertices':surface.vertices.size(),'source_vertices_per_fan':source.size(),'max_support_error':maximum_error,'skipped':skipped,'scope':'Root support on actual triangles and same production field; complete source leaves retained. Not every blade tip or arbitrary edits.'}
func capture_views(stage:String):
 await capture(stage,'close',Vector3(9,7.6,15),Vector3(0,-.2,0),11.8)
 await capture(stage,'grass',Vector3(5,8,12),Vector3(0,1.5,1),8.0)
 await capture(stage,'whole',Vector3(13,13,19),Vector3(0,-.2,0),18.5)
 await capture(stage,'reverse',Vector3(-13,8,-14),Vector3(0,-.2,0),14.0)
 await capture(stage,'bottom',Vector3(9,-8,15),Vector3(0,-.8,0),13.0)
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/master_mantle/'
 WORK='res://art/work/master_mantle/2026-10-18/'
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
   reports['carve_operation']={'center':str(at),'changed':count,'radius':1.1,'scope':'Public operation on actual field, below shallow soil.'}
  body.mesh=tagged_mesh(data);body.material_override=finish if stage in ['contact','carved'] else neutral
  grass.visible=stage in ['contact','carved'];var leaves_report:Dictionary=contact_leaves(data) if grass.visible else {}
  var values:PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  FileAccess.open(WORK+stage+'.bin',FileAccess.WRITE).store_buffer(values.to_byte_array())
  FileAccess.open(WORK+stage+'.layout',FileAccess.WRITE).store_string(JSON.stringify(data.serialize(),'\t',true,true))
  reports[stage]={'triangles':values.size()/3,'records':data.rocks.samples.size(),'cells':data.cells.size(),'contact':leaves_report,'layout_hash':JSON.stringify(data.serialize()).sha256_text()}
  await capture_views(stage)
  if stage=='carved':
   var edited:Dictionary=data.serialize();assert(data.undo() and data.serialize()==before);assert(data.redo() and data.serialize()==edited)
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'frames':frames,'stages':reports,'source_points_sha256':FileAccess.get_sha256(WORK+'master_source.bin'),'scope':'Source-defined strip experiment, uniform11m width, one .25m field including physical soil and body. Source-derived dry cells are not a cell-driven PCG compiler. No formal editor/default/target-device/full-art acceptance.'},'\t',true,true))
 print('MASTER MANTLE NATIVE: ',frames.size(),' frames');quit()
