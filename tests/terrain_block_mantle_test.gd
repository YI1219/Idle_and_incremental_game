extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Mantle=preload("res://scripts/terrain_editor/block_mantle.gd")
func _initialize():call_deferred("run")
func run():
 var data:=Data.new();data.make_preset(0);var field:=Field.new();field.refresh(data)
 var start:=Time.get_ticks_msec();var result:=Mantle.build(field.surfaces.cliff)
 var failed:=[];var triangles:=0;var minimum_volume:=INF
 for body:Dictionary in result.bodies:
  var surface=body.surface;var edges:Dictionary={};var volume:=0.0
  for i in range(0,surface.vertices.size(),3):
   var a:Vector3=surface.vertices[i];var b:Vector3=surface.vertices[i+1];var c:Vector3=surface.vertices[i+2]
   volume-=a.dot(b.cross(c))/6.0
   for j in 3:
    var p:=Vector3i((surface.vertices[i+j]*10000).round());var q:=Vector3i((surface.vertices[i+(j+1)%3]*10000).round())
    var key:Array=[p,q] if p<q else [q,p]
    edges[key]=edges.get(key,0)+1
  var odd:=0
  for uses:int in edges.values():
   if uses%2!=0:odd+=1
  if odd>0 or volume<=.001:failed.append({"key":str(body.key),"open_edges":odd,"volume":volume})
  minimum_volume=minf(minimum_volume,volume);triangles+=surface.vertices.size()/3
 var ok:bool=not result.bodies.is_empty() and failed.is_empty()
 print("BLOCK MANTLE: ",JSON.stringify({"bodies":result.bodies.size(),"triangles":triangles,"minimum_volume":minimum_volume,"build_ms":Time.get_ticks_msec()-start,"failed":failed,"passed":ok}))
 quit(0 if ok else 1)
