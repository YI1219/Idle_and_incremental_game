extends RefCounted
## Tool-only broad low grass patches. Not an accepted runtime change.
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface

static func _hash(p:Vector2)->float:
 return fposmod(sin(p.dot(Vector2(127.1,311.7)))*43758.5453,1.0)

static func _arc_sites(loop:PackedVector2Array,h:float)->Array:
 # Cap triangulation can split a straight boundary into many tiny edges.
 # Sample physical distance, with a canonical start, rather than each edge.
 if loop.size()<3:return []
 var first:=0
 for i in loop.size():
  if loop[i].x<loop[first].x or (loop[i].x==loop[first].x and loop[i].y<loop[first].y):first=i
 var points:=PackedVector2Array();var starts:Array[float]=[0.0]
 for i in loop.size():points.append(loop[(first+i)%loop.size()])
 for i in points.size():starts.append(starts[-1]+points[i].distance_to(points[(i+1)%points.size()]))
 var perimeter:float=starts[-1]
 if perimeter<.12:return []
 var count:=maxi(1,floori(perimeter/.60));var step:=perimeter/count
 var base:=0;var edge:=0;var result:Array=[]
 for k in count:
  var middle:float=(k+.5)*step
  while base<points.size()-1 and starts[base+1]<=middle:base+=1
  var seed_point:=points[base].lerp(points[(base+1)%points.size()],(middle-starts[base])/maxf(starts[base+1]-starts[base],.000001)).snapped(Vector2.ONE*.0001)
  var at:float=(k+.25+.50*_hash(seed_point+Vector2(h,17)))*step
  while edge<points.size()-1 and starts[edge+1]<=at:edge+=1
  var a:=points[edge];var b:=points[(edge+1)%points.size()]
  if a.distance_squared_to(b)<.0000000001:continue
  var center:=a.lerp(b,(at-starts[edge])/(starts[edge+1]-starts[edge])).snapped(Vector2.ONE*.0001)
  var tangent:Vector2=(b-a).normalized()
  result.append({'center':center,'tangent':tangent,'out':Vector2(tangent.y,-tangent.x)})
 return result

static func _sites(loop:PackedVector2Array,h:float,resample:bool)->Array:
 if resample:return _arc_sites(loop,h)
 var result:Array=[]
 for e in loop.size():
  var a:=loop[e];var b:=loop[(e+1)%loop.size()];var length:=a.distance_to(b)
  if length<.12:continue
  var tangent:=(b-a)/length;var out:=Vector2(tangent.y,-tangent.x)
  var count:=maxi(1,floori(length/.60))
  for k in count:
   var offset:=.25+.50*_hash(a+b+Vector2(k,h))
   result.append({'center':a.lerp(b,(k+offset)/count),'tangent':tangent,'out':out})
 return result

static func _turn_distance(loop:PackedVector2Array,p:Vector2)->float:
 var distance:=INF
 for i in loop.size():
  var a:Vector2=loop[i]-loop[(i+loop.size()-1)%loop.size()]
  var b:Vector2=loop[(i+1)%loop.size()]-loop[i]
  if minf(a.length_squared(),b.length_squared())<.00000001:continue
  if a.normalized().dot(b.normalized())>.90:continue
  distance=minf(distance,p.distance_to(loop[i]))
 return distance

static func lip(regions:Dictionary,crowns:Array,assets:Dictionary,resample:bool=false,corner_bias:bool=false):
 # Source leaves form the edge silhouette; there is no separate molded sod.
 var result:=Surface.new();var blades:=PackedVector3Array()
 for part:Dictionary in assets.get("grass",[]):
  for p:Vector3 in part.mesh.get_faces():blades.append(part.pose*p)
 if blades.is_empty():return result
 var box:=AABB(blades[0],Vector3.ZERO)
 for p:Vector3 in blades:box=box.expand(p)
 for h:float in regions:
  for loop:PackedVector2Array in regions[h]:
   for site:Dictionary in _sites(loop,h,resample):
     var center:Vector2=site.center;var tangent:Vector2=site.tangent;var out:Vector2=site.out
     var choice:=_hash(center*2.1+Vector2(h,7))
     var patch:=_hash((center*.60).floor()+Vector2(h,29))
     if patch<.40 or choice<.38:continue
     if corner_bias and choice<lerpf(.25,.80,smoothstep(.40,1.15,_turn_distance(loop,center))):continue
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

static func _inside(loops:Array,p:Vector2)->bool:
 var winding:=0
 for loop:PackedVector2Array in loops:
  if not Geometry2D.is_point_in_polygon(p,loop):continue
  var area:=0.0
  for i in loop.size():area+=loop[i].cross(loop[(i+1)%loop.size()])
  winding+=1 if area>0.0 else -1
 return winding>0

static func _blades(result,center:Vector2,tangent:Vector2,out:Vector2,h:float,choice:float,blades:PackedVector3Array,box:AABB,regions:Array)->void:
 # Broaden retained source leaves; unequal low fans share supported roots.
 # No pads, closed sod bands, extra ground, or texture-painted shoulder.
 var foot:=Vector3(box.position.x+box.size.x*.5,box.position.y,box.position.z+box.size.z*.5)
 for fan in 4:
  var at:Vector2=center+tangent*[-.20,-.035,.13,.27][fan]-out*[.10,.09,.11,.12][fan]
  if not _inside(regions,at):continue
  var scale:float=([.19,.22,.15,.12][fan]+.015*choice)/maxf(box.size.y,.001)
  var lean:=Basis(Vector3(tangent.x,0,tangent.y),[-.30,-.95,-.45,-1.14][fan]-.10*choice)
  var basis:=lean*Basis(Vector3.UP,choice*TAU+fan*1.9)
  basis=basis.scaled_local(Vector3(2.5,1.0,2.0)*scale)
  var pose:=Transform3D(basis,Vector3(at.x,h-.012,at.y)-basis*foot)
  var start:int=result.vertices.size()
  for i in range(0,blades.size(),3):result.triangle(pose*blades[i],pose*blades[i+1],pose*blades[i+2],Color.WHITE)
  for i in range(start,result.vertices.size()):
   result.colors[i]=Color(.5,choice,1,1)
   result.uv[i]=Vector2(h,0.0);result.uv2.append(at)
