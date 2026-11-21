extends SceneTree
const Shard=preload("res://scripts/terrain_editor/procedural_shard.gd")
const Before=preload("res://art/lookdev/20261110_sol61_polish/checks/source_before/scripts__terrain_editor__procedural_shard.gd")
var failures:int=0
var checks:int=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
 else:print("ok: ",message)
func key(p:Vector3)->String:
 return str(Vector3i((p*100000.0).round()))
func crown(mesh:Mesh)->Dictionary:
 var found:Dictionary={}
 for p:Vector3 in mesh.get_faces():
  if absf(p.y)<.000001:found[key(p)]=true
 return found
func _initialize()->void:
 for i:int in 8:
  var seed_value:int=16+i*9
  var built:Dictionary=Shard.build(seed_value)
  var old:Dictionary=Before.build(seed_value)
  check(crown(built.mesh)==crown(old.mesh) and built.cap_polygon==old.cap_polygon,"variant %d preserves y=0 crown and cap polygon"%i)
  var faces:PackedVector3Array=built.mesh.get_faces()
  var planar:bool=true
  var worst_angle:float=0.0
  # Nine cap triangles and nine collar quads precede the three body bands.
  var lower_start:int=27*3+2*9*6
  for quad:int in 9:
   var offset:int=lower_start+quad*6
   var n0:Vector3=(faces[offset+1]-faces[offset]).cross(faces[offset+2]-faces[offset]).normalized()
   var n1:Vector3=(faces[offset+4]-faces[offset+3]).cross(faces[offset+5]-faces[offset+3]).normalized()
   worst_angle=maxf(worst_angle,rad_to_deg(n0.angle_to(n1)))
   planar=planar and n0.dot(n1)>cos(deg_to_rad(1.0))
  check(planar,"variant %d lower broad planes stay coplanar (worst %.3f degrees)"%[i,worst_angle])
  var edges:Dictionary={}
  var finite:bool=true
  for j:int in range(0,faces.size(),3):
   for k:int in 3:
    var a:Vector3=faces[j+k];var b:Vector3=faces[j+(k+1)%3]
    finite=finite and a.is_finite() and (faces[j+1]-faces[j]).cross(faces[j+2]-faces[j]).length_squared()>.0000000001
    var ka:String=key(a);var kb:String=key(b);var edge:String=ka+"|"+kb if ka<kb else kb+"|"+ka
    edges[edge]=int(edges.get(edge,0))+1
  var closed:bool=true
  for count:int in edges.values():closed=closed and count==2
  check(finite and closed,"variant %d is finite, nondegenerate and watertight"%i)
 print("CLIFF GEOMETRY: %d checks, %d failures"%[checks,failures])
 quit(1 if failures>0 else 0)
