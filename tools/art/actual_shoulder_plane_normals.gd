extends RefCounted
## Isolate real cut-plane lighting without modifying a single skin position.
static func apply(field)->Dictionary:
 var folder:='res://art/work/actual_shoulder/2026-10-17/'
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+'report.json'))
 var control:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://art/review/terrain_fidelity/2026-10-16/sculpt_base/actual_shoulder1_captures.json'))
 var digest=preload('res://tools/art/apply_cliff_planes.gd')
 var skin=field.surfaces.sculpted_terrain
 assert(digest.digest(skin.vertices.to_byte_array())==control.skin_vertices_sha256)
 var origin:=Vector3(report.origin[0],report.origin[1],report.origin[2])
 var outward:=Vector3(report.outward[0],report.outward[1],report.outward[2])
 var tangent:=Vector3(report.tangent[0],report.tangent[1],report.tangent[2])
 var normal:Vector3=(outward-tangent*float(report.slope)).normalized()
 var triangles:=0;var changed:=0;var max_distance:=0.0
 for i in range(0,skin.vertices.size(),3):
  var a:Vector3=skin.vertices[i];var b:Vector3=skin.vertices[i+1];var c:Vector3=skin.vertices[i+2]
  var geometric:Vector3=-(b-a).cross(c-a).normalized()
  if geometric.dot(normal)<.995:continue
  var distance:=0.0;var valid:=true
  for p:Vector3 in [a,b,c]:
   var delta:=p-origin;var along:=delta.dot(tangent)
   distance=maxf(distance,absf((delta.dot(outward)-report.slope*along-report.intercept)/sqrt(1.0+report.slope*report.slope)))
   if p.y<3.0 or p.y>3.499 or along<-.85 or along>.45:valid=false;break
  if not valid or distance>.005:continue
  triangles+=1;max_distance=maxf(max_distance,distance)
  for j in 3:
   if skin.normals[i+j].distance_to(normal)>.000001:changed+=1
   skin.normals[i+j]=normal
 assert(triangles>0 and changed>0,'Actual fitted cut must expose real plane triangles')
 field._index_triangles()
 return {'triangles':triangles,'normal_occurrences_changed':changed,'max_vertex_plane_distance':max_distance,'normal':str(normal),'input_vertices_sha256':control.skin_vertices_sha256,'output_normals_sha256':digest.digest(skin.normals.to_byte_array()),'scope':'Only exact exposed cut-plane triangles, geometric normal agreement>.995, all three vertices within5mm of fitted real plane, Y3..3.499 and inner unfaded tangent span. Same data/vertices/colors/UV/material. Analytic normal diagnostic, not a persistent ordinary-save rendering feature or art acceptance.'}
