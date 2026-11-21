class_name TerrainEditor
extends Node3D
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Renderer=preload("res://scripts/terrain_editor/terrain_renderer.gd")
const Decoration=preload("res://scripts/terrain_editor/terrain_decoration.gd")
const Camera=preload("res://scripts/terrain_editor/editor_camera.gd")
const HUD=preload("res://scripts/terrain_editor/editor_hud.gd")
const WaterView=preload("res://scripts/terrain_editor/water_renderer.gd")
const Director=preload("res://scripts/gameplay/director.gd")
@export var sunlight_energy := 1.24
@export var fill_energy := 0.23
@export var ambient_energy := 0.46
@export_range(0.0,1.0) var background_haze := 0.68
@export var dof_enabled := true:
	set(value):
		dof_enabled = value
		if camera != null and camera.has_method("set_dof"):
			camera.set_dof(dof_enabled, dof_strength)
@export_range(0.0,1.0) var dof_strength := 0.26:
	set(value):
		dof_strength = clampf(value, 0.0, 1.0)
		if camera != null and camera.has_method("set_dof"):
			camera.set_dof(dof_enabled, dof_strength)
@export var ambient_motes_enabled := true:
	set(value):
		ambient_motes_enabled = value
		if motes != null:
			motes.visible = ambient_motes_enabled
var data:=Data.new()
var renderer:=Renderer.new()
var water_view:=WaterView.new()
var preview_quality:=preload("res://scripts/terrain_editor/preview_quality.gd").new()
var _light_blur_saved:=false
var _light_blur_enabled:=true
var background_view:=preload("res://scripts/terrain_editor/background_renderer.gd").new()
var runtime_power:=preload("res://scripts/terrain_editor/runtime_power.gd").new()
var camera:=Camera.new()
var landscape:=preload("res://scripts/terrain_editor/distant_landscape.gd").new()
var motes:=preload("res://scripts/terrain_editor/ambient_motes.gd").new()
var hud:CanvasLayer
var gameplay:Director
var tool:="raise":
	set(value):
		tool=value
		if gameplay!=null:gameplay.on_brush_tool_selected(value)
var radius:float=2.2:
	set(value):
		var next:float=clampf(value,.1,16.0)
		if is_equal_approx(radius,next):return
		if painting:cancel_input()
		radius=next
		_brush_shape_key=""
var snap:=true
var build_height:=1.5
var water_level:=3
var style_preset:=0
var painting:=false
var blueprint_data:Data
var _blueprint_tool:String=""
var _stroke_plane_height:float=NAN
var _stroke_plane_offset := Vector2.ZERO
var _brush_shape_key:String=""
var last_edit_ms:=0.0
var brush:=MeshInstance3D.new()
## Jade ghost of the stroke result shown until the threaded rebuild publishes.
var preview:=preload("res://scripts/terrain_editor/edit_preview.gd").new()
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
	camera.set_dof(dof_enabled,dof_strength)
	add_child(landscape)
	add_child(motes)
	motes.visible=ambient_motes_enabled
	motes.rebuild_from_data(data)
	_setup_environment()
	add_child(brush)
	add_child(preview)
	var marker:=StandardMaterial3D.new()
	marker.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.albedo_color=Color(0.95,0.93,0.86,0.68)
	marker.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.no_depth_test=true
	brush.material_override=marker
	hud=HUD.new()
	hud.editor=self
	add_child(hud)
	gameplay=Director.new()
	add_child(gameplay)
	gameplay.setup(self)
	add_child(water_view)
	water_view.configure(data,renderer)
	renderer.terrain_published.connect(water_view.sync)
	preview_quality.configure(get_viewport())
	add_child(background_view)
	background_view.configure(self)
	add_child(runtime_power)
	runtime_power.configure(self)
func _create_decoration()->RefCounted:
	return Decoration.new()
func _setup_environment()->void:
	preload("res://scripts/terrain_editor/terrain_environment.gd").setup(self,landscape,sunlight_energy,fill_energy,ambient_energy,background_haze)
