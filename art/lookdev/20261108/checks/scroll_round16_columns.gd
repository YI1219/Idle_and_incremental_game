extends SceneTree
const Shard = preload("res://scripts/terrain_editor/procedural_shard.gd")
func _initialize() -> void:
 var failures: int=0
 for seed_value: int in [16,25,34,43,52,61,70,79]:
  var built: Dictionary=Shard.build(seed_value)
  for label: String in ["mesh","render_mesh"]:
   var mesh: ArrayMesh=built[label]
   var arrays: Array=mesh.surface_get_arrays(0)
   var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   var edges: Dictionary={}
   var balance: Dictionary={}
   var edge_high: Dictionary={}
   var degenerate: int=0
   var normals_bad: int=0
   var volume: float=0.0
   for i in range(0,points.size(),3):
    var cn: Vector3=-(points[i+1]-points[i]).cross(points[i+2]-points[i])
    if cn.length_squared()<1e-8:degenerate+=1
    if cn.normalized().dot(normals[i])<=0.0:normals_bad+=1
    volume-=points[i].dot(points[i+1].cross(points[i+2]))/6.0
    for j in 3:
     var a:=str(Vector3i((points[i+j]*100000.0).round()))
     var b:=str(Vector3i((points[i+(j+1)%3]*100000.0).round()))
     var key: String=a+"/"+b if a<b else b+"/"+a
     edges[key]=int(edges.get(key,0))+1
     balance[key]=int(balance.get(key,0))+(1 if a<b else -1)
     edge_high[key]=maxf(absf(points[i+j].y),absf(points[i+(j+1)%3].y))
   var open_edges: int=0
   var bad_edges: int=0
   for key: String in edges:
    if edges[key]==1:
     open_edges+=1
     if label=="mesh" or edge_high[key]>0.00001:bad_edges+=1
    elif edges[key]!=2 or balance[key]!=0:bad_edges+=1
   var planar_error: float=0.0
   var min_quad_dot: float=1.0
   var starts: Array[int]=[]
   if label=="mesh":
    for i in 9:starts.append((i*3+1)*3)
    for i in 27:starts.append(81+i*6)
   else:
    for i in 36:starts.append(i*6)
   for i: int in starts:
    var n1:=-(points[i+1]-points[i]).cross(points[i+2]-points[i]).normalized()
    var n2:=-(points[i+4]-points[i+3]).cross(points[i+5]-points[i+3]).normalized()
    min_quad_dot=minf(min_quad_dot,n1.dot(n2))
   var body_start: int=135 if label=="mesh" else 108
   for i in range(body_start,body_start+108,6):
    var plane:=Plane(points[i],points[i+1],points[i+2])
    for k in 6:planar_error=maxf(planar_error,absf(plane.distance_to(points[i+k])))
   var box: AABB=mesh.get_aabb()
   var expected_open: int=0 if label=="mesh" else 9
   var failed: bool=bad_edges>0 or open_edges!=expected_open or degenerate>0 or normals_bad>0 or min_quad_dot<=0 or planar_error>0.00001 or box.end.y>0.00001 or volume<=0
   if failed:failures+=1
   print("COLUMN seed=",seed_value," part=",label," tris=",points.size()/3," open=",open_edges," bad_edges=",bad_edges," degenerate=",degenerate," normal_bad=",normals_bad," min_quad_normal_dot=",min_quad_dot," broad_plane_error=",planar_error," volume=",volume," box=",box)
 print("ROUND16_COLUMNS failures=",failures)
 quit(1 if failures else 0)
