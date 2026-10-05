extends SceneTree
## Fixed-step functional checks. These do not measure performance or establish art acceptance.
var checks := 0
var failures := 0
var player: CharacterBody3D
var state: Node

class InputGate extends Node:
	var blocked := false
	func is_input_blocked() -> bool: return blocked

class GroundEdge extends Node:
	var build_mode := false
	func is_walkable(at: Vector3) -> bool: return at.z < 0.5

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func release_input() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)

func reset_player() -> void:
	release_input()
	player.global_position = Vector3.ZERO
	player.mesh.rotation.y = 0.0
	player.sync_location()

func step(delta: float) -> void:
	player._physics_process(delta)
	player._animation.advance(delta)

func run() -> void:
	state = root.get_node("SpaceState")
	state.space_id = "outside"
	player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player._animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	reset_player()
	Input.action_press("move_back")
	step(1.0 / 60)
	check(player.velocity.length() > 0.0 and player.velocity.length() < 0.5, "Starting travel accelerates without an instantaneous full-speed step")
	for i in 30: step(1.0 / 60)
	check(absf(player.velocity.length() - 2.0) < 0.005, "Sustained normal movement uses the courtyard pace of 2.0 m/s")
	check(player._animation.current_animation == "gentle_jog", "Normal movement uses the gentle human-template jog")
	for fps in [30, 60, 120]:
		for target in ["move_right", "move_left", "move_forward"]:
			reset_player()
			Input.action_press("move_back")
			for i in fps: step(1.0 / fps)
			Input.action_release("move_back")
			Input.action_press(target)
			var desired := Vector3.RIGHT if target == "move_right" else Vector3.LEFT if target == "move_left" else Vector3.FORWARD
			var minimum_alignment := 1.0
			var minimum_speed := 2.0
			var reached_at := -1.0
			var maximum_speed := 0.0
			var saw_step := false
			var previous_yaw: float = player.mesh.rotation.y
			var maximum_yaw_rate := 0.0
			for i in 3 * fps:
				step(1.0 / fps)
				var speed := player.velocity.length()
				minimum_speed = minf(minimum_speed, speed)
				maximum_speed = maxf(maximum_speed, speed)
				saw_step = saw_step or player._animation.current_animation.begins_with("turn_")
				maximum_yaw_rate = maxf(maximum_yaw_rate, absf(angle_difference(previous_yaw, player.mesh.rotation.y)) * fps)
				previous_yaw = player.mesh.rotation.y
				if speed > 0.08 and player._turn_clip.is_empty():
					minimum_alignment = minf(minimum_alignment, player.velocity.normalized().dot(player.facing()))
				if reached_at < 0.0 and speed > 1.95 and player.facing().dot(desired) > 0.99:
					reached_at = float(i + 1) / fps
			check(saw_step, "Sharp direction changes play a captured stepping transition")
			check(maximum_yaw_rate < 6.0, "Heading changes continuously through captured footwork without a snap")
			check(minimum_alignment > 0.995, "Ordinary travel follows facing outside captured side-steps during %s turn at %d Hz; dot=%.3f" % [target, fps, minimum_alignment])
			check(minimum_speed < 1.0, "Sharp direction changes reduce travel before resuming")
			check(reached_at > 0.0 and reached_at < 2.3, "Turn completes its captured support-foot change and resumes travel within 2.3 s")
			check(maximum_speed < 2.005, "Turning never exceeds normal speed")
			print("TURN fps=%d target=%s min_facing_dot=%.5f min_speed=%.3f resumed=%.3fs" % [fps, target, minimum_alignment, minimum_speed, reached_at])
			release_input()
			var stop_from := player.global_position
			step(1.0 / fps)
			check(player.velocity.length() > 0.0 and player.velocity.length() < 2.0, "Release brakes instead of stopping instantly")
			for i in ceili(0.2 * fps): step(1.0 / fps)
			check(player.velocity.length() < 0.001, "Released input stops within 0.2 s")
			check(player.global_position.distance_to(stop_from) < 0.4, "Release has a short bounded stopping distance")
	# A brief braking pause must not restart the stride on the other foot.
	reset_player()
	player.velocity = Vector3(0, 0, 2.0)
	player._update_locomotion(0.016)
	player._animation.seek(0.4, true)
	var phase: float = player._animation.current_animation_position / player._animation.current_animation_length
	player.velocity = Vector3.ZERO
	player._update_locomotion(0.016)
	player.velocity = Vector3(0, 0, 2.0)
	player._update_locomotion(0.016)
	check(absf(player._animation.current_animation_position / player._animation.current_animation_length - phase) < 0.002, "A braking pause preserves locomotion phase")
	# Blocking and teleports must clear motion immediately, even during a reversal.
	var gate := InputGate.new()
	root.add_child(gate)
	gate.add_to_group("space_controller")
	reset_player()
	Input.action_press("move_back")
	for i in 30: step(1.0 / 60)
	gate.blocked = true
	var before := player.global_position
	step(1.0 / 60)
	check(player.velocity == Vector3.ZERO and player.global_position == before, "Blocked input immediately cancels travel")
	gate.blocked = false
	step(1.0 / 60)
	check(player.velocity.length() > 0.0 and player.velocity.length() < 0.5, "Held input resumes with fresh acceleration after unblocking")
	player.global_position += Vector3(50, 0, 0)
	release_input()
	before = player.global_position
	step(1.0 / 60)
	check(player.global_position == before and player.velocity == Vector3.ZERO, "Teleport detection clears old travel")
	player.velocity = Vector3(0, 0, 2.0)
	player.sync_location()
	step(1.0 / 60)
	check(player.velocity == Vector3.ZERO, "Explicit relocation reset leaves no old momentum")
	check(player._animation.current_animation == "idle" and player._stride_phase < 0.0, "Relocation resets locomotion animation and cached phase")
	gate.queue_free()
	# Use the real collision path and a real static wall, not a mocked movement function.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(4, 3, 0.2)
	wall.add_child(shape)
	wall.position = Vector3(0, 0, 1.0)
	root.add_child(wall)
	await physics_frame
	reset_player()
	Input.action_press("move_back")
	for i in 90: step(1.0 / 60)
	check(player.global_position.z < 0.9 and player.velocity.length() < 0.01, "Physical collision blocks travel without stored momentum")
	check(player._animation.current_animation == "idle", "Pressing into a wall uses actual stopped travel for animation")
	wall.free()
	state.space_id = "outside"
	var edge := GroundEdge.new()
	root.add_child(edge)
	edge.add_to_group("island_shell")
	reset_player()
	Input.action_press("move_back")
	for i in 90: step(1.0 / 60)
	check(player.global_position.z < 0.5, "Turning changes preserve non-walkable ground protection")
	edge.free()
	state.space_id = "outside"
	reset_player()
	Input.action_press("move_back")
	player.actions.start("attack")
	step(1.0 / 60)
	check(absf(player.velocity.length() - 0.6) < 0.002, "Attack travel keeps its existing movement rule")
	player.actions.cancel()
	player.actions.start("counter")
	step(1.0 / 60)
	check(absf(player.velocity.length() - 0.6) < 0.002, "Counter travel keeps its existing movement rule")
	player.actions.cancel()
	player.actions.charges = 2
	player.actions.start("dodge")
	player._dodge_direction = Vector3.RIGHT
	step(1.0 / 60)
	check(absf(player.velocity.x - 6.2) < 0.002, "Dodge keeps its authored action direction and gameplay speed")
	release_input()
	player._play_action("dodge")
	player.actions.advance(0.38)
	var dodge_end := player.global_position
	step(1.0 / 60)
	check(player.velocity == Vector3.ZERO and player.global_position == dodge_end, "Dodge completion does not carry ordinary braking momentum into recovery")
	check(player._animation.current_animation == "dodge_recovery", "Dodge still enters its authored recovery at rest")
	reset_player()
	Input.action_press("move_back")
	Input.action_press("move_right")
	for i in 60: step(1.0 / 60)
	check(absf(player.velocity.length() - 2.0) < 0.005, "Diagonal movement is normalized to normal speed")
	release_input()
	print("RUNNING TURN checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
