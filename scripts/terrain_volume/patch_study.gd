extends Node3D
## Local native art gate; deliberately independent from the formal sandbox.
const Document := preload('res://scripts/terrain_volume/patch_document.gd')
const Surface := preload('res://scripts/terrain_volume/patch_surface.gd')
const SAVE := 'user://volume_patch_study/layout.json'
var document := Document.new()
var camera := Camera3D.new()
var body := MeshInstance3D.new()
var water := MeshInstance3D.new()
var collision := CollisionShape3D.new()
var material := ShaderMaterial.new()
var hud := CanvasLayer.new()
var status := Label.new()
var cursor := MeshInstance3D.new()
var last_build: Dictionary = {}
var tool := 'rock_cut'
var radius := .65
var painting := false
var last_point := Vector3(INF,INF,INF)
var _yaw := .46
var _pitch := .48
var _orbiting := false
func _ready() -> void:
	if not document.load_preset():
		push_error('Volume patch preset missing; run prepare/sample/pack tools first.')
		return
	_setup_environment()
	material.shader = preload('res://shaders/terrain_editor/volume_patch.gdshader')
	material.set_shader_parameter('stone_detail_map', preload('res://assets/textures/terrain/stone_detail_spall_v3.res'))
	material.set_shader_parameter('stone_mineral_map', preload('res://assets/textures/terrain/stone_mineral_v1.png'))
	material.set_shader_parameter('ground_detail_map', preload('res://assets/textures/terrain/ground_detail.png'))
	body.material_override = material
	add_child(body)
	var solid := StaticBody3D.new()
	solid.add_child(collision)
	add_child(solid)
	var lake_material := ShaderMaterial.new()
	lake_material.shader = preload('res://shaders/terrain_editor/volume_patch_water.gdshader')
	water.material_override = lake_material
	add_child(water)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.5
	camera.current = true
	add_child(camera)
	_orbit()
	var sphere := SphereMesh.new()
	sphere.radius = 1.
	sphere.height = 2.
	sphere.radial_segments = 24
	sphere.rings = 12
	cursor.mesh = sphere
	var marker := StandardMaterial3D.new()
	marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.albedo_color = Color(.94,.84,.49,.15)
	marker.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor.material_override = marker
	cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cursor)
	cursor.hide()
	_setup_hud()
	rebuild()
func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color('bdccd0')
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color('b8c9db')
	env.ambient_light_energy = .45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ssao_enabled = true
	env.ssao_radius = .8
	env.ssao_intensity = 1.1
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,40,0)
	sun.light_color = Color('ffe7c9')
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	sun.light_angular_distance = 2.2
	sun.shadow_normal_bias = .3
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-45,-28,0)
	fill.light_color = Color('cedbe5')
	fill.light_energy = .19
	add_child(fill)
