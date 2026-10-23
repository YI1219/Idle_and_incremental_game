extends Node3D
## Standalone brush study for DREDGE-style hard slabs.
## Run this scene directly. It does not open or edit the courtyard seed island.

const FIELD := preload("res://scripts/slab_brush/slab_field.gd")
const SLAB := preload("res://scripts/slab_brush/hard_slab.gd")

var field: SlabField = FIELD.new()
var camera: Camera3D
var slab_root: Node3D
var ghost: MeshInstance3D
var highlight: MeshInstance3D
var status: Label
var kind := 0
var _yaw := 32.0
var _pitch := 18.0
var _distance := 24.0
var _focus := Vector3(0.0, 2.2, 0.0)
var _orbiting := false
var _rock: Material
var _ghost_mat: StandardMaterial3D
var _hover_key := ""

func _ready() -> void:
	_rock = ShaderMaterial.new()
	_rock.shader = load("res://shaders/slab_brush/slab_rock.gdshader")
	_ghost_mat = _matte(Color(0.72, 0.70, 0.78, 0.38), 0.9)
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.vertex_color_use_as_albedo = true
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_build_world()
	_apply_camera()

func show_single() -> void:
	field.clear()
	field.place_seed(Vector3.ZERO, deg_to_rad(18.0), SLAB.WALL, 7301)
	_sync_meshes()
	frame_on_bounds(28.0, 14.0, 20.0, 0.35)

func show_cluster() -> void:
	field.paint_sample(7301)
	_sync_meshes()
	frame_on_bounds(36.0, 20.0, 32.0, 0.45)

func frame_on_bounds(yaw_deg: float, pitch_deg: float, distance: float, lift: float) -> void:
	var box := field.bounds()
	_focus = box.get_center() + Vector3(0.0, lift, 0.0)
	_yaw = yaw_deg
	_pitch = pitch_deg
	_distance = distance
	_apply_camera()

func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24.0, 78.0, 0.0)
	sun.light_color = Color("ffe7c9")
	sun.light_energy = 1.25
	sun.light_specular = 0.12
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 0.9
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22.0, -124.0, 0.0)
	fill.light_color = Color("d7d2e8")
	fill.light_energy = 0.26
	fill.shadow_enabled = false
	add_child(fill)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/terrain_editor/sky.gdshader")
	sky_material.set_shader_parameter("haze", 0.62)
	var backdrop: Texture2D = load("res://assets/terrain_editor/cloud_backdrop_v01.png")
	sky_material.set_shader_parameter("cloud_backdrop", backdrop)
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c5c0d4")
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 1.15
	env.ssao_power = 1.5
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("c9d5e2")
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	world.environment = env
	add_child(world)
	var deck := MeshInstance3D.new()
	var deck_mesh := PlaneMesh.new()
	deck_mesh.size = Vector2(90.0, 90.0)
	deck.mesh = deck_mesh
	deck.position = Vector3(0.0, -1.85, 0.0)
	deck.material_override = _matte(Color(0.58, 0.72, 0.74), 1.0)
	add_child(deck)
	camera = Camera3D.new()
	camera.fov = 31.0
	camera.near = 0.1
	camera.far = 400.0
	camera.current = true
	add_child(camera)
	slab_root = Node3D.new()
	slab_root.name = "Slabs"
	add_child(slab_root)
	ghost = MeshInstance3D.new()
	ghost.material_override = _ghost_mat
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)
	highlight = MeshInstance3D.new()
	var hi := _matte(Color(1.0, 0.94, 0.82, 0.42), 1.0)
	hi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hi.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight.material_override = hi
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(highlight)
	var layer := CanvasLayer.new()
	add_child(layer)
	status = Label.new()
	status.position = Vector2(18, 14)
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color(0.22, 0.2, 0.28))
	status.add_theme_color_override("font_outline_color", Color(0.95, 0.93, 0.9))
	status.add_theme_constant_override("outline_size", 6)
	status.theme = load("res://assets/ui/game_theme.tres")
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(status)
	_refresh_status()

