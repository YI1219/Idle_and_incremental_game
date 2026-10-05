extends SceneTree
# Review probe for this 17-lobe candidate; finite contact evidence, not all-branch coverage.
class ProbeModels:
 extends 'res://scripts/terrain_editor/terrain_models.gd'
 var tree_parts:Array=[]
 func _merge(parts:Array)->Dictionary:
  if parts.size()==18:tree_parts=parts.duplicate()
  return super._merge(parts)
func _initialize()->void:call_deferred('run')
func run()->void:
 var model:=ProbeModels.new()
 model.load_assets()
 var parts:Array=model.tree_parts
 if parts.size()!=18:push_error('Missing expected tree source parts');quit(1);return
 var wood:Array=[]
 for point:Vector3 in parts[0].mesh.get_faces():wood.append(parts[0].pose*point)
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
  for i in range(1,parts.size()):
   var part:Dictionary=parts[i]
   var local:Vector3=part.pose.affine_inverse()*point
   var hits:Array=[]
   var faces:PackedVector3Array=part.mesh.get_faces()
   for j in range(0,faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(local,Vector3(1,.317,.13).normalized(),faces[j],faces[j+1],faces[j+2])
    if hit==null:continue
    var distance:float=hit.distance_to(local)
    var duplicate:=false
    for previous:float in hits:
     if absf(previous-distance)<.00001:duplicate=true
    if not duplicate:hits.append(distance)
   if hits.size()%2==1:covering.append(i-1)
  if not covering.is_empty():covered+=1
  print('ACTUAL WOOD EXTREMUM ',point,' covered by leaf lobes ',covering)
 print('ACTUAL CANOPY CONTACT: ',covered,'/5')
 quit(0 if covered==5 else 1)
