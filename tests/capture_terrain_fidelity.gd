extends SceneTree
const OUT:="res://art/review/terrain_fidelity/2026-10-05/"
func _initialize()->void:call_deferred("run")
func shot(editor,name_value:String)->void:
	while editor.renderer.has_pending_updates():
		editor.renderer.flush_dirty(2)
		await process_frame
	for i in 60:await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(OUT+name_value+".png")
	if error!=OK:push_error("Failed capture "+name_value);quit(1)
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var editor=load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.hud.hide()
	editor.brush.hide()
	editor.set_process(false)
	await shot(editor,"composition_wip")
	var evidence:Array=[]
	var initial:Dictionary=editor.data.serialize()
	for spec in [["raise",Vector2(-13,2),2.3],["lower",Vector2(13,7),2.0],["expand",Vector2(18,4),2.6],["contract",Vector2(3,7),2.2]]:
		editor.data.deserialize(initial)
		editor.data.begin_stroke()
		var changed:int=editor.data.apply_brush(spec[1],spec[2],spec[0],false,1.5,3)
		editor.data.end_stroke()
		if changed==0:push_error("Capture edit did not change terrain");quit(1);return
		await shot(editor,"edit_"+spec[0])
		evidence.append({"operation":spec[0],"changed_cells":changed,"center":[spec[1].x,spec[1].y],"radius":spec[2]})
	editor.data.deserialize(initial)
	# Close-ups use the public wheel path; panning itself never changes height.
	for spec in [["shoreline",Vector2(7.2,-1.8),-5.0],["cliffs",Vector2(-9.7,2.9),-5.0],["vegetation",Vector2(-12.7,-14.5),-3.0]]:
		editor.camera.wheel(log(21.0/editor.camera.height_goal)/log(1.12))
		editor.camera.wheel(spec[2])
		editor.camera.recenter(spec[1])
		await shot(editor,"detail_"+spec[0])
	editor.camera.wheel(log(21.0/editor.camera.height_goal)/log(1.12))
	editor.camera.recenter(Vector2(0,-1))
	editor.set_process(true)
	editor.hud.show()
	await shot(editor,"editor_ui")
	var manifest:=FileAccess.open(OUT+"captures.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"source":"actual Godot 4.7.2 Metal Forward+ renders","resolution":[1672,940],"edits":evidence,"status":"work in progress, user visual acceptance pending"},"\t"))
	print("FIDELITY CAPTURES: ",JSON.stringify(evidence))
	quit()
