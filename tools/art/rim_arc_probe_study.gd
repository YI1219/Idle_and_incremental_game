extends RefCounted
## Rejected tool-only whole-loop arc sampler; local edits reseed unrelated edges.
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface

static func _hash(p:Vector2)->float:
 return fposmod(sin(p.dot(Vector2(127.1,311.7)))*43758.5453,1.0)

static func _edge_sites(loop:PackedVector2Array,h:float)->Array:
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
   for site:Dictionary in _edge_sites(loop,h):
     var center:Vector2=site.center;var tangent:Vector2=site.tangent;var out:Vector2=site.out
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
