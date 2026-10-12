extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration=preload("res://scripts/terrain_editor/terrain_decoration.gd")
var failures:=0
func _initialize():call_deferred("run")
func run():
 var data:=Data.new();data.make_preset(0)
 var field:=Field.new();field.refresh(data)
 var water_before:Dictionary={}
 for kind in ["water","waterfall","shore","bank"]:water_before[kind]=hash(field.surfaces[kind].vertices)
 var deco:=Decoration.new();deco.load_assets();deco._column_layout(field,data.seed)
 var overlaps:=0;var checked:=0
 var grass:PackedVector3Array=field.surfaces.grass.vertices
 for col:Dictionary in deco._columns:
  var hull:=PackedVector2Array()
  for p:Vector3 in deco.assets[col.kind][0].mesh.get_faces():
   if absf(p.y)>.00001:continue
   var q:Vector3=col.pose*p;hull.append(Vector2(q.x,q.z))
  hull=Geometry2D.convex_hull(hull)
  for i in range(0,grass.size(),3):
   if field.surfaces.grass.colors[i].a<.5:continue # single baked crown top
   if absf(grass[i].y-col.pose.origin.y)>.001:continue
   var center:Vector3=(grass[i]+grass[i+1]+grass[i+2])/3.0
   checked+=1
   if Geometry2D.is_point_in_polygon(Vector2(center.x,center.z),hull):overlaps+=1
 if overlaps>0:failures+=1;push_error("Old grass cap overlaps crown tops: %d triangles"%overlaps)
 for kind in water_before:
  if water_before[kind]!=hash(field.surfaces[kind].vertices):failures+=1;push_error("Rim union changed "+kind)
 # A cap must be drawn exactly once, including overlaps between neighboring
 # stones. Authoring solids stay closed; MultiMesh skins omit their top.
 var cap_probes:=0;var duplicate_tops:=0
 for col:Dictionary in deco._columns:
  var mesh:Mesh=deco.assets[col.kind][0].mesh
  var vertices:PackedVector3Array=mesh.get_faces()
  for i in range(0,vertices.size(),3):
   if absf(vertices[i].y)+absf(vertices[i+1].y)+absf(vertices[i+2].y)>.00001:continue
   var p:Vector3=col.pose*(vertices[i]*.271+vertices[i+1]*.337+vertices[i+2]*.392)
   var matches:=0;var boundary_sample:=false
   for j in range(0,grass.size(),3):
    if absf(grass[j].y-p.y)>.001:continue
    var triangle:=PackedVector2Array([Vector2(grass[j].x,grass[j].z),Vector2(grass[j+1].x,grass[j+1].z),Vector2(grass[j+2].x,grass[j+2].z)])
    var box:=Rect2(triangle[0],Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
    if box.grow(.00001).has_point(Vector2(p.x,p.z)) and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),triangle):matches+=1
    for edge in 3:
     if Vector2(p.x,p.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(p.x,p.z),triangle[edge],triangle[(edge+1)%3]))<.00002:boundary_sample=true
   # A ray exactly on a shared triangulation edge has two valid owners.
   # Omit this numerically ambiguous probe; other interior probes still
   # enforce one top, with no tolerance for overlapping triangle interiors.
   if boundary_sample:continue
   cap_probes+=1
   if matches!=1:duplicate_tops+=1
 if duplicate_tops>0:failures+=1;push_error("Missing/duplicated baked crown tops: %d"%duplicate_tops)
 # Regression for a strip cut beyond a yawed crown beside the upper fall:
 # its new cap boundary previously opened a 7cm slit through the island.
 var open_sides:=0;var side_probes:=0
 var faces:PackedVector3Array=field.surfaces.cliff.vertices.duplicate()
 var hulls:Array=[]
 for col:Dictionary in deco._columns:
  var points:=PackedVector2Array()
  for p:Vector3 in deco.assets[col.kind][0].mesh.get_faces():
   if absf(p.y)>.00001:continue
   var q:Vector3=col.pose*p;points.append(Vector2(q.x,q.z))
  hulls.append({"polygon":Geometry2D.convex_hull(points),"height":col.pose.origin.y})
  for p:Vector3 in deco.assets[col.kind][0].render_mesh.get_faces():faces.append(col.pose*p)
 for h:float in field.rim_regions:
  for polygon:PackedVector2Array in field.rim_regions[h]:
   for i in polygon.size():
    var a:=polygon[i];var b:=polygon[(i+1)%polygon.size()]
    if a.distance_to(b)<.03:continue
    var p:Vector2=(a+b)*.5
    var near:=INF
    for col:Dictionary in deco._columns:
     if absf(col.pose.origin.y-h)<.001:near=minf(near,p.distance_to(col.edge))
    if near>1.5:continue
    # The closed-volume suite covers the body skins. Here inspect only the
    # joins introduced between those bodies and the existing terrain.
    var on_body:=INF
    for hull:Dictionary in hulls:
     if absf(hull.height-h)>.001:continue
     for e in hull.polygon.size()-1:on_body=minf(on_body,p.distance_to(Geometry2D.get_closest_point_to_segment(p,hull.polygon[e],hull.polygon[e+1])))
    if on_body<.02:continue
    var tangent:Vector2=(b-a).normalized();var out:=Vector3(tangent.y,0,-tangent.x)
    var origin:=Vector3(p.x,h-.1,p.y)+out*.02
    var distance:=INF
    for j in range(0,faces.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(origin,-out,faces[j],faces[j+1],faces[j+2])
     if hit!=null:distance=minf(distance,origin.distance_to(hit))
    side_probes+=1
    if distance>.25:open_sides+=1
 if open_sides>0:failures+=1;push_error("Top boundary lacks supporting stone sides: %d"%open_sides)
 # Body top planes must coincide with the terrace; no raised lip or tilt.
 for col:Dictionary in deco._columns:
  var support:Dictionary=field.surface_at(col.edge-Vector2(col.outward.x,col.outward.z)*.35)
  if support.is_empty() or absf(col.pose.origin.y-support.height)>.001 or col.pose.basis.y.normalized().dot(Vector3.UP)<.99999:
   failures+=1;push_error("Crown is raised/tilted above its lawn join")
 print("RIM UNION: ",checked," overlap probes; ",cap_probes," single-top probes; ",side_probes," closed-side probes; failures=",failures)
 quit(1 if failures else 0)
