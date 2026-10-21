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
  if not root:normal.y=.065*sin(float(seed_value*11+i*7))
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
  var relief_amount:=rng.randf_range(-.09,.11)
  if not root:
   # Unequal fracture depth and off-centre fracture junctions; the cap's
   # original vertices and RNG stream stay fixed, so island plans do not move.
   var chip:=.5+.5*sin(float(seed_value*17+index*31))
   relief_amount=lerpf(-.085,.11,chip*chip)
  var apex:=center+plane.normal.normalized()*relief_amount
  if not root and relief:
   apex+=(face[(seed_value+index)%face.size()]-center)*.32
  var cap:=not root and index==0
  if cap:apex=center
  var triangles:Array=[]
  if relief or cap:
   for j in face.size():triangles.append([apex,face[j],face[(j+1)%face.size()]])
  else:
   for j in range(1,face.size()-1):triangles.append([face[0],face[j],face[j+1]])
  var triangle_index:=0
  for triangle:Array in triangles:
   var a:Vector3=triangle[0];var b:Vector3=triangle[1];var c:Vector3=triangle[2]
   if -(b-a).cross(c-a).dot(plane.normal)<0:
    var swap:=b;b=c;c=swap
   if (b-a).cross(c-a).length_squared()<1e-16:continue
   # Separate deterministic tint stream leaves the fracture and root RNG alone.
   var tone:=.5+.5*sin(float(seed_value*37+index*19))
   var warmth:=sin(float(seed_value*13+index*7))
   var tint:=Color(shade,shade,shade) if root else Color(.645+.025*tone+.005*warmth,.645+.025*tone,.645+.025*tone-.005*warmth)
   triangle_index+=1
   for p:Vector3 in [a,b,c]:
    var vertex:=Vector3((p.x-bounds.get_center().x)/bounds.size.x,p.y,(p.z-bounds.get_center().z)/bounds.size.z)
    if root:
     vertex.z-=1.28*pow(clampf(-p.y,0.0,1.0),1.6)
    positions.append(vertex)
    normals.append(Vector3(plane.normal.x*bounds.size.x,plane.normal.y,plane.normal.z*bounds.size.z).normalized())
    colors.append(tint)
    # Interpolated distance from the top perimeter, for a bare stone ledge.
    # The cap fan has a covered interior; all perimeter/shoulder vertices are bare.
    var inset:=0.0
    if cap and p==center:
     inset=1.0
     for j in face.size():
      var edge:=face[(j+1)%face.size()]-face[j]
      inset=minf(inset,edge.cross(center-face[j]).length()/edge.length())
    uv.append(Vector2(inset,0))
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
 var crown_z:=0.0
 for p:Vector3 in positions:
  if p.y>-.08:crown_z=maxf(crown_z,p.z)
 return {"mesh":mesh,"render_mesh":render_mesh,"height":bounds.size.y,"crown_z":crown_z,"span_x":1.0,"span_z":1.0}

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