func _process(delta:float)->void:
	preview_quality.advance(delta, Engine.max_fps)
	landscape.position=Vector3(camera._center.x,0,camera._center.y)
	renderer.flush_dirty(6)
	# During a committed terrain build, keep water matched to the visible bed.
	# Uncommitted blueprints do not pause the published world.
	if not renderer.has_pending_updates():water_view.tick(delta)
	preview.refresh(blueprint_data if blueprint_data!=null else data,renderer,blueprint_data!=null)
	if gameplay!=null:gameplay.tick(delta)
	var mouse:=get_viewport().get_mouse_position()
	var sculpt_active:bool=(gameplay==null) or (gameplay.stance=="sculpt" and not gameplay.wallpaper_mode)
	if not sculpt_active or hud.is_over_panel(mouse):brush.visible=false
	else:
		_update_brush(mouse)
		if painting:continue_paint(mouse)
	var ground:ShaderMaterial=renderer.materials.grass
	ground.set_shader_parameter("show_grid",brush.visible and snap)
	if brush.visible:
		ground.set_shader_parameter("grid_center",Vector2(brush.position.x,brush.position.z))
		ground.set_shader_parameter("grid_radius",radius)
	_clock+=delta
	if _clock>0.25:
		_clock=0
		hud.update_diagnostics()
func _notification(what:int)->void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:cancel_input()
func cancel_input()->void:
	painting=false
	renderer.cancel_blueprint()
	blueprint_data=null
	_blueprint_tool=""
	_stroke_plane_height=NAN
	_stroke_plane_offset = Vector2.ZERO
	data.end_stroke()
	camera.cancel_input()
	preview.refresh(data, renderer)
func _input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and painting:
		cancel_input()
		get_viewport().set_input_as_handled()
		return
	# Release is global: a stroke ends even if the cursor finishes over a panel.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		commit_blueprint()
func _unhandled_input(event:InputEvent)->void:
	if gameplay!=null and gameplay.handle_unhandled_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if event.alt_pressed:return
		if gameplay!=null and (gameplay.stance!="sculpt" or gameplay.wallpaper_mode):return
		begin_paint(event.position,false)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if (event.ctrl_pressed or event.meta_pressed) and event.keycode==KEY_Z:
			cancel_input()
			if event.shift_pressed:data.redo()
			else:data.undo()
			if gameplay!=null:data.cell_quota=gameplay.state.max_land_cells()
		elif event.keycode==KEY_HOME:camera.recenter(Vector2(0,-1))
		elif event.keycode==KEY_F10:
			dof_enabled=not dof_enabled
			if gameplay!=null and gameplay.shihai_hud!=null:
				gameplay.shihai_hud.show_toast("光学远景景深：已开启（弱）" if dof_enabled else "光学远景景深：已关闭",2.2)
		elif event.keycode==KEY_ESCAPE:cancel_input()
func _nearest_brush_plane(origin:Vector3,direction:Vector3)->float:
	var source:Data=renderer._published_data if renderer._published_data!=null else data
	var best:float=INF
	var height:float=build_height
	var points:Dictionary={}
	for cell:Vector2i in source.cells:
		var h:float=Data._record_top(source.cells[cell])
		if not points.has(h):
			var t:float=(h-origin.y)/direction.y
			points[h]=Vector2(origin.x+direction.x*t,origin.z+direction.z*t)
		var q:Vector2=points[h]
		var nearest:=q.clamp(Vector2(cell),Vector2(cell)+Vector2.ONE)
		var distance:float=q.distance_squared_to(nearest)
		if distance<best-.0001 or (absf(distance-best)<.0001 and h>height):best=distance;height=h
	return height

