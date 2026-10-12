extends SceneTree
const Stone=preload('res://scripts/terrain_editor/procedural_stone.gd')
func section(mesh:Mesh,y:float)->float:
 var faces:=mesh.get_faces();var points:=PackedVector2Array()
 for i in range(0,faces.size(),3):
  for j in 3:
   var a:Vector3=faces[i+j];var b:Vector3=faces[i+(j+1)%3]
   if absf(a.y-y)<.00001:points.append(Vector2(a.x,a.z))
   if (a.y-y)*(b.y-y)<0:
    var p:=a.lerp(b,(y-a.y)/(b.y-a.y));points.append(Vector2(p.x,p.z))
 var hull:=Geometry2D.convex_hull(points);var area:=0.0
 for i in hull.size()-1:area+=hull[i].cross(hull[i+1])*.5
 return absf(area)
func _initialize():
 var failures:=0;var ratios:=[]
 for seed_value in [11,29,47,71]:
  var built:=Stone.build(seed_value);var top:=section(built.mesh,0);var shoulder:=section(built.mesh,-.12)
  var ratio:=shoulder/maxf(top,.001);ratios.append(ratio)
  if ratio>1.06 or ratio<.95:failures+=1
 print('STONE SHOULDERS: area ratios=',ratios,', failures=',failures)
 quit(0 if failures==0 else 1)
