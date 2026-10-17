extends SceneTree
## Tool-only native-kernel comparison using existing closed crown sources.
const DIR='res://art/work/cliff_representation/2026-10-17/'
const INPUT='res://art/work/rendered_island/2026-10-17/complete/'
const Surface=preload('res://scripts/terrain_editor/chunk_geometry.gd').Surface
var combiner:CSGCombiner3D
func _initialize():call_deferred('run')
static func mesh_from_points(points:PackedVector3Array)->ArrayMesh:
 var surface=Surface.new()
 for i in range(0,points.size(),3):
  var normal:Vector3=-(points[i+1]-points[i]).cross(points[i+2]-points[i]).normalized()
  for j in 3:
   surface.vertices.append(points[i+j]);surface.normals.append(normal);surface.colors.append(Color.WHITE);surface.uv.append(Vector2.ZERO)
 return surface.mesh()
static func read_points(path:String)->PackedVector3Array:
 var numbers:PackedFloat32Array=FileAccess.get_file_as_bytes(path).to_float32_array()
 var points:=PackedVector3Array()
 for i in range(0,numbers.size(),3):points.append(Vector3(numbers[i],numbers[i+1],numbers[i+2]))
 return points
func export_result(name:String)->Dictionary:
 var start:=Time.get_ticks_usec()
 combiner._update_shape()
 var result:Array=combiner.get_meshes()
 assert(result.size()==2,'Native CSG failed to produce a mesh')
 var points:=PackedVector3Array()
 var transform:Transform3D=result[0]
 for p:Vector3 in result[1].get_faces():points.append(transform*p)
 assert(not points.is_empty(),'Native CSG output is empty')
 FileAccess.open(DIR+name+'.bin',FileAccess.WRITE).store_buffer(points.to_byte_array())
 return {'triangles':points.size()/3,'cached_result_retrieval_and_export_usec_not_kernel_benchmark':Time.get_ticks_usec()-start,'sha256_hex_algorithm':points.to_byte_array().hex_encode().sha256_text()}
func run():
 DirAccess.make_dir_recursive_absolute(DIR)
 combiner=CSGCombiner3D.new();root.add_child(combiner)
 var report:Dictionary={'engine':Engine.get_version_info(),'inputs':[],'scope':'Exact three retained source crowns; no new rock shape, production change, or real-time editing claim.'}
 var assembled:=PackedVector3Array()
 for id in [36,37,38]:
  var path:String=INPUT+'crown_'+str(id)+'.bin'
  var bytes:=FileAccess.get_file_as_bytes(path)
  var points:=read_points(path);assembled.append_array(points)
  var node:=CSGMesh3D.new();node.mesh=mesh_from_points(points);combiner.add_child(node)
  report.inputs.append({'path':path,'triangles':points.size()/3,'sha256_hex_algorithm':bytes.hex_encode().sha256_text()})
 FileAccess.open(DIR+'assembly.bin',FileAccess.WRITE).store_buffer(assembled.to_byte_array())
 await process_frame
 report['union']=export_result('union')
 var clip:=CSGBox3D.new();clip.operation=CSGShape3D.OPERATION_INTERSECTION
 clip.size=Vector3(30,20,30);clip.position=Vector3(-15,3.25-10,3);combiner.add_child(clip)
 report['top_clip_y']=3.25;report['union_clip']=export_result('union_clip')
 FileAccess.open(DIR+'native_kernel.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 print('CLIFF MANIFOLD: ',JSON.stringify(report));quit()
