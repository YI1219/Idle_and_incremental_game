extends RefCounted
## Fractured side stones over a continuous, faceted bottom envelope.
## World-anchored Voronoi cells avoid horizontal courses and keep edits local.
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface
const SIZE:=4.8

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

static func _top_at(p:Vector2,regions:Dictionary,cells:Dictionary)->float:
 if not cells.is_empty():
  var cell:=Vector2i(p.floor())
  var rec:Dictionary=cells.get(cell,{})
  if not rec.is_empty():
   return float(rec.water)*.5 if int(rec.get("water",-1))>=0 else float(rec.height)
  for dz in range(-1,2):
   for dx in range(-1,2):
    var near:Dictionary=cells.get(cell+Vector2i(dx,dz),{})
    if not near.is_empty() and p.distance_squared_to(Vector2(cell+Vector2i(dx,dz))+Vector2(.5,.5))<=.55:
     return float(near.water)*.5 if int(near.get("water",-1))>=0 else float(near.height)
  return -INF
 var top:=-INF
 for level:float in regions:
  if preload("res://scripts/terrain_editor/contour_terrain.gd").contains(regions[level],p):top=maxf(top,level)
 return top

static func build(source,regions:Dictionary={},cells:Dictionary={})->Dictionary:
 var ContourTerrain=preload("res://scripts/terrain_editor/contour_terrain.gd")
 var region_signs:Dictionary={}
 for level:float in regions:
  var signs:=PackedInt32Array()
  for loop:PackedVector2Array in regions[level]:signs.append(1 if ContourTerrain._area(loop)>0 else -1)
  region_signs[level]=signs
 var patches:Dictionary={};var planes:Dictionary={};var caps:Dictionary={}
 var backing:=Surface.new();var stone:=Surface.new();var bodies:Array=[]
 var shared_normals:Dictionary={};var base_vertices:Dictionary={};var shared_caps:Dictionary={}
 for i in range(0,source.vertices.size(),3):
  var weighted:Vector3=-(source.vertices[i+1]-source.vertices[i]).cross(source.vertices[i+2]-source.vertices[i])
  for j in 3:
   var key:=Vector3i((source.vertices[i+j]*10000).round())
   shared_normals[key]=shared_normals.get(key,Vector3.ZERO)+weighted
   shared_caps[key]=minf(shared_caps.get(key,INF),source.uv[i+j].x)
   if source.uv[i+j].y<-.5:base_vertices[key]=true
 for i in range(0,source.vertices.size(),3):
  var tri:Array=[source.vertices[i],source.vertices[i+1],source.vertices[i+2]]
  var normal:Vector3=-(tri[1]-tri[0]).cross(tri[2]-tri[0]).normalized()
  var h:float=source.uv[i].x
  var base:bool=source.uv[i].y<-.5
  # Keep backing close behind the outer blocks so it never forms a deep concave bowl;
  # modest recession avoids coplanar z-fighting while preventing narrow peninsula crossover.
  var start:=backing.vertices.size()
  var inset:Array=[]
  for p:Vector3 in tri:
   var point_key:=Vector3i((p*10000).round())
   var shared:Vector3=shared_normals[point_key].normalized()
   # A shared edge has one position even where its incident faces belong to
   # different terraces. The lowest cap protects the receiving endpoint;
   # face-local heights split the backing apart at high/low wall junctions.
   var cap:float=shared_caps[point_key]
   var recess:=0.0 if base_vertices.has(point_key) else .68*smoothstep(.45,1.25,cap-p.y)*lerpf(.22,1.0,smoothstep(-4.0,-1.4,p.y))
   # A terrace wall must stay seated on its receiving land or pond. Full
   # normal recession lifts its exposed foot away from that cap and can
   # pull it below the water, opening a view into the island's underside.
   if recess>0.0:
    var outward:=Vector2(shared.x,shared.z).normalized()
    var support:float=_top_at(Vector2(p.x,p.z)+outward*.95,regions,cells)
    if is_finite(support) and support<cap-.1:
     recess*=smoothstep(support+.08,support+.80,p.y)
   inset.append(p-shared*recess)
  backing.triangle(inset[0],inset[1],inset[2],Color(.78,.78,.78))
  for j in range(start,backing.vertices.size()):backing.uv[j]=source.uv[i+j-start]
  # Extrude crisp 3D Voronoi polyhedral hull stones across the mid-to-lower inward-tapering
  # island shell so the entire underside converges as one unified carved rock mountain!
  if not cells.is_empty() and cells.size()<=6:continue
  if base or normal.y<-.78:continue
  var poly:=_clip(inset,Vector3.UP,minf(h-2.15,-0.45))
  poly=_clip(poly,Vector3.DOWN,4.5-h)
  if poly.size()<3:continue
  var box:=AABB(poly[0],Vector3.ZERO)
  for p:Vector3 in poly:box=box.expand(p)
  var box_center:=box.get_center()
  var max_r2:=(SIZE*1.35)*(SIZE*1.35)
  for z in range(floori(box.position.z/SIZE),floori(box.end.z/SIZE)+1):
   for y in range(floori(box.position.y/SIZE),floori(box.end.y/SIZE)+1):
    for x in range(floori(box.position.x/SIZE),floori(box.end.x/SIZE)+1):
     var key:=Vector3i(x,y,z);var center:=_seed(key)
     if center.distance_squared_to(box_center)>max_r2:continue
     if not planes.has(key):
      var cuts:Array=[]
      for dz in range(-1,2):
       for dy in range(-1,2):
        for dx in range(-1,2):
         var manhattan:=absi(dx)+absi(dy)+absi(dz)
         if manhattan==0 or manhattan>2:continue
         var other:=_seed(key+Vector3i(dx,dy,dz));var n:=other-center
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
  var raw_pieces:Array=patches[key]
  var seed_n:=Vector3.ZERO
  var seed_c:=Vector3.ZERO
  var best_w:=-1.0
  for poly:Array in raw_pieces:
   var pn:=Vector3.ZERO;var pc:=Vector3.ZERO;var pw:=0.0
   for j in range(1,poly.size()-1):
    var cr:Vector3=-(poly[j]-poly[0]).cross(poly[j+1]-poly[0])
    var w:=cr.length()
    pn+=cr;pc+=(poly[0]+poly[j]+poly[j+1])/3.0*w;pw+=w
   if pw>best_w and pn.length_squared()>.00001:
    best_w=pw;seed_n=pn.normalized();seed_c=pc/pw
  if best_w<=0.0:continue
  var pieces:Array=[]
  for poly:Array in raw_pieces:
   var pn:=Vector3.ZERO;var pc:=Vector3.ZERO;var pw:=0.0
   for j in range(1,poly.size()-1):
    var cr:Vector3=-(poly[j]-poly[0]).cross(poly[j+1]-poly[0])
    var w:=cr.length()
    pn+=cr;pc+=(poly[0]+poly[j]+poly[j+1])/3.0*w;pw+=w
   if pw>.0001 and pn.length_squared()>.00001 and pn.normalized().dot(seed_n)>=.72 and (pc/pw).distance_to(seed_c)<=2.75:
    pieces.append(poly)
  if pieces.is_empty():continue
  var center:=Vector3.ZERO;var normal:=Vector3.ZERO;var area:=0.0
  for poly:Array in pieces:
   for j in range(1,poly.size()-1):
    var cross:Vector3=-(poly[j]-poly[0]).cross(poly[j+1]-poly[0])
    var weight:=cross.length()
    center+=(poly[0]+poly[j]+poly[j+1])/3.0*weight;normal+=cross;area+=weight
  if area<.32 or normal.length_squared()<.00001:continue
  center/=area;normal=normal.normalized()
  var min_plane_d:=0.0
  for poly:Array in pieces:
   for p:Vector3 in poly:min_plane_d=minf(min_plane_d,(p-center).dot(normal))
  if normal.y<-.85:
   normal=(normal+Vector3((_hash(Vector3(key)+Vector3(1,4,3))-.5)*.85,0,(_hash(Vector3(key)+Vector3(4,9,8))-.5)*.85)).normalized()
  var choice:=_hash(Vector3(key)+Vector3(29,11,8))
  var scale:=.998 if choice<.78 else .972
  var offset:=lerpf(-.20,-.05,_hash(Vector3(key)+Vector3(5,11,21)))
  if normal.y<-.34:offset=lerpf(-.10,.02,choice)
  if min_plane_d<-0.14:offset+=min_plane_d+0.10
  var depth:=1.55+choice*.95
  var body:=Surface.new()
  var tv:=.94+choice*.12
  var tint:=Color(tv,tv,tv,1.0)
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
    var e1:=(previous-hull[j]).normalized();var e2:=(following-hull[j]).normalized()
    if e1.dot(e2)>0.82:
     hull.remove_at(j);changed=true;break
  var rect:=Rect2(hull[0],Vector2.ZERO)
  for p:Vector2 in hull:rect=rect.expand(p)
  if minf(rect.size.x,rect.size.y)<.28:continue
  var outline:Array=[]
  var cr_ang:=(_hash(Vector3(key)+Vector3(13,7,19))-.5)*1.45
  var crease:=Vector3(cos(cr_ang),sin(cr_ang),0).normalized();var cut:=(choice-.5)*.38
  for p:Vector2 in hull:outline.append(Vector3(p.x,p.y,0))
  var faces:Array=[outline]
  if choice>.24:
   faces=[_clip(outline,crease,cut),_clip(outline,-crease,-cut)]
   var divided:Array=[]
   for j in outline.size():
    var a:Vector3=outline[j];var b:Vector3=outline[(j+1)%outline.size()]
    var da:=crease.dot(a)-cut;var db:=crease.dot(b)-cut
    divided.append(a)
    if da*db<-.0000001:divided.append(a.lerp(b,da/(da-db)))
   outline=divided
  var front:Array=[]
  for p:Vector3 in outline:front.append(_face_point(p,center,axis,other,normal,offset,choice,caps[key]-.18,crease,cut))
  var ceiling:float=caps[key]-.18
  var footprint:=Rect2(Vector2(front[0].x,front[0].z),Vector2.ZERO)
  for p:Vector3 in front:
   footprint=footprint.expand(Vector2(p.x,p.z))
   var back:=p-normal*depth
   footprint=footprint.expand(Vector2(back.x,back.z))
  for z in range(floori(footprint.position.y/.65),ceili(footprint.end.y/.65)+1):
   for x in range(floori(footprint.position.x/.65),ceili(footprint.end.x/.65)+1):
    var at:=Vector2(x*.65,z*.65)
    var top:=_top_at(at,regions,cells)
    if top!=-INF:ceiling=minf(ceiling,top-.22)
  for j in front.size():front[j].y=minf(front[j].y,ceiling)
  for face_idx in faces.size():
   var face:Array=faces[face_idx]
   var face_tint:Color=tint*(1.05 if face_idx==0 else .92)
   var points:Array=[]
   for p:Vector3 in face:points.append(_face_point(p,center,axis,other,normal,offset,choice,ceiling,crease,cut))
   for j in range(1,points.size()-1):body.triangle(points[0],points[j+1],points[j],face_tint)
  var rear:=center-normal*depth;rear.y=minf(rear.y,ceiling)
  for j in front.size():
   var a:Vector3=front[j];var b:Vector3=front[(j+1)%front.size()]
   var back_a:=a-normal*depth;var back_b:=b-normal*depth
   back_a.y=minf(back_a.y,ceiling);back_b.y=minf(back_b.y,ceiling)
   body.triangle(rear,back_a,back_b,tint*.70)
   body.quad(a,b,back_b,back_a,tint*.78)
  _soften_surface(body,12.0,.24)
  stone.vertices.append_array(body.vertices);stone.normals.append_array(body.normals)
  stone.colors.append_array(body.colors);stone.uv.append_array(body.uv)
  bodies.append({"key":key,"surface":body,"area":area*.5,"depth":depth})
 return {"backing":backing,"stone":stone,"bodies":bodies}

