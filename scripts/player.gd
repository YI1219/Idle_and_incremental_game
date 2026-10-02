extends CharacterBody3D
## Camera-relative walking, small combat actions and a single reusable actor across spaces.
const COURTYARD_JOG_SPEED := 2.0
const EXPLORATION_RUN_SPEED := 4.5
const INDOOR_WALK_SPEED := 0.8
const GENTLE_JOG_NATIVE_SPEED := 1.9866961489
const GentleJog := preload("res://assets/characters/qinglan/gentle_jog.tres")
const TRAVEL_ACCELERATION := 14.0
const TRAVEL_BRAKING := 24.0
const TURN_RATE := 3.5 # Radians per second; rotate the actor, never overwrite authored joints.
const STEP_TURN_ANGLE := PI / 3.0
const PIVOT_SPEED := 0.25
const GarmentMotion := preload("res://scripts/characters/garment_motion.gd")
var _garment_motion: SkeletonModifier3D
const FabricFinish := preload("res://scripts/characters/fabric_finish.gd")
const TurnLibrary := preload("res://assets/characters/qinglan/turn_motion.tres")
const TemplateMotion := preload("res://assets/characters/qinglan/template_motion.gd")
const ActionState := preload("res://scripts/combat/sword_actions.gd")
@onready var mesh: Node3D = $Mesh
const Geometry := preload("res://scripts/combat/combat_geometry.gd")
var actions := ActionState.new()
var ward_state := preload("res://scripts/combat/ward_state.gd").new()
var _mouse_aim := false
var _sword: Node3D
var _last_land := Vector3.ZERO
var _space_id := "outside"
var _animation: AnimationPlayer
var _visual_action := ""
var _travel_clip := "idle"
var _dodge_direction := Vector3.FORWARD
var _stride_phase := -1.0
var _action_travel := false
var _turn_clip := ""
var _turn_time := 0.0
var _turn_start_yaw := 0.0
var _turn_angle := 0.0
var _obstructed_turn_yaw := INF
var _turn_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/qinglan/turn_motion.json")).clips

func _ready() -> void:
	add_to_group("player")
	global_position = Vector3(SpaceState.player_x, 0.0, SpaceState.player_z)
	sync_location()
	_animation = _find_animation(mesh)
	if _animation:
		_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		var library := _animation.get_animation_library("").duplicate(true) as AnimationLibrary
		library.add_animation("gentle_jog", GentleJog)
		for clip in TurnLibrary.get_animation_list():
			library.add_animation(clip, TurnLibrary.get_animation(clip))
		_animation.remove_animation_library("")
		_animation.add_animation_library("", library)
		for name in _animation.get_animation_list():
			if String(name) in TemplateMotion.LOOPS:
				_animation.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	FabricFinish.apply(mesh)
	_play("idle")
	if _animation: _animation.advance(0)
	_equip_sword()
	var skeleton := _find_skeleton(mesh)
	if skeleton:
		skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS
		_garment_motion = GarmentMotion.new()
		_garment_motion.name = "GarmentMotion"
		_garment_motion.actor = self
		skeleton.add_child(_garment_motion)

func _find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation(child)
		if result:
			return result
	return null

func _play(clip: String) -> void:
	if _animation == null:
		return
	for name in _animation.get_animation_list():
		if String(name) == clip or String(name).ends_with("/" + clip):
			if _animation.current_animation != name:
				if _animation.current_animation in ["walk", "gentle_jog", "jog", "run"]:
					_stride_phase = fmod(_animation.current_animation_position / _animation.current_animation_length, 1.0)
				_animation.play(name, 0.18 if (clip in TemplateMotion.LOOPS or clip == "gentle_jog") else 0.10)
				if clip in ["walk", "gentle_jog", "jog", "run"] and _stride_phase >= 0.0:
					_animation.seek(_stride_phase * _animation.get_animation(name).length, false)
			_animation.speed_scale = 1.0
			return

