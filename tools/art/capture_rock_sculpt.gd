extends 'res://tests/capture_rim_round.gd'
func run():
 var args:=OS.get_cmdline_user_args();var tag:='sculpt2' if args.is_empty() else args[0]
 OUT='res://art/review/terrain_fidelity/2026-10-16/rock_sculpt/'
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load('res://scenes/terrain_editor.tscn').instantiate();viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 frame(Vector2(-14,4),8,16,30);await capture('before_close')
 preload('res://tools/art/author_sculpted_cliff.gd').author(editor.data)
 editor.renderer.rebuild_all()
 frame(Vector2(-14,4),8,16,30);await capture(tag+'_close')
 frame(Vector2(0,-1),21,16,27);await capture(tag+'_overview')
 frame(Vector2(-14,4),9,-105,28);await capture(tag+'_reverse')
 var file=FileAccess.open(OUT+tag+'_layout.json',FileAccess.WRITE);file.store_string(JSON.stringify(editor.data.serialize()))
 editor.data.begin_stroke();editor.data.apply_rock_brush(Vector3(-15.3,4.1,5.1),1.0,'rock_cut');editor.data.end_stroke();publish()
 frame(Vector2(-14,4),8,16,30);await capture(tag+'_carved')
 editor.data.undo();publish();await capture(tag+'_undo')
 var report={'captures':captures,'samples':editor.data.rocks.samples.size(),'source':'Actual Godot runtime; authored same production brush API. Study only; default prefab unchanged.'}
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 print('ROCK SCULPT CAPTURES: ',captures.size(),' samples=',editor.data.rocks.samples.size());quit()
