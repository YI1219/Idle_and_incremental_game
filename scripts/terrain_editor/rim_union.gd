extends RefCounted
## Crown solids replace the old cap/shoulder in their contour span. Subtract
## their actual footprint from the lawn, so the two tops share an inner edge.
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")

static func apply(field,columns:Array,assets:Dictionary)->void:
 var cuts:Array=[]
 var crowns:Array=[]
 var strips:Array=[]
 for col:Dictionary in columns:
  var points:=PackedVector2Array()
  for p:Vector3 in assets[col.kind][0].mesh.get_faces():
   if absf(p.y)>.00001:continue
   var q:Vector3=col.pose*p;points.append(Vector2(q.x,q.z))
  var hull:=Geometry2D.convex_hull(points)
  var out:=Vector2(col.outward.x,col.outward.z)
  var tangent:=Vector2(col.tangent.x,col.tangent.z)
  var c:Vector2=col.edge
  # A rectangular span must stop inside the actual crown, not its bounding
  # box. Intersect cross-sections through the old shoulder to keep termination
  # cuts backed by stone, including yawed crowns beside waterfall openings.
  var reach:=Vector2(-col.width*.58,col.width*.58)
  for depth:float in [-.10,0.0,.20,.40]:
   var section:=Vector2(INF,-INF)
   for e in hull.size()-1:
    var a:=hull[e]-c;var b:=hull[e+1]-c
    var da:=a.dot(out);var db:=b.dot(out)
    if absf(db-da)<.000001 or depth<minf(da,db) or depth>maxf(da,db):continue
    var t:=a.lerp(b,(depth-da)/(db-da)).dot(tangent)
    section.x=minf(section.x,t);section.y=maxf(section.y,t)
   reach.x=maxf(reach.x,section.x+.015);reach.y=minf(reach.y,section.y-.015)
  var strip:=PackedVector2Array([c+tangent*reach.x-out*.10,c+tangent*reach.y-out*.10,c+tangent*reach.y+out*3.0,c+tangent*reach.x+out*3.0])
  crowns.append({"polygon":hull,"height":col.pose.origin.y,"column":col})
  var masks:Array=[hull]
  if reach.y>reach.x:
   strips.append({"polygon":strip,"height":col.pose.origin.y})
   masks.append(strip)
  for polygon:PackedVector2Array in masks:
   if Field._area(polygon)<0:polygon.reverse()
   var planes:Array[Plane]=[]
   var box:=Rect2(polygon[0],Vector2.ZERO)
   for i in polygon.size():
    var a:=polygon[i];var b:=polygon[(i+1)%polygon.size()]
    if a.distance_squared_to(b)<.0000001:continue
    var n:=Vector2(b.y-a.y,a.x-b.x).normalized()
    planes.append(Plane(Vector3(n.x,0,n.y),n.dot(a)))
    box=box.expand(a)
   cuts.append({"planes":planes,"bounds":box,"height":col.pose.origin.y})
 # Resolve the whole filled top before triangulating. Newly enclosed pockets
 # between crowns are lawn, not holes through the island. Authored holes remain.
 var regions:Dictionary={}
 for h:float in field.levels:
  var polygons:Array=[];var holes:Array=[]
  for loop:PackedVector2Array in field.land_regions[h]:
   if Field._area(loop)<0:holes.append(loop);continue
   var pieces:Array=[loop]
   for strip:Dictionary in strips:
    if absf(strip.height-h)>.001:continue
    var next:Array=[]
    for piece:PackedVector2Array in pieces:
     for result:PackedVector2Array in Geometry2D.clip_polygons(piece,strip.polygon):
      if Field._area(result)>0:next.append(result)
    pieces=next
   polygons.append_array(pieces)
  for crown:Dictionary in crowns:
   if absf(crown.height-h)<.001:_union(polygons,crown.polygon)
  polygons.append_array(holes)
  regions[h]=polygons
 field.rim_regions=regions
 var lawn:=Surface.new()
 for i in field.levels.size():
  var h:float=field.levels[i]
  var loops:Array=regions[h].duplicate()
  if i+1<field.levels.size():
   for loop:PackedVector2Array in field.land_regions[field.levels[i+1]]:
    var hole:=loop.duplicate();hole.reverse();loops.append(hole)
  for crown:Dictionary in crowns:
   if absf(crown.height-h)>.001:continue
   var hole:PackedVector2Array=crown.polygon.duplicate()
   if Field._area(hole)>0:hole.reverse()
   loops.append(hole)
  field._cap(lawn,loops,h,Color.WHITE)
 # Each crown remains a closed authoring solid. Bake its top into the shared
 # surface once, subtracting earlier crowns so coplanar overlaps cannot flicker.
 var previous:Array=[]
 for crown:Dictionary in crowns:
  var col:Dictionary=crown.column
  var mesh:ArrayMesh=assets[col.kind][0].mesh
  var vertices:PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  for i in range(0,vertices.size(),3):
   if absf(vertices[i].y)+absf(vertices[i+1].y)+absf(vertices[i+2].y)>.00001:continue
   var fragments:Array=[[col.pose*vertices[i],col.pose*vertices[i+1],col.pose*vertices[i+2]]]
   for earlier:Dictionary in previous:
    if absf(earlier.height-crown.height)>.001:continue
    var next:Array=[]
    for piece:Array in fragments:next.append_array(_subtract(piece,earlier.planes))
    fragments=next
   for piece:Array in fragments:
    for j in range(1,piece.size()-1):
     var start:=lawn.vertices.size()
     lawn.triangle(piece[0],piece[j],piece[j+1],Color(1,1,1,0),true)
     for k in range(start,lawn.vertices.size()):
      var p:Vector3=lawn.vertices[k]
      var point:=Vector2(p.x,p.z)
      var inset:=0.0
      for other:Dictionary in crowns:
       if absf(other.height-crown.height)>.001 or not Geometry2D.is_point_in_polygon(point,other.polygon):continue
       var distance:=INF
       for e in other.polygon.size()-1:
        distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,other.polygon[e],other.polygon[e+1])))
       inset=maxf(inset,distance)
      var local:Vector3=col.pose.affine_inverse()*p
      lawn.uv[k]=Vector2(inset,local.z)
  previous.append({"planes":_planes(crown.polygon),"height":crown.height})
 field.surfaces.grass=lawn
 for kind in ["cliff"]:
  var original=field.surfaces[kind]
  var result:=Surface.new()
  for i in range(0,original.vertices.size(),3):
   var a:Vector3=original.vertices[i];var b:Vector3=original.vertices[i+1];var c:Vector3=original.vertices[i+2]
   var box:=Rect2(Vector2(a.x,a.z),Vector2.ZERO).expand(Vector2(b.x,b.z)).expand(Vector2(c.x,c.z))
   var fragments:Array=[[a,b,c]]
   for cut:Dictionary in cuts:
    if not box.intersects(cut.bounds,true):continue
    if kind=="grass" and absf(a.y-cut.height)>.001:continue
    if kind=="cliff" and (maxf(a.y,maxf(b.y,c.y))<cut.height-.70 or minf(a.y,minf(b.y,c.y))>cut.height+.001):continue
    var planes:Array[Plane]=cut.planes.duplicate()
    if kind=="cliff":
     planes.append(Plane(Vector3.DOWN,-cut.height+.70))
     planes.append(Plane(Vector3.UP,cut.height+.001))
    var next:Array=[]
    for polygon:Array in fragments:next.append_array(_subtract(polygon,planes))
    fragments=next
    if fragments.is_empty():break
   for polygon:Array in fragments:
    for j in range(1,polygon.size()-1):
     var start:=result.vertices.size()
     result.triangle(polygon[0],polygon[j],polygon[j+1],Color.WHITE,kind=="grass")
     for k in range(start,result.vertices.size()):
      var p:Vector3=result.vertices[k]
      result.normals[k]=Field._interpolated_normal(p,a,b,c,original.normals[i],original.normals[i+1],original.normals[i+2])
      result.colors[k]=Field._interpolated_color(p,a,b,c,original.colors[i],original.colors[i+1],original.colors[i+2])
      var u:Vector2=original.uv[i];var v:Vector2=original.uv[i+1];var w:Vector2=original.uv[i+2]
      var value:=Field._interpolated_color(p,a,b,c,Color(u.x,u.y,0),Color(v.x,v.y,0),Color(w.x,w.y,0))
      result.uv[k]=Vector2(value.r,value.g)
  field.surfaces[kind]=result
 field._index_triangles()

