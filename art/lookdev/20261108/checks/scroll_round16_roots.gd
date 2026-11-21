extends SceneTree
const Shard = preload("res://scripts/terrain_editor/procedural_shard.gd")
func _initialize() -> void:
 var failures: int = 0
 for seed_value: int in [88,97,106,115]:
  var built: Dictionary = Shard.build(seed_value,true)
  var mesh: ArrayMesh = built.mesh
  var arrays: Array = mesh.surface_get_arrays(0)
  var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
  var edges: Dictionary = {}
  var oriented: Dictionary = {}
  var degenerate: int = 0
  var normal_bad: int = 0
  var volume: float = 0.0
  var minimum_area: float = INF
  for i in range(0,points.size(),3):
   var cross: Vector3 = -(points[i+1]-points[i]).cross(points[i+2]-points[i])
   minimum_area = minf(minimum_area,cross.length()*0.5)
   if cross.length_squared()<1e-8: degenerate+=1
   if cross.normalized().dot(normals[i])<0.999: normal_bad+=1
   volume -= points[i].dot(points[i+1].cross(points[i+2]))/6.0
   for j in 3:
    var a := str(Vector3i((points[i+j]*100000.0).round()))
    var b := str(Vector3i((points[i+(j+1)%3]*100000.0).round()))
    var key: String = a+"/"+b if a<b else b+"/"+a
    edges[key] = int(edges.get(key,0))+1
    oriented[key] = int(oriented.get(key,0))+(1 if a<b else -1)
  var nonmanifold: int = 0
  var winding_bad: int = 0
  for key: String in edges:
   if edges[key]!=2: nonmanifold+=1
   if oriented[key]!=0: winding_bad+=1
  var box: AABB = mesh.get_aabb()
  var max_y: float = box.end.y
  var cap_error: float = 0.0
  var cap_area: float = 0.0
  var cap_hull: PackedVector2Array = PackedVector2Array()
  var body_plane_error: float = 0.0
  var cap_start: int = points.size()-27
  var cap_plane := Plane(points[cap_start],points[cap_start+1],points[cap_start+2])
  for j in range(cap_start,points.size()):
   cap_error=maxf(cap_error,absf(cap_plane.distance_to(points[j])))
   var p2:=Vector2(points[j].x,points[j].z)
   if not cap_hull.has(p2):cap_hull.append(p2)
  for j in range(cap_start,points.size(),3):
   var cn: Vector3=-(points[j+1]-points[j]).cross(points[j+2]-points[j])
   if cn.y<=0:normal_bad+=1
   cap_area+=absf(cn.y)*0.5
  var hull: PackedVector2Array = Geometry2D.convex_hull(cap_hull)
  var hull_area: float = 0.0
  for j in range(hull.size()-1):hull_area+=hull[j].cross(hull[j+1])*0.5
  for j in range(0,108,6):
   var plane:=Plane(points[j],points[j+1],points[j+2])
   for k in 6:body_plane_error=maxf(body_plane_error,absf(plane.distance_to(points[j+k])))
  print("CAP seed=",seed_value," coplanarity=",cap_error," projected_fan_area=",cap_area," hull_area=",absf(hull_area)," body_quad_planarity=",body_plane_error)
  if cap_error>0.00001 or absf(cap_area-absf(hull_area))>0.00001 or body_plane_error>0.00001:failures+=1
  var min_quad_dot: float=1.0
  for j in range(0,108,6):
   var n1:=-(points[j+1]-points[j]).cross(points[j+2]-points[j]).normalized()
   var n2:=-(points[j+4]-points[j+3]).cross(points[j+5]-points[j+3]).normalized()
   min_quad_dot=minf(min_quad_dot,n1.dot(n2))
  print("ROOT_QUADS seed=",seed_value," min_pair_normal_dot=",min_quad_dot)
  if min_quad_dot<=0:failures+=1
  var failed: bool = nonmanifold>0 or winding_bad>0 or degenerate>0 or normal_bad>0 or volume<=0
  if failed: failures+=1
  print("ROOT arch=",seed_value%8," triangles=",points.size()/3," box=",box," max_y=",max_y," min_area=",minimum_area," volume=",volume," nonmanifold=",nonmanifold," winding=",winding_bad," degenerate=",degenerate," normals=",normal_bad)
 print("ROOT_ROUND16 failures=",failures)
 quit(1 if failures else 0)
