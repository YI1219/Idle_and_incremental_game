extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
var failures:=0
func _initialize():call_deferred("run")
func sample(data)->Dictionary:
 var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco.contours=field;deco._column_layout(field,data.seed)
 return {"field":field,"deco":deco}
func remote_difference(before,after)->Dictionary:
 var buckets:Dictionary={};var count_before:=0;var count_after:=0
 for p:Vector3 in before.vertices:
  if p.x>=0:continue
  count_before+=1
  var key:=Vector3i(p.floor())
  if not buckets.has(key):buckets[key]=[]
  buckets[key].append(p)
 var worst:=0.0
 for p:Vector3 in after.vertices:
  if p.x>=0:continue
  count_after+=1;var best:=INF;var key:=Vector3i(p.floor())
  for z in range(-1,2):
   for y in range(-1,2):
    for x in range(-1,2):
     for q:Vector3 in buckets.get(key+Vector3i(x,y,z),[]):best=minf(best,p.distance_to(q))
  worst=maxf(worst,best)
 return {"maximum_delta_m":worst,"same_vertex_count":count_before==count_after,"within_3mm":worst<=.003 and count_before==count_after}
func run():
 var data:=Data.new();data.make_preset(0)
 var original:=sample(data)
 var reports:Array=[]
 for state in ["default","expand","contract","deep_lower"]:
  if state=="deep_lower":
   data.undo()
   for edit in 7:
    data.begin_stroke();data.apply_brush(Vector2(18.6,4.4),2.2,"lower",false,1.5,3);data.end_stroke()
  if state=="expand":data.begin_stroke();data.apply_brush(Vector2(19.2,4.6),2.8,"expand",false,1.5,3);data.end_stroke()
  if state=="contract":data.undo();data.begin_stroke();data.apply_brush(Vector2(18.6,4.4),2.2,"contract",false,1.5,3);data.end_stroke()
  var fixture=original if state=="default" else sample(data)
  var field=fixture.field;var deco=fixture.deco
  var mantle=field.surfaces.stone_mantle
  var leaks:=0;var edges:Dictionary={};var checked:Dictionary={}
  for i in range(0,mantle.vertices.size(),3):
   for j in 3:
    var p:Vector3=mantle.vertices[i+j];var q:Vector3=mantle.vertices[i+(j+1)%3]
    var a:=Vector3i((p*10000).round());var b:=Vector3i((q*10000).round())
    var key:Array=[a,b] if a<b else [b,a];edges[key]=edges.get(key,0)+1
    if checked.has(a):continue
    checked[a]=true
    var top:=-INF
    for h:float in field.rim_regions:
     if Field.contains(field.rim_regions[h],Vector2(p.x,p.z)):top=maxf(top,h)
    if top!=-INF and p.y>top+.001:leaks+=1
  var open_edges:=0
  for uses:int in edges.values():
   if uses%2!=0:open_edges+=1
  var buried:=0;var vines:=0;var chunks:Dictionary={}
  for cell:Vector2i in data.cells:chunks[Data.chunk_of(cell)]=true
  for chunk:Vector2i in chunks:
   for pose:Transform3D in deco.placements(data,chunk).vine:
    if pose.basis.y.normalized().y<.2:continue
    vines+=1
    var center:Vector3=pose*deco._vine_center;var outward:=pose.basis.z.normalized()
    var faces:PackedVector3Array=deco.column_faces_near(center)
    var front:=INF
    for i in range(0,faces.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(center+outward*.6,-outward,faces[i],faces[i+1],faces[i+2])
     if hit!=null:front=minf(front,(center+outward*.6).distance_to(hit))
    if front<.57:buried+=1
  var remote:=remote_difference(original.field.surfaces.stone_mantle,mantle)
  var remote_cap:=remote_difference(original.field.surfaces.cliff,field.surfaces.cliff)
  var base_probes:=0;var base_misses:=0
  var bottom_faces:PackedVector3Array=mantle.vertices.duplicate();bottom_faces.append_array(field.surfaces.cliff.vertices)
  for z in range(-8,9,2):
   for x in range(-18,19,2):
    var p:=Vector2(x,z);var inside:=true
    for offset:Vector2 in [Vector2.ZERO,Vector2(3,0),Vector2(-3,0),Vector2(0,3),Vector2(0,-3)]:
     if field.surface_at(p+offset).is_empty():inside=false
    if not inside:continue
    base_probes+=1;var covered:=false
    for i in range(0,bottom_faces.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(Vector3(p.x,-10,p.y),Vector3.UP,bottom_faces[i],bottom_faces[i+1],bottom_faces[i+2])
     if hit!=null and hit.y<0:covered=true;break
    if not covered:base_misses+=1
  if leaks or open_edges or buried or not remote.within_3mm or not remote_cap.within_3mm or base_misses or base_probes<25:failures+=1
  reports.append({"state":state,"lawn_leaks":leaks,"open_edges":open_edges,"buried_vines":buried,"vines":vines,"remote":remote,"remote_cap":remote_cap,"base_probes":base_probes,"base_misses":base_misses})
 print("MANTLE INTEGRATION: ",JSON.stringify({"fixtures":reports,"failures":failures}))
 quit(0 if failures==0 else 1)