func _matte(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material

func _apply_camera() -> void:
	var yaw := deg_to_rad(_yaw)
	var pitch := deg_to_rad(_pitch)
	camera.position = _focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _distance
	camera.look_at(_focus, Vector3.UP)

func _sync_meshes() -> void:
	for child in slab_root.get_children():
		child.free()
	for body: Dictionary in field.modules:
		var instance := MeshInstance3D.new()
		instance.mesh = body["mesh"]
		instance.material_override = _rock
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		slab_root.add_child(instance)
	_refresh_status()

func _refresh_status() -> void:
	if status == null:
		return
	var tool := "崖壁" if kind == SLAB.WALL else "坡肩"
	status.text = "硬面岩刷  ·  %s\n左键空地放下第一块，左键侧面长出下一块\n1 崖壁    2 坡肩    Z 撤销    R 清空\n右键环视   滚轮远近   Q/E 转   已放 %d 块" % [tool, field.modules.size()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance / 1.08, 6.0, 80.0)
			_apply_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance * 1.08, 6.0, 80.0)
			_apply_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_stamp()
	elif event is InputEventMouseMotion:
		if _orbiting:
			_yaw -= event.relative.x * 0.22
			_pitch = clampf(_pitch + event.relative.y * 0.16, 8.0, 68.0)
			_apply_camera()
		else:
			_update_hover()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				kind = SLAB.WALL
			KEY_2:
				kind = SLAB.SHOULDER
			KEY_Z:
				if field.undo():
					_sync_meshes()
					_hover_key = ""
					_update_hover()
			KEY_R:
				field.clear()
				_sync_meshes()
				ghost.mesh = null
				highlight.mesh = null
				_hover_key = ""
			KEY_Q:
				_yaw -= 8.0
				_apply_camera()
			KEY_E:
				_yaw += 8.0
				_apply_camera()
		_refresh_status()

func _stamp() -> void:
	var op := _operation()
	if op.is_empty():
		return
	var salt := _next_salt()
	if op["op"] == "seed":
		var origin: Vector3 = op["origin"]
		field.place_seed(Vector3(origin.x, 0.0, origin.z), deg_to_rad(_yaw), kind, salt)
	else:
		field.expand(op["module"], op["face"], kind, salt)
	_sync_meshes()
	_hover_key = ""
	_update_hover()

func _update_hover() -> void:
	var op := _operation()
	var key := _op_key(op)
	if key == _hover_key:
		return
	_hover_key = key
	ghost.mesh = null
	highlight.mesh = null
	if op.is_empty():
		return
	var salt := _next_salt()
	if op["op"] == "seed":
		var preview := SLAB.seed_module(kind, salt, deg_to_rad(_yaw), Vector3(op["origin"].x, 0.0, op["origin"].z))
		ghost.mesh = preview["mesh"]
		return
	var host: Dictionary = field.modules[op["module"]]
	var faces: Array[Dictionary] = host["faces"]
	var face: Dictionary = faces[op["face"]]
	highlight.mesh = _face_overlay(face)
	var guest := SLAB.expand_module(face, kind, salt)
	face["welded"] = false
	if guest["faces"].size() >= 5:
		ghost.mesh = guest["mesh"]

func _next_salt() -> int:
	return 7301 + field.modules.size() * 17 + kind * 3

func _op_key(op: Dictionary) -> String:
	if op.is_empty():
		return ""
	if op["op"] == "seed":
		var origin: Vector3 = op["origin"]
		return "seed:%.2f,%.2f:%d" % [origin.x, origin.z, kind]
	return "expand:%d:%d:%d" % [int(op["module"]), int(op["face"]), kind]

func _operation() -> Dictionary:
	if camera == null:
		return {}
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	if field.modules.is_empty():
		var ground := _ground_point(origin, dir)
		if not ground.is_finite():
			return {}
		return {"op": "seed", "origin": ground}
	var hit := field.raycast(origin, dir)
	if not hit.is_empty() and hit["role"] == "side":
		return {"op": "expand", "module": hit["module"], "face": hit["face"]}
	var ground := _ground_point(origin, dir)
	if not ground.is_finite():
		return {}
	var near := field.face_near_point(ground, 3.4)
	if near.is_empty():
		return {}
	return {"op": "expand", "module": near["module"], "face": near["face"]}

func _ground_point(origin: Vector3, dir: Vector3) -> Vector3:
	if absf(dir.y) < 0.00001:
		return Vector3(INF, INF, INF)
	var t := -origin.y / dir.y
	if t < 0.0:
		return Vector3(INF, INF, INF)
	return origin + dir * t

func _face_overlay(face: Dictionary) -> ArrayMesh:
	var polygon: PackedVector3Array = face["polygon"]
	var normal: Vector3 = face["normal"]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for index in range(1, polygon.size() - 1):
		for point: Vector3 in [polygon[0], polygon[index], polygon[index + 1]]:
			vertices.append(point + normal * 0.045)
			normals.append(normal)
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
