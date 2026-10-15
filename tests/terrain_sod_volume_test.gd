extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
var failures:=0
func _initialize():call_deferred("run")
func run():
 var data:=Data.new();data.make_preset(0);var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco.assets.erase("grass");deco._column_layout(field,data.seed)
 # Isolate the solid root cuff. Curved source leaf tips legitimately turn down.
 var cover=field.surfaces.rim_green;var above:=0;var inward:=0;var invalid:=0
 for i in range(0,cover.vertices.size(),3):
  var a:Vector3=cover.vertices[i];var b:Vector3=cover.vertices[i+1];var c:Vector3=cover.vertices[i+2]
  var normal:=-(b-a).cross(c-a).normalized();var h:float=cover.uv[i].x
  # A crown above the lawn exposes its top, not a downward-facing back skin.
  # Buried underside triangles are allowed below the actual ground plane.
  if minf(a.y,minf(b.y,c.y))>h+.002:
   above+=1
   if normal.y<-.05:inward+=1
  for j in 3:
   var n:Vector3=cover.normals[i+j]
   if not n.is_finite() or absf(n.length()-1.0)>.002:invalid+=1
 if above==0 or inward>0 or invalid>0:
  failures+=1;push_error("Exposed sod top is inverted or normals invalid")
 print("SOD VOLUME: exposed top triangles=",above," inverted=",inward," invalid normals=",invalid," failures=",failures)
 quit(1 if failures else 0)
