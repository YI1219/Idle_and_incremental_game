extends RefCounted
## Seat dry props after sculpting changes a cap's real support footprint.
## Separate from shore rocks, whose wet side may deliberately overhang.
static func seat(field,mesh:Mesh,pose:Transform3D)->Dictionary:
 var faces:=mesh.get_faces();var lo:=INF;var hi:=-INF
 for i in faces.size():
  faces[i]=pose*faces[i];lo=minf(lo,faces[i].y);hi=maxf(hi,faces[i].y)
 if not is_finite(lo) or hi<=lo:return {}
 var section:=lo+(hi-lo)*.30
 var lowering:=0.0;var seen:Dictionary={}
 for i in range(0,faces.size(),3):
  for j in 3:
   var a:=faces[i+j];var b:=faces[i+(j+1)%3]
   if (a.y-section)*(b.y-section)>=0:continue
   var point:=a.lerp(b,(section-a.y)/(b.y-a.y));var at:=Vector2(point.x,point.z)
   var key:=at.snapped(Vector2.ONE*.001)
   if seen.has(key):continue
   seen[key]=true
   var ground:Dictionary=field.surface_at(at)
   if ground.is_empty() or ground.water>=0:return {}
   lowering=minf(lowering,ground.height-section-.03)
 # A big drop should remove a small lawn prop, not sink it through a cliff.
 if seen.is_empty() or lowering<-(hi-lo)*.45:return {}
 pose.origin.y+=lowering
 return {'pose':pose}
