extends SceneTree
const Stone=preload("res://scripts/terrain_editor/procedural_stone.gd")
var failures:=0
var count:=0
func _initialize():call_deferred("run")
func run():
 for root in [false,true]:
  for seed_value in [11,23,37,41,53,67,101,203]:
   var stone:Dictionary=Stone.build(seed_value,root)
   var faces:PackedVector3Array=stone.mesh.get_faces()
   var edges:Dictionary={};var volume:=0.0
   for i in range(0,faces.size(),3):
    volume-=faces[i].dot(faces[i+1].cross(faces[i+2]))/6.0
    for j in 3:
     var a:=faces[i+j];var b:=faces[i+(j+1)%3]
     var key:Array=[a,b] if a<b else [b,a]
     edges[key]=edges.get(key,0)+1
   var closed:=true
   for uses:int in edges.values():
    if uses!=2:closed=false
   count+=2
   if not closed:failures+=1;push_error("Open procedural stone "+str([root,seed_value]))
   if volume<=.08:failures+=1;push_error("Stone lacks outward closed volume "+str([root,seed_value,volume]))
   var arrays:Array=stone.mesh.surface_get_arrays(0)
   var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var norms:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
   var flipped:=0
   var concave:=0
   var worst:=0.0
   for i in range(0,verts.size(),3):
    var a:Vector3=verts[i];var b:Vector3=verts[i+1];var c:Vector3=verts[i+2]
    var raw:Vector3=(b-a).cross(c-a)
    if raw.length_squared()<1e-12:continue
    var outward:Vector3=(-raw).normalized()
    if outward.dot(norms[i])<.98:flipped+=1
    if root:continue
    var face_worst:=0.0
    for v:Vector3 in verts:
     face_worst=maxf(face_worst,outward.dot(v-a))
    worst=maxf(worst,face_worst)
    if face_worst>.012:concave+=1
   count+=2
   if flipped>0:failures+=1;push_error("Outer facet normal is flipped "+str([root,seed_value,flipped]))
   if concave>0:failures+=1;push_error("Crown face folds inward "+str([seed_value,concave,worst]))
   if root:
    var top:=PackedVector2Array();var bottom:=PackedVector2Array()
    for p:Vector3 in faces:
     if p.y>-.2:top.append(Vector2(p.x,p.z))
     if p.y<-stone.height*.85:bottom.append(Vector2(p.x,p.z))
    count+=1
    # An inward-leaning root translates its lower section. Compare section
    # areas, so translation cannot be mistaken for an outward flare.
    if hull_area(bottom)>=hull_area(top)*.65:failures+=1;push_error("Underside cross-section must taper inward")
 print("STONE VOLUMES: ",count-failures,"/",count)
 quit(1 if failures else 0)

func hull_area(points:PackedVector2Array)->float:
 var hull:=Geometry2D.convex_hull(points);var area:=0.0
 for i in hull.size()-1:area+=hull[i].cross(hull[i+1])*.5
 return absf(area)