func _play_action(kind: String) -> void:
	_turn_clip = ""
	_obstructed_turn_yaw = INF
	var clip := "attack_1" if kind == "attack" else kind
	_play(clip)
	_stride_phase = -1.0
	_visual_action = clip
	if _animation:
		_animation.seek(0.0, true)
		_animation.speed_scale = 1.0

func _update_locomotion(_delta: float) -> void:
	if actions.action != "idle" or not _turn_clip.is_empty(): return
	var travel := Vector2(velocity.x, velocity.z).length()
	# Allow authored recovery to finish at rest; movement and a new action can interrupt it.
	if not _visual_action.is_empty():
		if travel < 0.08 and _visual_action == "dodge":
			# The source holds its low dash pose from roughly .4–1.0 s.
			# Blend into its authored recovery when gameplay translation has ended.
			_play("dodge_recovery")
			_visual_action = "dodge_recovery"
		if travel < 0.08 and _animation and _animation.is_playing() and _animation.current_animation == _visual_action:
			return
		_visual_action = ""
	var clip := "idle"
	if travel > 0.08:
		var walk_boundary := 1.1 if _travel_clip == "walk" else 0.9
		var run_boundary := 3.2 if _travel_clip == "run" else 3.5
		clip = "walk" if travel < walk_boundary else "gentle_jog"
		if SpaceState.is_exploring() and travel > run_boundary:
			clip = "run"
	_travel_clip = clip
	_play(clip)
	if _animation and clip != "idle":
		var native_speed: float = GENTLE_JOG_NATIVE_SPEED if clip == "gentle_jog" else TemplateMotion.CLIPS[clip].native_travel_speed
		_animation.speed_scale = travel / maxf(native_speed, 0.01)

func sync_location() -> void:
	if _garment_motion: _garment_motion.reset_motion()
	_turn_clip = ""
	_obstructed_turn_yaw = INF
	_visual_action = ""
	_play("idle")
	_travel_clip = "idle"
	_stride_phase = -1.0
	_action_travel = false
	_last_land = global_position
	_space_id = SpaceState.space_id
	actions.cancel()
	velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if _blocked():
		return
	if event is InputEventMouseMotion:
		_mouse_aim = true
	var attack: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var counter: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	var dodge := false
	if event is InputEventKey and event.pressed and not event.echo:
		attack = event.physical_keycode == KEY_J
		counter = event.physical_keycode == KEY_K
		dodge = event.physical_keycode == KEY_SPACE
	var island := get_tree().get_first_node_in_group("island_shell")
	if island and island.build_mode and event is InputEventMouseButton: return
	if attack or counter:
		if actions.start("counter" if counter else "attack"):
			var toward := _aim_direction()
			mesh.rotation.y = atan2(toward.x,toward.z)
			_play_action("counter" if counter else "attack")
		get_viewport().set_input_as_handled()
	elif dodge:
		if actions.start("dodge"):
			_dodge_direction = _move_direction()
			if _dodge_direction.length_squared() < 0.01: _dodge_direction = facing()
			mesh.rotation.y = atan2(_dodge_direction.x,_dodge_direction.z)
			_play_action("dodge")
		get_viewport().set_input_as_handled()

func _aim_direction() -> Vector3:
	var raw := facing()
	var camera := get_viewport().get_camera_3d()
	if _mouse_aim and camera:
		var cursor := get_viewport().get_mouse_position()
		raw = Geometry.direction_from_ray(camera.project_ray_origin(cursor),camera.project_ray_normal(cursor),global_position,raw)
	var arena := get_tree().get_first_node_in_group("combat_arena")
	var targets: Array = [arena.target_position()] if arena and SpaceState.is_courtyard() and arena.health > 0 else []
	return Geometry.aim_direction(global_position,raw,targets)

