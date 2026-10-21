class_name TerrainEditor
extends Node3D
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Renderer=preload("res://scripts/terrain_editor/terrain_renderer.gd")
const Decoration=preload("res://scripts/terrain_editor/terrain_decoration.gd")
const Camera=preload("res://scripts/terrain_editor/editor_camera.gd")
const HUD=preload("res://scripts/terrain_editor/editor_hud.gd")
@export var sunlight_energy := 1.18
@export var fill_energy := 0.19
@export var ambient_energy := 0.45
@export_range(0.0,1.0) var background_haze := 0.65
var data:=Data.new()
var renderer:=Renderer.new()
var camera:=Camera.new()
var landscape:=preload("res://scripts/terrain_editor/distant_landscape.gd").new()
var hud:CanvasLayer
var tool:="raise"
var radius:=1.6
var snap:=false
var build_height:=1.5
var water_level:=3
var painting:=false
var last_edit_ms:=0.0
var brush:=MeshInstance3D.new()
var _last_paint:=Vector2(INF,INF)
var _clock:=0.0
var _last_sculpt:=Vector3(INF,INF,INF)
var _last_sculpt_screen:=Vector2(INF,INF)
func _ready()->void:
	data.make_preset(0)
	add_child(renderer)
	renderer.configure(data)
	renderer.decoration=_create_decoration()
	renderer.rebuild_all()
	add_child(camera)
	add_child(landscape)
	_setup_environment()
	add_child(brush)
	var marker:=StandardMaterial3D.new()
	marker.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.albedo_color=Color("fff5b0")
	marker.no_depth_test=true
	brush.material_override=marker
	hud=HUD.new()
	hud.editor=self
	add_child(hud)
func _create_decoration()->RefCounted:
	return Decoration.new()
func _setup_environment()->void:
	preload("res://scripts/terrain_editor/terrain_environment.gd").setup(self,landscape,sunlight_energy,fill_energy,ambient_energy,background_haze)
func _process(delta:float)->void:
	landscape.position=Vector3(camera._center.x,0,camera._center.y)
	renderer.flush_dirty(2)
	var mouse:=get_viewport().get_mouse_position()
	if hud.is_over_panel(mouse):brush.visible=false
	else:
		_update_brush(mouse)
		if painting:continue_paint(mouse)
	_clock+=delta
	if _clock>0.25:
		_clock=0
		hud.update_diagnostics()
func _notification(what:int)->void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:cancel_input()
func cancel_input()->void:
	painting=false
	data.end_stroke()
	camera.cancel_input()
func _input(event:InputEvent)->void:
	# Release is global: a stroke ends even if the cursor finishes over a panel.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		painting=false
		data.end_stroke()
func _unhandled_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if event.alt_pressed:return
		begin_paint(event.position,false)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if (event.ctrl_pressed or event.meta_pressed) and event.keycode==KEY_Z:
			cancel_input()
			if event.shift_pressed:data.redo()
			else:data.undo()
		elif event.keycode==KEY_HOME:camera.recenter(Vector2(0,-1))
		elif event.keycode==KEY_ESCAPE:cancel_input()
func _pointer(screen:Vector2)->Dictionary:
	var origin:=camera.project_ray_origin(screen)
	var direction:=camera.project_ray_normal(screen)
	var hit:=renderer.pick(origin,direction)
	if tool=="expand" or hit.is_empty():
		if absf(direction.y)>0.0001:
			var t:float=(build_height-origin.y)/direction.y
			if t>0:
				var p:=origin+direction*t
				if hit.is_empty() or tool=="expand":return {"position":p,"cell":Vector2i(floori(p.x),floori(p.z)),"normal":Vector3.UP}
	return hit
func begin_paint(screen:Vector2,from_ui:bool=false)->bool:
	if from_ui or hud.is_over_panel(screen):return false
	var focus:=get_viewport().gui_get_focus_owner()
	if focus:focus.release_focus()
	painting=true
	_last_paint=Vector2(INF,INF)
	_last_sculpt=Vector3(INF,INF,INF)
	_last_sculpt_screen=Vector2(INF,INF)
	data.begin_stroke()
	continue_paint(screen)
	return true