static func _soften_surface(surf,crease_deg:float,strength:float)->void:
 if surf.normals.size()!=surf.vertices.size():return
 var cos_lim:=cos(deg_to_rad(crease_deg))
 var groups:Dictionary={}
 for i in surf.vertices.size():
  var k:=Vector3i(roundi(surf.vertices[i].x*10000),roundi(surf.vertices[i].y*10000),roundi(surf.vertices[i].z*10000))
  if not groups.has(k):groups[k]=[]
  groups[k].append(i)
 var out_n:=PackedVector3Array();out_n.resize(surf.normals.size())
 for indices:Array in groups.values():
  for i:int in indices:
   var sum:=Vector3.ZERO
   for j:int in indices:
    var nb:Vector3=surf.normals[j].normalized()
    if surf.normals[i].normalized().dot(nb)>=cos_lim:sum+=nb
   if sum.length_squared()<1e-6:sum=surf.normals[i]
   out_n[i]=surf.normals[i].normalized().lerp(sum.normalized(),strength).normalized()
 surf.normals=out_n

static func _face_point(p:Vector3,center:Vector3,axis:Vector3,other:Vector3,normal:Vector3,offset:float,choice:float,ceiling:float,crease:Vector3=Vector3(.65,.30,0),cut:float=0.0)->Vector3:
 var distance:=p.dot(crease)-cut
 var relief:=distance*.14
 if choice>.24:relief-=maxf(0.0,distance)*(.38+choice*.24)
 var point:=center+axis*p.x+other*p.y+normal*(offset+relief)
 point.y=minf(point.y,ceiling)
 return point

