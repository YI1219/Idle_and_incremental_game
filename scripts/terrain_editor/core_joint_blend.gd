extends RefCounted
## Source-derived, bounded shoulder-to-core connection. No extra rock objects.
const VERSION:int=1
const MAX_EXPANSION:float=1.4

static func _first_hit(faces:PackedVector3Array,origin:Vector3,direction:Vector3)->float:
 var result:float=INF
 for i:int in range(0,faces.size(),3):
  if origin.y<minf(faces[i].y,minf(faces[i+1].y,faces[i+2].y)) or origin.y>maxf(faces[i].y,maxf(faces[i+1].y,faces[i+2].y)):continue
  var hit=Geometry3D.ray_intersects_triangle(origin,direction,faces[i],faces[i+1],faces[i+2])
  if hit!=null:result=minf(result,origin.distance_to(hit))
 return result

static func _faces(mesh:Mesh,pose:Transform3D)->PackedVector3Array:
 var faces:=PackedVector3Array()
 for s:int in mesh.get_surface_count():
  var arrays:Array=mesh.surface_get_arrays(s)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var indices:=PackedInt32Array()
  if arrays[Mesh.ARRAY_INDEX]!=null:indices=arrays[Mesh.ARRAY_INDEX]
  if indices.is_empty():
   for p:Vector3 in vertices:faces.append(pose*p)
  else:
   for i:int in indices:faces.append(pose*vertices[i])
 return faces

static func guides_for(surface,field,columns:Array,assets:Dictionary)->Array[Dictionary]:
 var guides:Array[Dictionary]=[]
 for col:Dictionary in columns:
  var out:Vector3=col.outward
  var profile:Dictionary=field._cliff_profile(col.edge,Vector2(out.x,out.z))
  if not profile.base:continue
  var mesh:Mesh=assets[col.kind][0].mesh
  var faces:PackedVector3Array=_faces(mesh,col.pose)
  var bounds:AABB=col.pose*mesh.get_aabb()
  var y:float=lerpf(col.pose.origin.y,bounds.position.y,.85)
  var origin:=Vector3(col.edge.x,y,col.edge.y)+out*12.0
  var a:float=_first_hit(faces,origin,-out)
  var b:float=_first_hit(surface.vertices,origin,-out)
  # Reject rays that only encounter the far side of the island. An already
  # buried foot needs no new expansion at this cross section.
  if not is_finite(a) or not is_finite(b) or absf(12.0-b)>4.0 or b-a<=.08:continue
  var lo:float=INF;var hi:float=-INF
  for p:Vector3 in faces:
   var along:float=p.dot(col.tangent)
   lo=minf(lo,along);hi=maxf(hi,along)
  var width:float=hi-lo
  guides.append({'point':origin-out*b,'out':out,'tangent':col.tangent,'width':width,'delta':minf(b-a-.08,minf(MAX_EXPANSION,width*.3))})
 return guides

static func deform(point:Vector3,guides:Array,veils:Array)->Vector3:
 var delta:=Vector3.ZERO
 var weight_sum:float=0.0
 for guide:Dictionary in guides:
  var offset:Vector3=point-guide.point
  var along:float=absf(offset.dot(guide.tangent))
  var across:float=absf(offset.dot(guide.out))
  var width:float=maxf(1.0,guide.width)
  var weight:float=1.0-smoothstep(width*.25,width*.65,along)
  weight*=1.0-smoothstep(.8,2.5,across)
  weight*=1.0-smoothstep(guide.point.y+.3,guide.point.y+1.2,point.y)
  weight*=smoothstep(guide.point.y-2.2,guide.point.y-.4,point.y)
  delta+=guide.out*guide.delta*weight
  weight_sum+=weight
 delta/=maxf(1.0,weight_sum)
 var clearance:float=1.0
 for veil:Dictionary in veils:
  if point.y>veil.lip.y+.1 or point.y<veil.foot.y-.1:continue
  var out:=Vector3(veil.out.x,0,veil.out.y)
  var offset:Vector3=point-veil.lip
  if absf(offset.dot(out))>3.0:continue
  var tangent:=Vector3(out.z,0,-out.x)
  clearance=minf(clearance,smoothstep(veil.half_width+.45,veil.half_width+1.15,absf(offset.dot(tangent))))
 return point+delta*clearance

static func apply(surface,field,columns:Array,assets:Dictionary)->Dictionary:
 var started:int=Time.get_ticks_usec()
 var guides:Array[Dictionary]=guides_for(surface,field,columns,assets)
 var cache:Dictionary={};var changed:int=0;var maximum:float=0.0
 for i:int in surface.vertices.size():
  var p:Vector3=surface.vertices[i]
  if not cache.has(p):cache[p]=deform(p,guides,field.fall_veils)
  var q:Vector3=cache[p]
  if p!=q:changed+=1;maximum=maxf(maximum,p.distance_to(q))
  surface.vertices[i]=q
 return {'version':VERSION,'guides':guides.size(),'changed_vertices':changed,'maximum_expansion':maximum,'build_ms':(Time.get_ticks_usec()-started)/1000.0}
