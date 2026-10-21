extends RefCounted
## Preserve the source geometry and hard breaks; soften only neighboring
## normals within a crease angle. Called once when retained stone meshes load.
static func soften(mesh:ArrayMesh,crease_degrees:float=55.0,strength:float=.80)->ArrayMesh:
 var result:=ArrayMesh.new()
 var cosine:=cos(deg_to_rad(crease_degrees))
 for surface in mesh.get_surface_count():
  var arrays:=mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  if normals.size()!=vertices.size():
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   result.surface_set_material(surface,mesh.surface_get_material(surface));continue
  var groups:Dictionary={}
  for i in vertices.size():
   var key:=Vector3i(roundi(vertices[i].x*100000),roundi(vertices[i].y*100000),roundi(vertices[i].z*100000))
   if not groups.has(key):groups[key]=[]
   groups[key].append(i)
  var softened:=PackedVector3Array();softened.resize(normals.size())
  for indices:Array in groups.values():
   for i:int in indices:
    var sum:=Vector3.ZERO
    var seen:Dictionary={}
    for j:int in indices:
     var neighbor:=normals[j].normalized()
     if normals[i].normalized().dot(neighbor)<cosine:continue
     # Triangulation density must not bias a shared geological plane.
     var key:=Vector3i(roundi(neighbor.x*10000),roundi(neighbor.y*10000),roundi(neighbor.z*10000))
     if seen.has(key):continue
     seen[key]=true;sum+=neighbor
    if sum.length_squared()<.000001:sum=normals[i]
    softened[i]=normals[i].normalized().lerp(sum.normalized(),clampf(strength,0,1)).normalized()
  arrays[Mesh.ARRAY_NORMAL]=softened
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  result.surface_set_material(surface,mesh.surface_get_material(surface))
 return result