static func close_base(source,regions:Dictionary={},floor_shift:Callable=Callable(),flat_floor:float=NAN,cells:Dictionary={})->void:
 # Close the actual low boundary of the existing cliff envelope, not the
 # lawn outline or upper join skirts. UV.y=-1 keeps closure out of side-block extrusion.
 var edges:Dictionary={};var points:Dictionary={};var neighbors:Dictionary={};var owners:Dictionary={}
 var cap_height:=1.5
 if not regions.is_empty():cap_height=regions.keys().min()
 var floor_cache:Dictionary={}
 for i in range(0,source.vertices.size(),3):
  if source.uv[i].y>1.5:continue
  for j in 3:
   var a:Vector3=source.vertices[i+j];var b:Vector3=source.vertices[i+(j+1)%3]
   if maxf(a.y,b.y)>=0:continue
   var ka:=Vector3i((a*10000).round());var kb:=Vector3i((b*10000).round())
   var key:Array=[ka,kb] if ka<kb else [kb,ka]
   edges[key]=edges.get(key,0)+1;points[ka]=a;points[kb]=b
   owners[ka]=source.uv[i+j].x;owners[kb]=source.uv[i+(j+1)%3].x
 for key:Array in edges:
  if edges[key]!=1:continue
  var a:Vector3=points[key[0]];var b:Vector3=points[key[1]]
  var support:float=minf(owners[key[0]],owners[key[1]])
  if cap_height<0:
   var middle:=Vector2((a.x+b.x)*.5,(a.z+b.z)*.5)
   for offset:Vector2 in [Vector2.ZERO,Vector2(.3,0),Vector2(-.3,0),Vector2(0,.3),Vector2(0,-.3)]:
    var top:=_top_at(middle+offset,regions,cells)
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
  for j in chain.size():
   var next:=(j+1)%chain.size()
   var a:Vector3=chain[j];var b:Vector3=chain[next]
   var cuts:Array[float]=[0.0,1.0]
   for axis:Vector2 in [Vector2.RIGHT,Vector2.DOWN,Vector2(1,-1)]:
    var av:=Vector2(a.x,a.z).dot(axis);var bv:=Vector2(b.x,b.z).dot(axis)
    if absf(bv-av)<.00001:continue
    for line in range(floori(minf(av,bv)/3.5)+1,ceili(maxf(av,bv)/3.5)):
     var t:float=(line*3.5-av)/(bv-av)
     if t>.00001 and t<.99999:cuts.append(t)
   cuts.sort()
   for k in cuts.size()-1:
    if cuts[k+1]-cuts[k]<.000001:continue
    var l:=a.lerp(b,cuts[k]);var r:=a.lerp(b,cuts[k+1])
    var fl_y:float=flat_floor if is_finite(flat_floor) else clampf(_closure_y(Vector2(l.x,l.z),regions,floor_cache,chains,floor_shift,cells),l.y-.14,l.y)
    var fr_y:float=flat_floor if is_finite(flat_floor) else clampf(_closure_y(Vector2(r.x,r.z),regions,floor_cache,chains,floor_shift,cells),r.y-.14,r.y)
    var fl:=Vector3(l.x,fl_y,l.z)
    var fr:=Vector3(r.x,fr_y,r.z)
    var start:int=source.vertices.size()
    source.quad(r,l,fl,fr,Color.WHITE)
    for vertex in range(start,source.vertices.size()):source.uv[vertex]=Vector2(1.5,-1)
 if loops.is_empty():return
 var bounds:=Rect2(loops[0][0],Vector2.ZERO)
 for polygon:PackedVector2Array in loops:
  for p:Vector2 in polygon:bounds=bounds.expand(p)
 var cap_helper=preload("res://scripts/terrain_editor/contour_terrain.gd").new()
 const TILE:=3.5
 for z in range(floori(bounds.position.y/TILE),ceili(bounds.end.y/TILE)):
  for x in range(floori(bounds.position.x/TILE),ceili(bounds.end.x/TILE)):
   var corner:=Vector2(x,z)*TILE
   var tiles:Array=[PackedVector2Array([corner,corner+Vector2(TILE,0),corner+Vector2(TILE,TILE)]),PackedVector2Array([corner,corner+Vector2(TILE,TILE),corner+Vector2(0,TILE)])]
   for tile:PackedVector2Array in tiles:
    var pieces:Array=[]
    for polygon:PackedVector2Array in loops:
     var hole:=Geometry2D.is_polygon_clockwise(polygon)
     for piece:PackedVector2Array in Geometry2D.intersect_polygons(polygon,tile):
      if Geometry2D.is_polygon_clockwise(piece)!=hole:piece.reverse()
      pieces.append(piece)
    if pieces.is_empty():continue
    var floor_surface:=Surface.new()
    cap_helper._cap(floor_surface,pieces,-2.25,Color.WHITE,PackedFloat32Array(),true)
    for j in floor_surface.vertices.size():
     var point:Vector3=floor_surface.vertices[j]
     point.y=flat_floor if is_finite(flat_floor) else _closure_y(Vector2(point.x,point.z),regions,floor_cache,chains,floor_shift,cells)
     floor_surface.vertices[j]=point
    for j in range(0,floor_surface.vertices.size(),3):
     var start:int=source.vertices.size()
     source.triangle(floor_surface.vertices[j],floor_surface.vertices[j+2],floor_surface.vertices[j+1],Color.WHITE)
     for k in range(start,source.vertices.size()):source.uv[k]=Vector2(1.5,-1)

