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
]
const COLUMN_COLORS: Dictionary = {
	"cliff_column_0": Color(.15, .70, .20), "cliff_column_b": Color(.65, .85, .10), "cliff_column_c": Color(.05, .55, .55),
	"cliff_column_d": Color(.95, .85, .10), "cliff_column_e": Color(.10, .85, .90), "cliff_column_f": Color(.45, .45, .05),
	"cliff_column_g": Color(.35, .95, .55), "cliff_column_h": Color(.80, .95, .65),
}
var plain: bool = false
var hide_kinds: PackedStringArray = []
var only_cameras: PackedStringArray = []
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
