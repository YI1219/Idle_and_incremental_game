extends "res://tools/art/capture_lookdev.gd"
## Diagnostic only: tints every cliff generator's output with its own flat
## colour so a fragment in a still can be traced to the code that built it.
## Never a production look. Usage:
## godot --path . --script <this> -- --out=res://.../dir [--seed=7301] [--preset=0] [--plain]
const CAMERAS: Array[Dictionary] = [
	{"name": "cliff_close", "center": Vector2(-8, 6), "height": 10.0, "yaw": 16.0, "pitch": 20.0},
	{"name": "foot_front", "center": Vector2(-8, 6), "height": 13.0, "yaw": 16.0, "pitch": 24.0},
	{"name": "foot_reverse", "center": Vector2(-2, -1), "height": 17.0, "yaw": 196.0, "pitch": 18.0},
	{"name": "side_106", "center": Vector2(-2, -1), "height": 32.0, "yaw": 106.0, "pitch": 30.0},
	{"name": "side_286", "center": Vector2(-2, -1), "height": 32.0, "yaw": 286.0, "pitch": 30.0},
	{"name": "whole", "center": Vector2(-2, -1), "height": 32.0, "yaw": 16.0, "pitch": 30.0},
	{"name": "reverse", "center": Vector2(-2, -1), "height": 32.0, "yaw": 196.0, "pitch": 30.0},
	{"name": "under_196", "center": Vector2(-2, -1), "height": 3.2, "yaw": 196.0, "pitch": 5.0},
	{"name": "under_106", "center": Vector2(-2, -1), "height": 3.2, "yaw": 106.0, "pitch": 5.0},
	{"name": "under_016", "center": Vector2(-2, -1), "height": 3.2, "yaw": 16.0, "pitch": 5.0},
	{"name": "game", "center": Vector2(0, -1), "height": 21.0, "yaw": 16.0, "pitch": 27.0},
	{"name": "close", "center": Vector2(-10, -5), "height": 13.0, "yaw": 16.0, "pitch": 30.0},
	{"name": "terrace_close", "center": Vector2(-3, -2), "height": 12.5, "yaw": 28.0, "pitch": 26.0},
	{"name": "outer_hull", "center": Vector2(3, 4), "height": 13.5, "yaw": 344.0, "pitch": 18.0},
	{"name": "pond_low", "center": Vector2(2, -1), "height": 9.0, "yaw": 40.0, "pitch": 19.0},
	{"name": "fall_close", "center": Vector2(5, 8), "height": 9.0, "yaw": 16.0, "pitch": 20.0},
]
const COLUMN_COLORS: Dictionary = {
	"cliff_column_0": Color(.15, .70, .20), "cliff_column_b": Color(.65, .85, .10), "cliff_column_c": Color(.05, .55, .55),
	"cliff_column_d": Color(.95, .85, .10), "cliff_column_e": Color(.10, .85, .90), "cliff_column_f": Color(.45, .45, .05),
	"cliff_column_g": Color(.35, .95, .55), "cliff_column_h": Color(.80, .95, .65),
}
var plain: bool = false
var hide_kinds: PackedStringArray = []
var only_cameras: PackedStringArray = []
var phases: PackedFloat32Array = []
var before: bool = false
var uniforms: Dictionary = {}
var legend: Dictionary = {}

func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _shader_file(node: GeometryInstance3D) -> String:
	var material: Material = node.material_override
	if material == null:
		var mesh: Mesh = null
		if node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
			mesh = (node as MultiMeshInstance3D).multimesh.mesh
		if mesh != null and mesh.get_surface_count() > 0:
			material = mesh.surface_get_material(0)
	if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
		return (material as ShaderMaterial).shader.resource_path.get_file()
	return ""

