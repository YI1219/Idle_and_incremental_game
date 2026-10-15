extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration=preload("res://scripts/terrain_editor/terrain_decoration.gd")
var failures:=0
func _initialize():call_deferred("run")
# General point-in-polygon ray tests can miss extremely thin triangles at
# world coordinates. Barycentric coordinates inspect the actual triangle.
func owns(p:Vector2,a:Vector2,b:Vector2,c:Vector2)->bool:
 var ab:=b-a;var ac:=c-a;var ap:=p-a
 var det:float=ab.cross(ac)
 if absf(det)<1e-14:return false
 var u:float=ap.cross(ac)/det;var v:float=ab.cross(ap)/det
 return u>=0.0 and v>=0.0 and u+v<=1.0
func run():
 var thin:=PackedVector2Array([Vector2(-17.81649,-9.586769),Vector2(-17.80442,-9.595413),Vector2(3.347405,-9.595413)])
 if not owns(Vector2(-15.46738,-9.595251),thin[0],thin[1],thin[2]):failures+=1;push_error("Thin cap ownership regression")
 var data:=Data.new();data.make_preset(0)
 var field:=Field.new();field.refresh(data)
 # A hole crossing an outer edge changes crossing order inside a vertex slab.
 # Include intersection rows; vertex rows alone can fill outside the shape.
 var outer:=PackedVector2Array([Vector2(0,0),Vector2(4,0),Vector2(4,4),Vector2(0,4)])
 var hole:=PackedVector2Array([Vector2(-1,1),Vector2(3,2),Vector2(-1,3)])
 if Field._area(hole)>0:hole.reverse()
 var cap=preload("res://scripts/terrain_editor/lake_bed.gd").BedSurface.new()
 field._cap(cap,[outer,hole],0.0,Color.WHITE)
 var sweep_errors:=0
 for z in 38:
  for x in 48:
   var probe:=Vector2(x*.11-.8,z*.11+.017);var owners:=0
   for j in range(0,cap.vertices.size(),3):
    var a:Vector3=cap.vertices[j];var b:Vector3=cap.vertices[j+1];var c:Vector3=cap.vertices[j+2]
    if owns(probe,Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)):owners+=1
   if (owners==1)!=Field.contains([outer,hole],probe) or owners>1:sweep_errors+=1
 if sweep_errors:failures+=1;push_error("Crossing-hole cap errors: "+str(sweep_errors))
 var water_before:Dictionary={}
 for kind in ["water","waterfall","shore","bank"]:water_before[kind]=hash(field.surfaces[kind].vertices)
 var deco:=Decoration.new();deco.load_assets();deco._column_layout(field,data.seed)
 var checked:=0
 var grass:PackedVector3Array=field.surfaces.grass.vertices
 # Crown caps and lawn are now one baked top. Check its actual ray owners
 # below, rather than relying on the old cap-vs-lawn color flag.
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
   var raw:Dictionary=field.surface_at(Vector2(p.x,p.z))
   if not raw.is_empty() and raw.height>p.y+.001:continue # cap buried under a higher terrace
   # Water now has an actual lower bed. Its coincident crown cap must not
   # be drawn as grass through the refracting surface.
   if not raw.is_empty() and raw.water>=0 and absf(raw.height-p.y)<.001:continue
   if not field.contains(field.rim_regions[col.pose.origin.y],Vector2(p.x,p.z)):continue
   var matches:=0;var boundary_sample:=false
   for j in range(0,grass.size(),3):
    if absf(grass[j].y-p.y)>.001:continue
    var triangle:=PackedVector2Array([Vector2(grass[j].x,grass[j].z),Vector2(grass[j+1].x,grass[j+1].z),Vector2(grass[j+2].x,grass[j+2].z)])
    var box:=Rect2(triangle[0],Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
    if box.grow(.00001).has_point(Vector2(p.x,p.z)) and owns(Vector2(p.x,p.z),triangle[0],triangle[1],triangle[2]):matches+=1
    for edge in 3:
     if Vector2(p.x,p.z).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(p.x,p.z),triangle[edge],triangle[(edge+1)%3]))<.00002:boundary_sample=true
   # A ray exactly on a shared triangulation edge has two valid owners.
   # Omit this numerically ambiguous probe; other interior probes still
   # enforce one top, with no tolerance for overlapping triangle interiors.
   if boundary_sample:continue
   cap_probes+=1
   if matches!=1:duplicate_tops+=1
 if duplicate_tops>0:failures+=1;push_error("Missing/duplicated baked crown tops: %d"%duplicate_tops)
 # Exact dry-cap neighborhood exercises the pond-hole sweep far from water.
 for delta:Vector2 in [Vector2.ZERO,Vector2(.00003,0),Vector2(-.00003,0),Vector2(0,.00003),Vector2(0,-.00003)]:
  var probe:=Vector2(-15.46738,-9.595251)+delta;var owners:=0
  for j in range(0,grass.size(),3):
   if absf(grass[j].y-3.5)>.001:continue
   if owns(probe,Vector2(grass[j].x,grass[j].z),Vector2(grass[j+1].x,grass[j+1].z),Vector2(grass[j+2].x,grass[j+2].z)):owners+=1
  if owners!=1:failures+=1;push_error("Dry cap neighborhood missing/duplicated: "+str(owners))
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
  var boundary:=Geometry2D.convex_hull(points)
  var authored:PackedVector2Array=deco.assets[col.kind][0].get("cap_polygon",PackedVector2Array())
  if not authored.is_empty():
   boundary.clear()
   for p:Vector2 in authored:
    var q:Vector3=col.pose*Vector3(p.x,0,p.y);boundary.append(Vector2(q.x,q.z))
   boundary.append(boundary[0])
  hulls.append({"polygon":boundary,"height":col.pose.origin.y})
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
