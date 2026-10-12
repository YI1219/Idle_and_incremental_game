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
 var render_mesh:=mesh
 if not root:
  var walls:Array=arrays.duplicate(true)
  for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]:walls[slot].clear()
  for i in range(0,positions.size(),3):
   if absf(positions[i].y)+absf(positions[i+1].y)+absf(positions[i+2].y)<.00001:continue
   for j in 3:
    for slot in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV]:walls[slot].append(arrays[slot][i+j])
  render_mesh=ArrayMesh.new();render_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,walls)
 return {"mesh":mesh,"render_mesh":render_mesh,"height":bounds.size.y,"crown_z":crown_z,"span_x":1.0,"span_z":1.0}

static func _pack(p:Vector3,bounds:AABB,root:bool)->Vector3:
 var vertex:=Vector3((p.x-bounds.get_center().x)/bounds.size.x,p.y,(p.z-bounds.get_center().z)/bounds.size.z)
 if root:vertex.z-=1.28*pow(clampf(-p.y,0.0,1.0),1.6)
 return vertex

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
