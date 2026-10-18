extends RefCounted
## Reuse complete existing grass modules, rooted just inside actual planar
## cap boundaries. Prototype only; no decorative land or modified source mesh.
static func apply(editor,low_soft:bool=false)->Dictionary:
 var surface=editor.renderer.contours.surfaces.sculpted_terrain
 var edges:Dictionary={}
 for i in range(0,surface.vertices.size(),3):
  var a:Vector3=surface.vertices[i];var b:Vector3=surface.vertices[i+1];var c:Vector3=surface.vertices[i+2]
  if surface.uv[i].y>=0 or -(b-a).cross(c-a).normalized().y<.9:continue
  var cap:float=surface.uv[i].x
  if absf(a.y-cap)>.005 or absf(b.y-cap)>.005 or absf(c.y-cap)>.005:continue
  for segment in [[a,b],[b,c],[c,a]]:
   var p:=Vector2(segment[0].x,segment[0].z);var q:=Vector2(segment[1].x,segment[1].z)
   var ka:=Vector2i((p*10000).round());var kb:=Vector2i((q*10000).round())
   var key:Array=[ka,kb] if ka<kb else [kb,ka]
   if not edges.has(key):edges[key]={'uses':0,'a':p,'b':q,'height':cap}
   edges[key].uses+=1
 var parts:Array=editor.renderer.decoration.assets.grass_clump
 var roots:Dictionary={};var source_vertices:=0
 for part:Dictionary in parts:
  var points:PackedVector3Array=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  source_vertices+=points.size()
  for p:Vector3 in points:
   var local:Vector3=part.pose*p
   if local.y<=.025:roots[local]=true
 var selected:Array=[];var occupied:Dictionary={};var heights:Dictionary={}
 var rejected:=0;var checks:=0;var max_gap:=0.0
 for edge:Dictionary in edges.values():
  if edge.uses!=1 or edge.a.distance_to(edge.b)<.02:continue
  var mid:Vector2=(edge.a+edge.b)*.5
  var cell:=Vector2i((mid/.32).floor())
  if occupied.has(cell):continue
  occupied[cell]=true
  var growth:float=sin(mid.x*.92+sin(mid.y*.51)*.7)*cos(mid.y*.73-mid.x*.3)
  if growth<(.35 if low_soft else .15):continue
  var near:=false
  for previous:Transform3D in selected:
   if mid.distance_to(Vector2(previous.origin.x,previous.origin.z))<(.42 if low_soft else .27):near=true;break
  if near:continue
  var tangent:Vector2=(edge.b-edge.a).normalized();var inward:=Vector2(-tangent.y,tangent.x)
  var turn:=atan2(-inward.x,-inward.y)+sin(mid.x*2.3+mid.y*.9)*.35
  var size:float=(.42 if low_soft else .50)+.10*(.5+.5*sin(mid.x*3.1+mid.y*1.7))
  var upright:float=(.31+.10*growth) if low_soft else (.56+.16*growth)
  var basis:=Basis(Vector3.UP,turn).scaled(Vector3(size,upright,size))
  var accepted:=false
  for inset:float in [.16,.24,.32,.40]:
   var at:Vector2=mid+inward*inset
   var pose:=Transform3D(basis,Vector3(at.x,edge.height-.01,at.y))
   var supported:=true;var candidate_gap:=0.0
   for root:Vector3 in roots:
    var world:=pose*root;var xz:=Vector2(world.x,world.z)
    if not heights.has(xz):heights[xz]=editor.data.rocks.height_at(xz)
    var roof:float=heights[xz];checks+=1
    if not is_finite(roof) or absf(roof-edge.height)>.015 or absf(roof-world.y)>.035:supported=false;break
    candidate_gap=maxf(candidate_gap,absf(roof-world.y))
   if supported:
    selected.append(pose);max_gap=maxf(max_gap,candidate_gap);accepted=true;break
  if not accepted:rejected+=1
 var node:=Node3D.new();node.name='ActualTopRimGrass';editor.add_child(node)
 for part:Dictionary in parts:
  var mesh:ArrayMesh=part.mesh.duplicate()
  var material:ShaderMaterial=mesh.surface_get_material(0).duplicate()
  if low_soft:material.shader=preload('res://tools/art/island_rim_grass_finish.gdshader')
  var dark:=Color('829b54' if low_soft else '6c8946').srgb_to_linear();var light:=Color('abb76d' if low_soft else 'a4b56b').srgb_to_linear()
  material.set_shader_parameter('dark_color',Vector3(dark.r,dark.g,dark.b));material.set_shader_parameter('light_color',Vector3(light.r,light.g,light.b))
  mesh.surface_set_material(0,material)
  assert(mesh.get_faces().to_byte_array()==part.mesh.get_faces().to_byte_array())
  var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=selected.size()
  for i in selected.size():mm.set_instance_transform(i,selected[i]*part.pose)
  var instance:=MultiMeshInstance3D.new();instance.multimesh=mm;node.add_child(instance)
 return {'rule_version':'low_soft2' if low_soft else 'tall_dark1','grass_instances':selected.size(),'existing_source_parts':parts.size(),'source_vertex_occurrences':source_vertices,'lower_root_vertices':roots.size(),'actual_field_root_checks':checks,'maximum_accepted_root_gap':max_gap,'rejected_positions':rejected,'rule':'Sparse spatial growth groups on actual upper cap triangle boundaries; every whole-module lower root checked against actual highest dry cap, insets.16–.40m, original geometry unchanged. Tools-only; not integrated into edit rebuilding yet.'}
