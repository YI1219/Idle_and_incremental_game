extends SceneTree
var checks:int=0
var failures:int=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(1280,720)
	var editor=load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.set_process(false)
	var gp=editor.gameplay
	gp.set_process(false)
	var hud=gp.shihai_hud
	gp.stance="sculpt"
	hud._stance="sculpt"
	hud._dock_alpha=1.0
	hud.queue_redraw()
	await process_frame
	await process_frame
	var before:Dictionary=editor.data.serialize()
	for i:int in 3:
		var press:=InputEventMouseButton.new()
		press.button_index=MOUSE_BUTTON_LEFT
		press.position=hud._size_hit_rects[i].get_center()+Vector2(0,18)
		press.pressed=true
		root.push_input(press,true)
		check(is_equal_approx(editor.radius,hud.BRUSH_RADII[i]),"viewport size token %d selects radius"%i)
		check(not editor.painting,"size selection never begins paint")
		press.pressed=false
		root.push_input(press,true)
	check(editor.data.serialize()==before,"size selection preserves terrain")
	var camera=editor.camera
	camera.set_process(false)
	camera.wheel(-100)
	check(is_equal_approx(camera._pitch,27.0),"wheel does not jump orientation")
	camera.advance(10.0)
	check(is_equal_approx(camera._height,6.0) and camera._pitch>=18 and camera._pitch<=20,"near zoom has low pitch")
	camera.wheel(100)
	camera.advance(10.0)
	check(is_equal_approx(camera._height,100.0) and camera._pitch>=65 and camera._pitch<=70,"far zoom has top down pitch")
	var previous_pitch:float=0.0
	for height_value:float in [6.0,12.0,21.0,40.0,70.0,100.0]:
		camera.height_goal=height_value
		camera.wheel(0)
		camera.advance(10)
		check(camera._pitch>previous_pitch,"zoom pitch is monotonic at %s"%height_value)
		previous_pitch=camera._pitch
		if height_value==21.0:
			check(is_equal_approx(camera._pitch,27.0),"default zoom retains familiar pitch")
	var height:float=camera.height_goal
	var orbit_distance:float=camera.position.distance_to(Vector3(camera._center.x,0,camera._center.y))
	camera.orbit_pixels(Vector2(40,-40))
	camera.advance(10)
	check(is_equal_approx(camera.height_goal,height),"orbit preserves zoom parameter")
	check(is_equal_approx(camera.position.distance_to(Vector3(camera._center.x,0,camera._center.y)),orbit_distance),"pitch orbit preserves actual eye to focus distance")
	var orbit_press:=InputEventMouseButton.new()
	orbit_press.button_index=MOUSE_BUTTON_RIGHT
	orbit_press.pressed=true
	orbit_press.position=Vector2(1000,350)
	root.push_input(orbit_press,true)
	var old_yaw:float=camera._yaw_goal
	var old_pitch:float=camera._pitch_goal
	var motion:=InputEventMouseMotion.new()
	motion.position=orbit_press.position
	motion.relative=Vector2(40,20)
	root.push_input(motion,true)
	check(camera._yaw_goal<old_yaw and camera._pitch_goal>old_pitch,"viewport right drag rotates yaw and pitch")
	check(is_equal_approx(camera.height_goal,height),"viewport orbit preserves zoom parameter")
	for i:int in 5:
		camera.advance(0.016)
		check(is_equal_approx(camera.position.distance_to(Vector3(camera._center.x,0,camera._center.y)),orbit_distance),"viewport orbit preserves radius throughout smoothing")
	orbit_press.pressed=false
	root.push_input(orbit_press,true)
	var center:Vector2=camera._center_goal
	orbit_press.button_index=MOUSE_BUTTON_MIDDLE
	orbit_press.pressed=true
	root.push_input(orbit_press,true)
	root.push_input(motion,true)
	check(camera._center_goal!=center,"viewport middle drag pans")
	orbit_press.pressed=false
	root.push_input(orbit_press,true)
	camera._height=32.0
	camera.height_goal=32.0
	camera._pitch=35.0
	camera._pitch_goal=35.0
	camera.advance(0)
	check(is_equal_approx(camera.position.y,32.0) and is_equal_approx(camera.rotation_degrees.x,-35.0),"explicit capture framing preserves height and pitch")
	var framed_distance:float=camera.position.distance_to(Vector3(camera._center.x,0,camera._center.y))
	camera.orbit_pixels(Vector2(30,-30))
	camera.advance(10)
	check(is_equal_approx(camera.position.distance_to(Vector3(camera._center.x,0,camera._center.y)),framed_distance),"orbit after explicit framing preserves radius")
	print("terrain_controls_test: %d checks, %d failures"%[checks,failures])
	editor.queue_free()
	await process_frame
	quit(1 if failures else 0)
