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
   if root:
    var top:=0.0;var bottom:=0.0
    for p:Vector3 in faces:
     if p.y>-.2:top=maxf(top,Vector2(p.x,p.z).length())
     if p.y<-stone.height*.85:bottom=maxf(bottom,Vector2(p.x,p.z).length())
    count+=1
    if bottom>=top*.8:failures+=1;push_error("Underside must taper inward")
 print("STONE VOLUMES: ",count-failures,"/",count)
 quit(1 if failures else 0)