static func _union(polygons:Array,addition:PackedVector2Array)->void:
 var merged:=addition
 var i:=0
 while i<polygons.size():
  var result:=Geometry2D.merge_polygons(merged,polygons[i])
  var positive:Array=[]
  for polygon:PackedVector2Array in result:
   if Field._area(polygon)>0:positive.append(polygon)
  if positive.size()==1:
   merged=positive[0];polygons.remove_at(i);i=0
  else:i+=1
 polygons.append(merged)

static func _planes(polygon:PackedVector2Array)->Array[Plane]:
 var result:Array[Plane]=[]
 for i in polygon.size()-1:
  var a:=polygon[i];var b:=polygon[i+1]
  if a.distance_squared_to(b)<.0000001:continue
  var n:=Vector2(b.y-a.y,a.x-b.x).normalized()
  result.append(Plane(Vector3(n.x,0,n.y),n.dot(a)))
 return result

static func _subtract(polygon:Array,planes:Array[Plane])->Array:
 var inside:Array=polygon
 var result:Array=[]
 for plane:Plane in planes:
  if inside.size()<3:break
  var next:Array=[];var outside:Array=[]
  for i in inside.size():
   var a:Vector3=inside[i];var b:Vector3=inside[(i+1)%inside.size()]
   var da:=plane.distance_to(a);var db:=plane.distance_to(b)
   if da<=0.0:next.append(a)
   else:outside.append(a)
   if (da<0.0 and db>0.0) or (da>0.0 and db<0.0):
    var crossing:=a.lerp(b,da/(da-db))
    next.append(crossing);outside.append(crossing)
  if outside.size()>=3:result.append(outside)
  inside=next
 return result
