extends RefCounted
## Clip a retained closed stone source into a terrain crown, then close its
## cut with a shared cap. Source faces determine the geological shoulder.
const Surface=preload('res://scripts/terrain_editor/chunk_geometry.gd').Surface
static func build(source:ArrayMesh,height:float=.68,cut_fraction:float=.72)->Dictionary:
 var box:=source.get_aabb()
 var cut:float=box.position.y+box.size.y*cut_fraction
 var cap:Dictionary={};var polygons:Array=[]
 var faces:=source.get_faces()
 for i in range(0,faces.size(),3):
  var input:Array=[faces[i],faces[i+1],faces[i+2]];var polygon:Array=[]
  for j in 3:
   var a:Vector3=input[j];var b:Vector3=input[(j+1)%3]
   if a.y<=cut:polygon.append(a)
   if (a.y<cut and b.y>cut) or (a.y>cut and b.y<cut):
    var p:=a.lerp(b,(cut-a.y)/(b.y-a.y));p.y=cut
    polygon.append(p);cap[Vector2(p.x,p.z).snapped(Vector2.ONE*.000001)]=p
  if polygon.size()>2:polygons.append(polygon)
 var bounds:=AABB(Vector3.ZERO,Vector3.ZERO);var first:=true
 for polygon:Array in polygons:
  for p:Vector3 in polygon:
   if first:bounds=AABB(p,Vector3.ZERO);first=false
   else:bounds=bounds.expand(p)
 var cap_lo:=Vector2(INF,INF);var cap_hi:=-cap_lo
 for p:Vector3 in cap.values():cap_lo=cap_lo.min(Vector2(p.x,p.z));cap_hi=cap_hi.max(Vector2(p.x,p.z))
 var cap_center:=(cap_lo+cap_hi)*.5
 var cap_size:=cap_hi-cap_lo
 var center:=Vector3(cap_center.x,cut,cap_center.y)
 # Placement widths describe the cap that joins the terrain, not the wider
 # body below it. Source shoulders may extend modestly beyond that cap.
 var scale3:=Vector3(1.0/cap_size.x,height/(cut-box.position.y),1.0/cap_size.y)
 var full:=Surface.new();var walls:=Surface.new();var tint:=Color(.66,.66,.66)
 for polygon:Array in polygons:
  for j in range(1,polygon.size()-1):
   var a:Vector3=(polygon[0]-center)*scale3
   var b:Vector3=(polygon[j]-center)*scale3
   var c:Vector3=(polygon[j+1]-center)*scale3
   _triangle(full,a,b,c,tint);_triangle(walls,a,b,c,tint)
 var ring:Array=cap.values();var midpoint:=Vector3.ZERO
 for p:Vector3 in ring:midpoint+=p
 midpoint/=maxi(1,ring.size())
 ring.sort_custom(func(a:Vector3,b:Vector3):return atan2(a.z-midpoint.z,a.x-midpoint.x)<atan2(b.z-midpoint.z,b.x-midpoint.x))
 var crown_z:=0.0
 var cap_polygon:=PackedVector2Array()
 for j in ring.size():
  var a:Vector3=(ring[j]-center)*scale3;a.y=0.0
  var b:Vector3=(ring[(j+1)%ring.size()]-center)*scale3;b.y=0.0
  crown_z=maxf(crown_z,a.z)
  cap_polygon.append(Vector2(a.x,a.z))

 var cap_indices:=Geometry2D.triangulate_polygon(cap_polygon)
 for j in range(0,cap_indices.size(),3):
  var a:=cap_polygon[cap_indices[j]];var b:=cap_polygon[cap_indices[j+1]];var c:=cap_polygon[cap_indices[j+2]]
  _triangle(full,Vector3(a.x,0,a.y),Vector3(b.x,0,b.y),Vector3(c.x,0,c.y),tint,true)
 return {'mesh':full.mesh(),'render_mesh':walls.mesh(),'height':height,'crown_z':crown_z,'span_x':1.0,'span_z':1.0,'cap_polygon':cap_polygon}

static func _triangle(surface,a:Vector3,b:Vector3,c:Vector3,tint:Color,up:bool=false)->void:
 # A plane cut can create very small real faces. The general terrain
 # builder discards them at 1e-8, which would open the closed source here.
 var cross:=-(b-a).cross(c-a)
 if cross.length_squared()<1e-16:return
 var normal:=cross.normalized()
 if up and normal.y<0.0:
  var swap:=b;b=c;c=swap;normal=-normal
 for p:Vector3 in [a,b,c]:
  surface.vertices.append(p);surface.normals.append(normal)
  surface.colors.append(tint);surface.uv.append(Vector2.ZERO)
