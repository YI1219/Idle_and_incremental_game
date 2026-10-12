extends RefCounted
## A stone is the closed intersection of unequal fracture planes.
## Crowns and hanging roots use different cuts, rather than scaling one column.
static func build(seed_value:int,root:bool=false)->Dictionary:
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 var height:=1.0 if root else .68
 var planes:Array[Plane]=[Plane(Vector3.UP,0),Plane(Vector3.DOWN,height)]
 var sides:=(5+seed_value%2) if root else (7+seed_value%3)
 for i in sides:
  var angle:=TAU*(float(i)/sides+rng.randf_range(-.025,.025))
  var normal:=Vector3(cos(angle),rng.randf_range(-.07,.10),sin(angle))
  if not root:normal.y=0.0
  var wall:=Plane(normal,(rng.randf_range(.43,.56) if root else rng.randf_range(.32,.61)))
  planes.append(wall)
  # Fracture undercuts: staggered in depth, unequal in slope and orientation.
  var cut:=Vector3(normal.x,-rng.randf_range(.48,.62) if root else -rng.randf_range(.22,.44),normal.z)
  planes.append(Plane(cut,rng.randf_range(.68,.78) if root else rng.randf_range(.57,.70)))
  if i%2==0:
   var shoulder:=Plane(Vector3(normal.x,rng.randf_range(.75,1.3),normal.z),rng.randf_range(.38,.48))
   if root and i==2:planes.append(shoulder)
 var fracture_count:=planes.size()
 # The cap meets the side directly; local turf clusters soften its silhouette.
 var vertices:=_intersections(planes)
 var positions:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var uv:=PackedVector2Array()
 var crown_z:=0.0
 var bounds:=AABB(vertices[0],Vector3.ZERO)
 for v:Vector3 in vertices:bounds=bounds.expand(v)
 for index in planes.size():
  var plane:Plane=planes[index]
  var face:Array[Vector3]=[]
  var center:=Vector3.ZERO
  for v:Vector3 in vertices:
   if absf(plane.distance_to(v))<.00002:face.append(v);center+=v
  if face.size()<3:continue
  center/=face.size()
  var axis:=plane.normal.cross(Vector3.UP).normalized()
  if axis.length_squared()<.01:axis=Vector3.RIGHT
  var other:=plane.normal.normalized().cross(axis)
  face.sort_custom(func(a:Vector3,b:Vector3):return atan2((a-center).dot(other),(a-center).dot(axis))<atan2((b-center).dot(other),(b-center).dot(axis)))
  var shade:=rng.randf_range(.62,.70)
  var relief:=face.size()>3 and absf(plane.normal.normalized().y)<(.82 if root else .35) and (root or index<fracture_count)
  # The random draw stays so later shade values, and the legacy crown depth
  # below, keep the previous stream. Its sign is not a cut direction.
  var relief_draw:=rng.randf_range(-.09,.11)
  var chip:=.5+.5*sin(float(seed_value*17+index*31))
  var cap:=not root and index==0
  var outward_n:=plane.normal.normalized()
  # Legacy apex: negative relief folded the face into a pit. It is used only
  # to keep crown_z, which anchors the stone to the terrace, unchanged.
  var legacy_amount:=relief_draw
  if not root:legacy_amount=lerpf(-.085,.11,chip*chip)
  var legacy_apex:=center+outward_n*legacy_amount
  if not root and relief:legacy_apex+=(face[(seed_value+index)%face.size()]-center)*.32
  if cap:legacy_apex=center
  # Visible faces stay on their fracture planes. An apex pushed through a
  # plane — inward, or sideways past a neighbour — folds a large triangle
  # into a pit. The unequal planes are already the convex cuts.
  var apex:=center
  var legacy_triangles:Array=[]
  var triangles:Array=[]
  if relief or cap:
   for j in face.size():
    legacy_triangles.append([legacy_apex,face[j],face[(j+1)%face.size()]])
    triangles.append([apex,face[j],face[(j+1)%face.size()]])
  else:
   for j in range(1,face.size()-1):
    legacy_triangles.append([face[0],face[j],face[j+1]])
    triangles.append([face[0],face[j],face[j+1]])
  var hint:=Vector3(plane.normal.x*bounds.size.x,plane.normal.y,plane.normal.z*bounds.size.z)
  for triangle:Array in legacy_triangles:
   var la:Vector3=triangle[0];var lb:Vector3=triangle[1];var lc:Vector3=triangle[2]
   if -(lb-la).cross(lc-la).dot(plane.normal)<0:
    var swap:=lb;lb=lc;lc=swap
   if (lb-la).cross(lc-la).length_squared()<1e-16:continue
   for p:Vector3 in [la,lb,lc]:
    var legacy:=_pack(p,bounds,root)
    if legacy.y>-.08:crown_z=maxf(crown_z,legacy.z)
  var cap_inset:=0.0
  if cap:
   cap_inset=1.0
   for j in face.size():
    var edge:=face[(j+1)%face.size()]-face[j]
    cap_inset=minf(cap_inset,edge.cross(center-face[j]).length()/maxf(edge.length(),.00001))
  for triangle:Array in triangles:
   var a:Vector3=_pack(triangle[0],bounds,root)
   var b:Vector3=_pack(triangle[1],bounds,root)
   var c:Vector3=_pack(triangle[2],bounds,root)
   var geo:=(b-a).cross(c-a)
   if geo.dot(hint)>0.0:
    var swap:=b;b=c;c=swap
    geo=-geo
   if geo.length_squared()<1e-16:continue
   var outward:=(-geo).normalized()
   if outward.dot(hint)<0.0:outward=hint.normalized()
   # One value for the whole cut. Per-triangle tint painted dark wedges on a
   # flat face, and those wedges read as sunk folds under the sun.
   var tone:=.5+.5*sin(float(seed_value*37+index*19))
   var warmth:=sin(float(seed_value*13+index*7))
   var tint:=Color(shade,shade,shade) if root else Color(.63+.035*tone+.01*warmth,.63+.035*tone,.63+.035*tone-.01*warmth)
   var insets:=[0.0,0.0,0.0]
   if cap and triangle[0]==center:insets[0]=cap_inset
   for i in 3:
    positions.append([a,b,c][i])
    normals.append(outward)
    colors.append(tint)
    uv.append(Vector2(insets[i],0.0))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uv
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var render_arrays:Array=arrays
 if not root:
  var walls:Array=arrays.duplicate(true)
  for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]:walls[slot].clear()
  for i in range(0,positions.size(),3):
   if absf(positions[i].y)+absf(positions[i+1].y)+absf(positions[i+2].y)<.00001:continue
   for j in 3:
    for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]:walls[slot].append(arrays[slot][i+j])
  render_arrays=walls
 # Authoring mesh stays the convex footprint. The skin bows outward so a
 # cut is no longer one flat wall; the top ring is not moved.
 var render_mesh:=_weather_skin(render_arrays,seed_value)
 return {"mesh":mesh,"render_mesh":render_mesh,"height":bounds.size.y,"crown_z":crown_z,"span_x":1.0,"span_z":1.0}

