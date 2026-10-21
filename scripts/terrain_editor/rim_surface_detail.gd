extends RefCounted
## Cosmetic surface detail assembled from the authoritative merged rim.
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface

static func _hash(p:Vector2)->float:
 return fposmod(sin(p.dot(Vector2(127.1,311.7)))*43758.5453,1.0)

static func lip(regions:Dictionary,crowns:Array,assets:Dictionary):
 # Source leaves form the edge silhouette; there is no separate molded sod.
 var result:=Surface.new();var blades:=PackedVector3Array()
 for part:Dictionary in assets.get("grass",[]):
  for p:Vector3 in part.mesh.get_faces():blades.append(part.pose*p)
 if blades.is_empty():return result
 var box:=AABB(blades[0],Vector3.ZERO)
 for p:Vector3 in blades:box=box.expand(p)
 for h:float in regions:
  for loop:PackedVector2Array in regions[h]:
   for e in loop.size():
    var a:=loop[e];var b:=loop[(e+1)%loop.size()];var length:=a.distance_to(b)
    if length<.12:continue
    var tangent:=(b-a)/length;var out:=Vector2(tangent.y,-tangent.x)
    var count:=maxi(1,floori(length/.60))
    for k in count:
     var offset:=.25+.50*_hash(a+b+Vector2(k,h))
     var center:=a.lerp(b,(k+offset)/count)
     var choice:=_hash(center*2.1+Vector2(h,7))
     var patch:=_hash((center*.60).floor()+Vector2(h,29))
     if patch<.32 or choice<.18:continue
     # Only final crown-backed contours get cover; fall openings stay clear.
     var on_crown:=false
     for crown:Dictionary in crowns:
      if absf(crown.height-h)>.001:continue
      var poly:PackedVector2Array=crown.polygon
      for j in poly.size()-1:
       if center.distance_to(Geometry2D.get_closest_point_to_segment(center,poly[j],poly[j+1]))<.003:on_crown=true;break
      if on_crown:break
     if on_crown:_blades(result,center,tangent,out,h,choice,blades,box,regions[h])
 return result

static func sculpt_lip(field,assets:Dictionary):
 # Actual rooted blades, with no cuff disks or a painted green wall band.
 var result:=Surface.new();var blades:=PackedVector3Array()
 for part:Dictionary in assets.get("grass",[]):
  for p:Vector3 in part.mesh.get_faces():blades.append(part.pose*p)
 if blades.is_empty():return result
 var box:=AABB(blades[0],Vector3.ZERO)
 for p:Vector3 in blades:box=box.expand(p)
 var foot:=Vector3(box.get_center().x,box.position.y,box.get_center().z)
 for h:float in field.land_regions:
  for loop:PackedVector2Array in field.land_regions[h]:
   for e in loop.size():
    var a:=loop[e];var b:=loop[(e+1)%loop.size()];var length:=a.distance_to(b)
    if length<.15:continue
    var tangent:=(b-a).normalized();var out:=Vector2(tangent.y,-tangent.x)
    var count:=maxi(1,ceili(length/.58))
    for k in count:
     var p:=a.lerp(b,(k+.25+.5*_hash(a+Vector2(k,h)))/count)-out*.13
     var choice:=_hash(p*2.1+Vector2(h,7))
     if choice<.40:continue
     var ground:Dictionary=field.surface_at(p)
     if ground.is_empty() or ground.water>=0 or absf(ground.height-h)>.12:continue
     for fan in 2:
      var at:=p+tangent*(fan-.5)*.12-out*.035*fan
      var sample:Dictionary=field.surface_at(at)
      if sample.is_empty() or sample.water>=0 or absf(sample.height-h)>.12:continue
      var scale:float=(.20+.10*choice-.055*fan)/maxf(box.size.y,.001)
      var basis:=Basis(Vector3(tangent.x,0,tangent.y),-.35-.25*choice)*Basis(Vector3.UP,choice*TAU+fan*1.9)
      basis=basis.scaled(Vector3.ONE*scale)
      var pose:=Transform3D(basis,Vector3(at.x,sample.height-.012,at.y)-basis*foot)
      var start:=result.vertices.size()
      for j in range(0,blades.size(),3):result.triangle(pose*blades[j],pose*blades[j+1],pose*blades[j+2],Color.WHITE)
      for j in range(start,result.vertices.size()):
       result.colors[j]=Color(.5,choice,1,1);result.uv[j]=Vector2(sample.height,0);result.uv2.append(at)
 return result

static func _inside(loops:Array,p:Vector2)->bool:
 var winding:=0
 for loop:PackedVector2Array in loops:
  if not Geometry2D.is_point_in_polygon(p,loop):continue
  var area:=0.0
  for i in loop.size():area+=loop[i].cross(loop[(i+1)%loop.size()])
  winding+=1 if area>0.0 else -1
 return winding>0