static func _base_y(p:Vector2,regions:Dictionary,cache:Dictionary,floor_shift:Callable=Callable(),cells:Dictionary={})->float:
 var key:=Vector2i((p/2.0).floor());var f:=p/2.0-Vector2(key)
 return lerpf(lerpf(_base_node(key,regions,cache,floor_shift,cells),_base_node(key+Vector2i.RIGHT,regions,cache,floor_shift,cells),f.x),lerpf(_base_node(key+Vector2i.DOWN,regions,cache,floor_shift,cells),_base_node(key+Vector2i.ONE,regions,cache,floor_shift,cells),f.x),f.y)

static func _base_node(key:Vector2i,regions:Dictionary,cache:Dictionary,floor_shift:Callable=Callable(),cells:Dictionary={})->float:
 if cache.has(key):return cache[key]
 var low:=1.5
 var inside_count:=0
 for z in range(-2,3):
  for x in range(-2,3):
   var p:=Vector2(key)*2.0+Vector2(x,z)*.95
   var top:=_top_at(p,regions,cells)
   if top!=-INF:
    low=minf(low,top)
    inside_count+=1
 # Narrow brush extrusions (low inside_count) always stay below -1.75 (never >= 0)
 # so close_base never skips an edge or creates a vertical knife-blade; broad
 # island lobes converge into bold asymmetric mountain keels (-4.85..-6.15).
 var span_weight:=clampf((float(inside_count)-3.0)/10.0,0.0,1.0)
 var core_weight:=clampf((float(inside_count)-13.0)/10.0,0.0,1.0)
 var p:=Vector2(key)*2.0
 var center_inside:=_top_at(p,regions,cells)!=-INF
 var near_count:=0
 for offset:Vector2 in [Vector2(2.2,0),Vector2(-2.2,0),Vector2(0,2.2),Vector2(0,-2.2),Vector2(1.6,1.6),Vector2(-1.6,1.6),Vector2(1.6,-1.6),Vector2(-1.6,-1.6)]:
  if _top_at(p+offset,regions,cells)!=-INF:near_count+=1
 # Tuck narrow hourglass pinches & concave bays cleanly above cliff feet so no tip pokes below concave corners:
 if not center_inside or near_count<7:
  span_weight=minf(span_weight,float(near_count)/8.0*.28 if center_inside else .04)
  core_weight=0.0
 var relief:=.24*sin(p.x*.27+p.y*.19)+.16*cos(p.y*.38-p.x*.16+1.4)
 var keel_lobe_a:=exp(-p.distance_squared_to(Vector2(3.2,2.6))/40.0)*.75
 var keel_lobe_b:=exp(-p.distance_squared_to(Vector2(-10.2,-2.2))/36.0)*.65
 var shallow_floor:=minf(-1.75,low-1.65)
 var deep_floor:=minf(-3.35,low-1.5)+relief-(keel_lobe_a+keel_lobe_b)*core_weight
 cache[key]=lerpf(shallow_floor,deep_floor,span_weight)
 if floor_shift.is_valid():cache[key]=minf(low-.5,cache[key]+float(floor_shift.call(p))*clampf((low+4.0)/4.0,0,1))
 return cache[key]

