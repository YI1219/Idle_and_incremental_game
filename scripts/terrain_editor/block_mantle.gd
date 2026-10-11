extends RefCounted
## Closed, irregular stone volumes cut from the existing lower envelope.
## World-anchored Voronoi cells avoid horizontal courses and keep edits local.
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface
const SIZE:=2.7

static func _hash(p:Vector3)->float:
 return fposmod(sin(p.dot(Vector3(127.1,311.7,74.7)))*43758.5453,1.0)

static func _seed(k:Vector3i)->Vector3:
 var p:=Vector3(k)
 return (p+Vector3(.08+.84*_hash(p),.08+.84*_hash(p+Vector3(17,3,9)),.08+.84*_hash(p+Vector3(7,19,2))))*SIZE

static func _clip(poly:Array,n:Vector3,d:float)->Array:
 var result:Array=[]
 for i in poly.size():
  var a:Vector3=poly[i];var b:Vector3=poly[(i+1)%poly.size()]
  var da:=n.dot(a)-d;var db:=n.dot(b)-d
  if da<=.000001:result.append(a)
  if (da<-.000001 and db>.000001) or (db<-.000001 and da>.000001):result.append(a.lerp(b,da/(da-db)))
 return result

static func build(source,regions:Dictionary={})->Dictionary:
 var patches:Dictionary={};var planes:Dictionary={};var caps:Dictionary={}
 var backing:=Surface.new();var stone:=Surface.new();var bodies:Array=[]
 var shared_normals:Dictionary={}
 for i in range(0,source.vertices.size(),3):
  var weighted:Vector3=-(source.vertices[i+1]-source.vertices[i]).cross(source.vertices[i+2]-source.vertices[i])
  for j in 3:
   var key:=Vector3i((source.vertices[i+j]*10000).round())
   shared_normals[key]=shared_normals.get(key,Vector3.ZERO)+weighted
 for i in range(0,source.vertices.size(),3):
  var tri:Array=[source.vertices[i],source.vertices[i+1],source.vertices[i+2]]
  var normal:Vector3=-(tri[1]-tri[0]).cross(tri[2]-tri[0]).normalized()
  var h:float=source.uv[i].x
  # The upper join stays untouched behind crowns. Lower backing is buried;
  # every visible patch has its own front, back, and deep fracture side walls.
  var start:=backing.vertices.size()
  var inset:Array=[]
  for p:Vector3 in tri:
   var shared:Vector3=shared_normals[Vector3i((p*10000).round())].normalized()
   inset.append(p-shared*.42*smoothstep(.7,1.3,h-p.y))
  backing.triangle(inset[0],inset[1],inset[2],Color(.76,.78,.81))
  for j in range(start,backing.vertices.size()):backing.uv[j]=source.uv[i+j-start]
  var poly:=_clip(tri,Vector3.UP,h-.85)
  if poly.size()<3:continue
  var box:=AABB(poly[0],Vector3.ZERO)
  for p:Vector3 in poly:box=box.expand(p)
  for z in range(floori(box.position.z/SIZE)-1,floori(box.end.z/SIZE)+2):
   for y in range(floori(box.position.y/SIZE)-1,floori(box.end.y/SIZE)+2):
    for x in range(floori(box.position.x/SIZE)-1,floori(box.end.x/SIZE)+2):
     var key:=Vector3i(x,y,z);var center:=_seed(key)
     if not planes.has(key):
      var cuts:Array=[]
      for dz in range(-1,2):
       for dy in range(-1,2):
        for dx in range(-1,2):
         if dx==0 and dy==0 and dz==0:continue
         var other:=_seed(key+Vector3i(dx,dy,dz));var n:=other-center
         # A weighted partition gives unequal blocks while each shared
         # fracture plane remains complementary to its neighbour.
         var weight:=(_hash(Vector3(key)+Vector3(31,9,5))-.5)*3.8
         var other_weight:=(_hash(Vector3(key+Vector3i(dx,dy,dz))+Vector3(31,9,5))-.5)*3.8
         cuts.append(Plane(n.normalized(),n.normalized().dot((center+other)*.5)+(weight-other_weight)/(2.0*n.length())))
      planes[key]=cuts
     var piece:=poly
     for plane:Plane in planes[key]:
      piece=_clip(piece,plane.normal,plane.d)
      if piece.size()<3:break
     if piece.size()<3:continue
     if not patches.has(key):patches[key]=[]
     patches[key].append(piece)
     caps[key]=minf(caps.get(key,INF),h)
 for key:Vector3i in patches:
  var pieces:Array=patches[key]
  var center:=Vector3.ZERO;var normal:=Vector3.ZERO;var area:=0.0
  for poly:Array in pieces:
   for j in range(1,poly.size()-1):
    var cross:Vector3=-(poly[j]-poly[0]).cross(poly[j+1]-poly[0])
    var weight:=cross.length()
    center+=(poly[0]+poly[j]+poly[j+1])/3.0*weight;normal+=cross;area+=weight
  if area<.30 or normal.length_squared()<.00001:continue
  center/=area;normal=normal.normalized()
  if normal.y<-.85:
   normal=(normal+Vector3((_hash(Vector3(key)+Vector3(1,4,3))-.5)*.50,0,(_hash(Vector3(key)+Vector3(4,9,8))-.5)*.50)).normalized()
  var choice:=_hash(Vector3(key)+Vector3(29,11,8))
  var scale:=.992 if choice<.72 else .947
  var offset:=lerpf(-.06,.16,_hash(Vector3(key)+Vector3(5,11,21)))
  if normal.y<-.85:offset=lerpf(-.08,.55,choice*choice)
  var depth:=1.10+choice*.85
  var body:=Surface.new()
  var tint:=Color(.90+choice*.12,.94+choice*.08,1.0-choice*.025)
  var axis:=normal.cross(Vector3.UP).normalized()
  if axis.length_squared()<.01:axis=Vector3.RIGHT
  var other:=normal.cross(axis).normalized()
  var projected:=PackedVector2Array()
  for poly:Array in pieces:
   for p:Vector3 in poly:projected.append(Vector2((p-center).dot(axis),(p-center).dot(other))*scale)
  var hull:=Geometry2D.convex_hull(projected)
  if hull.size()<4:continue
  hull.remove_at(hull.size()-1)
  var changed:=true
  while changed and hull.size()>3:
   changed=false
   for j in hull.size():
    var previous:=hull[(j+hull.size()-1)%hull.size()];var following:=hull[(j+1)%hull.size()]
    if hull[j].distance_to(Geometry2D.get_closest_point_to_segment(hull[j],previous,following))<.004:
     hull.remove_at(j);changed=true;break
  var rect:=Rect2(hull[0],Vector2.ZERO)
  for p:Vector2 in hull:rect=rect.expand(p)
  if minf(rect.size.x,rect.size.y)<.28:continue
  var front:Array=[]
  for p:Vector2 in hull:
   var point:=center+axis*p.x+other*p.y+normal*offset
   point.y=minf(point.y,caps[key]-.18)
   front.append(point)
  # A terrace may put lower lawn next to a higher cliff. Bound the whole
  # solid beneath any lawn its footprint crosses, including the buried back;
  # a closed volume must not turn into a grey shelf through that lower lawn.
  var ceiling:float=caps[key]-.18
  var footprint:=Rect2(Vector2(front[0].x,front[0].z),Vector2.ZERO)
  for p:Vector3 in front:
   footprint=footprint.expand(Vector2(p.x,p.z))
   var back:=p-normal*depth
   footprint=footprint.expand(Vector2(back.x,back.z))
  for z in range(floori(footprint.position.y/.3),ceili(footprint.end.y/.3)+1):
   for x in range(floori(footprint.position.x/.3),ceili(footprint.end.x/.3)+1):
    var at:=Vector2(x*.3,z*.3);var top:=-INF
    for level:float in regions:
     if preload("res://scripts/terrain_editor/contour_terrain.gd").contains(regions[level],at):top=maxf(top,level)
    if top!=-INF:ceiling=minf(ceiling,top-.18)
  for j in front.size():front[j].y=minf(front[j].y,ceiling)
  # A convex footprint closes slivers from the source triangulation instead
  # of extruding each triangle's internal edges into stray thin fins.
  # Eroded faces are broad, off-centre fracture shoulders rather
  # than a flat plate. Relief varies independently of cell size/depth.
  var relief:=.18+.85*pow(_hash(Vector3(key)+Vector3(7,41,13)),1.4)
  var middle:=center+normal*(offset+relief)
  var shoulder:Array=[]
  for j in front.size():
   var point:Vector3=center+(front[j]-center)*(.44+.25*_hash(Vector3(key)+Vector3(j,6,19)))+normal*(relief*.85)
   point.y=minf(point.y,ceiling)
   shoulder.append(point)
  middle.y=minf(middle.y,ceiling)
  var rear:=center-normal*depth;rear.y=minf(rear.y,ceiling)
  for j in front.size():
   var a:Vector3=front[j];var b:Vector3=front[(j+1)%front.size()]
   var ca:Vector3=shoulder[j];var cb:Vector3=shoulder[(j+1)%front.size()]
   body.triangle(middle,cb,ca,tint)
   body.quad(ca,cb,b,a,tint*(.92+.10*_hash(Vector3(key)+Vector3(j,3,7))))
   var back_a:=a-normal*depth;var back_b:=b-normal*depth
   back_a.y=minf(back_a.y,ceiling);back_b.y=minf(back_b.y,ceiling)
   body.triangle(rear,back_a,back_b,tint*.72)
   body.quad(a,b,back_b,back_a,tint*.80)
  stone.vertices.append_array(body.vertices);stone.normals.append_array(body.normals)
  stone.colors.append_array(body.colors);stone.uv.append_array(body.uv)
  bodies.append({"key":key,"surface":body,"area":area*.5,"depth":depth})
 return {"backing":backing,"stone":stone,"bodies":bodies}

