extends RefCounted
## Seat retained shore meshes in the actual authored bank/bed triangles.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')

static func height_at(field,p:Vector2,water_y:float)->float:
 var height:=-INF
 var chunk:=Data.chunk_of(Vector2i(p.floor()))
 for kind in ['grass','shore','lake_bed']:
  var vertices:PackedVector3Array=field.surfaces[kind].vertices
  for i:int in field.triangle_chunks.get(chunk,{}).get(kind,[]):
   var hit=Geometry3D.ray_intersects_triangle(Vector3(p.x,water_y+.2,p.y),Vector3.DOWN,vertices[i],vertices[i+1],vertices[i+2])
   if hit!=null:height=maxf(height,hit.y)
 return height

static func seat(field,mesh:Mesh,pose:Transform3D,water_y:float)->Dictionary:
 var faces:=mesh.get_faces();var lo:=INF;var hi:=-INF
 for i in faces.size():
  faces[i]=pose*faces[i];lo=minf(lo,faces[i].y);hi=maxf(hi,faces[i].y)
 # Bury the lower third rather than resting a pinched foot on the lawn.
 # The water-facing side may overhang, provided its landward flank is rooted.
 var section:=lo+(hi-lo)*.30
 var lowering:=0.0;var contacts:=0;var seen:Dictionary={}
 for i in range(0,faces.size(),3):
  for j in 3:
   var a:=faces[i+j];var b:=faces[i+(j+1)%3]
   if (a.y-section)*(b.y-section)>=0.0:continue
   var point:=a.lerp(b,(section-a.y)/(b.y-a.y));var p:=Vector2(point.x,point.z)
   var land:Dictionary=field.surface_at(p)
   if land.is_empty() or land.water>=0 or absf(land.height-water_y)>.15:continue
   var key:=p.snapped(Vector2.ONE*.001)
   if seen.has(key):continue
   seen[key]=true
   var ground:=height_at(field,p,water_y)
   if ground==-INF:return {}
   lowering=minf(lowering,ground-section-.035);contacts+=1
 if contacts==0:
  # Fully submerged accents follow the real shallow bed. A fixed water-level
  # offset left small stones visibly suspended above its sloping mineral floor.
  var p:=Vector2(pose.origin.x,pose.origin.z)
  var ground:=height_at(field,p,water_y)
  if ground==-INF:return {}
  var bottom:=INF
  for i in range(0,faces.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(Vector3(p.x,water_y+.2,p.y),Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
   if hit!=null:bottom=minf(bottom,hit.y)
  if bottom==INF:return {}
  lowering=minf(lowering,ground-bottom-.025)
 pose.origin.y+=lowering
 return {'pose':pose}