static func _blades(result,center:Vector2,tangent:Vector2,out:Vector2,h:float,choice:float,blades:PackedVector3Array,box:AABB,regions:Array)->void:
 # Instance the existing curved grass source at its original proportions.
 # Unequal upright, outward and low fans share supported roots inside the cap.
 var foot:=Vector3(box.position.x+box.size.x*.5,box.position.y,box.position.z+box.size.z*.5)
 for fan in 3:
  var at:Vector2=center+tangent*[-.080,.035,.12][fan]-out*[.060,.085,.12][fan]
  if not _inside(regions,at):continue
  var scale:float=([.24,.20,.14][fan]+.020*choice)/maxf(box.size.y,.001)
  var lean:=Basis(Vector3(tangent.x,0,tangent.y),[-.24,-1.08,-.65][fan]-.10*choice)
  var basis:=lean*Basis(Vector3.UP,choice*TAU+fan*1.9)
  basis=basis.scaled(Vector3.ONE*scale)
  var pose:=Transform3D(basis,Vector3(at.x,h-.012,at.y)-basis*foot)
  var start:int=result.vertices.size()
  for i in range(0,blades.size(),3):result.triangle(pose*blades[i],pose*blades[i+1],pose*blades[i+2],Color.WHITE)
  for i in range(start,result.vertices.size()):
   result.colors[i]=Color(.5,choice,1,1)
   result.uv[i]=Vector2(h,0.0);result.uv2.append(at)

static func lawn(mesh:ArrayMesh,boundaries:Dictionary,wet:Dictionary={},relief:float=.055)->ArrayMesh:
 if mesh.get_surface_count()==0 or is_zero_approx(relief):return mesh
 var arrays:=mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var result:=Surface.new();var cache:Dictionary={}
 for i in range(0,vertices.size(),3):
  if colors[i].a<.5:
   for j in 3:
    result.vertices.append(vertices[i+j]);result.normals.append(Vector3.UP);result.colors.append(colors[i+j]);result.uv.append(uv[i+j])
   continue
  # Shared world grid intersections avoid displaced T-junctions across slabs
  # and chunks. Original crown tops remain calm and exactly in place.
  var polys:Array=[[vertices[i],vertices[i+1],vertices[i+2]]]
  for axis in [0,2]:
   var lo:=minf(vertices[i][axis],minf(vertices[i+1][axis],vertices[i+2][axis]))
   var hi:=maxf(vertices[i][axis],maxf(vertices[i+1][axis],vertices[i+2][axis]))
   for row in range(floori(lo/.8)+1,ceili(hi/.8)):
    var next:Array=[]
    for poly:Array in polys:
     var sides:=[[],[]]
     for j in poly.size():
      var a:Vector3=poly[j];var b:Vector3=poly[(j+1)%poly.size()]
      var da:float=a[axis]-row*.8;var db:float=b[axis]-row*.8
      if da<=0:sides[0].append(a)
      if da>=0:sides[1].append(a)
      if da*db<0:
       var cross:=a.lerp(b,da/(da-db));sides[0].append(cross);sides[1].append(cross)
     for side:Array in sides:
      if side.size()>2:next.append(side)
    polys=next
  for poly:Array in polys:
   for j in range(1,poly.size()-1):
    var points:Array=[]
    for p:Vector3 in [poly[0],poly[j],poly[j+1]]:
     var key:=Vector3(snappedf(p.x,.00001),p.y,snappedf(p.z,.00001))
     if not cache.has(key):
      var distance:=INF;var q:=Vector2(p.x,p.z)
      for edge:PackedVector2Array in boundaries.get(p.y,[]):
       for n in edge.size():distance=minf(distance,q.distance_to(Geometry2D.get_closest_point_to_segment(q,edge[n],edge[(n+1)%edge.size()])))
      var submerged:=false
      for water_level:int in wet:
       if water_level*.5<p.y-.001:continue
       var winding:=0
       for edge:PackedVector2Array in wet[water_level]:
        for n in edge.size():distance=minf(distance,q.distance_to(Geometry2D.get_closest_point_to_segment(q,edge[n],edge[(n+1)%edge.size()])))
        if Geometry2D.is_point_in_polygon(q,edge):winding+=-1 if Geometry2D.is_polygon_clockwise(edge) else 1
       if winding>0:submerged=true
      if submerged:distance=0.0
      cache[key]=relief*sin(p.x*.8+p.z*.3)*sin(p.z*.62-p.x*.21)*smoothstep(.02,.85,distance)
     points.append(p+Vector3.UP*cache[key])
    result.triangle(points[0],points[1],points[2],colors[i],true)
 return result.mesh()