static func _closure_y(p:Vector2,regions:Dictionary,cache:Dictionary,chains:Array,floor_shift:Callable=Callable(),cells:Dictionary={})->float:
 var key:=Vector2i((p/2.0).floor());var f:=p/2.0-Vector2(key)
 var a:=_closure_node(key,regions,cache,chains,floor_shift,cells)
 var c:=_closure_node(key+Vector2i.ONE,regions,cache,chains,floor_shift,cells)
 if f.x>=f.y:return a*(1.0-f.x)+_closure_node(key+Vector2i.RIGHT,regions,cache,chains,floor_shift,cells)*(f.x-f.y)+c*f.y
 return a*(1.0-f.y)+c*f.x+_closure_node(key+Vector2i.DOWN,regions,cache,chains,floor_shift,cells)*(f.y-f.x)

static func _closure_node(key:Vector2i,regions:Dictionary,cache:Dictionary,chains:Array,floor_shift:Callable=Callable(),cells:Dictionary={})->float:
 var cache_key:=Vector3i(key.x,991,key.y)
 if cache.has(cache_key):return cache[cache_key]
 var p:=Vector2(key)*2.0;var distance:=INF;var edge_y:=0.0
 for chain:Array in chains:
  for i in chain.size():
   var a:Vector3=chain[i];var b:Vector3=chain[(i+1)%chain.size()]
   var av:=Vector2(a.x,a.z);var bv:=Vector2(b.x,b.z)
   var point:=Geometry2D.get_closest_point_to_segment(p,av,bv)
   var d:=p.distance_to(point)
   if d<distance:
    distance=d;edge_y=lerpf(a.y,b.y,av.distance_to(point)/maxf(.00001,av.distance_to(bv)))
 cache[cache_key]=lerpf(edge_y-.06,_base_y(p,regions,cache,floor_shift,cells),smoothstep(1.65,4.8,distance))
 return cache[cache_key]
