extends SceneTree
## Actual production crown surfaces: manifold edges, outward normals and finite
## input containment. Use render arrays: Mesh.get_faces() passes through the
## triangle-mesh convenience representation, which rounds vertices. Float
## plane reconstruction uses 1e-5 normalized units, not exact volume identity.
const INPUT_TOLERANCE:=.00001
class ProbeModels:
 extends 'res://scripts/terrain_editor/terrain_models.gd'
 var crown:Array=[]
 var source_points:PackedVector3Array=[]
 func _join_crown(parts:Array)->Array:
  for part:Dictionary in parts:
   for point:Vector3 in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:source_points.append(part.pose*point)
  crown=super._join_crown(parts)
  return crown
func _initialize():call_deferred('run')
func run():
 var model=ProbeModels.new();model.load_assets()
 var closed=0;var outward=0;var planes=[];var reports=[]
 for part:Dictionary in model.crown:
  var faces:PackedVector3Array=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX];var vertices={};var edges={};var center=Vector3.ZERO
  for p:Vector3 in faces:
   if not vertices.has(p):vertices[p]=vertices.size();center+=p
  center/=vertices.size()
  var out=true;var group_planes:Array[Plane]=[]
  for i in range(0,faces.size(),3):
   var n=-(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
   if n.dot(faces[i]-center)<=0:out=false
   group_planes.append(Plane(n,n.dot(faces[i])))
   for j in 3:
    var a:int=vertices[faces[i+j]];var b:int=vertices[faces[i+(j+1)%3]]
    var key=Vector2i(mini(a,b),maxi(a,b))
    if not edges.has(key):edges[key]=Vector2i.ZERO
    edges[key]+=Vector2i(1,1 if a<b else -1)
  var shut=true
  for counts:Vector2i in edges.values():
   if counts!=Vector2i(2,0):shut=false
  if shut:closed+=1
  if out:outward+=1
  planes.append(group_planes)
  reports.append({'vertices':vertices.size(),'triangles':faces.size()/3,'closed':shut,'outward':out})
 var contained=0;var max_violation=-INF
 for point:Vector3 in model.source_points:
  var best=INF
  for group:Array in planes:
   var violation=-INF
   for plane:Plane in group:violation=maxf(violation,plane.distance_to(point))
   best=minf(best,violation)
  max_violation=maxf(max_violation,best)
  for group:Array in planes:
   var inside=true
   for plane:Plane in group:
    if plane.distance_to(point)>INPUT_TOLERANCE:inside=false;break
   if inside:contained+=1;break
 var report={'max_plane_violation':max_violation,'surfaces':reports,'closed_surfaces':closed,'outward_surfaces':outward,'contained_source_entries':contained,'source_entries':model.source_points.size(),'scope':'Actual generated crown boundaries and all current input vertex entries; duplicates included. Does not prove branch coverage or arbitrary inputs.'}
 print('CROWN INTEGRITY: ',JSON.stringify(report))

 var published:PackedVector3Array=model.assets.tree[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 var colors:PackedColorArray=model.assets.tree[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
 var actual=PackedVector3Array();var expected=PackedVector3Array()
 for i in range(0,published.size(),3):
  if colors[i].g>colors[i].r:
   for j in 3:actual.append(published[i+j])
 for part:Dictionary in model.crown:expected.append_array(part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
 var same=actual.size()==expected.size();var max_distance=0.0;var different=0
 if same:
  for i in actual.size():
   var distance=actual[i].distance_to(expected[i]);max_distance=maxf(max_distance,distance)
   if distance>0.000001:same=false;different+=1
 print('PUBLISHED CROWN MATCH: ',same,', entries=',actual.size(),', max_difference=',max_distance,', different_entries=',different)
 quit(0 if not model.crown.is_empty() and not model.source_points.is_empty() and closed==model.crown.size() and outward==model.crown.size() and contained==model.source_points.size() and same else 1)
