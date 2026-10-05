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
	check(camera.rotation==orientation and camera.position.y==initial.y,"vertical and orbit inputs disabled")
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
