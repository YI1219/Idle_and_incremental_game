extends SceneTree
var failures:=0
func _initialize()->void:call_deferred('run')
func contains_triangle(p:Vector2,a:Vector2,b:Vector2,c:Vector2)->bool:
 var v0:=c-a;var v1:=b-a;var v2:=p-a
 var det:=v0.cross(v1)
 if absf(det)<1e-9:return false
 var u:=v2.cross(v1)/det;var v:=v0.cross(v2)/det
 return u>=-.00001 and v>=-.00001 and u+v<=1.00001
func run()->void:
 var data=load('res://scripts/terrain_editor/terrain_data.gd').new();data.make_preset(0)
 var field=load('res://scripts/terrain_editor/contour_terrain.gd').new();field.refresh(data)
 var deco=load('res://scripts/terrain_editor/terrain_decoration.gd').new();deco.load_assets();deco._column_layout(field,data.seed)
 var seen:Dictionary={};var probes:=0;var grass:PackedVector3Array=field.surfaces.grass.vertices
 for col:Dictionary in deco._columns:
  if seen.has(col.kind):continue
  seen[col.kind]=true
  var faces:PackedVector3Array=deco.assets[col.kind][0].mesh.get_faces();var cap:Array=[];var points:=PackedVector2Array()
  for i in range(0,faces.size(),3):
   if absf(faces[i].y)+absf(faces[i+1].y)+absf(faces[i+2].y)>.00001:continue
   cap.append([faces[i],faces[i+1],faces[i+2]])
   for j in 3:points.append(Vector2(faces[i+j].x,faces[i+j].z))
  var hull:=Geometry2D.convex_hull(points)
  var kind_probes:=0
  for z in range(-25,26):
   for x in range(-25,26):
    var p:=Vector2(x+.271,z+.337)*.02
    if not Geometry2D.is_point_in_polygon(p,hull):continue
    var actual:=false
    for tri:Array in cap:
     if contains_triangle(p,Vector2(tri[0].x,tri[0].z),Vector2(tri[1].x,tri[1].z),Vector2(tri[2].x,tri[2].z)):actual=true;break
    if actual:continue
    var world:Vector3=col.pose*Vector3(p.x,0,p.y)
    # Exact concave caps may legitimately recess the OUTER boundary. Only
    # declared joined land must have a drawn top; phantom convex land must not.
    if not field.contains(field.rim_regions[col.pose.origin.y],Vector2(world.x,world.z)):continue
    var covered:=false
    for i in range(0,grass.size(),3):
     if absf(grass[i].y-world.y)>.001:continue
     if contains_triangle(Vector2(world.x,world.z),Vector2(grass[i].x,grass[i].z),Vector2(grass[i+1].x,grass[i+1].z),Vector2(grass[i+2].x,grass[i+2].z)):covered=true;break
    probes+=1;kind_probes+=1
    if not covered:
     var raw:Dictionary=field.surface_at(Vector2(world.x,world.z))
     if not raw.is_empty() and raw.height>world.y+.001:continue
     failures+=1
    if kind_probes>=12:break
   if kind_probes>=12:break
 if probes==0:failures+=1
 print('SOURCE CAP JOIN: concavity probes=',probes,' missing=',failures)
 quit(1 if failures else 0)
