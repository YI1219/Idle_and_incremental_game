extends "res://tools/art/capture_lookdev.gd"
## Same-scene A/B stills at a real fixed-pixel target. Time, wind and water are
## frozen once; each camera is drawn with variant A then variant B, so a pair
## differs only by the named switch.
## Usage: godot --path . --script <this> -- --out=res://.../dir --pair=grass_lod|ssil_quality [--size=3840x2160] [--native]
class FixedQuality:
	extends "res://scripts/terrain_editor/preview_quality.gd"
	func advance(_delta: float, _limit: int = 0) -> void:
		pass

const CAMERAS: Array[Dictionary] = [
	{"name": "game", "center": Vector2(-2, -1), "height": 32.0, "yaw": 16.0, "pitch": 30.0},
	{"name": "terrace_close", "center": Vector2(-3, -2), "height": 12.5, "yaw": 28.0, "pitch": 26.0},
	{"name": "outer_hull", "center": Vector2(3, 4), "height": 13.5, "yaw": 344.0, "pitch": 18.0},
	{"name": "whole", "center": Vector2(-2, -1), "height": 52.0, "yaw": 16.0, "pitch": 30.0},
]
var pair: String = "grass_lod"
var px := Vector2i(3840, 2160)
var native_quality: bool = false
var records: Array[Dictionary] = []

func _grass_nodes() -> Array[MultiMeshInstance3D]:
	var result: Array[MultiMeshInstance3D] = []
	for node: Node in editor.find_children("grass_blades", "MultiMeshInstance3D", true, false):
		result.append(node as MultiMeshInstance3D)
	return result

func _apply(variant: String) -> void:
	if pair == "grass_lod":
		var script_path: String = "res://art/lookdev/20261119_native4k/checks/source_before/scripts/terrain_editor/grass_field.gd" if variant == "before" else "res://scripts/terrain_editor/grass_field.gd"
		var mesh: ArrayMesh = load(script_path).clump_mesh()
		for node: MultiMeshInstance3D in _grass_nodes():
			node.multimesh.mesh = mesh
	elif pair == "ssil_quality":
		var prefix: String = "rendering/environment/ssil/"
		RenderingServer.environment_set_ssil_quality(int(ProjectSettings.get_setting(prefix + "quality")) if variant == "before" else RenderingServer.ENV_SSIL_QUALITY_VERY_LOW, bool(ProjectSettings.get_setting(prefix + "half_size")), float(ProjectSettings.get_setting(prefix + "adaptive_target")), int(ProjectSettings.get_setting(prefix + "blur_passes")), float(ProjectSettings.get_setting(prefix + "fadeout_from")), float(ProjectSettings.get_setting(prefix + "fadeout_to")))
	elif pair == "final":
		# Task start (old clump LOD table + project SSIL gather) against production.
		var start: bool = variant == "before"
		var mesh_path: String = "res://art/lookdev/20261119_native4k/checks/source_before/scripts/terrain_editor/grass_field.gd" if start else "res://scripts/terrain_editor/grass_field.gd"
		var clump: ArrayMesh = load(mesh_path).clump_mesh()
		for node: MultiMeshInstance3D in _grass_nodes():
			node.multimesh.mesh = clump
		editor.preview_quality._apply()
		if start:
			var base: String = "rendering/environment/ssil/"
			RenderingServer.environment_set_ssil_quality(int(ProjectSettings.get_setting(base + "quality")), bool(ProjectSettings.get_setting(base + "half_size")), float(ProjectSettings.get_setting(base + "adaptive_target")), int(ProjectSettings.get_setting(base + "blur_passes")), float(ProjectSettings.get_setting(base + "fadeout_from")), float(ProjectSettings.get_setting(base + "fadeout_to")))
	elif pair == "none":
		pass

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg.begins_with("--pair="):
			pair = arg.trim_prefix("--pair=")
		if arg.begins_with("--size="):
			var parts: PackedStringArray = arg.trim_prefix("--size=").split("x")
			px = Vector2i(int(parts[0]), int(parts[1]))
		if arg == "--native":
			native_quality = true
		if arg.begins_with("--progress="):
			progress = float(arg.trim_prefix("--progress="))
	if output == "" or FileAccess.file_exists(output.path_join("captures.json")):
		push_error("Select a new --out directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.title = "对照采图 · 自动关闭"
	root.size = Vector2i(1280, 720)
	viewport = SubViewport.new()
	viewport.size = px
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(display)
	editor = load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.runtime_power.process_mode = Node.PROCESS_MODE_DISABLED
	editor.preview_quality = FixedQuality.new()
	editor.preview_quality.configure(viewport)
	editor.preview_quality.native = native_quality
	editor.preview_quality._last_native = native_quality
	editor.preview_quality._scale = 1.0
	editor.preview_quality._apply()
	editor.hud.hide()
	editor.gameplay.set_wallpaper_mode(true)
	editor.gameplay.time_system.set_progress(progress, editor)
	# Let the live water reach its published surface, then stop every clock.
	for index: int in 30:
		await process_frame
	editor.water_view.flush()
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	_freeze_node(editor)
	editor.gameplay.time_system.set_progress(progress, editor)
	for camera: Dictionary in CAMERAS:
		_frame(camera.center, camera.height, camera.yaw, camera.pitch)
		editor.background_view.sync()
		for variant: String in ["before", "after", "before_repeat"]:
			_apply("before" if variant == "before_repeat" else variant)
			for index: int in 30:
				RenderingServer.force_draw(false)
				await process_frame
			RenderingServer.force_draw(false)
			var image: Image = viewport.get_texture().get_image()
			var file: String = "%s_%s.png" % [camera.name, variant]
			var result: Error = image.save_png(output.path_join(file))
			records.append({"file": file, "camera": camera.name, "variant": variant, "save_error": result, "size": [image.get_width(), image.get_height()], "msaa": viewport.msaa_3d, "scale": viewport.scaling_3d_scale, "native_quality": native_quality, "background_active": editor.background_view.is_active(), "primitives": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME), "position": _vector(editor.camera.position), "rotation_degrees": _vector(editor.camera.rotation_degrees), "day_progress": progress})
			print("AB saved ", file)
	_apply("after")
	FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE).store_string(JSON.stringify({"pair": pair, "adapter": RenderingServer.get_video_adapter_name(), "phase": PHASE, "seed": 7301, "preset": 0, "method": "one live scene, frozen time/wind/water, real fixed-pixel target; before_repeat re-draws variant A after B to show the frame-to-frame noise floor", "captures": records, "art_accepted": false, "target_hardware_performance_measured": false}, "\t"))
	editor.free()
	viewport.free()
	quit()
