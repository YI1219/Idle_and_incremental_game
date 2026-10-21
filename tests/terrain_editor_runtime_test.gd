extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	if not ResourceLoader.exists("res://scenes/terrain_editor.tscn"):
		check(false,"interactive terrain editor scene missing")
		quit(1)
		return
	var editor=load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.set_process(false)
	var camera=editor.camera
	camera.set_process(false)
	var initial:Vector3=camera.position
	var orientation:Vector3=camera.rotation
	camera.pan(Vector2(1,-1),1.0)
	camera.advance(1.0/60.0)
	check(camera.position.y==initial.y and camera.position.distance_to(initial)>0.01,"keyboard pan moves horizontally only")
	camera.pan_pixels(Vector2(80,30))
	for i in 100:camera.advance(1.0/60.0)
	check(camera.position.y==initial.y,"mouse panning preserves height")
	for key in [KEY_Q,KEY_E]:
		var event:=InputEventKey.new()
		event.keycode=key
		event.pressed=true
		camera._unhandled_input(event)
	var motion:=InputEventMouseMotion.new()
	motion.relative=Vector2(100,100)
	motion.button_mask=MOUSE_BUTTON_MASK_LEFT|MOUSE_BUTTON_MASK_RIGHT
	camera._unhandled_input(motion)
	check(camera.rotation==orientation and camera.position.y==initial.y,"unpressed orbit motion does not change camera")
	camera.wheel(-2.0)
	check(camera.position.y==initial.y,"wheel changes target without height jump")
	camera.advance(1.0/60.0)
	check(camera.position.y<initial.y and camera.position.y>camera.height_goal,"wheel height smoothly approaches target")
	for i in 100:camera.advance(1.0/60.0)
	var h:float=camera.position.y
	camera.recenter(Vector2(8,4))
	for i in 100:camera.advance(1.0/60.0)
	check(is_equal_approx(camera.position.y,h),"recenter preserves wheel-selected height")
	editor.select_preset(2)
	for i in 100:camera.advance(1.0/60.0)
	check(is_equal_approx(camera.position.y,h),"preset changes preserve camera height")
	editor.data.cells.clear()
	editor.renderer.rebuild_all()
	camera.recenter(Vector2.ZERO)
	check(is_equal_approx(camera.position.y,h),"empty island remains navigable without height reset")
	check(not editor.begin_paint(Vector2(10,10),true),"UI-origin drag cannot begin terrain stroke")
	var before:Dictionary=editor.data.serialize()
	editor.continue_paint(Vector2(900,400))
	check(editor.data.serialize()==before,"drag from UI cannot modify terrain")
	editor.select_preset(0)
	# Exercise actual viewport routing, not just the UI-origin guard argument.
	await process_frame
	await process_frame
	var ui_before:Dictionary=editor.data.serialize()
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.position=Vector2(30,30)
	root.push_input(press,true)
	editor.continue_paint(Vector2(900,400))
	check(not editor.painting and editor.data.serialize()==ui_before,"viewport UI click cannot paint when dragged onto terrain")
	press.pressed=false
	root.push_input(press,true)
	for i in 100:camera.advance(1.0/60.0)
	editor.tool="raise"
	editor.radius=0.49
	var picked_cell:=Vector2i(9,-3)
	var old_height:float=editor.data.cells[picked_cell].height
	press.position=camera.unproject_position(Vector3(9.5,old_height,-2.5))
	press.pressed=true
	root.push_input(press,true)
	press.pressed=false
	root.push_input(press,true)
	check(editor.data.cells[picked_cell].height==old_height+0.5,"viewport world click edits the pointed cell")
	# Actual pointer routing must retain ownership on exact east/south cliff boundaries.
	camera.recenter(Vector2.ZERO)
	camera.advance(10.0)
	for axis in [0,2]:
		editor.data.cells.clear()
		editor.data.cells[Vector2i.ZERO]={"height":1.5,"water":-1}
		editor.renderer.rebuild_all()
		editor.tool="contract"
		editor.snap=true
		var face:=Vector3.ZERO
		var found:=false
		for chunk in editor.renderer.chunks.values():
			var cliff=chunk.get_node_or_null("cliff")
			if cliff==null:continue
			var faces:PackedVector3Array=cliff.mesh.get_faces()
			for i in range(0,faces.size(),3):
				var normal:=-(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
				var center:Vector3=(faces[i]+faces[i+1]+faces[i+2])/3.0
				if normal[axis]>.7 and center.y>0 and center.y<1.3:
					face=center;found=true;break
			if found:break
		check(found,"actual visible cliff face available for viewport routing")
		press.position=camera.unproject_position(face)
		var owner:Dictionary=editor._pointer(press.position)
		check(not owner.is_empty() and owner.cell==Vector2i.ZERO,"cliff pointer identifies owning cell")
		press.pressed=true
		root.push_input(press,true)
		press.pressed=false
		root.push_input(press,true)
		check(not editor.data.cells.has(Vector2i.ZERO),"snapped viewport brush edits east/south cliff owner")
	editor.select_preset(0)
	var saved:Dictionary=editor.data.serialize()
	check(editor.save_layout("user://terrain_editor/runtime_test.json")==OK,"layout save succeeds")
	editor.select_preset(1)
	check(editor.load_layout("user://terrain_editor/runtime_test.json")==OK and editor.data.serialize()==saved,"saved layout restores terrain and seed")
	var file:=FileAccess.open("user://terrain_editor/runtime_bad.json",FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(editor.load_layout("user://terrain_editor/runtime_bad.json")!=OK and editor.data.serialize()==saved,"corrupt load leaves current terrain intact")
	editor.painting=true
	editor.data.begin_stroke()
	editor.cancel_input()
	check(not editor.painting,"focus loss ends active stroke")
	DirAccess.remove_absolute("user://terrain_editor/runtime_test.json")
	DirAccess.remove_absolute("user://terrain_editor/runtime_bad.json")
	editor.free()
	print("TERRAIN EDITOR RUNTIME: %d/%d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
