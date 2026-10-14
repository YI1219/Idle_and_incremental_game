extends SceneTree
## Finite actual-mesh containment checks for four distinct branch selectors.
## Z minimum and Y maximum coincide; this is not whole-tree connectivity proof.
class ProbeModels:
 extends 'res://scripts/terrain_editor/terrain_models.gd'
 var crown_parts:Array=[]
 func _join_crown(parts:Array)->Array:
  crown_parts=super._join_crown(parts)
  return crown_parts
func _initialize()->void:call_deferred('run')
func run()->void:
 var model:=ProbeModels.new()
 model.load_assets()
 var parts:Array=model.crown_parts
 if parts.is_empty():push_error('Missing assembled crown surfaces');quit(1);return
 # Select actual wood triangles from the published solid tree resource. The
 # retained wood palette has R>G, while all foliage colors have G>R.
 var arrays:Array=model.assets.tree[0].mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
 var wood:Array=[]
 for i in range(0,vertices.size(),3):
  if colors[i].r>colors[i].g:
   for j in 3:wood.append(vertices[i+j])
 if wood.is_empty():push_error('Missing actual wood triangles');quit(1);return
 var points:Array=[wood[0],wood[0],wood[0],wood[0]]
 for point:Vector3 in wood:
  if point.x<points[0].x:points[0]=point
  if point.x>points[1].x:points[1]=point
  if point.z<points[2].z:points[2]=point
  if point.y>points[3].y:points[3]=point
 var stem:Vector3=Vector3(0,-INF,0)
 for point:Vector3 in wood:
  if absf(point.x)<.1 and absf(point.z)<.1 and point.y>stem.y:stem=point
 points.append(stem)
 var covered:=0
 for point:Vector3 in points:
  var covering:Array=[]
  for i in range(parts.size()):
   var part:Dictionary=parts[i]
   var local:Vector3=part.pose.affine_inverse()*point
   var hits:Array=[]
   var faces:PackedVector3Array=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
   for j in range(0,faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(local,Vector3(1,.317,.13).normalized(),faces[j],faces[j+1],faces[j+2])
    if hit==null:continue
    var distance:float=hit.distance_to(local)
    var duplicate:=false
    for previous:float in hits:
     if absf(previous-distance)<.00001:duplicate=true
    if not duplicate:hits.append(distance)
   if hits.size()%2==1:covering.append(i)
  if not covering.is_empty():covered+=1
  print('ACTUAL WOOD EXTREMUM ',point,' covered by leaf lobes ',covering)
 print('TERRAIN CANOPY CONTACT: ',covered,'/5')
 quit(0 if covered==5 else 1)
