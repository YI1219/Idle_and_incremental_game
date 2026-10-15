extends RefCounted
## Exposed bedrock accents assembled from retained stone sources, rooted in
## the editable dry rim. Most boundary spans stay quiet and grassy.
const Paths=preload("res://scripts/terrain_editor/terrain_paths.gd")
const TREES=[Vector2(-16,-3),Vector2(-5,-8),Vector2(6.3,-3.3),Vector2(15.6,2)]

static func clear(p:Vector2)->bool:
 if p.distance_to(Vector2(-11,-7))<3.0:return false
 if p.distance_to(Vector2(11,-2))<2.0 or p.distance_to(Vector2(12.3,-2.5))<1.3:return false
 if p.x> -11 and p.x< -6.5 and p.y> -6.5 and p.y< -2.4:return false
 for tree:Vector2 in TREES:
  if p.distance_to(tree)<1.4:return false
 for i in Paths.POINTS.size()-1:
  if p.distance_to(Geometry2D.get_closest_point_to_segment(p,Paths.POINTS[i],Paths.POINTS[i+1]))<1.6:return false
 return true

static func pose_for(mesh:Mesh,p:Vector2,h:float,size:Vector3,yaw:float,burial:float)->Transform3D:
 var box:=mesh.get_aabb()
 var basis:=Basis(Vector3.UP,yaw)*Basis.from_scale(size/box.size)
 var foot:=Vector3(box.get_center().x,box.position.y,box.get_center().z)
 return Transform3D(basis,Vector3(p.x,h-burial,p.y)-basis*foot)

static func dry_surface(field,p:Vector2,h:float)->bool:
 # The visible rim crown is part of the authoritative contour assembly.
 # It can extend beyond the source-cell contour, but never beyond its final cap.
 if not field.contains(field.rim_regions.get(h,[]),p):return false
 for water:int in field.water_regions:
  if water*.5>=h-.001 and field.contains(field.water_regions[water],p):return false
 var original:Dictionary=field.surface_at(p)
 return original.is_empty() or (original.water<0 and original.height<=h+.01)

static func supported(field,mesh:Mesh,pose:Transform3D,h:float)->bool:
 # Cliff blocks straddle the edge rather than sitting as props on the lawn.
 # A majority of the footprint must connect to the existing cap; the outer
 # face may project at most 35 cm beyond it, with no lake overlap anywhere.
 var points:=PackedVector2Array();var lo:=Vector2(INF,INF);var hi:=-lo
 for vertex:Vector3 in mesh.get_faces():
  var v:=pose*vertex;var p:=Vector2(v.x,v.z)
  points.append(p);lo=lo.min(p);hi=hi.max(p)
 var hull:=Geometry2D.convex_hull(points)
 var total:=0;var backed:=0
 for z in range(floori(lo.y/.20),ceili(hi.y/.20)+1):
  for x in range(floori(lo.x/.20),ceili(hi.x/.20)+1):
   var p:=Vector2(x,z)*.20
   if not Geometry2D.is_point_in_polygon(p,hull):continue
   total+=1
   if dry_surface(field,p,h):backed+=1;continue
   var surface:Dictionary=field.surface_at(p)
   if not surface.is_empty():return false
   var distance:=INF
   for loop:PackedVector2Array in field.rim_regions.get(h,[]):
    for i in loop.size():distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,loop[i],loop[(i+1)%loop.size()])))
   if distance>.35:return false
 return total>0 and float(backed)/total>=.60

