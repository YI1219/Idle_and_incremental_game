extends RefCounted
## Clip only local half-metre triangles; extra contour vertices do not cut the whole lake.
const STEP:float=.5
const VERSION:int=1
static func build(field,surface_class,sample_height:Callable):
 var result=surface_class.new()
 for level:int in field.water_regions:
  var h:float=level*.5;var loops:Array=field.water_regions[level];var shores:Array=[]
  var low:=Vector2(INF,INF);var high:=-low
  for loop:PackedVector2Array in loops:
   for i:int in loop.size():
    var a:=loop[i];var b:=loop[(i+1)%loop.size()];low=low.min(a);high=high.max(a)
    var out:=Vector2(b.y-a.y,a.x-b.x).normalized()
    if field.shore_support((a+b)*.5,out,h,.30):shores.append([a,b])
  var cache:Dictionary={}
  for z:int in range(floori(low.y/STEP),ceili(high.y/STEP)):
   for x:int in range(floori(low.x/STEP),ceili(high.x/STEP)):
    var p:=Vector2(x,z)*STEP
    var tiles:Array=[PackedVector2Array([p,p+Vector2(STEP,0),p+Vector2(STEP,STEP)]),PackedVector2Array([p,p+Vector2(STEP,STEP),p+Vector2(0,STEP)])]
    for tile:PackedVector2Array in tiles:
     var pieces:Array=[]
     for loop:PackedVector2Array in loops:
      var hole:bool=field._area(loop)<0
      for piece:PackedVector2Array in Geometry2D.intersect_polygons(loop,tile):
       if (field._area(piece)<0)!=hole:piece.reverse()
       pieces.append(piece)
     if pieces.is_empty():continue
     var flat=surface_class.new();field._cap(flat,pieces,h,Color.WHITE)
     for i:int in range(0,flat.vertices.size(),3):
      var points:Array[Vector3]=[]
      for j:int in 3:
       var at:=Vector2(flat.vertices[i+j].x,flat.vertices[i+j].z).snapped(Vector2.ONE*.00001)
       points.append(Vector3(at.x,_height(at,field.source,level,shores,cache,sample_height),at.y))
      result.triangle(points[0],points[1],points[2],Color(level/255.0,0,0),true)
  for loop:PackedVector2Array in loops:
   for i:int in loop.size():
    var a:=loop[i];var b:=loop[(i+1)%loop.size()];var ts:Array[float]=[0.0,1.0]
    for axis:Vector2 in [Vector2.RIGHT,Vector2.DOWN,Vector2(1,-1)]:
     var av:float=a.dot(axis);var bv:float=b.dot(axis)
     if absf(av-bv)<.000001:continue
     for line:int in range(floori(minf(av,bv)/STEP)+1,ceili(maxf(av,bv)/STEP)):
      var t:float=(line*STEP-av)/(bv-av)
      if t>.000001 and t<.999999:ts.append(t)
    ts.sort()
    for j:int in ts.size()-1:
     var p:=a.lerp(b,ts[j]).snapped(Vector2.ONE*.00001);var q:=a.lerp(b,ts[j+1]).snapped(Vector2.ONE*.00001)
     if p.distance_squared_to(q)<1e-14:continue
     result.quad(Vector3(p.x,h,p.y),Vector3(p.x,_height(p,field.source,level,shores,cache,sample_height),p.y),Vector3(q.x,_height(q,field.source,level,shores,cache,sample_height),q.y),Vector3(q.x,h,q.y),Color(level/255.0,0,0))
 return result

static func conform(source,surface_class):
 # Polygon clipping/ear triangulation may remove a collinear point on just
 # one side of a tile edge. Insert all shared points before publishing, so
 # a short edge meets the same two vertices on its neighboring triangle.
 var buckets:Dictionary={};var unique:Dictionary={}
 for p:Vector3 in source.vertices:
  if unique.has(p):continue
  unique[p]=true
  var cell:=Vector2i((Vector2(p.x,p.z)/STEP).floor())
  if not buckets.has(cell):buckets[cell]=[]
  buckets[cell].append(p)
 var result=surface_class.new()
 for i:int in range(0,source.vertices.size(),3):
  var ring:Array[Vector3]=[];var split:bool=false
  for j:int in 3:
   var a:Vector3=source.vertices[i+j];var b:Vector3=source.vertices[i+(j+1)%3]
   ring.append(a)
   var ab:=b-a;var length2:=ab.length_squared();var interior:Array=[]
   var lo:Vector2i=Vector2i((Vector2(minf(a.x,b.x),minf(a.z,b.z))/STEP).floor())-Vector2i.ONE
   var hi:Vector2i=Vector2i((Vector2(maxf(a.x,b.x),maxf(a.z,b.z))/STEP).floor())+Vector2i.ONE
   for z:int in range(lo.y,hi.y+1):
    for x:int in range(lo.x,hi.x+1):
     for p:Vector3 in buckets.get(Vector2i(x,z),[]):
      if p==a or p==b:continue
      var t:float=(p-a).dot(ab)/length2
      if t<=0.0 or t>=1.0 or p.distance_squared_to(a+ab*t)>1.21e-8:continue
      interior.append([t,p])
   interior.sort_custom(func(p:Array,q:Array):return p[0]<q[0])
   for entry:Array in interior:
    ring.append(entry[1]);split=true
  if not split:
   result.triangle(source.vertices[i],source.vertices[i+1],source.vertices[i+2],source.colors[i])
  else:
   var center:Vector3=(source.vertices[i]+source.vertices[i+1]+source.vertices[i+2])/3.0
   for j:int in ring.size():result.triangle(center,ring[j],ring[(j+1)%ring.size()],source.colors[i])
 return result
static func _node(key:Vector2i,data,level:int,shores:Array,cache:Dictionary,sample_height:Callable)->float:
 if not cache.has(key):cache[key]=sample_height.call(data,Vector2(key)*STEP,level,shores)
 return cache[key]
static func _height(p:Vector2,data,level:int,shores:Array,cache:Dictionary,sample_height:Callable)->float:
 var key:=Vector2i((p/STEP).floor());var f:=p/STEP-Vector2(key)
 var a:float=_node(key,data,level,shores,cache,sample_height);var c:float=_node(key+Vector2i.ONE,data,level,shores,cache,sample_height)
 if f.x>=f.y:return a*(1.0-f.x)+_node(key+Vector2i.RIGHT,data,level,shores,cache,sample_height)*(f.x-f.y)+c*f.y
 return a*(1.0-f.y)+c*f.x+_node(key+Vector2i.DOWN,data,level,shores,cache,sample_height)*(f.y-f.x)
