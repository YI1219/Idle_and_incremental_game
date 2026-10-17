extends SceneTree
const DIR='res://art/work/cliff_representation/2026-10-17/'
func _initialize():call_deferred('run')
func run():
 var records=JSON.parse_string(FileAccess.get_file_as_string(DIR+'samples.json'))
 var field=preload('res://scripts/terrain_editor/rock_sculpt.gd').new()
 assert(field.load_records(records))
 var start:=Time.get_ticks_usec()
 var surface=preload('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(field)
 var build_usec:=Time.get_ticks_usec()-start
 assert(not surface.vertices.is_empty())
 FileAccess.open(DIR+'sampled.bin',FileAccess.WRITE).store_buffer(surface.vertices.to_byte_array())
 FileAccess.open(DIR+'sampled_normals.bin',FileAccess.WRITE).store_buffer(surface.normals.to_byte_array())
 var copy=preload('res://scripts/terrain_editor/rock_sculpt.gd').new()
 assert(copy.load_records(field.records()))
 var report:Dictionary={'triangles':surface.vertices.size()/3,'elapsed_usec_build_only':build_usec,'grid_step':field.STEP,'records_loaded':records.size(),'record_roundtrip_equal':copy.records()==field.records(),'scope':'Existing production mesher on a standalone local field; not a new full-island save or editor acceptance or comparable native boolean benchmark.'}
 assert(report.record_roundtrip_equal)
 FileAccess.open(DIR+'reconstruction.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 print('CLIFF REPRESENTATION RECONSTRUCTION: ',JSON.stringify(report));quit()