static func _pack(p:Vector3,bounds:AABB,root:bool)->Vector3:
 var vertex:=Vector3((p.x-bounds.get_center().x)/bounds.size.x,p.y,(p.z-bounds.get_center().z)/bounds.size.z)
 if root:vertex.z-=1.28*pow(clampf(-p.y,0.0,1.0),1.6)
 return vertex

static func _q(p:Vector3)->Vector3i:
 return Vector3i(roundi(p.x*10000.0),roundi(p.y*10000.0),roundi(p.z*10000.0))

static func _ek(a:Vector3,b:Vector3)->String:
 var qa:=_q(a);var qb:=_q(b)
 if qb<qa:var swap:=qa;qa=qb;qb=swap
 return "%d,%d,%d|%d,%d,%d"%[qa.x,qa.y,qa.z,qb.x,qb.y,qb.z]

static func _vk(p:Vector3)->String:
 var q:=_q(p)
 return "%d,%d,%d"%[q.x,q.y,q.z]

static func _unit(a:float)->float:
 return fmod(abs(sin(a*12.9898)*43758.5453),1.0)

static func _weather_skin(arrays:Array,seed_value:int)->ArrayMesh:
 var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
 var groups:Dictionary={}
 var order:Array=[]
 for i in range(0,positions.size(),3):
  var a:Vector3=positions[i];var b:Vector3=positions[i+1];var c:Vector3=positions[i+2]
  var raw:Vector3=(b-a).cross(c-a)
  var n:Vector3=normals[i]
  if raw.length_squared()>1e-12:
   var geo:=(-raw).normalized()
   if n.dot(geo)<0.0:n=geo
   else:n=n.normalized()
  var key:="%d,%d,%d,%d"%[roundi(n.x*200.0),roundi(n.y*200.0),roundi(n.z*200.0),roundi(n.dot(a)*200.0)]
  if not groups.has(key):
   groups[key]={"normal":n,"tris":[]}
   order.append(key)
  groups[key].tris.append([a,b,c,colors[i]])
 var faces:Array=[]
 for key:String in order:
  var group:Dictionary=groups[key]
  var poly:PackedVector3Array=_boundary(group.tris)
  faces.append({"normal":group.normal,"tris":group.tris,"poly":poly})
 var edge_n:Dictionary={}
 var edge_lock:Dictionary={}
 for face:Dictionary in faces:
  var poly:PackedVector3Array=face.poly
  var steep:bool=absf((face.normal as Vector3).y)>.55
  if poly.size()<3:continue
  for i in poly.size():
   var a:Vector3=poly[i];var b:Vector3=poly[(i+1)%poly.size()]
   var ek:=_ek(a,b)
   if not edge_n.has(ek):edge_n[ek]=Vector3.ZERO
   edge_n[ek]=edge_n[ek]+face.normal
   if steep or (a.y>-.028 and b.y>-.028):edge_lock[ek]=true
 var out_v:=PackedVector3Array();var out_n:=PackedVector3Array();var out_c:=PackedColorArray();var out_u:=PackedVector2Array()
 for face:Dictionary in faces:
  var normal:Vector3=face.normal
  var poly:PackedVector3Array=face.poly
  if absf(normal.y)>.55 or poly.size()<3:
   for tri:Array in face.tris:_push_flat(out_v,out_n,out_c,out_u,tri[0],tri[1],tri[2],tri[3],normal)
   continue
  var boundary:Array=[]
  for i in poly.size():
   var a:Vector3=poly[i];var b:Vector3=poly[(i+1)%poly.size()]
   var ek:=_ek(a,b)
   var nsum:Vector3=edge_n.get(ek,normal)
   if nsum.length_squared()<.0001:nsum=normal
   var locked:bool=edge_lock.has(ek)
   for s in 4:boundary.append(_edge_point(a,b,float(s)/4.0,nsum.normalized(),seed_value,locked))
  var center:=Vector3.ZERO
  for p:Vector3 in poly:center+=p
  center/=poly.size()
  var span:=.2
  for p:Vector3 in poly:span=maxf(span,p.distance_to(center))
  # One smooth outward dome per cut. High-frequency lumps became knife shards;
  # the amplitude is capped by the face so a small cut cannot grow a spike.
  var dome:=_unit(center.x*.9+center.y*.45+center.z*1.15+float(seed_value)*.17)
  var amp:=minf(.05+.22*dome,span*.24)
  var count:int=boundary.size()
  var rings:Array=[]
  for ring in 5:
   var row:Array=[]
   var t:=float(ring)/4.0
   var along:=1.0-t
   if ring==0:row.append(center+normal*amp)
   else:
    for i in count:
     var brim:Vector3=boundary[i]
     var p:Vector3=center.lerp(brim,t)
     if ring==4:p=brim
     else:p+=normal*(amp*along*along)
     row.append(p)
   rings.append(row)
  var tint:Color=face.tris[0][3]
  for ring in 4:
   var inner:Array=rings[ring]
   var outer:Array=rings[ring+1]
   if inner.size()==1:
    for i in outer.size():
     var j:=(i+1)%outer.size()
     _push_out(out_v,out_n,out_c,out_u,inner[0],outer[i],outer[j],normal,tint,seed_value)
   else:
    for i in outer.size():
     var j:=(i+1)%outer.size()
     _push_out(out_v,out_n,out_c,out_u,inner[i],outer[i],outer[j],normal,tint,seed_value)
     _push_out(out_v,out_n,out_c,out_u,inner[i],outer[j],inner[j],normal,tint,seed_value)
 var result:=ArrayMesh.new()
 if out_v.is_empty():
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  return result
 var built:Array=[];built.resize(Mesh.ARRAY_MAX)
 built[Mesh.ARRAY_VERTEX]=out_v;built[Mesh.ARRAY_NORMAL]=out_n;built[Mesh.ARRAY_COLOR]=out_c;built[Mesh.ARRAY_TEX_UV]=out_u
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,built)
 return result