func _pick_heightmap(origin: Vector3, direction: Vector3, source: Data) -> Dictionary:
	var nearest := INF
	var result: Dictionary = {}
	for cell: Vector2i in source.cells:
		var top: float = Data._record_top(source.cells[cell])
		var bounds := AABB(Vector3(cell.x, -12.0, cell.y), Vector3(1.0, top + 12.0, 1.0))
		var point: Variant = bounds.intersects_ray(origin, direction)
		if point == null:
			continue
		var distance: float = origin.distance_squared_to(point)
		if distance >= nearest:
			continue
		nearest = distance
		var normal := Vector3.UP
		if absf(point.y - top) > .001:
			var offset: Vector2 = Vector2(point.x, point.z) - Vector2(cell) - Vector2.ONE * .5
			normal = Vector3(signf(offset.x), 0.0, 0.0) if absf(offset.x) > absf(offset.y) else Vector3(0.0, 0.0, signf(offset.y))
		result = {"position": point, "cell": cell, "normal": normal}
	return result

func _pointer(screen:Vector2)->Dictionary:
	var origin:Vector3=camera.project_ray_origin(screen)
	var direction:Vector3=camera.project_ray_normal(screen)
	if tool.begins_with("rock_"):
		return renderer.pick(origin, direction)
	if absf(direction.y) < .0001:
		return {}
	if painting and is_finite(_stroke_plane_height):
		var distance: float = (_stroke_plane_height - origin.y) / direction.y
		if distance <= 0.0:
			return {}
		var point: Vector3 = origin + direction * distance
		point.x += _stroke_plane_offset.x
		point.z += _stroke_plane_offset.y
		return {"position": point, "cell": Vector2i(floori(point.x), floori(point.z)), "normal": Vector3.UP, "surface_height": _stroke_plane_height}
	var source:Data=renderer._published_data if renderer._published_data!=null else data
	var hit: Dictionary = _pick_heightmap(origin, direction, source)
	var plane: float = NAN
	if not hit.is_empty() and source.cells.has(hit.cell):
		# On a terrace wall, floor(XZ) can belong to the lower receiver even
		# though the visible face belongs to the taller cell behind it.
		if Data._record_top(source.cells[hit.cell])<float(hit.position.y)-.08:
			var closest:float=INF
			var p2:=Vector2(hit.position.x,hit.position.z)
			var base:=Vector2i(p2.floor())
			for dz:int in range(-2,3):
				for dx:int in range(-2,3):
					var cell:=base+Vector2i(dx,dz)
					if not source.cells.has(cell) or Data._record_top(source.cells[cell])<float(hit.position.y)-.08:continue
					var distance:float=p2.distance_squared_to(Vector2(cell)+Vector2.ONE*.5)
					if distance<closest:closest=distance;hit.cell=cell
		var owner_height:float=Data._record_top(source.cells[hit.cell])
		if not is_finite(plane):plane=owner_height
		# A side face selects its owning terrace's crown. A narrow brush should
		# never create a second shelf below the visible top of that cliff.
		if (absf(hit.normal.y)<.45 or float(hit.position.y)<owner_height-.12 or not source.cells.has(Vector2i(Vector2(hit.position.x,hit.position.z).floor()))) and absf(owner_height-plane)<.01:
			var projected:Vector3=origin+direction*((plane-origin.y)/direction.y)
			var projected_center:=Vector2(projected.x,projected.z)
			# A valid plane projection wins over the wall anchor. This keeps a
			# removed patch directly under the pointer when filling it back in.
			# Query authoritative land so a stationary held draft cannot walk off
			# its own freshly-filled footprint when it becomes occupied in draft.
			if data.can_apply_brush(projected_center,radius,tool,snap,plane,water_level,plane):
				return {"position":projected,"cell":Vector2i(projected_center.floor()),"normal":Vector3.UP,"surface_height":plane}
			var at:Vector2=Vector2(hit.cell)+Vector2.ONE*.5
			if tool=="expand":at+=Vector2(hit.normal.x,hit.normal.z).normalized()*minf(.8,radius*.65)
			return {"position":Vector3(at.x,plane,at.y),"cell":hit.cell,"normal":Vector3.UP,"surface_height":plane}
	if not is_finite(plane):
		plane=_nearest_brush_plane(origin,direction) if not source.cells.is_empty() else build_height
	var t:float=(plane-origin.y)/direction.y
	if t<=0:return {}
	var p:Vector3=origin+direction*t
	return {"position":p,"cell":Vector2i(floori(p.x),floori(p.z)),"normal":Vector3.UP,"surface_height":plane}
