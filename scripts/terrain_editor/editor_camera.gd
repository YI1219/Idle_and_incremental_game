class_name EditorCamera
extends Camera3D
## Height is a separate state changed exclusively by wheel input.
var height_goal:=21.0
var _height:=21.0
var _center:=Vector2(0,-1)
var _center_goal:=Vector2(0,-1)
var _dragging:=false
var _orbiting:=false
var _yaw:=16.0
var _yaw_goal:=16.0
var _pitch:=27.0
var _pitch_goal:=27.0
const MIN_HEIGHT:=6.0
const MAX_HEIGHT:=100.0
const PITCH:=27.0
const YAW:=16.0
func _ready()->void:
	fov=31.0
	near=0.1
	far=1800.0
	rotation_degrees=Vector3(-PITCH,YAW,0)
	current=true
	advance(0.0)
func _process(delta:float)->void:
	var focus:=get_viewport().gui_get_focus_owner()
	if not focus is LineEdit and not focus is TextEdit:
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
	_pitch_goal=clampf(_pitch_goal+relative.y*.18,20.0,65.0)
func wheel(steps:float)->void:
	height_goal=clampf(height_goal*pow(1.12,clampf(steps,-100,100)),MIN_HEIGHT,MAX_HEIGHT)
func advance(delta:float)->void:
	var weight:=1.0-exp(-12.0*maxf(delta,0.0))
	_yaw=lerpf(_yaw,_yaw_goal,weight)
	_pitch=lerpf(_pitch,_pitch_goal,weight)
	rotation_degrees=Vector3(-_pitch,_yaw,0)
	_center=_center.lerp(_center_goal,weight)
	_height=lerpf(_height,height_goal,weight)
	var horizontal_offset:=_height/tan(deg_to_rad(_pitch))
	position=Vector3(_center.x+sin(deg_to_rad(_yaw))*horizontal_offset,_height,_center.y+cos(deg_to_rad(_yaw))*horizontal_offset)
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
