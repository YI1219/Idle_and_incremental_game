extends SceneTree
const OLD='res://art/work/cliff_representation/2026-10-17/'
const OUT='res://art/work/cliff_dual/2026-10-17/'
func _initialize():call_deferred('run')
func run():
 DirAccess.make_dir_recursive_absolute(OUT)
 var field=preload('res://scripts/terrain_editor/rock_sculpt.gd').new()
 assert(field.load_records(JSON.parse_string(FileAccess.get_file_as_string(OLD+'samples.json'))))
 var original:Array=field.records()
 var center:=Vector3(-15,3.25,3);var radius:=4.0
 var undo:Dictionary=field.brush(center,radius,'rock_plane',Vector3.UP)
 assert(not undo.is_empty())
 var edited:Array=field.records();var redo:Dictionary={}
 for key in undo:redo[key]=field.samples.get(key)
 FileAccess.open(OUT+'edited_samples.json',FileAccess.WRITE).store_string(JSON.stringify(edited))
 var mesh=preload('res://scripts/terrain_editor/rock_sculpt_mesh.gd').build(field)
 FileAccess.open(OUT+'sampled_edited.bin',FileAccess.WRITE).store_buffer(mesh.vertices.to_byte_array())
 field.restore(undo);assert(field.records()==original)
 field.restore(redo);assert(field.records()==edited)
 var copy=preload('res://scripts/terrain_editor/rock_sculpt.gd').new();assert(copy.load_records(edited));assert(copy.records()==edited)
 var report:Dictionary={'brush':'rock_plane','center':[center.x,center.y,center.z],'normal':[0,1,0],'radius':radius,'changed_nodes':undo.size(),'edited_records':edited.size(),'undo_exact':true,'redo_exact':true,'reload_exact':true,'scope':'One standalone public rock field brush; not TerrainData editor integration, surface support, collision, or arbitrary-edit acceptance.'}
 FileAccess.open(OUT+'edit.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print('CLIFF DUAL EDIT: ',JSON.stringify(report));quit()
