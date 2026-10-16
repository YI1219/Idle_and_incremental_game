extends RefCounted
static func digest(bytes:PackedByteArray)->String:
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
static func apply(field)->Dictionary:
 var folder:='res://art/work/cliff_finish/2026-10-17/'
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+'plane_report.json'))
 var surface=field.surfaces.sculpted_terrain
 assert(digest(surface.vertices.to_byte_array())==report.input_vertex_sha256)
 assert(digest(surface.normals.to_byte_array())==report.input_normal_sha256)
 var bytes:=FileAccess.get_file_as_bytes(folder+'plane_normals.bin')
 assert(digest(bytes)==report.output_normal_sha256)
 var numbers:=bytes.to_float32_array();var normals:=PackedVector3Array()
 for i in range(0,numbers.size(),3):normals.append(Vector3(numbers[i],numbers[i+1],numbers[i+2]))
 assert(normals.size()==surface.normals.size())
 surface.normals=normals;field._index_triangles()
 return report