func _equip_sword() -> void:
	var skeleton := _find_skeleton(mesh)
	if skeleton == null: return
	var hand := skeleton.find_bone("Hand.R")
	if hand < 0: return
	var attachment := BoneAttachment3D.new()
	attachment.name = "SwordHand"
	attachment.bone_name = "Hand.R"
	skeleton.add_child(attachment)
	var sword := preload("res://assets/weapons/sword/starter_jian.glb").instantiate()
	sword.name = "StarterSword"
	_sword = sword
	attachment.add_child(sword)
	var pose := skeleton.get_bone_global_rest(hand)
	var up := (skeleton.global_basis.inverse() * mesh.global_basis * Vector3(0,0,1)).normalized()
	var right := Vector3.RIGHT
	var desired := Transform3D(Basis(right,up,right.cross(up)),pose.origin+pose.basis.y*.035)
	sword.transform = pose.affine_inverse()*desired
	sword.scale *= .8

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result: return result
	return null

func facing() -> Vector3:
	return Vector3(sin(mesh.rotation.y), 0.0, cos(mesh.rotation.y))

func _move_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw := _camera_yaw()
	return (Vector3(cos(yaw),0,-sin(yaw))*input.x + Vector3(sin(yaw),0,cos(yaw))*input.y).limit_length(1.0)

func _pace_for_space() -> float:
	if SpaceState.is_inside(): return INDOOR_WALK_SPEED
	if SpaceState.is_exploring(): return EXPLORATION_RUN_SPEED
	return COURTYARD_JOG_SPEED

func _begin_turn(target_yaw: float) -> void:
	_turn_start_yaw = mesh.rotation.y
	_turn_angle = angle_difference(_turn_start_yaw, target_yaw)
	_turn_clip = "turn_%s_%d" % ["left" if _turn_angle > 0.0 else "right", 180 if absf(_turn_angle) > PI * 0.75 else 90]
	_turn_time = 0.0
	_visual_action = ""
	# Replay explicitly: even a same-name redirect needs its previous pose blended out.
	_animation.play(_turn_clip, 0.10)
	_animation.speed_scale = 1.0
	_stride_phase = -1.0
	_animation.seek(0.0, true)

