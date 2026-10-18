extends SceneTree
## Real editor-file boundary: imported float32 densities must not be rounded
## to JSON's default short decimal output when the player saves their island.
const Editor=preload('res://scripts/terrain_editor/editor.gd')
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
var checks:=0;var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred('run')
func run():
 var editor=Editor.new()
 editor.data.cells[Vector2i.ZERO]={'height':3.5,'water':-1}
 check(editor.data.set_sculpt_base(true),'real save fixture uses unified terrain')
 editor.data.rocks.samples[Vector3i(4,12,1)]=-0.12345000356435776
 editor.data.rocks.samples[Vector3i(4,13,1)]=0.00020000000949949026
 var before:Dictionary=editor.data.serialize()
 var path:='user://tests/terrain_precise_save.layout'
 check(editor.save_layout(path)==OK,'native editor writes its normal layout file')
 var payload:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 var copy:=Data.new()
 check(payload is Dictionary and copy.deserialize(payload),'normal loader accepts actual editor-written file')
 check(copy.serialize()==before,'editor save/read preserves imported density values exactly, including near-zero guards')
 editor.renderer.free();editor.camera.free();editor.landscape.free();editor.brush.free();editor.free()
 print('TERRAIN PRECISE SAVE: ',checks-failures,'/',checks)
 quit(1 if failures else 0)
