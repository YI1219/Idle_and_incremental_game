extends SceneTree
## Every published bed vertex carries its own authoritative water level.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Field=preload('res://scripts/terrain_editor/contour_terrain.gd')
var failures:=0
func _initialize()->void:call_deferred('run')
func inspect(vertices:PackedVector3Array,colors:PackedColorArray,levels:Array,label:String,regions:Dictionary)->void:
 var bad:=0
 for i in vertices.size():
  var level:=roundf(colors[i].r*255.0)*.5
  if not levels.has(level) or vertices[i].y>level+.0002:bad+=1
  if i%3==0:
   var center:Vector3=(vertices[i]+vertices[i+1]+vertices[i+2])/3.0
   var own_levels:Array=[]
   for own:int in regions:
    if Field.contains(regions[own],Vector2(center.x,center.z)):own_levels.append(own*.5)
   if not own_levels.is_empty() and not own_levels.has(level):bad+=1
 failures+=bad
 print('BED LIGHT LEVEL ',label,': vertices=',vertices.size(),' invalid=',bad)
func run()->void:
 var data:=Data.new();data.make_preset(0)
 var field:=Field.new();field.refresh(data)
 inspect(field.surfaces.lake_bed.vertices,field.surfaces.lake_bed.colors,[1.5,3.5],'raw',field.water_regions)
 for chunk:Vector2i in field.triangle_chunks:
  var mesh:Mesh=field.build(chunk).lake_bed
  if mesh.get_surface_count():
   var arrays:=mesh.surface_get_arrays(0)
   inspect(arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_COLOR],[1.5,3.5],'published'+str(chunk),field.water_regions)
 # All permitted water levels survive color encoding and GPU mesh upload.
 var pond:=Data.new()
 for z in range(-1,5):
  for x in range(-1,5):
   var wet:=x>=0 and x<4 and z>=0 and z<4
   pond.cells[Vector2i(x,z)]={'height':-4.0 if wet else 4.0,'water':0 if wet else -1}
 for level in 8:
  pond.begin_stroke();pond.apply_brush(Vector2(2,2),2.5,'water',false,0.0,level);pond.end_stroke()
  field.refresh(pond)
  inspect(field.surfaces.lake_bed.vertices,field.surfaces.lake_bed.colors,[level*.5],'water edit'+str(level),field.water_regions)
  for chunk:Vector2i in field.triangle_chunks:
   var mesh:Mesh=field.build(chunk).lake_bed
   if mesh.get_surface_count():
    var arrays:=mesh.surface_get_arrays(0)
    inspect(arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_COLOR],[level*.5],'uploaded edit'+str(level),field.water_regions)
 quit(1 if failures else 0)
