extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String):
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1280,720)
	var game=load("res://scenes/play.tscn").instantiate()
	root.add_child(game)
	for i in 8:await process_frame
	var builder=get_first_node_in_group("sandbox_builder")
	if builder==null:
		check(false,"Playable scene exposes sandbox builder")
		quit(1)
		return
	var key:=InputEventKey.new()
	key.physical_keycode=KEY_B
	key.pressed=true
	Input.parse_input_event(key)
	await process_frame
	check(builder.island.build_mode and builder.panel.visible,"Build opens live controls")
	var player=get_first_node_in_group("player")
	var location: Vector3=player.global_position
	Input.action_press("move_forward")
	key=InputEventKey.new()
	key.physical_keycode=KEY_J
	key.pressed=true
	Input.parse_input_event(key)
	for i in 8:await physics_frame
	Input.action_release("move_forward")
	check(player.global_position.distance_to(location)<.001 and player.actions.action=="idle","Build input does not walk or attack")
	var cell:=Vector2i(3,-2)
	var count_before: int=builder.layout.objects.size()
	await click_screen(builder.panel.buttons["rock"].get_global_rect().get_center())
	check(builder.tool=="rock" and builder.layout.objects.size()==count_before,"UI tool click does not place into world")
	await click_screen(root.get_camera_3d().unproject_position(Vector3(3.5,0,-1.5)))
	check(builder.layout.objects.size()==count_before+1 and builder.layout.at(cell)>=0,"Screen click places actual mesh at projected ground cell")
	var id: int=builder.layout.last_id
	check(builder.nodes.has(id),"Placed mesh registered")
	for i in 2:await physics_frame
	var ray:=PhysicsRayQueryParameters3D.create(Vector3(3.5,.4,-.9),Vector3(3.5,.4,-2),1)
	check(not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Placed solid prop has physical collision")
	check(builder.edit_land(cell,true)=="land_support","Cannot delete support under placed prop")
	builder.selected=id
	builder.start_move()
	builder.preview_at(Vector2i(40,40))
	builder.cancel()
	check(builder.layout.at(cell)==id and builder.moving==-1,"Cancel move preserves original")
	check(builder.commit_place("tree",cell)=="overlap","Reject overlap in runtime")
	check(builder.commit_move(id,Vector2i(40,40))=="no_land","Invalid move rejected")
	check(builder.layout.at(cell)==id,"Invalid move retained old mesh/data")
	check(builder.commit_move(id,Vector2i(3,-3))=="ok","Move existing prop")
	var home: Vector2i=builder.layout.find(0).cell
	check(builder.commit_move(0,Vector2i(-1,-4))=="ok","Cottage moves to supported site")
	var state=root.get_node("SpaceState")
	check(state.house_door.distance_to(game.house.to_global(Vector3(0,0,2.2)))<.001,"Entrance follows moved house")
	check(is_equal_approx(state.exit_position().z,state.house_door.z+1.3),"Exit return follows moved house")
	var space=get_first_node_in_group("space_controller")
	space.set_physics_process(false)
	player.set_physics_process(false)
	for i in 2:await physics_frame
	player.global_position=state.house_door+Vector3(0,0,.8)
	for i in 16:player.move_and_collide(Vector3(0,0,-.1))
	check(player.global_position.z<state.house_door.z-.5,"Moved doorway physically traversable")
	player.global_position=location
	player.sync_location()
	player.set_physics_process(true)
	space.set_physics_process(true)
	check(builder.edit_land(Vector2i(1,4),false)=="ok","Add land before save")
	var snapshot: Dictionary=builder.snapshot()
	var file: String="user://sandbox_test_only.json"
	check(builder.save_layout(file)=="ok","Layout written")
	check(builder.commit_remove(id)=="ok","Remove actual prop")
	check(builder.edit_land(Vector2i(1,4),true)=="ok","Change saved land before load")
	island_add_resources(builder)
	builder.island.sim.catch_up(builder.island._clock_minutes)
	var pool: float=builder.island.sim.total_pool()
	check(builder.load_layout(file)=="ok","Reload layout")
	check(is_equal_approx(pool,builder.island.sim.total_pool()),"Layout load does not rewind resource balance")
	check(builder.layout.at(Vector2i(3,-3))==id,"Restored prop position")
	check(builder.island.terrain.land_cells.has(Vector2i(1,4)),"Layout load restores edited land")
	var before: String=JSON.stringify(builder.snapshot())
	var bad: Dictionary=snapshot.duplicate(true)
	bad.layout.objects[0].cell=[9000,9000]
	check(builder.restore_snapshot(bad)!="ok","Bad placement save rejected")
	check(JSON.stringify(builder.snapshot())==before,"Bad load keeps current scene")
	check(builder.edit_land(Vector2i(0,2),true)!="ok","Cannot delete door approach/player support")
	builder.choose("land")
	check(builder.edit_land(Vector2i(0,4),false)=="ok","Expand adjacent editable land")
	check(builder.island.terrain.land_cells.has(Vector2i(0,4)),"Expansion updates terrain")
	check(builder.edit_land(Vector2i(0,4),true)=="ok","Delete empty added land")
	check(not builder.island.terrain.land_cells.has(Vector2i(0,4)),"Deleted land disappears")
	check(builder.edit_land(Vector2i(90,90),false)=="ok","Disconnected islands are allowed")
	check(builder.island.terrain.island_count()>=2,"Isolated cell becomes its own island")
	builder.set_active(false)
	check(not builder.island.build_mode and not builder.panel.visible,"Build closes")
	state.space_id="inside"
	builder.set_active(true)
	check(not builder.active(),"Cannot enter courtyard building from interior")
	state.space_id="outside"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	game.queue_free()
	await process_frame
	print("SANDBOX RUNTIME checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func island_add_resources(builder):
	builder.island.sim.add_pool(17.0)

func click_screen(at: Vector2):
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=at
		event.global_position=at
		root.push_input(event)
		await process_frame
