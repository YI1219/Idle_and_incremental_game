extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration=preload("res://scripts/terrain_editor/terrain_decoration.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func top_spans(width:float)->Array:
 var result:Array=[]
 for run:Array in Decoration._runs(PackedVector2Array([Vector2.ZERO,Vector2(width,0),Vector2(width,8),Vector2(0,8)])):
  if absf(run[0].y)<.001 and absf(run[1].y)<.001:result.append(run[0].distance_to(run[1]))
 return result
func run():
 var small:=top_spans(6.0)
 var grown:=top_spans(7.0)
 var split:=top_spans(10.0)
 check(small.size()==grown.size() and not small.is_empty() and grown[0]>small[0],"expansion grows existing rim spans before splitting")
 check(split.size()>grown.size(),"oversize contour divides into more stones")
 check(top_spans(6.0).size()<split.size(),"contraction merges spans back into fewer stones")
 for width in [6.0,7.0,10.0,22.0]:
  for span:float in top_spans(width):check(span>=1.5 and span<=4.2,"stone span stays between 1.5 and 4.2 metres")
 var data:=Data.new();data.make_preset(0)
 var field:=Contours.new();field.refresh(data)
 var deco:=Decoration.new();deco.load_assets();deco._column_layout(field,data.seed)
 check(deco._columns.size()>20,"default terrain has independent rim crowns")
 check(deco._mass.size()>20,"underside has its own inward-tapering stone system")
 var mirrored:=0;var tall:=0
 for stone:Dictionary in deco._columns:
  if stone.pose.basis.determinant()<=0:mirrored+=1
  var box:AABB=stone.pose*deco.assets[stone.kind][0].mesh.get_aabb()
  if box.size.y>maxf(box.size.x,box.size.z)*1.3:tall+=1
 check(mirrored==0,"rim stones preserve outward winding")
 check(tall==0,"crown bodies remain broad rather than full-height columns")
 # A real two-height terrace: both calls have the same centre and seed.
 # Growing a span must resize the actual crown, not only change bookkeeping.
 var terrace:=Data.new()
 for z in range(-6,6):
  for x in range(-10,10):terrace.cells[Vector2i(x,z)]={"height":3.5 if z>=0 else 1.5,"water":-1}
 var step_field:=Contours.new();step_field.refresh(terrace)
 var widths:Array=[]
 for length in [2.0,3.6]:
  deco._columns.clear()
  var a:=Vector2(-length*.5,0);var b:=Vector2(length*.5,0)
  deco._rim_run(step_field,a,b,PackedVector2Array([a,b]),3.5,terrace.seed)
  check(deco._columns.size()==1,"terrace fixture has a crown")
  if deco._columns.size()==1:widths.append(deco._columns[0].pose.basis.x.length())
 check(widths.size()==2 and widths[1]>widths[0]*1.4,"actual terrace crown grows with its span")
 # Fracture relief may protrude beyond the normalized source box. Contact
 # lookup must include the spatial bucket containing that actual vertex.
 for kind in Decoration.BODY_KINDS:
  var box:AABB=deco.assets[kind][0].mesh.get_aabb()
  if box.end.x<=.5001:continue
  deco._columns.clear();deco._column_cells.clear()
  deco._columns.append({"kind":kind,"pose":Transform3D(Basis.IDENTITY,Vector3(2.001-box.end.x,0,0))})
  deco._bucket_column(0)
  check(deco._column_cells.get(Vector2i(1,0),[]).has(0),"spatial contact includes protruding fracture")
 print("RIM SYSTEMS: ",checks-failures,"/",checks," passed")
 quit(1 if failures else 0)
