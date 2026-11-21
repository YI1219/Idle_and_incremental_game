class_name EditorCamera
extends Camera3D
## Wheel controls height and zoom pitch. Orbit changes orientation independently.
var height_goal:=21.0
var _height:=21.0
var _orbit_distance:=21.0/sin(deg_to_rad(27.0))
var _orbit_distance_goal:=21.0/sin(deg_to_rad(27.0))
var _center:=Vector2(0,-1)
var _center_goal:=Vector2(0,-1)
var _dragging:=false
var _orbiting:=false
var _yaw:=16.0
var _yaw_goal:=16.0
var _pitch:=27.0
var _pitch_goal:=27.0
var keyboard_pan_enabled:=true
var dof_enabled:=true
var dof_strength:=0.26
var dof_attributes:=CameraAttributesPractical.new()
const MIN_HEIGHT:=6.0
const MAX_HEIGHT:=100.0
const PITCH:=27.0
const YAW:=16.0
func _ready()->void:
	fov=31.0
	near=0.1
	far=3600.0
	rotation_degrees=Vector3(-PITCH,YAW,0)
	dof_attributes.dof_blur_near_enabled=false
	attributes=dof_attributes
	set_dof(dof_enabled,dof_strength)
	current=true
	advance(0.0)
func set_dof(enabled:bool,strength:float)->void:
	dof_enabled=enabled
	dof_strength=clampf(strength,0.0,1.0)
	if dof_attributes!=null:
		dof_attributes.dof_blur_far_enabled=dof_enabled and dof_strength>0.001
		dof_attributes.dof_blur_amount=0.028*dof_strength
		_update_dof_focus()
func _update_dof_focus()->void:
	if dof_attributes==null:return
	var focus_dist:float=_orbit_distance
	dof_attributes.dof_blur_far_distance=focus_dist+maxf(40.0,_height*1.72)
	dof_attributes.dof_blur_far_transition=maxf(135.0,_height*5.2)
func _process(delta:float)->void:
	var focus:=get_viewport().gui_get_focus_owner()
	if not focus is LineEdit and not focus is TextEdit:
		if keyboard_pan_enabled:
			var horizontal:=Vector2.ZERO
			if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):horizontal.y-=1
			if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):horizontal.y+=1
			if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):horizontal.x-=1
			if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):horizontal.x+=1
			pan(horizontal.limit_length(),delta)
		if Input.is_physical_key_pressed(KEY_Q):orbit_pixels(Vector2(-delta*180,0))
		if Input.is_physical_key_pressed(KEY_E):orbit_pixels(Vector2(delta*180,0))
	advance(delta)
func pan(horizontal:Vector2,delta:float)->void:
	var right:=Vector2(cos(deg_to_rad(_yaw)),-sin(deg_to_rad(_yaw)))
	var back:=Vector2(sin(deg_to_rad(_yaw)),cos(deg_to_rad(_yaw)))
	_center_goal+=(right*horizontal.x+back*horizontal.y)*delta*height_goal*0.55
func pan_pixels(relative:Vector2)->void:
	var scale:=2.0*(_height/sin(deg_to_rad(_pitch)))*tan(deg_to_rad(fov*0.5))/maxf(1,get_viewport().get_visible_rect().size.y)
	var right:=Vector2(cos(deg_to_rad(_yaw)),-sin(deg_to_rad(_yaw)))
	var back:=Vector2(sin(deg_to_rad(_yaw)),cos(deg_to_rad(_yaw)))
	_center_goal-=right*relative.x*scale+back*relative.y*scale/sin(deg_to_rad(_pitch))
func orbit_pixels(relative:Vector2)->void:
	_yaw_goal-=relative.x*.25
	_pitch_goal=clampf(_pitch_goal+relative.y*.18,18.0,70.0)
func wheel(steps:float)->void:
	height_goal=clampf(height_goal*pow(1.12,clampf(steps,-100,100)),MIN_HEIGHT,MAX_HEIGHT)
	# Keep the familiar default view while opening into an overhead distant view.
	if height_goal<=21.0:
		_pitch_goal=lerpf(19.0,PITCH,(height_goal-MIN_HEIGHT)/(21.0-MIN_HEIGHT))
	else:
		_pitch_goal=lerpf(PITCH,68.0,(height_goal-21.0)/(MAX_HEIGHT-21.0))
	_orbit_distance_goal=height_goal/sin(deg_to_rad(_pitch_goal))
func advance(delta:float)->void:
	# Capture tools explicitly set height/pitch and call advance(0) to lock framing.
	if delta==0.0:
		_orbit_distance=_height/sin(deg_to_rad(_pitch))
		_orbit_distance_goal=_orbit_distance
	var weight:=1.0-exp(-12.0*maxf(delta,0.0))
	_yaw=lerpf(_yaw,_yaw_goal,weight)
	_pitch=lerpf(_pitch,_pitch_goal,weight)
	rotation_degrees=Vector3(-_pitch,_yaw,0)
	_center=_center.lerp(_center_goal,weight)
	_orbit_distance=lerpf(_orbit_distance,_orbit_distance_goal,weight)
	_height=_orbit_distance*sin(deg_to_rad(_pitch))
	var horizontal_offset:=_orbit_distance*cos(deg_to_rad(_pitch))
	position=Vector3(_center.x+sin(deg_to_rad(_yaw))*horizontal_offset,_height,_center.y+cos(deg_to_rad(_yaw))*horizontal_offset)
	_update_dof_focus()
func recenter(center:Vector2)->void:
	_center_goal=center
func cancel_input()->void:
	_dragging=false
	_orbiting=false
func _input(event:InputEvent)->void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index==MOUSE_BUTTON_MIDDLE:_dragging=false
		if event.button_index==MOUSE_BUTTON_RIGHT:_orbiting=false
func _unhandled_input(event:InputEvent)->void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_MIDDLE:
			_dragging=event.pressed
			get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			_orbiting=event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			wheel(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		pan_pixels(event.relative)
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _orbiting:
		orbit_pixels(event.relative)
		get_viewport().set_input_as_handled()
