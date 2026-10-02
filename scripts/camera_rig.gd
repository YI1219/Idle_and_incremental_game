extends Node3D
## Don't Starve dolly: zoom couples to pitch, ground-plane pan, 45° yaw steps.
## Doorway swaps snap this node under a full-screen cover so it never flies the gap.
@export var target_path: NodePath
@export var min_distance := 10.0
@export var max_distance := 28.0
@export var default_distance := 20.0
@export var pitch_deg := 50.0
@export var near_pitch_deg := 38.0
@export var far_pitch_deg := 58.0
@export var look_height := 0.72
@export var zoom_response := 8.0
@export var pan_limit := 12.0

const YAW_STEP := TAU / 8.0
var _target: Node3D
var _yaw_index := 1
var _distance := 20.0
var _last_focus := Vector3(INF, INF, INF)
var _smooth_yaw := TAU / 8.0
var _smooth_distance := 20.0
var _smooth_pitch := 50.0
var _pan_goal := Vector3.ZERO
var _smooth_pan := Vector3.ZERO
var _panning := false


func _ready() -> void:
	add_to_group("camera_rig")
	_distance = default_distance
	if _target == null:
		_target = get_node_or_null(target_path) as Node3D
	set_as_top_level(true)
	_apply(true)


func set_target(node: Node3D) -> void:
	_target = node
	_apply(true)


func get_yaw() -> float:
	return _smooth_yaw


func _space() -> Node:
	return get_tree().get_first_node_in_group("space_controller")


func _inside() -> bool:
	var space := _space()
	return space != null and space.has_method("is_inside") and bool(space.is_inside())


func _blocked() -> bool:
	var space := _space()
	if space and space.has_method("is_input_blocked") and space.is_input_blocked():
		return true
	var ui := get_tree().get_first_node_in_group("preview_menu")
	return ui != null and ui.has_method("is_open") and bool(ui.is_open())


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		_panning = false


func _unhandled_input(event: InputEvent) -> void:
	if _blocked():
		_panning = false
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			nudge_zoom(direction * 1.6 * (event.factor if event.factor > 0 else 1.0))
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = not event.double_click
			if event.double_click:
				recenter()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and _panning:
		pan_by_pixels(event.position, event.relative)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		nudge_zoom(event.delta.y * 0.6)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_HOME:
		recenter()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_left"):
		_yaw_index = (_yaw_index + 7) % 8
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_right"):
		_yaw_index = (_yaw_index + 1) % 8
		get_viewport().set_input_as_handled()


func nudge_zoom(amount: float) -> void:
	if is_finite(amount):
		_distance = clampf(_distance + amount, min_distance, max_distance)


func recenter() -> void:
	_pan_goal = Vector3.ZERO
	_panning = false


func pan_by_pixels(point: Vector2, relative: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or relative.length_squared() == 0:
		return
	var plane := Plane(Vector3.UP, look_height)
	var previous = plane.intersects_ray(camera.project_ray_origin(point - relative), camera.project_ray_normal(point - relative))
	var current = plane.intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if previous == null or current == null:
		return
	var motion: Vector3 = previous - current
	motion.y = 0
	var limit := minf(pan_limit, 4.0) if _inside() else pan_limit
	_pan_goal = (_pan_goal + motion).limit_length(limit)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_panning = false


func _physics_process(delta: float) -> void:
	_apply(false, delta)


func snap_to_target() -> void:
	_pan_goal = Vector3.ZERO
	_smooth_pan = Vector3.ZERO
	_panning = false
	_apply(true)


func _pitch_for_zoom(distance: float) -> float:
	if distance <= default_distance:
		return lerpf(near_pitch_deg, pitch_deg, clampf(inverse_lerp(min_distance, default_distance, distance), 0, 1))
	return lerpf(pitch_deg, far_pitch_deg, clampf(inverse_lerp(default_distance, max_distance, distance), 0, 1))


func _apply(snap: bool, delta: float = 0.01667) -> void:
	if _target == null:
		return
	var yaw := float(_yaw_index) * YAW_STEP
	var focus := Vector3(_target.global_position.x, look_height, _target.global_position.z)
	var desired_distance := _distance
	var space := _space()
	if space and space.has_method("get_camera_focus"):
		focus = space.get_camera_focus(_target.global_position)
		desired_distance = space.get_camera_distance(_distance)
	var desired_pitch := _pitch_for_zoom(_distance)
	if _inside():
		desired_pitch = maxf(44.0, desired_pitch)
	var follow := 1.0 - exp(-delta * 10.0)
	var zoom := 1.0 - exp(-delta * zoom_response)
	if snap or not _last_focus.is_finite():
		_last_focus = focus
		_smooth_yaw = yaw
		_smooth_distance = desired_distance
		_smooth_pitch = desired_pitch
		_smooth_pan = _pan_goal
	else:
		_last_focus = _last_focus.lerp(focus, follow)
		_smooth_yaw = lerp_angle(_smooth_yaw, yaw, follow)
		_smooth_distance = lerpf(_smooth_distance, desired_distance, zoom)
		_smooth_pitch = lerpf(_smooth_pitch, desired_pitch, zoom)
		_smooth_pan = _smooth_pan.lerp(_pan_goal, zoom)
	var pitch := deg_to_rad(_smooth_pitch)
	var offset := Vector3(sin(_smooth_yaw) * cos(pitch), sin(pitch), cos(_smooth_yaw) * cos(pitch)) * _smooth_distance
	global_transform = Transform3D(Basis.looking_at(-offset, Vector3.UP), _last_focus + _smooth_pan + offset)