static func _boundary(tris:Array)->PackedVector3Array:
 var count:Dictionary={};var dir:Dictionary={}
 for tri:Array in tris:
  for e in [[tri[0],tri[1]],[tri[1],tri[2]],[tri[2],tri[0]]]:
   var ek:=_ek(e[0],e[1])
   count[ek]=int(count.get(ek,0))+1
   if not dir.has(ek):dir[ek]=[e[0],e[1]]
 var adj:Dictionary={}
 for ek:String in count:
  if int(count[ek])!=1:continue
  var a:Vector3=dir[ek][0];var b:Vector3=dir[ek][1]
  if not adj.has(_vk(a)):adj[_vk(a)]=[]
  if not adj.has(_vk(b)):adj[_vk(b)]=[]
  adj[_vk(a)].append(b);adj[_vk(b)].append(a)
 if adj.is_empty():return PackedVector3Array()
 var start:Vector3
 var found:=false
 for ek:String in count:
  if int(count[ek])!=1:continue
  start=dir[ek][0];found=true;break
 if not found:return PackedVector3Array()
 var poly:=PackedVector3Array();var prev:String="";var cur:Vector3=start
 for _guard in 48:
  poly.append(cur)
  var options:Array=adj.get(_vk(cur),[])
  if options.is_empty():return PackedVector3Array()
  var nxt:Vector3=options[0]
  if options.size()>1 and _vk(nxt)==prev:nxt=options[1]
  if _vk(nxt)==_vk(start) and poly.size()>2:return poly
  prev=_vk(cur);cur=nxt
 return PackedVector3Array()

