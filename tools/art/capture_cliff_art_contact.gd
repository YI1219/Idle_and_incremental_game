extends 'res://tools/art/capture_cliff_representation_scene.gd'
## Six composed low source-leaf groups; no sod disks, painted band or new model.
var contact:MeshInstance3D
func cap_support(field,at:Vector2)->bool:
 var vertices:PackedVector3Array=field.surfaces.grass.vertices
 for i in range(0,vertices.size(),3):
  var a:=vertices[i];var b:=vertices[i+1];var c:=vertices[i+2]
  if maxf(absf(a.y-3.5),maxf(absf(b.y-3.5),absf(c.y-3.5)))>.001:continue
  var triangle:=PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
  if Geometry2D.is_point_in_polygon(at,triangle):return true
 return false
func side_mesh(shape:String)->ArrayMesh:
 if contact==null:build_contact()
 contact.visible=shape.ends_with('_contact')
 return super.side_mesh(shape.trim_suffix('_contact'))
func build_contact():
 var Surface=preload('res://scripts/terrain_editor/chunk_geometry.gd').Surface
 var detail=preload('res://scripts/terrain_editor/rim_surface_detail.gd')
 var field=editor.renderer.contours
 var source:=PackedVector3Array()
 for part:Dictionary in editor.renderer.decoration.assets.grass:
  for p:Vector3 in part.mesh.get_faces():source.append(part.pose*p)
 assert(not source.is_empty())
 var box:=AABB(source[0],Vector3.ZERO)
 for p:Vector3 in source:box=box.expand(p)
 var foot:=Vector3(box.get_center().x,box.position.y,box.get_center().z)
 var surface=Surface.new();var patches:Array=[];var roots:Array=[]
 var requests:Array=[Vector2(-19.3,2.4),Vector2(-17.2,3.8),Vector2(-15.2,4.25),Vector2(-13.6,5.7),Vector2(-11.4,6.6),Vector2(-10.0,6.0)]
 for index in requests.size():
  var wanted:Vector2=requests[index];var best:=INF;var center:=Vector2.ZERO;var tangent:=Vector2.ZERO
  for loop:PackedVector2Array in field.lawn_boundaries[3.5]:
   for i in loop.size():
    var a:=loop[i];var b:=loop[(i+1)%loop.size()]
    if a.distance_squared_to(b)<.000001:continue
    var p:=Geometry2D.get_closest_point_to_segment(wanted,a,b);var d:=p.distance_squared_to(wanted)
    if d<best:best=d;center=p;tangent=(b-a).normalized()
  assert(best<2.25)
  var out:=Vector2(tangent.y,-tangent.x)
  if not detail._inside(field.lawn_boundaries[3.5],center-out*.10):out=-out
  patches.append({'center':[center.x,center.y],'outward':[out.x,out.y],'width':.68+.12*(index%3)})
  for fan in 14:
   # Alternating irregular footprints form a low cushion with open intervals.
   var t:float=(fan+.5)/14.0;var angle:float=fan*2.399+index*.71;var radius:float=sqrt(t)
   var along:float=cos(angle)*radius*(.34+.06*(index%3))
   var inset:float=.17+sin(angle)*radius*.105
   var at:Vector2=center+tangent*along-out*inset
   if not detail._inside(field.lawn_boundaries[3.5],at):continue
   # The final editable-derived lawn includes the crown extensions. Original
   # land_regions/surface_at do not describe that drawn cap; query it directly.
   if not cap_support(field,at):continue
   var height:float=.09+.085*(1.0-radius)+.025*(.5+.5*sin(fan*1.7+index))
   var scale:float=height/maxf(box.size.y,.001)
   var lean:=Basis(Vector3(tangent.x,0,tangent.y),[-.12,-.45,-.85][fan%3]-.08*sin(fan*1.7))
   var basis:=lean*Basis(Vector3.UP,fan*2.399+index*.71);basis=basis.scaled(Vector3.ONE*scale)
   var pose:=Transform3D(basis,Vector3(at.x,3.488,at.y)-basis*foot)
   roots.append({'patch':index,'at':[at.x,at.y],'height':3.5,'inside_drawn_cap':true,'drawn_grass_triangle_support':true})
   # Preserve every existing source triangle. Small leaf faces must not be
   # lost through the generic terrain Surface.triangle area cutoff.
   for j in range(0,source.size(),3):
    var a:Vector3=pose*source[j];var b:Vector3=pose*source[j+1];var c:Vector3=pose*source[j+2]
    var normal:Vector3=-(b-a).cross(c-a).normalized()
    for vertex:Vector3 in [a,b,c]:
     surface.vertices.append(vertex);surface.normals.append(normal);surface.colors.append(Color(.5,.44+.035*index,1,1));surface.uv.append(Vector2(3.5,0));surface.uv2.append(at)
 assert(surface.vertices.size()==roots.size()*source.size())
 contact=MeshInstance3D.new();contact.name='LocalRootedLeafStudy';contact.mesh=surface.mesh();contact.material_override=editor.renderer.materials.rim_green;viewport.add_child(contact)
 var report:Dictionary={'patches':patches,'roots':roots,'source_vertex_occurrences':source.size(),'uploaded_vertex_occurrences':surface.vertices.size(),'all_source_faces_preserved':true,'scope':'Tool-only composed six existing-grass-source cushions, rooted inside actual authoritative-derived drawn dry cap with direct grass-triangle support. Original rim grass remains; no solid ground, collar/outline, material paint, tree/model replacement or production publication. Source leaf positions are for this local art fixture, not a final placement algorithm.'}
 FileAccess.open(OUT+'contact.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t',true,true))