func begin_paint(screen:Vector2,from_ui:bool=false)->bool:
	if from_ui or hud.is_over_panel(screen):return false
	var hit:Dictionary=_pointer(screen)
	if hit.is_empty():return false
	var samples_land: bool = tool == "expand" and data.cells.has(Vector2i(_brush_center(hit).floor()))
	if not tool.begins_with("rock_") and not samples_land and not data.can_apply_brush(_brush_center(hit),radius,tool,snap,float(hit.get("surface_height",build_height)),water_level,float(hit.get("surface_height",NAN))):return false
	if gameplay!=null and not gameplay.prepare_brush_step(tool):return false
	var focus:=get_viewport().gui_get_focus_owner()
	if focus:focus.release_focus()
	_stroke_plane_height=float(hit.get("surface_height",NAN))
	if is_finite(_stroke_plane_height):
		build_height = _stroke_plane_height
		var origin: Vector3 = camera.project_ray_origin(screen)
		var direction: Vector3 = camera.project_ray_normal(screen)
		var projected: Vector3 = origin + direction * ((_stroke_plane_height-origin.y)/direction.y)
		_stroke_plane_offset = Vector2(hit.position.x-projected.x,hit.position.z-projected.z)
	painting=true
	blueprint_data=data.copy()
	_blueprint_tool=tool
	_last_paint=Vector2(INF,INF)
	_last_sculpt=Vector3(INF,INF,INF)
	_last_sculpt_screen=Vector2(INF,INF)
	blueprint_data.begin_stroke()
	continue_paint(screen)
	return true

func commit_blueprint()->bool:
	if blueprint_data==null:return false
	var before_cells:int=data.cells.size()
	var before_wet:int=gameplay.count_wet_cells() if gameplay!=null and _blueprint_tool=="water" else 0
	var changed:bool=data.commit_blueprint(blueprint_data,_blueprint_tool)
	if changed:
		preview.commit(blueprint_data, renderer)
		renderer.commit_prepared_blueprint(blueprint_data)
	else:renderer.cancel_blueprint()
	if changed and gameplay!=null:gameplay.after_brush_step(before_cells,before_wet,_blueprint_tool)
	painting=false
	blueprint_data=null
	_blueprint_tool=""
	_stroke_plane_height=NAN
	_stroke_plane_offset = Vector2.ZERO
	return changed

func _brush_center(hit:Dictionary)->Vector2:
	var point:=Vector2(hit.position.x,hit.position.z)
	if snap or (tool!="expand" and not data.cells.has(Vector2i(point.floor()))):
		return Vector2(hit.cell)+Vector2.ONE*.5
	return point

func continue_paint(screen:Vector2)->void:
	if not painting or hud.is_over_panel(screen):return
	if blueprint_data==null or _blueprint_tool!=tool:
		cancel_input()
		return
	var hit:=_pointer(screen)
	if hit.is_empty():return
	if tool.begins_with("rock_"):
		_sculpt_at(screen,hit);return
	var center:=_brush_center(hit)
	# Interpolate fast drags so there are no holes between input samples.
	var start:Vector2=center if not _last_paint.is_finite() else _last_paint
	var steps:=maxi(1,ceili(start.distance_to(center)/maxf(0.25,radius*0.45)))
	steps=mini(steps,256)
	var begin:=Time.get_ticks_usec()
	for i in steps:
		blueprint_data.apply_brush(start.lerp(center,float(i+1)/steps),radius,tool,snap,build_height,water_level,_stroke_plane_height)
	_last_paint=center
	renderer.prepare_blueprint(blueprint_data)
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
	for i in steps:blueprint_data.apply_rock_brush(start.lerp(center,float(i+1)/steps),size,tool,normal)
	_last_sculpt=center;_last_sculpt_screen=screen
	renderer.prepare_blueprint(blueprint_data)
	last_edit_ms=(Time.get_ticks_usec()-begin)/1000.0
