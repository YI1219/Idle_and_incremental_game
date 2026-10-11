extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
func _initialize():call_deferred("run")
func run():
 var data:=Data.new();data.make_preset(0);var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco._column_layout(field,data.seed)
 var ok:=field.surfaces.has("rim_green")
 if not ok:push_error("No attached overhanging green lip geometry");quit(1);return
 var lip=field.surfaces.rim_green
 var low:=0;var anchored:=0;var depths:Dictionary={}
 for i in lip.vertices.size():
  var depth:float=lip.uv[i].x-lip.vertices[i].y
  if depth>.12:low+=1
  if absf(depth)<.02:anchored+=1
  depths[snappedf(depth,.05)]=true
  ok=ok and depth<.85 and depth>-.02
 ok=ok and low>50 and anchored>50 and depths.size()>5
 var uploaded:=0
 for chunk:Vector2i in field.triangle_chunks:
  var mesh:ArrayMesh=field.build(chunk).rim_green
  if mesh.get_surface_count()==0:continue
  var arrays:=mesh.surface_get_arrays(0)
  var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var anchors:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
  for i in positions.size():
   # World anchors must survive GPU mesh upload, including negatives/>1.
   if Vector2(positions[i].x,positions[i].z).distance_to(anchors[i])>=1.0:
    ok=false;print("bad anchor ",positions[i],anchors[i])
   if anchors[i].x<0 or anchors[i].y>1:uploaded+=1
 ok=ok and uploaded>100
 print("RIM DETAIL: hanging vertices=",low," anchors=",anchored," depth bands=",depths.size()," passed=",ok)
 quit(0 if ok else 1)