func _turn_sample(at: float) -> Vector3:
	# Packed curve columns: seconds, captured heading, root X, root Z.
	var curve: Array = _turn_data[_turn_clip].root_curve
	var index := mini(int(at * 30.0), curve.size() - 2)
	var a: Array = curve[index]
	var b: Array = curve[index + 1]
	var weight := clampf((at - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
	return Vector3(float(a[2]), float(a[1]), float(a[3])).lerp(Vector3(float(b[2]), float(b[1]), float(b[3])), weight)

func _curve_values(curve: Array, at: float) -> Array:
	var index := mini(int(at * 30.0), curve.size() - 2)
	var a: Array = curve[index]
	var b: Array = curve[index + 1]
	var weight := clampf((at - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
	var result: Array = []
	for i in a.size(): result.append(lerpf(float(a[i]), float(b[i]), weight))
	return result

func _turn_can_settle() -> bool:
	var soles := _curve_values(_turn_data[_turn_clip].sole_height_curve, _turn_time)
	return _turn_time >= 0.15 and maxf(soles[1], soles[2]) < 0.025

func _warped_turn_step(from_time: float, to_time: float) -> Vector3:
	var data: Dictionary = _turn_data[_turn_clip]
	var before := _turn_sample(from_time)
	var after := _turn_sample(to_time)
	var feet_before := _curve_values(data.foot_curve, from_time)
	var feet_after := _curve_values(data.foot_curve, to_time)
	var soles_before := _curve_values(data.sole_height_curve, from_time)
	var soles_after := _curve_values(data.sole_height_curve, to_time)
	# Choose one support foot for the whole interval, using actual sole heights.
	var offset := 1 if soles_before[1] + soles_after[1] <= soles_before[2] + soles_after[2] else 4
	var foot_before := Vector3(feet_before[offset], 0.0, feet_before[offset + 2])
	var foot_after := Vector3(feet_after[offset], 0.0, feet_after[offset + 2])
	var scale_yaw := _turn_angle / float(data.yaw_radians)
	var yaw_before := before.y * scale_yaw
	var yaw_after := after.y * scale_yaw
	var extra_yaw := (yaw_before - before.y + yaw_after - after.y) * 0.5
	var root_step := Vector3(after.x - before.x, 0.0, after.z - before.z)
	var source_foot_step := foot_after.rotated(Vector3.UP, after.y) - foot_before.rotated(Vector3.UP, before.y)
	var target_foot_step := foot_after.rotated(Vector3.UP, yaw_after) - foot_before.rotated(Vector3.UP, yaw_before)
	# Preserve the captured support-foot displacement when adapting the corner angle.
	return (root_step + source_foot_step).rotated(Vector3.UP, extra_yaw) - target_foot_step

func _advance_turn(delta: float) -> void:
	var data: Dictionary = _turn_data[_turn_clip]
	var before := _turn_time
	_turn_time = minf(_turn_time + delta, float(data.seconds))
	var after := _turn_sample(_turn_time)
	mesh.rotation.y = _turn_start_yaw + after.y * _turn_angle / float(data.yaw_radians)
	velocity = _warped_turn_step(before, _turn_time).rotated(Vector3.UP, _turn_start_yaw) / maxf(delta, 0.0001)

func _update_travel(direction: Vector3, delta: float) -> void:
	if not _turn_clip.is_empty() and _turn_time >= float(_turn_data[_turn_clip].seconds):
		_turn_clip = ""
		_stride_phase = -1.0
	if not _turn_clip.is_empty():
		var changed := direction.length_squared() < 0.0001 or absf(angle_difference(_turn_start_yaw + _turn_angle, atan2(direction.x, direction.z))) > PI / 6.0
		if changed and _turn_can_settle():
			_turn_clip = ""
			_stride_phase = -1.0
			velocity = Vector3.ZERO
		else:
			_advance_turn(delta)
			return
	var pace := _pace_for_space()
	var speed := minf(Vector2(velocity.x, velocity.z).length(), pace)
	var target_speed := 0.0
	if direction.length_squared() > 0.0001:
		var target_yaw := atan2(direction.x, direction.z)
		var angle := absf(angle_difference(mesh.rotation.y, target_yaw))
		if is_finite(_obstructed_turn_yaw) and absf(angle_difference(target_yaw, _obstructed_turn_yaw)) > 0.1:
			_obstructed_turn_yaw = INF
		if angle >= STEP_TURN_ANGLE and not is_finite(_obstructed_turn_yaw):
			if speed <= PIVOT_SPEED:
				_begin_turn(target_yaw)
				_advance_turn(delta)
				return
		else:
			mesh.rotation.y = rotate_toward(mesh.rotation.y, target_yaw, TURN_RATE * delta)
			var alignment := maxf(facing().dot(direction.normalized()), 0.0)
			target_speed = pace * direction.length() * alignment * alignment
	var rate := TRAVEL_ACCELERATION if target_speed > speed else TRAVEL_BRAKING
	speed = move_toward(speed, target_speed, rate * delta)
	velocity = facing() * speed

func _physics_process(delta: float) -> void:
	if _space_id != SpaceState.space_id or global_position.distance_to(_last_land) > 20.0:
		sync_location()
	if _blocked():
		_turn_clip = ""
		_obstructed_turn_yaw = INF
		actions.cancel()
		_visual_action = ""
		_stride_phase = -1.0
		_action_travel = false
		velocity = Vector3.ZERO
		_play("idle")
		_stride_phase = -1.0
		_travel_clip = "idle"
		return
	var arena_state := get_tree().get_first_node_in_group("combat_arena")
	var pressure: float = arena_state.pressure_at(global_position) if arena_state and SpaceState.is_courtyard() else 0.0
	ward_state.advance(delta,pressure)
	var impact := actions.advance(delta)
	if impact:
		var arena := get_tree().get_first_node_in_group("combat_arena")
		if arena:
			arena.strike(self)
	var direction := _move_direction()
	if actions.action == "dodge":
		_action_travel = true
		direction = _dodge_direction
		velocity = direction * 6.2
	elif actions.action in ["attack","counter"]:
		_action_travel = true
		velocity = direction * 0.6
	else:
		if _action_travel:
			velocity = Vector3.ZERO
			_action_travel = false
		_update_travel(direction, delta)
	var before := global_position
	var expected_motion := velocity * delta
	# Traverse in small increments so a dodge cannot tunnel across a narrow river.
	var distance := velocity.length() * delta
	var steps := maxi(1, ceili(distance/0.10))
	var motion := velocity * delta / steps
	for i in steps:
		var candidate := global_position + motion
		if not _walkable(candidate):
			# Slide along an edge when diagonal motion reaches water or the island edge.
			var along_x := global_position + Vector3(motion.x,0,0)
			var along_z := global_position + Vector3(0,0,motion.z)
			if absf(motion.x)>0.001 and _walkable(along_x):
				move_and_collide(Vector3(motion.x,0,0))
			elif absf(motion.z)>0.001 and _walkable(along_z):
				move_and_collide(Vector3(0,0,motion.z))
			break
		var collision := move_and_collide(motion)
		if collision:
			move_and_collide(collision.get_remainder().slide(collision.get_normal()))
	global_position.y = 0.0
	if _walkable(global_position):
		_last_land = global_position
	else:
		global_position = _last_land
	if not _turn_clip.is_empty() and (global_position - before).distance_to(expected_motion) > maxf(0.0002, expected_motion.length() * 0.2):
		# A blocked support step cannot keep its authored foot contact. Blend out and
		# use gradual gait steering for this direction rather than replaying the blocked step.
		_obstructed_turn_yaw = _turn_start_yaw + _turn_angle
		_turn_clip = ""
		_stride_phase = -1.0
	velocity = (global_position-before)/maxf(delta,0.0001)
	_update_locomotion(delta)
	SpaceState.player_x = global_position.x
	SpaceState.player_z = global_position.z

func _walkable(at: Vector3) -> bool:
	if SpaceState.is_inside():
		return true
	var ground := get_tree().get_first_node_in_group("explore_shell" if SpaceState.is_exploring() else "island_shell")
	if ground and ground.has_method("is_walkable"):
		return bool(ground.is_walkable(at))
	return true

func receive_hit() -> void:
	var arena := get_tree().get_first_node_in_group("combat_arena")
	receive_attack(20,8,0,arena.target_position() if arena else global_position-facing())

func receive_attack(physical: float, spiritual: float, realm: int, origin: Vector3) -> void:
	if _blocked() or actions.is_invulnerable(): return
	var arena := get_tree().get_first_node_in_group("combat_arena")
	if actions.try_parry(facing(),origin-global_position):
		if arena: arena.notice = "拆招成功 · 正面拦下一击"
		return
	ward_state.receive_attack(physical,spiritual,realm)
	if ward_state.health <= 0:
		ward_state.health = ward_state.max_health
		ward_state.ward = ward_state.max_ward
		actions.cancel()
		if arena:
			arena.notice = "试炼失利 · 调息后重新练习"
			arena.reset_after_defeat()

func _camera_yaw() -> float:
	var rig := get_tree().get_first_node_in_group("camera_rig")
	return float(rig.get_yaw()) if rig else 0.0

func _blocked() -> bool:
	var island := get_tree().get_first_node_in_group("island_shell")
	if island and island.build_mode:
		return true
	var space := get_tree().get_first_node_in_group("space_controller")
	if space and space.is_input_blocked():
		return true
	var ui := get_tree().get_first_node_in_group("preview_menu")
	return ui != null and ui.is_open()