func continue_paint(screen:Vector2)->void:
	if not painting or hud.is_over_panel(screen):return
	var hit:=_pointer(screen)
	if hit.is_empty():return
	if tool.begins_with("rock_"):
		_sculpt_at(screen,hit);return
	var center:=Vector2(hit.cell)+Vector2(0.5,0.5) if snap else Vector2(hit.position.x,hit.position.z)
	# Interpolate fast drags so there are no holes between input samples.
	var start:Vector2=center if not _last_paint.is_finite() else _last_paint
	var steps:=maxi(1,ceili(start.distance_to(center)/maxf(0.25,radius*0.45)))
	steps=mini(steps,256)
	var begin:=Time.get_ticks_usec()
	for i in steps:
		data.apply_brush(start.lerp(center,float(i+1)/steps),radius,tool,snap,build_height,water_level)
	_last_paint=center
	last_edit_ms=(Time.get_ticks_usec()-begin)/1000.0
func _sculpt_center(hit:Dictionary)->Vector3:
	var center:Vector3=hit.position
	var normal:Vector3=hit.get("normal",Vector3.UP)
	var size:=minf(radius,4.0)
	if tool in ["rock_add","rock_shoulder"]:center+=normal*size*.25
	elif tool=="rock_plane":center-=normal*size*.12
	return center
func _sculpt_at(screen:Vector2,hit:Dictionary)->void:
	# Stationary holding must not grow again merely because a new mesh publishes.
	if _last_sculpt_screen.is_finite() and screen.distance_squared_to(_last_sculpt_screen)<4.0:return
	var normal:Vector3=hit.get("normal",Vector3.UP)
	var size:=minf(radius,4.0)
	var center:=_sculpt_center(hit)
	var start:=center if not _last_sculpt.is_finite() else _last_sculpt
	var steps:=mini(64,maxi(1,ceili(start.distance_to(center)/maxf(.125,size*.3))))
	var begin:=Time.get_ticks_usec()
	for i in steps:data.apply_rock_brush(start.lerp(center,float(i+1)/steps),size,tool,normal)
	_last_sculpt=center;_last_sculpt_screen=screen
	last_edit_ms=(Time.get_ticks_usec()-begin)/1000.0
func _update_brush(screen:Vector2)->void:
	var hit:=_pointer(screen)
	brush.visible=not hit.is_empty()
	if not brush.visible:return
	var position3:Vector3=_sculpt_center(hit) if tool.begins_with("rock_") else hit.position
	if snap and not tool.begins_with("rock_"):
		position3.x=hit.cell.x+0.5
		position3.z=hit.cell.y+0.5
	brush.position=position3 if tool.begins_with("rock_") else position3+Vector3(0,0.06,0)
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var sculpt:=tool.begins_with("rock_")
	var size:=minf(radius,4.0) if sculpt else radius
	var rings:=3 if sculpt else 1
	for ring in rings:
		for i in 48:
			for angle:float in [TAU*i/48.0,TAU*(i+1)/48.0]:
				var point:=Vector3(cos(angle)*size,0,sin(angle)*size)
				if ring==1:point=Vector3(point.x,point.z,0)
				elif ring==2:point=Vector3(0,point.x,point.z)
				if tool in ["rock_shoulder","rock_cleave"]:point.y*=1.55
				mesh.surface_add_vertex(point)
	mesh.surface_end()
	brush.mesh=mesh
func select_preset(kind:int)->void:
	cancel_input()
	data.make_preset(kind)
	renderer.rebuild_all()
	camera.recenter(Vector2(0,-1))
func save_layout(path:String)->Error:
	data.end_stroke()
	var error:=DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error!=OK:return error
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data.serialize(),"",true,true))
	return file.get_error()
func load_layout(path:String)->Error:
	if not FileAccess.file_exists(path):return ERR_FILE_NOT_FOUND
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return FileAccess.get_open_error()
	if file.get_length()>16*1024*1024:return ERR_INVALID_DATA
	var parser:=JSON.new()
	if parser.parse(file.get_as_text())!=OK:return ERR_INVALID_DATA
	var candidate:Variant=parser.data
	if not candidate is Dictionary:return ERR_INVALID_DATA
	if not data.deserialize(candidate):return ERR_INVALID_DATA
	cancel_input()
	renderer.rebuild_all()
	return OK
