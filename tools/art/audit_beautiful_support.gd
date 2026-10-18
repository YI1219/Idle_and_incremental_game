extends SceneTree
## Fresh finite contact evidence from actual published MultiMeshes, not
## requested placements. Root vertices and vine centroids have separate scope.
var OUT='res://art/review/terrain_fidelity/2026-10-18/beautiful_island/playable/'
func _initialize():call_deferred('run')
func nearest(field,p:Vector3)->float:
 var vertices:PackedVector3Array=field.surfaces.sculpted_terrain.vertices
 var candidates:Dictionary={};var result:=INF
 for z in range(floori((p.z-.11)/8),floori((p.z+.11)/8)+1):
  for x in range(floori((p.x-.11)/8),floori((p.x+.11)/8)+1):
   for i:int in field.triangle_chunks.get(Vector2i(x,z),{}).get('sculpted_terrain',[]):candidates[i]=true
 for i:int in candidates:
  var a:=vertices[i];var b:=vertices[i+1];var c:=vertices[i+2]
  if p.x<minf(a.x,minf(b.x,c.x))-.11 or p.x>maxf(a.x,maxf(b.x,c.x))+.11 or p.z<minf(a.z,minf(b.z,c.z))-.11 or p.z>maxf(a.z,maxf(b.z,c.z))+.11:continue
  var n:Vector3=(b-a).cross(c-a).normalized();var distance:float=n.dot(p-a)
  var weights:=Geometry3D.get_triangle_barycentric_coords(p-n*distance,a,b,c)
  if minf(weights.x,minf(weights.y,weights.z))>=-.000001:result=minf(result,absf(distance))
  for edge in [[a,b],[b,c],[c,a]]:result=minf(result,p.distance_to(Geometry3D.get_closest_point_to_segment(p,edge[0],edge[1])))
 return result
func run():
 var light_variant:=OS.get_cmdline_user_args().has('--light')
 if light_variant:OUT='res://art/review/terrain_fidelity/2026-10-19/island_light/'
 var editor=load('res://scenes/beautiful_island_light.tscn' if light_variant else 'res://scenes/beautiful_island.tscn').instantiate();root.add_child(editor)
 editor.set_process(false);editor.camera.set_process(false)
 var reports:Dictionary={};var failures:=0
 for case:int in editor.CASES.size():
  editor.select_preset(case)
  var field=editor.renderer.contours
  var plants:Dictionary={};var vine_count:=0;var vine_bad:=0;var vine_gap:=0.0
  for chunk:Node in editor.renderer.chunks.values():
   for child:Node in chunk.get_children():
    if not child is MultiMeshInstance3D:continue
    var kind:String=str(child.name).get_slice('_0',0)
    var mm:MultiMesh=child.multimesh
    var points:PackedVector3Array=mm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    if kind=='vine':
     var center:=Vector3.ZERO
     for p:Vector3 in points:center+=p
     center/=points.size()
     for instance in mm.instance_count:
      var pose:=mm.get_instance_transform(instance)
      if pose.basis.y.normalized().y<.2:continue
      var gap:=nearest(field,pose*center);vine_count+=1
      if not is_finite(gap) or gap>.10:vine_bad+=1
      else:vine_gap=maxf(vine_gap,gap)
    elif kind in ['grass_clump','tree','bush','flower']:
     if not plants.has(kind):plants[kind]={'instances':0,'root_points':0,'missing':0,'separated_over_012':0,'max_absolute_vertical_gap':0.0}
     var bottom:float=mm.mesh.get_aabb().position.y
     var roots:Dictionary={}
     for p:Vector3 in points:
      if p.y<=bottom+.035:roots[p]=true
     for instance in mm.instance_count:
      plants[kind].instances+=1
      var pose:=mm.get_instance_transform(instance)
      for p:Vector3 in roots:
       var world:=pose*p;var surface:Dictionary=field.surface_at(Vector2(world.x,world.z))
       plants[kind].root_points+=1
       if surface.is_empty() or surface.water>=0:plants[kind].missing+=1;continue
       var gap:float=absf(world.y-surface.height)
       plants[kind].max_absolute_vertical_gap=maxf(plants[kind].max_absolute_vertical_gap,gap)
       if gap>.12:plants[kind].separated_over_012+=1
  var case_ok:bool=vine_count>0 and vine_bad==0 and plants.get('tree',{}).get('instances',0)==2
  for kind:String in plants:
   case_ok=case_ok and plants[kind].missing==0 and plants[kind].separated_over_012==0 and plants[kind].root_points>0
  if not case_ok:failures+=1
  reports[editor.CASES[case]]={'roots':plants,'vine_centroids':vine_count,'vine_separated_or_missing':vine_bad,'vine_max_absolute_triangle_gap':vine_gap,'passed':case_ok}
  print('ACTUAL ISLAND SUPPORT: ',editor.CASES[case],' ',reports[editor.CASES[case]])
 FileAccess.open(OUT+'support.json',FileAccess.WRITE).store_string(JSON.stringify({'cases':reports,'failures':failures,'scope':'Actual published plant mesh vertices within .035m of source bottom; .12m vertical gap gate, dry top required. Hanging vine centroids nearest actual skin triangles within .10m. Not every leaf/branch, arbitrary edit or full building collision proof.'},'\t',true,true))
 editor.queue_free();quit(1 if failures else 0)