func _tint() -> void:
	for node: Node in editor.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		var shader: String = _shader_file(geometry)
		var name: String = String(node.name)
		var key: String = ""
		var color := Color.WHITE
		if shader == "cliff.gdshader":
			key = "hull (contour_terrain cliff mesh)"; color = Color(.85, .22, .18)
		elif shader == "stone_mantle.gdshader":
			key = "stone_mantle (block_mantle)"; color = Color(.20, .35, .95)
		elif shader == "cliff_column.gdshader":
			if name.begins_with("underside_rock"):
				key = "underside_rock"; color = Color(1.0, .50, .0)
			else:
				for prefix: String in COLUMN_COLORS:
					if name.begins_with(prefix + "_") or name == prefix:
						key = prefix; color = COLUMN_COLORS[prefix]
				# cliff_column_0 is a prefix of nothing else; longer names win above.
				if key == "":
					key = "cliff_column other: " + name; color = Color(.9, .9, .9)
		elif shader == "cliff_rock.gdshader" and name.begins_with("cliff_rock"):
			key = "cliff_rock (shoulder boulders)"; color = Color(.90, .15, .85)
		if key == "":
			continue
		geometry.material_override = _flat(color)
		var count: int = 1
		if node is MultiMeshInstance3D:
			count = (node as MultiMeshInstance3D).multimesh.instance_count
		var row: Dictionary = legend.get(key, {"color": color.to_html(false), "nodes": 0, "instances": 0})
		row.nodes += 1
		row.instances += count
		legend[key] = row

func _set_phase(node: Node, value: float) -> void:
	var found: Array = []
	if node is GeometryInstance3D:
		found.append((node as GeometryInstance3D).material_override)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		for index: int in (node as MeshInstance3D).mesh.get_surface_count():
			found.append((node as MeshInstance3D).mesh.surface_get_material(index))
			found.append((node as MeshInstance3D).get_surface_override_material(index))
	for material: Variant in found:
		if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
			for parameter: Dictionary in (material as ShaderMaterial).shader.get_shader_uniform_list():
				if String(parameter.name) in ["water_time", "flow_time", "foam_time"]:
					(material as ShaderMaterial).set_shader_parameter(parameter.name, value)
	for child: Node in node.get_children():
		_set_phase(child, value)

## --before: run the task-start copies of the shaders this package changed
## (checks/source_before, with their own includes) in the same live scene.
func _swap_before() -> void:
	var before_dir: String = "res://art/lookdev/20261121_cliff_water/checks/source_before/shaders/terrain_editor/"
	var old_shaders: Dictionary = {}
	for file: String in ["water.gdshader", "waterfall.gdshader", "cliff_column.gdshader", "cliff.gdshader"]:
		var shader := Shader.new()
		shader.code = FileAccess.get_file_as_string(before_dir + file).replace("#include \"", "#include \"" + before_dir)
		old_shaders[file] = shader
	var swapped: int = 0
	for node: Node in editor.find_children("*", "GeometryInstance3D", true, false):
		var candidates: Array = [(node as GeometryInstance3D).material_override]
		var source: Mesh = null
		if node is MeshInstance3D:
			source = (node as MeshInstance3D).mesh
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
			source = (node as MultiMeshInstance3D).multimesh.mesh
		if source != null:
			for index: int in source.get_surface_count():
				candidates.append(source.surface_get_material(index))
		for material: Variant in candidates:
			if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
				var file: String = (material as ShaderMaterial).shader.resource_path.get_file()
				if old_shaders.has(file):
					(material as ShaderMaterial).shader = old_shaders[file]
					swapped += 1
	print("BEFORE shaders on ", swapped, " materials")

## --uniform=NAME=VALUE sets a float shader parameter on every material that has it.
func _set_uniform(node: Node, uniform_name: String, value: float) -> void:
	var found: Array = []
	if node is GeometryInstance3D:
		found.append((node as GeometryInstance3D).material_override)
	var source: Mesh = null
	if node is MeshInstance3D:
		source = (node as MeshInstance3D).mesh
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		source = (node as MultiMeshInstance3D).multimesh.mesh
	if source != null:
		for index: int in source.get_surface_count():
			found.append(source.surface_get_material(index))
	for material: Variant in found:
		if material is ShaderMaterial and (material as ShaderMaterial).shader != null:
			for parameter: Dictionary in (material as ShaderMaterial).shader.get_shader_uniform_list():
				if String(parameter.name) == uniform_name:
					(material as ShaderMaterial).set_shader_parameter(uniform_name, value)
	for child: Node in node.get_children():
		_set_uniform(child, uniform_name, value)

