extends RefCounted
## Physical submerged terrain, derived only from authored water/bed records.
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface

# Contour/grid crossings can create real sub-millimetre slivers. Keep them
# here: the general terrain builder's larger cull threshold opens thin seams.
class BedSurface extends Surface:
 func triangle(a:Vector3,b:Vector3,c:Vector3,color:Color,up:bool=false)->void:
  var cross:=-(b-a).cross(c-a)
  if cross.length_squared()<1e-16:return
  var normal:=cross.normalized()
  if up and normal.y<0.0:
   var swap:=b;b=c;c=swap;normal=-normal
  for p:Vector3 in [a,b,c]:
   vertices.append(p);normals.append(normal);colors.append(color);uv.append(Vector2(p.x+p.z,p.y))

static func build(field):
 var result:=BedSurface.new()
 for level:int in field.water_regions:
  var h:float=level*.5;var loops:Array=field.water_regions[level]
  var xs:Array=[];var zs:Array=[];var shores:Array=[]
  var low:=Vector2(INF,INF);var high:=-low
  for loop:PackedVector2Array in loops:
   for i in loop.size():
    var a:=loop[i];var b:=loop[(i+1)%loop.size()]
    xs.append(a.x);zs.append(a.y);low=low.min(a);high=high.max(a)
    var out:=Vector2(b.y-a.y,a.x-b.x).normalized()
    if field.shore_support((a+b)*.5,out,h,.30):shores.append([a,b])
  for x in range(floori(low.x*2.0),ceili(high.x*2.0)+1):xs.append(x*.5)
  for z in range(floori(low.y*2.0),ceili(high.y*2.0)+1):zs.append(z*.5)
  xs.sort();zs.sort()
  var cuts:Array=[]
  for x:float in xs:
   if cuts.is_empty() or absf(cuts[-1]-x)>.00001:cuts.append(x)
  var flat:=BedSurface.new()
  field._cap(flat,loops,h,Color.WHITE,PackedFloat32Array(zs),true)
  var cache:Dictionary={}
  for i in range(0,flat.vertices.size(),3):
   var pieces:Array=[[flat.vertices[i],flat.vertices[i+1],flat.vertices[i+2]]]
   var lo:=minf(flat.vertices[i].x,minf(flat.vertices[i+1].x,flat.vertices[i+2].x))
   var hi:=maxf(flat.vertices[i].x,maxf(flat.vertices[i+1].x,flat.vertices[i+2].x))
   for cut:float in cuts:
    if cut<=lo+.000001 or cut>=hi-.000001:continue
    var next:Array=[]
    for polygon:Array in pieces:
     var sides:Array=[[],[]]
     for j in polygon.size():
      var a:Vector3=polygon[j];var b:Vector3=polygon[(j+1)%polygon.size()]
      var da:float=a.x-cut;var db:float=b.x-cut
      if da<=0:sides[0].append(a)
      if da>=0:sides[1].append(a)
      if da*db<0:
       var cross:=a.lerp(b,da/(da-db));sides[0].append(cross);sides[1].append(cross)
     for side:Array in sides:
      if side.size()>2:next.append(side)
    pieces=next
   for polygon:Array in pieces:
    for j in range(1,polygon.size()-1):
     var positions:Array=[]
     for point:Vector3 in [polygon[0],polygon[j],polygon[j+1]]:
      var p:=Vector2(point.x,point.z).snapped(Vector2.ONE*.00001)
      if not cache.has(p):cache[p]=height_at(field.source,p,level,shores)
      positions.append(Vector3(p.x,cache[p],p.y))
     result.triangle(positions[0],positions[1],positions[2],Color.WHITE,true)
  # A short submerged bank joins the dry surface to the bed at its boundary.
  # Split at the same global cuts so nonlinear shore ramps cannot open seams.
  for loop:PackedVector2Array in loops:
   for i in loop.size():
    var a:=loop[i];var b:=loop[(i+1)%loop.size()];var ts:Array=[0.0,1.0]
    for axis in 2:
     if absf(b[axis]-a[axis])<.000001:continue
     for cut:float in (cuts if axis==0 else zs):
      var t:float=(cut-a[axis])/(b[axis]-a[axis])
      if t>.000001 and t<.999999:ts.append(t)
    ts.sort()
    for j in ts.size()-1:
     var p:=a.lerp(b,ts[j]).snapped(Vector2.ONE*.00001)
     var q:=a.lerp(b,ts[j+1]).snapped(Vector2.ONE*.00001)
     if p.distance_squared_to(q)<1e-14:continue
     result.quad(Vector3(p.x,h,p.y),Vector3(p.x,height_at(field.source,p,level,shores),p.y),Vector3(q.x,height_at(field.source,q,level,shores),q.y),Vector3(q.x,h,q.y),Color.WHITE)
 result=_weld(result)
 field._smooth_normals(result)
 return result

static func _weld(source):
 # Different clipping paths can put the same corner a few microns apart.
 # Canonicalize neighbors (including adjacent hash bins), then discard only
 # collapsed/duplicate faces. This joins the physical bank and floor exactly.
 const EPS:=.0001
 var buckets:Dictionary={};var points:Array[Vector3]=[];var indices:Array[int]=[]
 for p:Vector3 in source.vertices:
  var cell:=Vector3i((p/EPS).floor());var found:=-1
  for z in range(-1,2):
   for y in range(-1,2):
    for x in range(-1,2):
     for index:int in buckets.get(cell+Vector3i(x,y,z),[]):
      if points[index].distance_squared_to(p)<EPS*EPS:found=index;break
     if found>=0:break
    if found>=0:break
   if found>=0:break
  if found<0:
   found=points.size();points.append(p)
   if not buckets.has(cell):buckets[cell]=[]
   buckets[cell].append(found)
  indices.append(found)
 var result:=BedSurface.new();var seen:Dictionary={}
 for i in range(0,indices.size(),3):
  var ids:Array=[indices[i],indices[i+1],indices[i+2]]
  if ids[0]==ids[1] or ids[1]==ids[2] or ids[0]==ids[2]:continue
  var ab:=points[ids[1]]-points[ids[0]];var ac:=points[ids[2]]-points[ids[0]]
  if ab.cross(ac).length_squared()<ab.length_squared()*ac.length_squared()*1e-10:continue
  var key:=ids.duplicate();key.sort()
  var label:=str(key)
  if seen.has(label):continue
  seen[label]=true
  result.triangle(points[ids[0]],points[ids[1]],points[ids[2]],Color.WHITE)
 return result

static func height_at(data,p:Vector2,level:int,shores:Array)->float:
 var h:float=level*.5;var sample:=p-Vector2.ONE*.5;var cell:=Vector2i(sample.floor());var f:=sample-Vector2(cell)
 var total:=0.0;var weight:=0.0
 for z in 2:
  for x in 2:
   var record:Dictionary=data.cells.get(cell+Vector2i(x,z),{})
   if record.is_empty() or int(record.water)!=level:continue
   var w:float=(f.x if x else 1.0-f.x)*(f.y if z else 1.0-f.y)
   total+=float(record.height)*w;weight+=w
 var bed:=minf(h-.06,total/weight if weight>.000001 else h-.30)
 var distance:=INF
 for edge:Array in shores:distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,edge[0],edge[1])))
 return lerpf(h-.06,bed,smoothstep(.0,1.45,distance))
