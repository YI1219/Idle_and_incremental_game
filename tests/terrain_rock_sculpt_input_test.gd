extends SceneTree
var checks:=0;var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred('run')
func run():
 var editor=load('res://scenes/terrain_editor.tscn').instantiate();root.add_child(editor)
 editor.set_process(false);editor.camera.set_process(false)
 var tools=editor.hud.find_child('TerrainTools',true,false)
 var radius=editor.hud.find_child('BrushRadius',true,false)
 tools.select(6);tools.item_selected.emit(6)
 check(editor.tool=='rock_add' and radius.max_value==4,'HUD selects direct sculpting with its real radius limit')
 var hit={'position':Vector3(-14,3.5,4),'normal':Vector3.UP,'cell':Vector2i(-14,4)}
 editor.data.begin_stroke();editor._sculpt_at(Vector2(700,500),hit);editor.data.end_stroke()
 check(not editor.data.rocks.samples.is_empty(),'Editor input writes the authoritative sculpt field')
 var shape=editor.data.serialize()
 editor.renderer.rebuild_all()
 editor._sculpt_at(Vector2(700,500),{'position':Vector3(-14,5.5,4),'normal':Vector3.UP})
 check(editor.data.serialize()==shape,'Stationary cursor cannot grow with republished surface height')
 editor._update_brush(editor.camera.unproject_position(Vector3(-14,4.5,4)))
 check(editor.brush.mesh.get_surface_count()==1,'Sculpt cursor produces a visible volume guide')
 tools.select(7);tools.item_selected.emit(7)
 check(editor.tool=='rock_cut' and not editor.painting,'Changing sculpt tools closes the prior stroke')
 editor._sculpt_at(Vector2(700,520),hit);editor.data.end_stroke()
 check(editor.data.serialize()!=shape,'Editor carve input changes the same rock volume')
 check(editor.data.undo() and editor.data.serialize()==shape,'Editor carving is undoable')
 tools.select(0);tools.item_selected.emit(0)
 check(editor.tool=='raise' and radius.max_value==8,'Returning to terrain restores its brush range')
 editor.free()
 print('ROCK SCULPT INPUT: ',checks-failures,'/',checks)
 quit(1 if failures else 0)
