extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func key(code: Key) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
func run() -> void:
	var game:Node=load("res://scenes/play.tscn").instantiate()
	root.add_child(game)
	await frames(12)
	var player:=get_first_node_in_group("player")
	var arena:=get_first_node_in_group("combat_arena")
	var space:=get_first_node_in_group("space_controller")
	var state:=root.get_node("SpaceState")
	check(player._animation!=null,"人物GLB带动画播放器")
	for clip in ["idle","walk","gentle_jog","jog","run","turn_left_90","turn_right_90","turn_left_180","turn_right_180","attack_1","counter","dodge","dodge_recovery"]:
		check(player._animation.has_animation(clip),"动作存在: "+clip)
	var house:Node3D=game.house
	check(house.get_node("CottageModel").scene_file_path.ends_with("cottage_tripo.glb"),"运行小屋使用 Tripo 正式来源候选")
	check(float(house.get_meta("door_width"))>=1.5,"门宽有身体与衣袖余量")
	check(float(house.get_meta("door_height"))>=1.65,"门高高于角色")
	# Test capsule physically traverses the true doorway before the teleport is allowed.
	space.set_physics_process(false)
	player.set_physics_process(false)
	for x in [-.45,0.0,.45]:
		player.global_position=Vector3(x,0,.8)
		for i in 16: player.move_and_collide(Vector3(0,0,-.1))
		check(player.global_position.z < -.5,"门洞不同横向位置均可通过")
	player.global_position=Vector3(1.2,0,.8)
	for i in 16:player.move_and_collide(Vector3(0,0,-.1))
	check(player.global_position.z>=.15,"门旁墙体阻挡穿墙")
	player.global_position=Vector3(-3.8,0,.55)
	player.sync_location()
	player.set_physics_process(true)
	space.set_physics_process(true)
	key(KEY_J)
	await frames(34)
	check(is_equal_approx(arena.health,95.0),"完整剑招只结算一次护体减伤后的气血伤害")
	# A physics-frame signal may resume just before the final recovery step.
	# Wait for the authored action state rather than racing the 0.55 s boundary.
	for i in 8:
		if player.actions.action == "idle": break
		await frames(1)
	check(player.actions.action == "idle", "首招恢复结束后再发出下一招")
	var first_health: float = arena.health
	key(KEY_J)
	await frames(42)
	check(arena.health < first_health,"后续剑招可继续命中")
	var menu:=get_first_node_in_group("preview_menu")
	menu.open_menu()
	key(KEY_J)
	check(player.actions.action=="idle","暂停菜单不触发攻击")
	menu.resume()
	key(KEY_J)
	await frames(4)
	var health_before_pause: float=arena.health
	menu.open_menu()
	for i in 20: await process_frame
	check(arena.health==health_before_pause,"攻击前摇中暂停，不能在菜单下造成命中")
	menu.resume()
	player.actions.cancel()
	# Walk across the real bridge; do not teleport directly onto its far bank.
	var rig:=get_first_node_in_group("camera_rig")
	rig._yaw_index=0
	rig.snap_to_target()
	player.global_position=Vector3(2.4,0,1.5)
	player.sync_location()
	Input.action_press("move_right")
	# Allow the planted turn and gentler courtyard pace; stop on reaching the bank.
	for i in 300:
		await frames(1)
		if player.global_position.x > 6.3: break
	Input.action_release("move_right")
	check(player.global_position.x>6.25,"正常行走能通过桥抵达干燥东岸")
	player.global_position=Vector3(3.3,0,-.5)
	player.sync_location()
	Input.action_press("move_right")
	await frames(35)
	Input.action_release("move_right")
	check(player.global_position.x<4.05,"没有桥的位置河水阻挡行走")
	key(KEY_SPACE)
	await frames(25)
	check(player.global_position.x<4.05,"闪避也不能穿过河水")
	# Large-coordinate relocations must reset the saved valid ground location.
	state.player_x=state.explore_arrival().x
	state.player_z=state.explore_arrival().z
	state.enter("explore")
	await frames(4)
	state.player_x=state.gate_return().x
	state.player_z=state.gate_return().z
	state.enter("outside")
	await frames(4)
	check(player.global_position.distance_to(state.gate_return())<.1,"跨空间返回后不会被旧落点拉回")
	print("DEMO CHECKS %d/%d failures=%d" % [checks-failures,checks,failures])
	quit(1 if failures else 0)
