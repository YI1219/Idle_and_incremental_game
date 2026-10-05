extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
var failures:=0
func _initialize()->void:call_deferred("run")
func run()->void:
 var data:=Data.new();data.make_preset(0)
 var field:=Contours.new();field.refresh(data)
 var faces:PackedVector3Array=field.surfaces.cliff.vertices
 var samples:=0;var shoulders:=0;var joins:=0
 # The reference has upper outer walls next to the lower terrace. Their base
 # taper must not suppress every physical shoulder above that terrace.
 for key:Vector4 in field._profiles:
  var profile:Dictionary=field._profiles[key]
  var p:=Vector2(key.x,key.y);var n:=Vector2(key.z,key.w)
  var high:float=field.surface_at(p-n*.25).get("height",profile.top)
  if high<profile.top+.9 or not profile.base or profile.inset<=.8 or profile.water>=0:continue
  var y:float=(high+profile.top)*.5
  var origin:=Vector3(p.x+n.x*3,y,p.y+n.y*3)
  var direction:=Vector3(-n.x,0,-n.y)
  var nearest:=INF
  for i in range(0,faces.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(origin,direction,faces[i],faces[i+1],faces[i+2])
   if hit!=null:nearest=minf(nearest,origin.distance_to(hit))
  samples+=1
  if nearest<2.96:shoulders+=1
  # Both exact terrace heights stay on the shared cap boundary, preventing
  # the slit seen when a single envelope continued across the lower join.
  for h:float in [high,profile.top]:
   # A lower contour may extend beyond the upper one. Only test an
   # actual contour join at this height, not a projected absent cap.
   var contour_distance:=INF
   for loop:PackedVector2Array in field.land_regions[h]:
    for i in loop.size():
     contour_distance=minf(contour_distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,loop[i],loop[(i+1)%loop.size()])))
   if contour_distance>.0001:continue
   var expected:=Vector3(p.x,h,p.y)
   var distance:=INF
   for point:Vector3 in faces:distance=minf(distance,expected.distance_to(point))
   joins+=1
   if distance>.0001:
    failures+=1;push_error("Cliff/cap join separated at %s by %s"%[expected,distance])
 if samples<10 or shoulders<5:
  failures+=1;push_error("Upper outer rock shoulders suppressed: %d of %d ray samples"%[shoulders,samples])
 if joins<20:
  failures+=1;push_error("Insufficient actual contour join coverage")
 print("TERRAIN UPPER ROCK: %d rays, %d shoulders, %d nearby join vertices, %d failures"%[samples,shoulders,joins,failures])
 quit(1 if failures else 0)
