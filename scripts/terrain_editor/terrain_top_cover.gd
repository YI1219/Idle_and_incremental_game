extends RefCounted
## Presentation from the real editable top, not a fixed collar/extra shell.
## Confirm the actual topmost field root so undercut ledges stay stone.
static func apply(contours,volume)->Dictionary:
 var surface=contours.surfaces.sculpted_terrain
 var before:PackedByteArray=surface.vertices.to_byte_array()
 var roofs:Dictionary={};var changed:=0;var max_error:=0.0
 for i in surface.vertices.size():
  var p:Vector3=surface.vertices[i];var n:Vector3=surface.normals[i]
  var cap:float=surface.uv[i].x
  if surface.uv[i].y>=0 or absf(p.y-cap)>.14 or n.y<.35:continue
  var at:=Vector2(p.x,p.z)
  if not roofs.has(at):roofs[at]=volume.height_at(at)
  var roof:float=roofs[at]
  if not is_finite(roof) or absf(roof-p.y)>.001:continue
  var cover:float=(1.0-smoothstep(.025,.14,absf(p.y-cap)))*smoothstep(.35,.80,n.y)
  if cover<=surface.colors[i].r:continue
  surface.colors[i].r=cover;changed+=1;max_error=maxf(max_error,absf(roof-p.y))
 assert(before==surface.vertices.to_byte_array())
 contours._index_triangles()
 return {'changed_vertex_coverage':changed,'unique_top_queries':roofs.size(),'maximum_top_support_error':max_error,'vertex_bytes_unchanged':true,'scope':'Color coverage on actual dry upward cap faces confirmed topmost by the authoritative tetrahedral field. No extra mesh or data alteration.'}
