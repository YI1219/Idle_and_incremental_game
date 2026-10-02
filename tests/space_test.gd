extends SceneTree
## Doorway: full-screen cover, then relocate the same actor.

var checks := 0
var failures := 0
var player: CharacterBody3D
var space: Node3D
var rig: Node3D
var state: Node

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node = load("res://scenes/play.tscn").instantiate()
	root.add_child(scene)
	await frames(8)
	player = get_first_node_in_group("player")
	space = get_first_node_in_group("space_controller")
	rig = get_first_node_in_group("camera_rig")
	state = root.get_node("SpaceState")
	check(space.interior_root != null, "室内预载在独立坐标")
	check(state.home_origin().distance_to(state.house_door) > 500.0, "房间远离门外")
	rig._yaw_index = 0
	position_player(Vector3(state.house_door.x, 0, state.house_door.z + 1.2), "outside")
	await frames(18)
	var player_id := player.get_instance_id()
	var entered := await observe_transition("move_forward", "outside", "inside")
	check(bool(entered.finished) and state.is_inside(), "走到门槛自动进入独立房间")
	check(bool(entered.peak_before_swap), "峰值遮蔽至少出现一帧后才提交进屋瞬移")
	check(bool(entered.covered_swap), "进屋瞬移时遮蔽达到峰值")
	check(bool(entered.blocked) and int(entered.blocked_frames) <= 32 and not bool(entered.moved_while_blocked), "进屋过渡短暂阻断角色位移")
	check(bool(entered.camera_safe), "揭开遮蔽时镜头已在室内，没有飞越远距离")
	check(player.get_instance_id() == player_id, "进屋保持同一角色实例")
	check(Input.is_action_pressed("move_forward") and not space.is_input_blocked(), "转场结束后保留持续按键")
	var resumed_from := player.global_position
	await frames(12)
	check(player.velocity.z < -0.7 and player.velocity.length() <= 0.801, "Held input resumes in its original direction with bounded acceleration")
	Input.action_release("move_forward")
	await frames(1)
	# Interior travel settles at the new walking pace after relocation.
	check(player.global_position.z < resumed_from.z - 0.1, "不必松开重按，原有行走输入自动恢复")
	check(player.collision_mask == 2 and space.transition_opacity < 0.01, "室内稳态使用独立碰撞层，遮蔽归零")
	position_player(state.home_origin() + Vector3(0, 0, 4.0), "inside")
	await frames(8)
	var exited := await observe_transition("move_back", "inside", "outside")
	Input.action_release("move_back")
	check(bool(exited.finished) and not state.is_inside(), "走到内部出口自动返回门外")
	check(bool(exited.peak_before_swap) and bool(exited.covered_swap), "离屋同样只在完整遮蔽下瞬移")
	check(player.get_instance_id() == player_id and player.collision_mask == 1, "离屋保持角色并恢复外部碰撞")
	check(space.explore_root != null, "探索块预载在独立坐标")
	check(state.explore_origin().distance_to(state.house_door) > 500.0, "探索远离院落")
	position_player(Vector3(0.5, 0, 3.2), "outside")
	await frames(8)
	var explored := await observe_transition("move_back", "outside", "explore")
	Input.action_release("move_back")
	check(bool(explored.finished) and bool(state.is_exploring()), "走到南沿云口出门")
	check(bool(explored.peak_before_swap) and bool(explored.covered_swap), "出门同样只在完整遮蔽下瞬移")
	check(player.collision_mask == 8, "探索使用独立碰撞层")
	position_player(state.explore_origin() + Vector3(0.5, 0, 0.9), "explore")
	await frames(8)
	var withdrew := await observe_transition("move_forward", "explore", "outside")
	Input.action_release("move_forward")
	check(bool(withdrew.finished) and not bool(state.is_exploring()), "走回入口主动撤离")
	check(player.collision_mask == 1, "撤离后恢复院落碰撞")
	print("SPACE CHECKS: %d passed / %d, failures=%d" % [checks - failures, checks, failures])
	quit(1 if failures else 0)

func observe_transition(action: String, source: String, destination: String) -> Dictionary:
	var record := {"finished": false, "peak_before_swap": false, "covered_swap": false, "blocked": false, "blocked_frames": 0, "moved_while_blocked": false, "camera_safe": true}
	var previous_alpha := 0.0
	var previous_space := source
	var previous_position := player.global_position
	var previous_blocked := false
	var saw_peak_in_source := false
	var saw_transition := false
	if not action.is_empty():
		Input.action_press(action)
	# Allow a captured stepping turn plus the slower indoor walk before the fade.
	for i in 480:
		await physics_frame
		var current_space: String = state.space_id
		var alpha: float = space.transition_opacity
		var blocked: bool = space.is_input_blocked()
		if space.is_transitioning():
			saw_transition = true
		if current_space == source and alpha >= 0.999:
			saw_peak_in_source = true
		if current_space != previous_space:
			record.peak_before_swap = saw_peak_in_source and previous_alpha >= 0.999
			record.covered_swap = alpha >= 0.999
		if blocked:
			record.blocked = true
			record.blocked_frames += 1
		if previous_blocked and blocked and current_space == previous_space and player.global_position.distance_to(previous_position) > 0.02:
			record.moved_while_blocked = true
		if current_space == destination and alpha < 0.95 and rig.global_position.distance_to(player.global_position) > 80.0:
			record.camera_safe = false
		if saw_transition and current_space == destination and not space.is_transitioning():
			record.finished = true
			break
		previous_alpha = alpha
		previous_space = current_space
		previous_position = player.global_position
		previous_blocked = blocked
	return record

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func position_player(at: Vector3, space_id: String) -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(action)
	state.player_x = at.x
	state.player_z = at.z
	state.enter(space_id)
	space.sync_after_relocation()
