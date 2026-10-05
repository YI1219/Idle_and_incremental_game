class_name TerrainEditor
extends Node3D
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Renderer=preload("res://scripts/terrain_editor/terrain_renderer.gd")
const Decoration=preload("res://scripts/terrain_editor/terrain_decoration.gd")
const Camera=preload("res://scripts/terrain_editor/editor_camera.gd")
const HUD=preload("res://scripts/terrain_editor/editor_hud.gd")
var data:=Data.new()
var renderer:=Renderer.new()
var camera:=Camera.new()
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
func _ready()->void:
	data.make_preset(0)
	add_child(renderer)
	renderer.configure(data)
	renderer.decoration=Decoration.new()
	renderer.rebuild_all()
	add_child(camera)
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
func _setup_environment()->void:
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-50,-30,0)
	sun.light_color=Color("fff2ce")
	sun.light_energy=1.15
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=90
	sun.light_angular_distance=2.4
	add_child(sun)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_SKY
	var sky:=Sky.new()
	var sky_material:=ShaderMaterial.new()
	sky_material.shader=load("res://shaders/terrain_editor/sky.gdshader")
	sky_material.set_shader_parameter("cloud_backdrop",load("res://assets/terrain_editor/cloud_backdrop_v01.png"))
	sky.sky_material=sky_material
	sky.process_mode=Sky.PROCESS_MODE_QUALITY
	env.environment.sky=sky
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("daeaf1")
	env.environment.ambient_light_energy=0.36
	env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env.environment.ssao_enabled=true
	env.environment.ssao_radius=.85
	env.environment.ssao_intensity=1.1
	env.environment.ssao_power=1.3
	add_child(env)
func _process(delta:float)->void:
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
				if hit.is_empty() or tool=="expand":return {"position":p,"cell":Vector2i(floori(p.x),floori(p.z))}
	return hit
func begin_paint(screen:Vector2,from_ui:bool=false)->bool:
	if from_ui or hud.is_over_panel(screen):return false
	var focus:=get_viewport().gui_get_focus_owner()
	if focus:focus.release_focus()
	painting=true
	_last_paint=Vector2(INF,INF)
	data.begin_stroke()
	continue_paint(screen)
	return true
func continue_paint(screen:Vector2)->void:
	if not painting or hud.is_over_panel(screen):return
	var hit:=_pointer(screen)
	if hit.is_empty():return
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
func _update_brush(screen:Vector2)->void:
	var hit:=_pointer(screen)
	brush.visible=not hit.is_empty()
	if not brush.visible:return
	var position3:Vector3=hit.position
	if snap:
		position3.x=hit.cell.x+0.5
		position3.z=hit.cell.y+0.5
	brush.position=position3+Vector3(0,0.06,0)
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 48:
		for angle:float in [TAU*i/48.0,TAU*(i+1)/48.0]:mesh.surface_add_vertex(Vector3(cos(angle)*radius,0,sin(angle)*radius))
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
	file.store_string(JSON.stringify(data.serialize()))
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
