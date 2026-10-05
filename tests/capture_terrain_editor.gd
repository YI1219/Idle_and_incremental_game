extends SceneTree
const OUT:="res://art/review/terrain_editor/2026-10-05/"
func _initialize()->void:call_deferred("run")
func stroke(data,tool:String,center:Vector2,radius:float,height:float=1.5,water:int=3)->int:
	data.begin_stroke()
	var changed:int=data.apply_brush(center,radius,tool,false,height,water)
	data.end_stroke()
	return changed
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var editor=load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	var evidence:Array=[]
	for kind in 3:
		editor.select_preset(kind)
		var changes:=0
		if kind==0:
			changes+=stroke(editor.data,"raise",Vector2(-9.5,6.5),2.0)
			changes+=stroke(editor.data,"expand",Vector2(16.5,0.5),2.0)
		elif kind==1:
			changes+=stroke(editor.data,"contract",Vector2(0.5,-4.5),2.0)
			changes+=stroke(editor.data,"lower",Vector2(9.5,4.5),2.0)
		else:
			for i in 2:changes+=stroke(editor.data,"lower",Vector2(8.5,0.5),2.5)
			changes+=stroke(editor.data,"water",Vector2(8.5,0.5),2.5,1.5,2)
			changes+=stroke(editor.data,"raise",Vector2(-8.5,6.5),2.0)
		if changes==0:
			push_error("capture must contain actual edits")
			quit(1)
			return
		editor.renderer.rebuild_all()
		editor.camera.recenter(Vector2.ZERO)
		if kind==1:editor.camera.wheel(1)
		for i in 100:await process_frame
		if kind==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+"editor_ui.png")
		editor.hud.hide()
		editor.brush.hide()
		editor.set_process(false)
		for i in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"edited_layout_%d.png"%kind)
		var file:=FileAccess.open(OUT+"edited_layout_%d.json"%kind,FileAccess.WRITE)
		file.store_string(JSON.stringify(editor.data.serialize()))
		file.close()
		evidence.append({"layout":kind,"changed_cells":changes,"cells":editor.data.cells.size(),"chunks":editor.renderer.chunks.size()})
		editor.set_process(true)
		editor.hud.show()
	var manifest:=FileAccess.open(OUT+"captures.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify(evidence,"\t"))
	print("CAPTURED: ",JSON.stringify(evidence))
	quit()