static func _edge_point(a:Vector3,b:Vector3,t:float,nsum:Vector3,seed_value:int,locked:bool)->Vector3:
 var swap:=_q(b)<_q(a)
 var p0:=b if swap else a
 var p1:=a if swap else b
 var u:=(1.0-t) if swap else t
 var p:=p0.lerp(p1,u)
 if locked:return p
 var h:=_unit(p0.x*3.1+p0.y*1.7+p1.z*2.4+float(seed_value)*.17)
 # A small bow, pinned at the corners. A larger shared-edge bow became a ridge.
 var wobble:=sin(u*PI)*(0.02+0.04*h)
 return p+nsum*wobble

static func _bulk(p:Vector3,seed_value:int,fall:float)->float:
 var n:=_unit(p.x*7.2+p.y*4.4+p.z*6.1+float(seed_value)*.13)
 var m:=_unit(p.x*2.4-p.y*3.7+float(seed_value)*.07)
 return fall*(0.012+0.05*n)*(0.55+0.45*m)

static func _push_flat(out_v:PackedVector3Array,out_n:PackedVector3Array,out_c:PackedColorArray,out_u:PackedVector2Array,a:Vector3,b:Vector3,c:Vector3,color:Color,normal:Vector3)->void:
 var geo:Vector3=(b-a).cross(c-a)
 if geo.dot(normal)<0.0:var swap:=b;b=c;c=swap;geo=-geo
 if geo.length_squared()<1e-14:return
 var outward:=geo.normalized()
 for p:Vector3 in [a,b,c]:
  out_v.append(p);out_n.append(outward);out_c.append(color);out_u.append(Vector2.ZERO)

static func _push_out(out_v:PackedVector3Array,out_n:PackedVector3Array,out_c:PackedColorArray,out_u:PackedVector2Array,a:Vector3,b:Vector3,c:Vector3,normal:Vector3,color:Color,seed_value:int)->void:
 var geo:Vector3=(b-a).cross(c-a)
 if geo.dot(normal)<0.0:var swap:=b;b=c;c=swap;geo=-geo
 if geo.length_squared()<1e-14:return
 var outward:=geo.normalized()
 var mid:=(a+b+c)/3.0
 var wear:=clampf(_bulk(mid,seed_value,1.0)/.07,0.0,1.0)
 var moss:=Color(color.r*.78,color.g*.94,color.b*.74)
 var tint:=color.lerp(Color(minf(color.r*1.08,1.0),minf(color.g*1.05,1.0),color.b*.98),wear*.45)
 tint=tint.lerp(moss,(1.0-wear)*.28)
 for p:Vector3 in [a,b,c]:
  out_v.append(p);out_n.append(outward);out_c.append(tint);out_u.append(Vector2.ZERO)

static func _intersections(planes:Array[Plane])->PackedVector3Array:
 var vertices:=PackedVector3Array()
 for a in planes.size():
  for b in range(a+1,planes.size()):
   for c in range(b+1,planes.size()):
    var p=planes[a].intersect_3(planes[b],planes[c])
    if p==null:continue
    var inside:=true
    for plane:Plane in planes:
     if plane.distance_to(p)>.00001:inside=false;break
    if not inside:continue
    var duplicate:=false
    for v:Vector3 in vertices:
     if v.distance_squared_to(p)<1e-10:duplicate=true;break
    if not duplicate:vertices.append(p)
 return vertices