func _setup_hud() -> void:
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(18,18)
	var box := VBoxContainer.new()
	var font: Font = load('res://assets/fonts/YunluVolumeUI-Regular.res')
	box.add_theme_font_override('font', font)
	box.add_theme_font_size_override('font_size', 16)
	panel.add_child(box)
	hud.add_child(panel)
	var title := Label.new()
	title.text = '岩体小景 · 雕刻验证'
	box.add_child(title)
	var tools := HBoxContainer.new()
	box.add_child(tools)
	for item: Array in [['削岩','rock_cut'],['加岩','rock_add'],['切平','rock_plane'],['平滑','rock_smooth']]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(func() -> void: tool = item[1])
		tools.add_child(button)
	var history := HBoxContainer.new()
	box.add_child(history)
	for item: Array in [['撤销',undo],['重做',redo],['保存',save_study],['读取',load_study],['重置',reset]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		history.add_child(button)
	var details := CheckButton.new()
	details.text = '岩石贴图细节'
	details.button_pressed = true
	details.toggled.connect(func(on: bool) -> void: material.set_shader_parameter('detailed',on))
	box.add_child(details)
	var help := Label.new()
	help.text = '左键雕刻 · 右键旋转 · 滚轮缩放\n[ / ] 调整笔刷 · Ctrl+Z / Ctrl+Y'
	box.add_child(help)
	box.add_child(status)
func rebuild() -> void:
	last_build = Surface.build(document)
	body.mesh = last_build.terrain
	var contact: Dictionary = last_build.contact
	material.set_shader_parameter('use_contact_field', not contact.is_empty())
	if not contact.is_empty():
		material.set_shader_parameter('contact_field', ImageTexture.create_from_image(contact.map))
		material.set_shader_parameter('contact_origin', contact.origin)
		material.set_shader_parameter('contact_extent', contact.extent)
		material.set_shader_parameter('lake_center', Vector2(document.lake.center[0],document.lake.center[1]))
		material.set_shader_parameter('lake_level', document.lake.level)
		material.set_shader_parameter('lake_enabled', last_build.lake.valid)
	collision.shape = body.mesh.create_trimesh_shape() if body.mesh.get_surface_count() > 0 else null
	water.mesh = last_build.water
	water.visible = last_build.lake.valid
	status.text = '湖泊有效' if last_build.lake.valid else '湖岸破口：撤销修复或继续雕刻'
func _orbit() -> void:
	var center := Vector3(0,1.05,0)
	camera.position = center + Vector3(sin(_yaw)*cos(_pitch), sin(_pitch), cos(_yaw)*cos(_pitch))*18.
	camera.look_at(center)
func hit_at(screen: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin+camera.project_ray_normal(screen)*100., 1)
	return get_world_3d().direct_space_state.intersect_ray(query)
func _process(_delta: float) -> void:
	var hit := hit_at(get_viewport().get_mouse_position())
	cursor.visible = not hit.is_empty() and not _orbiting
	if not hit.is_empty():
		cursor.position = hit.position
		cursor.scale = Vector3.ONE*radius
		if painting and last_point.distance_to(hit.position) > radius*.45:
			_paint(hit)
func _paint(hit: Dictionary) -> void:
	if document.apply_brush(hit.position, radius, tool, hit.normal) > 0:
		last_point = hit.position
		rebuild()
func _input(event: InputEvent) -> void:
	# Always finish a stroke even if the mouse is released over the HUD.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		painting = false
		document.end_stroke()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		_orbiting = false
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var hit := hit_at(event.position)
			if not hit.is_empty():
				painting = true
				last_point = Vector3(INF,INF,INF)
				document.begin_stroke()
				_paint(hit)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera.size = clampf(camera.size * (.90 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 3., 20.)
	elif event is InputEventMouseMotion and _orbiting:
		_yaw -= event.relative.x*.008
		_pitch = clampf(_pitch + event.relative.y*.006, -.65, 1.35)
		_orbit()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_Z: undo()
		elif event.ctrl_pressed and event.keycode == KEY_Y: redo()
		elif event.keycode == KEY_BRACKETLEFT: radius = maxf(.25,radius-.15)
		elif event.keycode == KEY_BRACKETRIGHT: radius = minf(3.,radius+.15)
func undo() -> void:
	painting = false
	if document.undo(): rebuild()
func redo() -> void:
	painting = false
	if document.redo(): rebuild()
func reset() -> void:
	painting = false
	document = Document.new()
	if document.load_preset(): rebuild()
func save_study() -> void:
	document.end_stroke()
	DirAccess.make_dir_recursive_absolute(SAVE.get_base_dir())
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	if file == null:
		status.text = '保存失败'
		return
	file.store_string(JSON.stringify(document.serialize(), '', true, true))
	status.text = '已保存小景'
func load_study() -> void:
	if not FileAccess.file_exists(SAVE):
		status.text = '尚无小景存档'
		return
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if payload is Dictionary and document.deserialize(payload):
		painting = false
		rebuild()
	else:
		status.text = '读取失败：保留当前小景'
