extends RefCounted
## Diagnostic only: same vertices/data, interpolated field-gradient normals.
static func apply(field,volume)->Dictionary:
 var surface=field.surfaces.sculpted_terrain
 var nodes:Dictionary={};var points:Dictionary={};var changed:=0
 for i in surface.vertices.size():
  var p:Vector3=surface.vertices[i]
  var weight:=smoothstep(-22,-20.5,p.x)*(1.0-smoothstep(-10,-8,p.x))*smoothstep(-3,-1,p.z)*(1.0-smoothstep(7.5,9,p.z))*(1.0-smoothstep(3.25,3.5,p.y))
  if weight<=0:continue
  if not points.has(p):
   var q:=p/.25;var key:=Vector3i(q.floor());var f:=q-Vector3(key)
   var axes:Array[int]=[0,1,2];axes.sort_custom(func(a:int,b:int):return f[a]>f[b])
   var first:=key;first[axes[0]]+=1
   var second:=first;second[axes[1]]+=1
   for node:Vector3i in [key,first,second,key+Vector3i.ONE]:
    if not nodes.has(node):nodes[node]=volume.gradient(node)
   points[p]=((nodes[key] as Vector3)*(1.0-f[axes[0]])+(nodes[first] as Vector3)*(f[axes[0]]-f[axes[1]])+(nodes[second] as Vector3)*(f[axes[1]]-f[axes[2]])+(nodes[key+Vector3i.ONE] as Vector3)*f[axes[2]]).normalized()
  surface.normals[i]=surface.normals[i].lerp(points[p],weight).normalized();changed+=1
 field._index_triangles()
 return {'normal_occurrences_changed':changed,'unique_sample_points':points.size(),'gradient_nodes':nodes.size(),'scope':'Local diagnostic normal replacement only; no geometry, density, material, prop regeneration or production change.'}
