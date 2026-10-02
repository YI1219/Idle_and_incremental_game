extends Node3D
## Preloaded interior at a distant cell. Cover → teleport the same actor → reveal.
## One ColorRect uses the existing CanvasItem path. No second viewport, no per-mesh fade.

const INTERIOR_LAYER := 2
const EXTERIOR_LAYER := 1
const PLAYER_LAYER := 4
const EXPLORE_LAYER := 8
const ENTRY_WIDTH := 1.8
const COVER_SECONDS := 0.16
const HOLD_SECONDS := 0.035
const REVEAL_SECONDS := 0.20
const REENTRY_COOLDOWN := 0.22
enum Phase { IDLE, COVER, SWAP, REVEAL }

var transition_opacity := 0.0
var interior_root: Node3D
var explore_root: Node3D
var shell_root: Node3D
var _player: CharacterBody3D
var _interior_meshes: Array[GeometryInstance3D] = []
var _indoor_lights: Array[Light3D] = []
var _exterior_roots: Array[Node3D] = []
var _exterior_visibility: Array[bool] = []
var _world_environment: WorldEnvironment
var _outside_background_mode := Environment.BG_COLOR
var _outside_background := Color("becfd4")
var _outside_fog := Color("becfd4")
var _outside_ambient_source := Environment.AMBIENT_SOURCE_BG
var _outside_ambient_color := Color.WHITE
var _outside_ambient_energy := 0.0
var _veil: ColorRect
var _phase := Phase.IDLE
var _phase_time := 0.0
var _cooldown := 0.0
var _target_space := ""
var _entry_offset := 0.0
var _committing := false


func configure(house: Node3D) -> void:
	shell_root = house


func is_inside() -> bool:
	return SpaceState.is_inside()


func _ready() -> void:
	add_to_group("space_controller")
	_build_interior()
	_build_explore()
	_build_veil()
	var world := get_parent().get_parent()
	var sun := world.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.light_angular_distance = 1.6
		sun.shadow_blur = 2.2
	_world_environment = world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _world_environment and _world_environment.environment:
		_world_environment.environment = _world_environment.environment.duplicate()
		_outside_background_mode = _world_environment.environment.background_mode
		_outside_background = _world_environment.environment.background_color
		_outside_fog = _world_environment.environment.fog_light_color
		_outside_ambient_source = _world_environment.environment.ambient_light_source
		_outside_ambient_color = _world_environment.environment.ambient_light_color
		_outside_ambient_energy = _world_environment.environment.ambient_light_energy
	SpaceState.space_changed.connect(_on_space_changed)
	call_deferred("_initialize_player")


func _build_veil() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DoorVeil"
	layer.layer = 60
	add_child(layer)
	_veil = ColorRect.new()
	_veil.name = "JadeMist"
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.075, 0.15, 0.145, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.hide()
	layer.add_child(_veil)


func _initialize_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_cache_exterior_roots()
	if is_instance_valid(_player):
		_set_player_render_layers(_player)
	sync_after_relocation()


func _cache_exterior_roots() -> void:
	_exterior_roots.clear()
	_exterior_visibility.clear()
	var homestead := get_parent()
	for node in homestead.get_children():
		if node is Node3D and node != self:
			_exterior_roots.append(node)
	for node in homestead.get_parent().get_children():
		if node is Node3D and node != homestead and node != _player and not node.is_in_group("camera_rig") and not node is WorldEnvironment:
			_exterior_roots.append(node)
	for node in _exterior_roots:
		_exterior_visibility.append(node.visible)


func is_transitioning() -> bool:
	return _phase != Phase.IDLE


func is_input_blocked() -> bool:
	return is_transitioning()


func get_transition_phase() -> String:
	return ["idle", "cover", "swap", "reveal"][_phase]


func _physics_process(delta: float) -> void:
	var island := get_tree().get_first_node_in_group("island_shell")
	if island and island.build_mode:
		return
	if not is_instance_valid(_player):
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if is_transitioning() or _cooldown > 0.0:
		return
	var ui := get_tree().get_first_node_in_group("preview_menu")
	if ui and ui.has_method("is_open") and ui.is_open():
		return
	if SpaceState.is_inside():
		var local := _player.global_position - SpaceState.home_origin()
		if absf(local.x) < ENTRY_WIDTH * 0.5 and local.z >= 5.70:
			request_transition("outside")
	elif SpaceState.is_exploring():
		var local := _player.global_position - SpaceState.explore_origin()
		if absf(local.x) < 0.9 and local.z <= 0.35:
			request_transition("outside")
	else:
		var depth := SpaceState.house_door.z - _player.global_position.z
		if absf(_player.global_position.x - SpaceState.house_door.x) < ENTRY_WIDTH * 0.5 and depth >= -0.05 and depth < 1.1:
			request_transition("inside")
		var gate: Vector3 = SpaceState.GATE
		if absf(_player.global_position.x - gate.x) < 0.9 and _player.global_position.z >= 3.55 and _player.global_position.z < 4.2:
			request_transition("explore")