static func build(deco,field,seed_value:int)->Array:
 var result:Array=[];var anchors:Array[Vector2]=[]
 for col:Dictionary in deco._columns:
  var edge:Vector2=col.edge;var h:float=col.pose.origin.y
  var out:=Vector2(col.outward.x,col.outward.z)
  # Only the exterior cliff gets dry outcrops; pond/terrace lips retain space.
  var beyond:Dictionary=field.surface_at(edge+out*2.0)
  if not beyond.is_empty():continue
  var cell:=Vector2i((edge*3.0).floor())
  var choice:float=deco.random_at(cell,seed_value,4200)
  var patch:=sin(edge.x*.37+edge.y*.19)*cos(edge.y*.41-edge.x*.13)
  if patch<-.38 or choice>.88:continue
  var p:=edge-out*.10
  if not clear(p) or deco._water_distance(field,p,h)<1.9:continue
  var spaced:=true
  for anchor:Vector2 in anchors:
   if anchor.distance_to(p)<3.1:spaced=false;break
  if not spaced:continue
  var tall:bool=choice<.46
  var drop:float=clampf(col.height*.78,1.15,1.85)
  var rise:float=1.10+choice*1.0 if tall else .28+choice*.32
  var size:=Vector3(2.7+choice*.7,drop+rise,2.35 if tall else 2.2)
  var kind:="rim_outcrop" if tall else "rim_shelf"
  var mesh:Mesh=deco.assets[kind][0].mesh
  var yaw:=atan2(out.x,out.y)+.08+choice*.28
  var pose:Transform3D
  var fitted:=false
  # The same stone crosses the lawn level and continues into the upper portion
  # of the island wall. Its buried back intersects the retained cliff mass.
  for inset:float in [.60,.40,.20,0.0,-.20]:
   var candidate:=edge+out*inset
   if not clear(candidate) or deco._water_distance(field,candidate,h)<1.9:continue
   pose=pose_for(mesh,candidate,h,size,yaw,drop)
   if supported(field,mesh,pose,h):
    p=candidate;fitted=true;break
  if not fitted:continue
  result.append({"kind":kind,"pose":pose,"height":h,"anchor":p})
  anchors.append(p)
  if not tall:continue
  # A shorter cliff block interlocks with the high block, sharing its rooted depth.
  var tangent:=Vector2(-out.y,out.x)
  var shoulder:=p+tangent*(.70 if choice<.20 else -.85)-out*.18
  mesh=deco.assets.rim_shelf[0].mesh
  pose=pose_for(mesh,shoulder,h,Vector3(2.2,drop*.80+.45,2.05),yaw-.28,drop*.80)
  if clear(shoulder) and supported(field,mesh,pose,h):
   result.append({"kind":"rim_shelf","pose":pose,"height":h,"anchor":p})
 return result

static func trim_cover(surface,rocks:Array,assets:Dictionary):
 var result=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
 var footprints:Array=[]
 for rock:Dictionary in rocks:
  var points:=PackedVector2Array()
  for v:Vector3 in assets[rock.kind][0].mesh.get_faces():
   var p:Vector3=rock.pose*v;points.append(Vector2(p.x,p.z))
  footprints.append({"poly":Geometry2D.convex_hull(points),"height":rock.height})
 # Remove a complete sod patch when a rock occupies it. Per-triangle
 # removal left little detached tips and jagged cuts beside exposed stones.
 var hidden:Dictionary={}
 for i in range(0,surface.vertices.size(),3):
  var key:=Vector2(surface.uv[i].x,surface.colors[i].g)
  if hidden.has(key):continue
  var triangle:=PackedVector2Array()
  for j in 3:
   var v:Vector3=surface.vertices[i+j];triangle.append(Vector2(v.x,v.z))
  for footprint:Dictionary in footprints:
   if absf(key.x-footprint.height)>.01:continue
   var overlaps:=false
   for p:Vector2 in triangle:
    if Geometry2D.is_point_in_polygon(p,footprint.poly):overlaps=true;break
   if not overlaps and absf((triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]))>.000001:
    overlaps=not Geometry2D.intersect_polygons(triangle,footprint.poly).is_empty()
   if overlaps:hidden[key]=true;break
 for i in range(0,surface.vertices.size(),3):
  if hidden.has(Vector2(surface.uv[i].x,surface.colors[i].g)):continue
  for j in 3:
   result.vertices.append(surface.vertices[i+j]);result.normals.append(surface.normals[i+j])
   result.colors.append(surface.colors[i+j]);result.uv.append(surface.uv[i+j]);result.uv2.append(surface.uv2[i+j])
 return result
