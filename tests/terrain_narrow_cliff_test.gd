extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contour=preload("res://scripts/terrain_editor/contour_terrain.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var data:=Data.new()
 for x in range(24,35):data.cells[Vector2i(x,2)]={"height":1.5,"water":-1}
 var geometry:=Contour.new()
 geometry.refresh(data)
 var faces:PackedVector3Array=geometry.surfaces.cliff.mesh().get_faces()
 var checked:=0
 var failures:=0
 var smallest:=100.0
 # Ray slices test actual opposing triangles, including displaced X and Y.
 # Adding relief without a width limit can reverse their order midway down.
 var lowest:=INF
 for point in faces:lowest=minf(lowest,point.y)
 var first_row:=ceili(lowest*4+.01)
 for xi in range(98,134):
  for yi in range(first_row,6):
   var front:=-INF
   var back:=INF
   var origin:=Vector3(xi*.25,yi*.25,0)
   for i in range(0,faces.size(),3):
    var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
    if origin.x<minf(a.x,minf(b.x,c.x)) or origin.x>maxf(a.x,maxf(b.x,c.x)):continue
    if origin.y<minf(a.y,minf(b.y,c.y)) or origin.y>maxf(a.y,maxf(b.y,c.y)):continue
    var hit=Geometry3D.ray_intersects_triangle(origin,Vector3.BACK,a,b,c)
    if hit==null:continue
    var inward:Vector3=(b-a).cross(c-a)
    if inward.z>0:front=maxf(front,hit.z)
    elif inward.z<0:back=minf(back,hit.z)
   if front==-INF or back==INF:continue
   checked+=1
   smallest=minf(smallest,back-front)
   if front>=back:
    failures+=1
    push_error("Opposing rendered cliff walls overlap at %s: %s >= %s"%[origin,front,back])
 if checked<int(36*(6-first_row)*.85):
  failures+=1
  push_error("Full actual-height narrow-strip sampling did not cover both walls")
 print("TERRAIN NARROW CLIFF: %d slices, %d failures, smallest gap %.4f"%[checked,failures,smallest])
 quit(1 if failures else 0)