func run() -> void:
	var seed_arg: int = 7301
	var preset_arg: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg.begins_with("--seed="):
			seed_arg = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--preset="):
			preset_arg = int(arg.trim_prefix("--preset="))
		if arg.begins_with("--hide="):
			hide_kinds = arg.trim_prefix("--hide=").split(",")
		if arg.begins_with("--cameras="):
			only_cameras = arg.trim_prefix("--cameras=").split(",")
		if arg == "--plain":
			plain = true
		if arg.begins_with("--phases="):
			for token: String in arg.trim_prefix("--phases=").split(","):
				phases.append(float(token))
		if arg.begins_with("--uniform="):
			var pair: PackedStringArray = arg.trim_prefix("--uniform=").split("=")
			uniforms[pair[0]] = float(pair[1])
		if arg == "--before":
			before = true
		if arg.begins_with("--progress="):
			progress = float(arg.trim_prefix("--progress="))
	if output == "":
		push_error("--out required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.title = "岩体诊断 · 自动关闭"
	root.size = Vector2i(1280, 720)
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(display)
	editor = load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	# Same world setup as tools/art/capture_lookdev.gd: the editor never runs
	# live, so the opening water surge cannot flood the lower terrace.
	editor.runtime_power.process_mode = Node.PROCESS_MODE_DISABLED
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	editor.renderer.animate_edits = false
	editor.hud.hide()
	editor.gameplay.set_wallpaper_mode(true)
	if preset_arg != 0 or seed_arg != int(editor.data.seed):
		editor.data.make_preset(preset_arg)
		editor.data.seed = seed_arg
		editor.renderer.rebuild_all()
		editor.motes.rebuild_from_data(editor.data)
		editor.gameplay.on_preset_changed()
	editor.water_view.reset(editor.data)
	editor.water_view.tick(.1)
	editor.water_view.flush()
	editor.gameplay.time_system.set_progress(progress, editor)
	_freeze_node(editor)
	editor.gameplay.time_system.set_progress(progress, editor)
	if before:
		_swap_before()
	for uniform_name: String in uniforms:
		_set_uniform(editor, uniform_name, float(uniforms[uniform_name]))
	if not plain:
		_tint()
	# --hide=columns,underside,hull,mantle removes whole generator outputs so
	# what lies behind them can be inspected.
	for node: Node in editor.find_children("*", "GeometryInstance3D", true, false):
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		var node_name: String = String(node.name)
		var kind: String = ""
		if node_name.begins_with("cliff_column"):
			kind = "columns"
		elif node_name.begins_with("underside_rock"):
			kind = "underside"
		elif node_name == "cliff":
			kind = "hull"
		elif node_name == "stone_mantle":
			kind = "mantle"
		if kind != "" and kind in hide_kinds:
			geometry.visible = false
	for camera: Dictionary in CAMERAS:
		if not only_cameras.is_empty() and not String(camera.name) in only_cameras:
			continue
		_frame(camera.center, camera.height, camera.yaw, camera.pitch)
		for index: int in 24:
			RenderingServer.force_draw(false)
			await process_frame
		if not phases.is_empty():
			# Motion check: the same view at several shader clock values.
			for step: int in phases.size():
				_set_phase(editor, phases[step])
				for index: int in 3:
					RenderingServer.force_draw(false)
					await process_frame
				var phase_file: String = "%s_p%02d.png" % [camera.name, step]
				viewport.get_texture().get_image().save_png(output.path_join(phase_file))
				print("PARTS saved ", phase_file)
			_set_phase(editor, PHASE)
			continue
		RenderingServer.force_draw(false)
		var file: String = "%s.png" % camera.name
		viewport.get_texture().get_image().save_png(output.path_join(file))
		print("PARTS saved ", file)
	FileAccess.open(output.path_join("legend.json"), FileAccess.WRITE).store_string(JSON.stringify({"diagnostic": true, "plain": plain, "seed": seed_arg, "preset": preset_arg, "legend": legend}, "\t"))
	for key: String in legend:
		print("LEGEND ", key, " ", JSON.stringify(legend[key]))
	editor.free()
	viewport.free()
	quit()
