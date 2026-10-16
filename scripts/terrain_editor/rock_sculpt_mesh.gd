extends RefCounted
## A single editable volume skin, contoured from the authored density field.
## Six tetrahedra per lattice cube share consistent face diagonals. Cached
## lattice-edge crossings give identical points/normals across every cell.
const Field=preload('res://scripts/terrain_editor/rock_sculpt.gd')
const Surface=preload('res://scripts/terrain_editor/chunk_geometry.gd').Surface
const CORNERS=[Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,1,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(1,1,1),Vector3i(0,1,1)]
const TETS=[[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
class SculptSurface extends Surface:
 func triangle(a:Vector3,b:Vector3,c:Vector3,color:Color,up:bool=false)->void:
  # Keep real small faces at zero-crossings and at published chunk cuts.
  var cross:=-(b-a).cross(c-a)
  if cross.length_squared()<1e-20:return
  var normal:=cross.normalized()
  for p:Vector3 in [a,b,c]:
   vertices.append(p);normals.append(normal);colors.append(color);uv.append(Vector2.ZERO)
static func build(field)->Surface:
 var surface:=SculptSurface.new();var cells:Dictionary={};var cache:Dictionary={};var gradients:Dictionary={}
 for key:Vector3i in field.samples:
  if field.samples[key]>=0:continue
  for corner:Vector3i in CORNERS:cells[key-corner]=true
 var keys:=cells.keys();keys.sort()
 for cell:Vector3i in keys:
  var points:Array[Vector3i]=[]
  for corner:Vector3i in CORNERS:points.append(cell+corner)
  for tet:Array in TETS:
   var inside:Array[Vector3i]=[];var outside:Array[Vector3i]=[]
   for index:int in tet:
    if field.node_value(points[index])<0:inside.append(points[index])
    else:outside.append(points[index])
   if inside.is_empty() or outside.is_empty():continue
   var toward_air:=Vector3.ZERO;var toward_rock:=Vector3.ZERO
   for p:Vector3i in outside:toward_air+=Vector3(p)/outside.size()
   for p:Vector3i in inside:toward_rock+=Vector3(p)/inside.size()
   var outward:=toward_air-toward_rock
   var triangles:Array=[]
   if inside.size()==1 or outside.size()==1:
    var single:Vector3i=inside[0] if inside.size()==1 else outside[0]
    var other:Array=outside if inside.size()==1 else inside
    triangles.append([crossing(field,single,other[0],cache,gradients),crossing(field,single,other[1],cache,gradients),crossing(field,single,other[2],cache,gradients)])
   else:
    var a:=crossing(field,inside[0],outside[0],cache,gradients)
    var b:=crossing(field,inside[0],outside[1],cache,gradients)
    var c:=crossing(field,inside[1],outside[0],cache,gradients)
    var d:=crossing(field,inside[1],outside[1],cache,gradients)
    triangles.append([a,b,c]);triangles.append([b,d,c])
   for triangle:Array in triangles:
    var a:Vector3=triangle[0].point;var b:Vector3=triangle[1].point;var c:Vector3=triangle[2].point
    var cross:=-(b-a).cross(c-a)
    if cross.length_squared()<1e-20:continue
    if cross.dot(outward)<0:
     var swap:Dictionary=triangle[1];triangle[1]=triangle[2];triangle[2]=swap
    for entry:Dictionary in triangle:
     surface.vertices.append(entry.point);surface.normals.append(entry.normal)
     surface.colors.append(Color.WHITE);surface.uv.append(Vector2.ZERO)
 return surface
static func crossing(field,a:Vector3i,b:Vector3i,cache:Dictionary,gradients:Dictionary)->Dictionary:
 if b<a:
  var swap:=a;a=b;b=swap
 var key:Array=[a,b]
 if cache.has(key):return cache[key]
 var va:float=field.node_value(a);var vb:float=field.node_value(b)
 var t:=va/(va-vb)
 for node:Vector3i in [a,b]:
  if not gradients.has(node):gradients[node]=field.gradient(node)
 var result:Dictionary={'point':Vector3(a).lerp(Vector3(b),t)*Field.STEP,'normal':(gradients[a] as Vector3).lerp(gradients[b],t).normalized()}
 cache[key]=result
 return result
