extends SceneTree
## Actual imported candidate cap/skin evidence; does not promote the sources.
func _initialize():call_deferred('run')
func raw_cap_bounds(mesh:Mesh,height:float)->Rect2:
 var faces:=mesh.get_faces();var lo:=Vector2(INF,INF);var hi:=-lo
 for i in range(0,faces.size(),3):
  for j in 3:
   var a:=faces[i+j];var b:=faces[i+(j+1)%3]
   if (a.y-height)*(b.y-height)>=0:continue
   var point:=a.lerp(b,(height-a.y)/(b.y-a.y));var at:=Vector2(point.x,point.z)
   lo=lo.min(at);hi=hi.max(at)
 return Rect2(lo,hi-lo)
func run():
 var version:='v2' if OS.get_cmdline_user_args().has('v2') else 'v1'
 var models=load('res://scripts/terrain_editor/terrain_models.gd').new()
 var reports:Array=[];var failures:=0
 for spec in [['main',.72,'cliff_main_v4.glb'],['main',.62,'cliff_main_v4.glb'],['tall',.72,'cliff_tall_v2.glb'],['tall',.86,'cliff_tall_v2.glb']]:
  var candidate:Dictionary=models._merge(models._load('res://art/work/cliff_corner_planes/2026-10-16/Cliff_Corner_'+spec[0]+'_'+version+'.glb','cliff_rock'))
  var source:Dictionary=models._merge(models._load('res://assets/nature/refined/cliff_integrated_'+spec[0]+'_v1.glb','cliff_rock'))
  if candidate.mesh.get_surface_count()==0 or source.mesh.get_surface_count()==0:push_error('Candidate/source missing; cannot validate shape');quit(1);return
  var reference:Dictionary=models._merge(models._load('res://assets/nature/refined/'+spec[2],'cliff_rock'))
  var before:Dictionary=load('res://scripts/terrain_editor/source_stone_crown.gd').build(source.mesh,.68,spec[1],reference.mesh.get_aabb())
  var after:Dictionary=load('res://scripts/terrain_editor/source_stone_crown.gd').build(candidate.mesh,.68,spec[1],reference.mesh.get_aabb())
  var lo:=Vector2(INF,INF);var hi:=-lo
  for point:Vector2 in after.cap_polygon:lo=lo.min(point);hi=hi.max(point)
  var edges:Dictionary={};var invalid:=0;var vertices:PackedVector3Array=after.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  for i in range(0,vertices.size(),3):
   for j in 3:
    var a:=vertices[i+j].snapped(Vector3.ONE*.000001);var b:=vertices[i+(j+1)%3].snapped(Vector3.ONE*.000001)
    var key:Array=[a,b] if a<b else [b,a]
    edges[key]=edges.get(key,0)+1
    if not a.is_finite():invalid+=1
  for count:int in edges.values():
   if count!=2:invalid+=1
  var delta:float=absf(after.geometry_height-before.geometry_height)
  var bounds:AABB=reference.mesh.get_aabb();var cut:float=bounds.position.y+bounds.size.y*spec[1]
  var raw_before:=raw_cap_bounds(source.mesh,cut);var raw_after:=raw_cap_bounds(candidate.mesh,cut)
  var raw_delta:float=maxf(raw_before.position.distance_to(raw_after.position),raw_before.end.distance_to(raw_after.end))
  var match:bool=lo.distance_to(Vector2(-.5,-.5))<.0002 and hi.distance_to(Vector2(.5,.5))<.0002
  if invalid>0 or not match or not is_finite(raw_delta) or raw_delta>.0002:failures+=1
  reports.append({'kind':spec[0],'cut':spec[1],'cap_min':str(lo),'cap_max':str(hi),'cap_bounds_normalized':match,'raw_cap_bound_delta':raw_delta,'vertices':vertices.size(),'invalid_edges_or_vertices':invalid,'geometry_height_delta':delta})
 FileAccess.open('res://art/review/terrain_fidelity/2026-10-16/corner_planes/cap_checks_'+version+'.json',FileAccess.WRITE).store_string(JSON.stringify({'reports':reports,'failures':failures},'\t'))
 print('CORNER SOURCE CAPS: ',JSON.stringify({'reports':reports,'failures':failures}));quit(1 if failures else 0)
