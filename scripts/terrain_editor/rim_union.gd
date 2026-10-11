extends RefCounted
## Crown solids replace the old cap/shoulder in their contour span. Subtract
## their actual footprint from the lawn, so the two tops share an inner edge.
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")

static func apply(field,columns:Array,assets:Dictionary)->void:
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
  if reach.y>reach.x:
   strips.append({"polygon":strip,"height":col.pose.origin.y})
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
  field._cap(lawn,loops,h,Color.WHITE,_crossing_rows(loops))
  field.lawn_boundaries[h]=loops
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
     _top_triangle(lawn,piece[0],piece[j],piece[j+1],regions[crown.height])
  previous.append({"planes":_planes(crown.polygon),"height":crown.height})
 field.surfaces.grass=lawn
 # Keep a continuous core behind the independent crowns. Boolean cuts in
 # the old bulging shoulder made isolated chips; removing all outer pieces
 # instead opened gaps under the cap. Tuck its vertices beneath the final
 # outline without deleting faces, so the backing remains connected.
 var original=field.surfaces.cliff
 var result:=Surface.new()
 for i in range(0,original.vertices.size(),3):
  var a:=_tuck_shoulder(original.vertices[i],regions,original.uv[i].x)
  var b:=_tuck_shoulder(original.vertices[i+1],regions,original.uv[i+1].x)
  var c:=_tuck_shoulder(original.vertices[i+2],regions,original.uv[i+2].x)
  var start:=result.vertices.size()
  result.triangle(a,b,c,Color.WHITE)
  for k in range(start,result.vertices.size()):
   result.colors[k]=original.colors[i+k-start]
   result.uv[k]=original.uv[i+k-start]
 # Short original-contour joins between crown footprints need a skin after
 # the bulging old shoulder is trimmed. Match the final top boundary exactly.
 for h:float in regions:
  for loop:PackedVector2Array in regions[h]:
   for e in loop.size():
    var a:=loop[e];var b:=loop[(e+1)%loop.size()];var mid:=(a+b)*.5
    if a.distance_squared_to(b)<.000001:continue
    var near:=INF;var on_body:=INF
    for crown:Dictionary in crowns:
     if absf(crown.height-h)>.001:continue
     near=minf(near,mid.distance_to(crown.column.edge))
     for j in crown.polygon.size()-1:
      on_body=minf(on_body,mid.distance_to(Geometry2D.get_closest_point_to_segment(mid,crown.polygon[j],crown.polygon[j+1])))
    if near>1.5 or on_body<.002:continue
    var start:=result.vertices.size()
    result.quad(Vector3(a.x,h,a.y),Vector3(a.x,h-.70,a.y),Vector3(b.x,h-.70,b.y),Vector3(b.x,h,b.y),Color.WHITE)
    for j in range(start,result.vertices.size()):result.uv[j]=Vector2(h,1.0)
 preload("res://scripts/terrain_editor/block_mantle.gd").close_base(result,field.land_regions)
 var mantle=preload("res://scripts/terrain_editor/block_mantle.gd").build(result,regions)
 field.surfaces.cliff=mantle.backing
 field.surfaces.stone_mantle=mantle.stone
 field.surfaces.rim_green=preload("res://scripts/terrain_editor/rim_surface_detail.gd").lip(regions,crowns,assets)
 field._index_triangles()

static func _crossing_rows(loops:Array)->PackedFloat32Array:
 # Crown subtraction rings overlap. Their edges must not change order inside
 # a cap scanline slab, or its extrapolated trapezoids leave triangular holes.
 var rows:=PackedFloat32Array()
 for i in loops.size():
  var a:PackedVector2Array=loops[i]
  for j in range(i+1,loops.size()):
   var b:PackedVector2Array=loops[j]
   for e in a.size():
    var p:=a[e];var q:=a[(e+1)%a.size()]
    for f in b.size():
     var r:=b[f];var s:=b[(f+1)%b.size()]
     if maxf(p.x,q.x)<minf(r.x,s.x) or maxf(r.x,s.x)<minf(p.x,q.x):continue
     if maxf(p.y,q.y)<minf(r.y,s.y) or maxf(r.y,s.y)<minf(p.y,q.y):continue
     var crossing=Geometry2D.segment_intersects_segment(p,q,r,s)
     if crossing!=null:rows.append(crossing.y)
 return rows

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

static func _edge_distance(p:Vector3,regions:Array)->float:
 var point:=Vector2(p.x,p.z)
 var distance:=INF
 for loop:PackedVector2Array in regions:
  for i in loop.size():
   distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,loop[i],loop[(i+1)%loop.size()])))
 return distance

static func _top_triangle(surface,a:Vector3,b:Vector3,c:Vector3,regions:Array,depth:int=0)->void:
 var da:=_edge_distance(a,regions);var db:=_edge_distance(b,regions);var dc:=_edge_distance(c,regions)
 # Bound interpolation error near the narrow transition: long cap fan edges
 # used to carry a perimeter color right across the interior lawn.
 var ab:=a.distance_squared_to(b);var bc:=b.distance_squared_to(c);var ca:=c.distance_squared_to(a)
 if minf(da,minf(db,dc))<.30 and maxf(ab,maxf(bc,ca))>.09 and depth<9:
  if ab>=bc and ab>=ca:
   var mid:=(a+b)*.5;_top_triangle(surface,a,mid,c,regions,depth+1);_top_triangle(surface,mid,b,c,regions,depth+1)
  elif bc>=ca:
   var mid:=(b+c)*.5;_top_triangle(surface,a,b,mid,regions,depth+1);_top_triangle(surface,a,mid,c,regions,depth+1)
  else:
   var mid:=(c+a)*.5;_top_triangle(surface,a,b,mid,regions,depth+1);_top_triangle(surface,mid,b,c,regions,depth+1)
  return
 var start:int=surface.vertices.size()
 surface.triangle(a,b,c,Color(1,1,1,0),true)
 for k in range(start,surface.vertices.size()):surface.uv[k]=Vector2(_edge_distance(surface.vertices[k],regions),1.0)

static func _tuck_shoulder(point:Vector3,regions:Dictionary,h:float)->Vector3:
 # Use this face's own cap height: newly added lower levels elsewhere must
 # not retuck an unchanged upper cliff against a different terrace's outline.
 if not regions.has(h) or point.y<h-.70 or point.y>h+.001:return point
 var p:=Vector2(point.x,point.z)
 if Field.contains(regions[h],p):return point
 var distance:=INF;var closest:=p;var inward:=Vector2.ZERO
 for loop:PackedVector2Array in regions[h]:
  for i in loop.size():
   var a:=loop[i];var b:=loop[(i+1)%loop.size()]
   if a.distance_squared_to(b)<.000001:continue
   var q:=Geometry2D.get_closest_point_to_segment(p,a,b)
   var d:=p.distance_squared_to(q)
   if d<distance:
    distance=d;closest=q;inward=Vector2(a.y-b.y,b.x-a.x).normalized()
 if distance<2.25:
  point.x=closest.x+inward.x*.045;point.z=closest.y+inward.y*.045
 return point