static func close_base(source,regions:Dictionary={})->void:
 # Close the actual low boundary of the existing cliff envelope, not the
 # lawn outline. The same cell fracture pass then turns this cap into blocks.
 var edges:Dictionary={};var points:Dictionary={};var neighbors:Dictionary={};var owners:Dictionary={}
 var cap_height:=1.5
 if not regions.is_empty():cap_height=regions.keys().min()
 var floor_cache:Dictionary={}
 for i in range(0,source.vertices.size(),3):
  for j in 3:
   var a:Vector3=source.vertices[i+j];var b:Vector3=source.vertices[i+(j+1)%3]
   if maxf(a.y,b.y)>=0:continue
   var ka:=Vector3i((a*10000).round());var kb:=Vector3i((b*10000).round())
   var key:Array=[ka,kb] if ka<kb else [kb,ka]
   edges[key]=edges.get(key,0)+1;points[ka]=a;points[kb]=b
   owners[ka]=source.uv[i+j].x;owners[kb]=source.uv[i+(j+1)%3].x
 for key:Array in edges:
  if edges[key]!=1:continue
  # Negative-height edits must not mistake a lawn edge for a base edge.
  var a:Vector3=points[key[0]];var b:Vector3=points[key[1]]
  var support:float=minf(owners[key[0]],owners[key[1]])
  if cap_height<0:
   var middle:=Vector2((a.x+b.x)*.5,(a.z+b.z)*.5)
   for offset:Vector2 in [Vector2.ZERO,Vector2(.3,0),Vector2(-.3,0),Vector2(0,.3),Vector2(0,-.3)]:
    var top:=-INF
    for h:float in regions:
     if preload("res://scripts/terrain_editor/contour_terrain.gd").contains(regions[h],middle+offset):top=maxf(top,h)
    if top!=-INF:support=minf(support,top)
  if maxf(a.y,b.y)>support-.25:continue
  for j in 2:
   if not neighbors.has(key[j]):neighbors[key[j]]=[]
   neighbors[key[j]].append(key[1-j])
 var visited:Dictionary={};var loops:Array=[];var chains:Array=[]
 for first:Vector3i in neighbors:
  if visited.has(first):continue
  var chain:Array=[];var current:=first;var previous:=Vector3i(99999,99999,99999)
  var closed:=false
  for step in neighbors.size()+1:
   if visited.has(current):closed=current==first;break
   visited[current]=true;chain.append(points[current])
   var next=neighbors[current][0]
   if next==previous and neighbors[current].size()>1:next=neighbors[current][1]
   previous=current;current=next
  if not closed or chain.size()<3:continue
  var polygon:=PackedVector2Array()
  for p:Vector3 in chain:polygon.append(Vector2(p.x,p.z))
  loops.append(polygon);chains.append(chain)
 for i in loops.size():
  var polygon:PackedVector2Array=loops[i];var chain:Array=chains[i]
  var nesting:=0
  for j in loops.size():
   if j!=i and Geometry2D.is_point_in_polygon(polygon[0],loops[j]):nesting+=1
  var hole:=nesting%2==1
  if Geometry2D.is_polygon_clockwise(polygon)!=hole:
   polygon.reverse();chain.reverse()
  loops[i]=polygon
  var floor_chain:Array=[]
  for p:Vector3 in chain:floor_chain.append(Vector3(p.x,_base_y(Vector2(p.x,p.z),regions,floor_cache),p.z))
  for j in chain.size():
   var next:=(j+1)%chain.size();var start:int=source.vertices.size()
   source.quad(chain[next],chain[j],floor_chain[j],floor_chain[next],Color.WHITE)
   for k in range(start,source.vertices.size()):source.uv[k]=Vector2(1.5,0)
 if loops.is_empty():return
 var bounds:=Rect2(loops[0][0],Vector2.ZERO)
 for polygon:PackedVector2Array in loops:
  for p:Vector2 in polygon:bounds=bounds.expand(p)
 # World tiles keep floor triangulation local. A distant contour edit must
 # not insert scanlines through, or re-triangulate, every underside block.
 for z in range(floori(bounds.position.y/2),ceili(bounds.end.y/2)):
  for x in range(floori(bounds.position.x/2),ceili(bounds.end.x/2)):
   var tile:=PackedVector2Array([Vector2(x*2,z*2),Vector2(x*2+2,z*2),Vector2(x*2+2,z*2+2),Vector2(x*2,z*2+2)])
   var pieces:Array=[]
   for polygon:PackedVector2Array in loops:
    var hole:=Geometry2D.is_polygon_clockwise(polygon)
    for piece:PackedVector2Array in Geometry2D.intersect_polygons(polygon,tile):
     if Geometry2D.is_polygon_clockwise(piece)!=hole:piece.reverse()
     pieces.append(piece)
   var floor_surface:=Surface.new()
   preload("res://scripts/terrain_editor/contour_terrain.gd").new()._cap(floor_surface,pieces,-2.25,Color.WHITE,PackedFloat32Array(),true)
   for j in floor_surface.vertices.size():
    var point:Vector3=floor_surface.vertices[j]
    point.y=_base_y(Vector2(point.x,point.z),regions,floor_cache)
    floor_surface.vertices[j]=point
   for j in range(0,floor_surface.vertices.size(),3):
    var start:int=source.vertices.size()
    source.triangle(floor_surface.vertices[j],floor_surface.vertices[j+2],floor_surface.vertices[j+1],Color.WHITE)
    for k in range(start,source.vertices.size()):source.uv[k]=Vector2(1.5,0)

static func _base_y(p:Vector2,regions:Dictionary,cache:Dictionary)->float:
 var key:=Vector2i((p/2.0).floor());var f:=p/2.0-Vector2(key)
 return lerpf(lerpf(_base_node(key,regions,cache),_base_node(key+Vector2i.RIGHT,regions,cache),f.x),lerpf(_base_node(key+Vector2i.DOWN,regions,cache),_base_node(key+Vector2i.ONE,regions,cache),f.x),f.y)

static func _base_node(key:Vector2i,regions:Dictionary,cache:Dictionary)->float:
 if cache.has(key):return cache[key]
 var low:=1.5
 for z in range(-4,5):
  for x in range(-4,5):
   var p:=Vector2(key)*2.0+Vector2(x,z)*.5;var top:=-INF
   for h:float in regions:
    if preload("res://scripts/terrain_editor/contour_terrain.gd").contains(regions[h],p):top=maxf(top,h)
   if top!=-INF:low=minf(low,top)
 cache[key]=minf(-2.25,low-.95)
 return cache[key]
