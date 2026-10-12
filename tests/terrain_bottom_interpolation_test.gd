extends SceneTree
const Mantle=preload('res://scripts/terrain_editor/block_mantle.gd')
func _initialize():
 var chains:Array=[[Vector3(-1,-2,-1),Vector3(7,-3,-1),Vector3(7,-4,7),Vector3(-1,-3,7)]]
 var failures:=0;var maximum:=0.0;var count:=0
 for z in range(0,3):
  for x in range(0,3):
   var p:=Vector2(x,z)*2.0
   for points:Array in [[p,p+Vector2(2,0),p+Vector2(2,2)],[p,p+Vector2(2,2),p+Vector2(0,2)]]:
    var cache:Dictionary={}
    var values:=[]
    for q:Vector2 in points:values.append(Mantle._closure_y(q,{},cache,chains))
    for weights:Vector3 in [Vector3(.2,.3,.5),Vector3(.5,.5,0),Vector3(0,.7,.3)]:
     var q:Vector2=points[0]*weights.x+points[1]*weights.y+points[2]*weights.z
     var linear:float=values[0]*weights.x+values[1]*weights.y+values[2]*weights.z
     var error:=absf(Mantle._closure_y(q,{},cache,chains)-linear)
     maximum=maxf(maximum,error);count+=1
     if error>.00001:failures+=1
 print('BOTTOM INTERPOLATION: samples=',count,' errors=',failures,' max=',maximum)
 quit(0 if failures==0 else 1)