func _brush_valid(hit:Dictionary)->bool:
	if tool.begins_with("rock_"):return true
	var center:Vector2=_brush_center(hit)
	var source:Data=blueprint_data if blueprint_data!=null else data
	if source.can_apply_brush(center,radius,tool,snap,float(hit.get("surface_height",build_height)),water_level,float(hit.get("surface_height",NAN))):return true
	# An already selected part of the draft stays valid. Quota exhausted at a
	# new location is invalid even though the published island is still smaller.
	if blueprint_data!=null:
		for cell:Vector2i in blueprint_data._before:
			if (Vector2(cell)+Vector2.ONE*.5).distance_squared_to(center)<=radius*radius:return true
	return false

func _update_brush(screen:Vector2)->void:
	var hit:=_pointer(screen)
	brush.visible=not hit.is_empty()
	if not brush.visible:return
	var position3:Vector3=_sculpt_center(hit) if tool.begins_with("rock_") else hit.position
	if not tool.begins_with("rock_"):
		var center:=_brush_center(hit)
		position3.x=center.x
		position3.z=center.y
	brush.position=position3 if tool.begins_with("rock_") else position3+Vector3(0,0.06,0)
	var valid:bool=_brush_valid(hit)
	(brush.material_override as StandardMaterial3D).albedo_color=Color(.45,.95,.77,.95) if valid else Color(1.0,.22,.16,.98)
	var shape_key:String="%s|%.3f|%s"%[tool,radius,str(snap)]
	if shape_key==_brush_shape_key:return
	_brush_shape_key=shape_key
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
func set_native_preview(value:bool)->void:
	preview_quality.set_native(value)
	_sync_light_blur()
	if is_instance_valid(background_view):background_view.sync()
func set_light_preview(value:bool)->void:
	preview_quality.set_light(value)
	_sync_light_blur()
	if is_instance_valid(background_view):background_view.sync()
func _sync_light_blur()->void:
	# The light tier drops the far blur; leaving it restores what was set before.
	if preview_quality.light and not _light_blur_saved:
		_light_blur_saved=true
		_light_blur_enabled=camera.dof_enabled
		camera.set_dof(false,camera.dof_strength)
	elif not preview_quality.light and _light_blur_saved:
		_light_blur_saved=false
		camera.set_dof(_light_blur_enabled,camera.dof_strength)

func toggle_grid_snap()->void:
	cancel_input()
	snap=not snap

func select_style_preset(index:int)->void:
	style_preset=index
	preload("res://scripts/terrain_editor/terrain_environment.gd").apply_style_preset(self,index)
	if gameplay!=null:gameplay.on_style_preset_selected(index)
func select_preset(kind:int)->void:
	cancel_input()
	data.make_preset(kind)
	renderer.rebuild_all()
	water_view.reset(data)
	if motes!=null:motes.rebuild_from_data(data)
	select_style_preset(style_preset)
	if gameplay!=null:gameplay.on_preset_changed()
	camera.recenter(Vector2(0,-1))
func save_layout(path:String)->Error:
	data.end_stroke()
	water_view.flush()
	var error:=DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error!=OK:return error
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	var payload:Dictionary=data.serialize()
	if gameplay!=null:payload["gameplay"]=gameplay.serialize()
	file.store_string(JSON.stringify(payload,"",true,true))
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
	water_view.reset(data)
	if motes!=null:motes.rebuild_from_data(data)
	if gameplay!=null:
		if (candidate as Dictionary).has("gameplay") and (candidate as Dictionary)["gameplay"] is Dictionary:
			gameplay.deserialize((candidate as Dictionary)["gameplay"] as Dictionary)
		else:
			gameplay.on_preset_changed()
	return OK