func request_transition(target: String) -> bool:
	if not is_instance_valid(_player) or target not in ["inside", "outside", "explore"] or target == SpaceState.space_id:
		return false
	if is_transitioning() or _cooldown > 0.0:
		return false
	_target_space = target
	if target == "inside":
		_entry_offset = clampf(_player.global_position.x - SpaceState.house_door.x, -0.5, 0.5)
	elif target == "outside" and SpaceState.is_inside():
		_entry_offset = clampf((_player.global_position - SpaceState.home_origin()).x, -0.5, 0.5)
	else:
		_entry_offset = 0.0
	_phase = Phase.COVER
	_phase_time = 0.0
	_player.velocity = Vector3.ZERO
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_opacity(0.0)
	_veil.show()
	return true


func _process(delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	_phase_time += delta
	match _phase:
		Phase.COVER:
			_set_opacity(smoothstep(0.0, COVER_SECONDS, _phase_time))
			if _phase_time >= COVER_SECONDS:
				_set_opacity(1.0)
				_phase = Phase.SWAP
				_phase_time = 0.0
		Phase.SWAP:
			if not _target_space.is_empty():
				_commit_transfer()
			if _phase_time >= HOLD_SECONDS:
				_phase = Phase.REVEAL
				_phase_time = 0.0
		Phase.REVEAL:
			_set_opacity(1.0 - smoothstep(0.0, REVEAL_SECONDS, _phase_time))
			if _phase_time >= REVEAL_SECONDS:
				_phase = Phase.IDLE
				_set_opacity(0.0)
				_veil.hide()
				_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_cooldown = REENTRY_COOLDOWN


func _set_opacity(value: float) -> void:
	transition_opacity = clampf(value, 0.0, 1.0)
	if is_instance_valid(_veil):
		_veil.color.a = transition_opacity


func _commit_transfer() -> void:
	var destination: Vector3
	if _target_space == "inside":
		destination = SpaceState.home_arrival(_entry_offset)
	elif _target_space == "explore":
		destination = SpaceState.explore_arrival()
	elif SpaceState.is_exploring():
		destination = SpaceState.gate_return()
	else:
		destination = SpaceState.exit_position() + Vector3(_entry_offset, 0.0, 0.0)
	var sim := _sim()
	if SpaceState.is_exploring() and _target_space == "outside" and sim and sim.trip and bool(sim.trip.active):
		sim.trip.withdraw()
	if _target_space == "explore" and sim and sim.trip:
		sim.trip.begin()
	_committing = true
	_player.global_position = destination
	_player.velocity = Vector3.ZERO
	SpaceState.player_x = destination.x
	SpaceState.player_z = destination.z
	SpaceState.enter(_target_space)
	if _player.has_method("sync_location"):
		_player.sync_location()
	_apply_space()
	_snap_camera()
	_target_space = ""
	_committing = false


func _apply_space() -> void:
	var inside := SpaceState.is_inside()
	var exploring := SpaceState.is_exploring()
	if inside:
		_player.collision_mask = INTERIOR_LAYER
	elif exploring:
		_player.collision_mask = EXPLORE_LAYER
	else:
		_player.collision_mask = EXTERIOR_LAYER
	interior_root.visible = inside
	if explore_root:
		explore_root.visible = exploring
	for index in _exterior_roots.size():
		var node := _exterior_roots[index]
		if not is_instance_valid(node):
			continue
		if node is DirectionalLight3D:
			node.visible = _exterior_visibility[index] and not inside
		else:
			node.visible = _exterior_visibility[index] and not inside and not exploring
	var camera := get_viewport().get_camera_3d()
	if camera:
		var world_layer := EXPLORE_LAYER if exploring else EXTERIOR_LAYER
		camera.cull_mask = (INTERIOR_LAYER if inside else world_layer) | PLAYER_LAYER
	if _world_environment and _world_environment.environment:
		_world_environment.environment.background_mode = Environment.BG_COLOR if inside or exploring else _outside_background_mode
		if inside:
			_world_environment.environment.background_color = Color("10292b")
			_world_environment.environment.fog_light_color = Color("10292b")
			_world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_world_environment.environment.ambient_light_color = Color("d5d7c6")
			_world_environment.environment.ambient_light_energy = 0.45
		elif exploring:
			_world_environment.environment.background_color = Color("9aaeb4")
			_world_environment.environment.fog_light_color = Color("9aaeb4")
			_world_environment.environment.ambient_light_source = _outside_ambient_source
			_world_environment.environment.ambient_light_color = _outside_ambient_color
			_world_environment.environment.ambient_light_energy = _outside_ambient_energy
		else:
			_world_environment.environment.background_color = _outside_background
			_world_environment.environment.fog_light_color = _outside_fog
			_world_environment.environment.ambient_light_source = _outside_ambient_source
			_world_environment.environment.ambient_light_color = _outside_ambient_color
			_world_environment.environment.ambient_light_energy = _outside_ambient_energy


func sync_after_relocation() -> void:
	if not is_instance_valid(_player):
		return
	_phase = Phase.IDLE
	_phase_time = 0.0
	_target_space = ""
	_set_opacity(0.0)
	_veil.hide()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cooldown = 0.0
	_player.global_position = Vector3(SpaceState.player_x, 0.0, SpaceState.player_z)
	_player.velocity = Vector3.ZERO
	if _player.has_method("sync_location"):
		_player.sync_location()
	_apply_space()
	_snap_camera()


func _on_space_changed(_previous: String, _current: String) -> void:
	if not _committing:
		sync_after_relocation()


func _snap_camera() -> void:
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("snap_to_target"):
		rig.snap_to_target()


func _collect_geometry(node: Node, target: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		target.append(node)
	for child in node.get_children():
		_collect_geometry(child, target)


func _set_player_render_layers(node: Node) -> void:
	if node is GeometryInstance3D:
		node.layers = PLAYER_LAYER
	for child in node.get_children():
		_set_player_render_layers(child)


func get_camera_focus(player_position: Vector3) -> Vector3:
	var focus := Vector3(player_position.x, player_position.y + 0.72, player_position.z)
	if not SpaceState.is_inside():
		return focus
	var center := SpaceState.home_origin()
	var inside_focus := Vector3(clampf(player_position.x, center.x - 4.0, center.x + 4.0), 0.72, clampf(player_position.z, center.z - 3.0, center.z + 3.0))
	return focus.lerp(inside_focus, 0.58)


func get_camera_distance(outside_distance: float) -> float:
	return clampf(outside_distance * 0.91, 13.0, 24.0) if SpaceState.is_inside() else outside_distance


func _sim() -> RefCounted:
	var island := get_tree().get_first_node_in_group("island_shell")
	if island == null:
		return null
	return island.sim


func _build_explore() -> void:
	explore_root = preload("res://scripts/world/explore_shell.gd").new()
	explore_root.name = "ExploreShell"
	add_child(explore_root)
	explore_root.visible = false


func _build_interior() -> void:
	interior_root = Node3D.new()
	interior_root.name = "Interior"
	add_child(interior_root)
	interior_root.position = SpaceState.home_origin()
	_placeholder_box(Vector3(0, -0.015, 0), Vector3(16, 0.12, 12), Color("a3947e"))
	_placeholder_box(Vector3(0, 1.0, -6), Vector3(16, 2.0, 0.18), Color("e3decf"))
	_placeholder_box(Vector3(-8, 0.5, 0), Vector3(0.18, 1.0, 12), Color("9a8270"))
	_placeholder_box(Vector3(8, 0.5, 0), Vector3(0.18, 1.0, 12), Color("9a8270"))
	_room_collision(Vector3(-8.0, 1.2, 0), Vector3(0.35, 2.4, 12.3))
	_room_collision(Vector3(8.0, 1.2, 0), Vector3(0.35, 2.4, 12.3))
	_room_collision(Vector3(0, 1.2, -6.0), Vector3(16.3, 2.4, 0.35))
	_room_collision(Vector3(-4.55, 1.2, 6.0), Vector3(6.9, 2.4, 0.35))
	_room_collision(Vector3(4.55, 1.2, 6.0), Vector3(6.9, 2.4, 0.35))
	for p in [Vector3(-4, 3.8, -2.5), Vector3(4, 3.8, -2.5), Vector3(0, 3.2, 3.0)]:
		var light := OmniLight3D.new()
		light.position = p
		light.light_color = Color("ffe1aa")
		light.light_energy = 1.25
		light.omni_range = 9.5
		light.omni_attenuation = 1.35
		light.layers = INTERIOR_LAYER
		light.light_cull_mask = INTERIOR_LAYER | PLAYER_LAYER
		interior_root.add_child(light)
		_indoor_lights.append(light)
	# Sparse furniture establishes human scale without filling the room with detail.
	_placeholder_box(Vector3(-5.3,.15,-3.5),Vector3(2.8,.3,1.5),Color("726f60"))
	_placeholder_box(Vector3(-5.3,.34,-3.5),Vector3(2.65,.12,1.4),Color("ced7ca"))
	_placeholder_box(Vector3(3.8,.65,-3.7),Vector3(2.3,.16,1.0),Color("655747"))
	for x in [2.9,4.7]:
		_placeholder_box(Vector3(x,.3,-3.7),Vector3(.12,.6,.72),Color("655747"))
	_placeholder_box(Vector3(0,.065,-1),Vector3(2.1,.05,1.6),Color("6f9691"))
	_placeholder_box(Vector3(0,.065,5.6),Vector3(1.8,.03,.5),Color("ccbd91"))
	_collect_geometry(interior_root, _interior_meshes)
	for mesh in _interior_meshes:
		mesh.layers = INTERIOR_LAYER
	interior_root.visible = false


func _placeholder_box(at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	mesh.material_override = material
	mesh.position = at
	interior_root.add_child(mesh)


func _room_collision(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = INTERIOR_LAYER
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	interior_root.add_child(body)
