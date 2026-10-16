extends RefCounted
## Unaccepted world-probe grass sampling study. Not production rim cover.
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface

static func _hash(p:Vector2)->float:
 return fposmod(sin(p.dot(Vector2(127.1,311.7)))*43758.5453,1.0)

static func _edge_sites(loop:PackedVector2Array,h:float)->Array:
 # World-anchored probes preserve local cover when an unrelated edge changes.
 # Projection onto the whole boundary also ignores collinear subdivisions.
 if loop.size()<3:return []
 var first:=0
 for i in loop.size():
  if loop[i].x<loop[first].x or (loop[i].x==loop[first].x and loop[i].y<loop[first].y):first=i
 var candidates:Dictionary={};var spacing:=.60;var reach:=.30
 for e in loop.size():
  var a:=loop[(first+e)%loop.size()];var b:=loop[(first+e+1)%loop.size()]
  if a.distance_squared_to(b)<.0000000001:continue
  var lo:=a.min(b)-Vector2.ONE*reach;var hi:=a.max(b)+Vector2.ONE*reach
  for y in range(floori(lo.y/spacing),floori(hi.y/spacing)+1):
   for x in range(floori(lo.x/spacing),floori(hi.x/spacing)+1):
    var key:=Vector2i(x,y)
    if not candidates.has(key):
     var seed:=Vector2(key)+Vector2(h,17)
     var probe:=(Vector2(key)+Vector2(.15+.70*_hash(seed),.15+.70*_hash(seed+Vector2(31,7))))*spacing
     candidates[key]={'probe':probe,'distance':INF}
    var candidate:Dictionary=candidates[key]
    var center:=Geometry2D.get_closest_point_to_segment(candidate.probe,a,b)
    var distance:float=center.distance_squared_to(candidate.probe)
    if distance>=reach*reach or distance>=candidate.distance:continue
    candidate.distance=distance;candidate.center=center.snapped(Vector2.ONE*.0001)
    candidate.tangent=(b-a).normalized()
 var keys:Array=candidates.keys();keys.sort()
 var result:Array=[];var used:Dictionary={}
 for key:Vector2i in keys:
  var candidate:Dictionary=candidates[key]
  if not candidate.has('center') or used.has(candidate.center):continue
  used[candidate.center]=true
  var tangent:Vector2=candidate.tangent
  # Variation belongs to the fixed probe, so microscopic projection changes
  # cannot reseed an entire leaf group after retessellation.
  result.append({'center':candidate.center,'tangent':tangent,'out':Vector2(tangent.y,-tangent.x),'choice':_hash(Vector2(key)+Vector2(h,7)),'patch':_hash((candidate.probe*.60).floor()+Vector2(h,29))})
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
    var choice:float=site.choice
    var patch:float=site.patch
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
