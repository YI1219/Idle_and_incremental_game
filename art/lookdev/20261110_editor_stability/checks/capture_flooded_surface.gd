extends "res://tools/art/capture_lookdev.gd"
## Same-instance shader comparison after two ordinary lower strokes beside the
## upper pond. Restores dry surfaces using the existing dry brush, never layout IO.
const PACKAGE = "res://art/lookdev/20261110_editor_stability"
const SNAPSHOT = PACKAGE + "/checks/source_before"
const FLOOD_SHADERS = {"grass": "ground.gdshader", "rim_green": "rim_green.gdshader", "grass_blades": "grass_blades.gdshader"}
var current_shaders: Dictionary = {}
var baseline_shaders: Dictionary = {}
var terrain_checks: Array[Dictionary] = []
var reframed: bool = OS.get_cmdline_user_args().has("--reframed")
var capture_root: String = PACKAGE
var production_sources: Dictionary = {}

func _inspection_frame(yaw: float, pitch: float) -> void:
	_frame(Vector2(-7.5, -3.5), 7, yaw, pitch)
	if reframed:
		editor.camera.position.y += 2.5

func _snapshot_source(path: String) -> String:
	var snapshot: String = SNAPSHOT.path_join(path.trim_prefix("res://"))
	var source: String = FileAccess.get_file_as_string(snapshot if FileAccess.file_exists(snapshot) else path)
	var expanded: PackedStringArray = []
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("#include"):
			var relative: String = line.get_slice('"', 1)
			var include_path: String = relative if relative.begins_with("res://") else path.get_base_dir().path_join(relative)
			expanded.append(_snapshot_source(include_path))
		else:
			expanded.append(line)
	var token: RegEx = RegEx.new()
	token.compile("\\bTIME\\b")
	return token.sub("\n".join(expanded), str(PHASE), true)

func _select_baseline(baseline: bool) -> void:
	for kind: String in FLOOD_SHADERS:
		var material: ShaderMaterial = editor.renderer.materials[kind]
		material.shader.code = baseline_shaders[kind] if baseline else current_shaders[kind]

func _state_capture(label: String) -> void:
	var before: String = JSON.stringify(editor.data.serialize(), "", true, true).sha256_text()
	await _capture(label, .29)
	captures[-1].seed = editor.data.seed
	captures[-1].data_sha256 = before
	captures[-1].data_unchanged = before == JSON.stringify(editor.data.serialize(), "", true, true).sha256_text()
	captures[-1].water_volume = editor.water_view.published_volume
	captures[-1].discharged = editor.water_view.published_discharged_volume
	captures[-1].shader_sha256 = {}
	for kind: String in FLOOD_SHADERS:
		captures[-1].shader_sha256[kind] = editor.renderer.materials[kind].shader.code.sha256_text()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): capture_root = arg.trim_prefix("--out=")
	production_sources = _source_hashes()
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var held_seeds: Array[int] = [7301, 2104, 4242]
	if reframed:
		held_seeds = [7301]
	var angles: Array[Dictionary] = [{"name": "front", "yaw": 16.0, "pitch": 50.0}, {"name": "reverse", "yaw": 196.0, "pitch": 50.0}]
	if reframed:
		angles = [{"name": "front", "yaw": 16.0, "pitch": 65.0}, {"name": "side", "yaw": 106.0, "pitch": 65.0}, {"name": "reverse", "yaw": 196.0, "pitch": 65.0}]
	for held_seed: int in held_seeds:
		output = capture_root.path_join("seed_" + str(held_seed)) if capture_root != PACKAGE else PACKAGE.path_join(("flooded_surface_reframed/seed_" if reframed else "flooded_surface_native/seed_") + str(held_seed))
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output)):push_error("Use new evidence directory");quit(1);return
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		editor = load("res://scenes/terrain_editor.tscn").instantiate()
		viewport.add_child(editor)
		editor.process_mode = Node.PROCESS_MODE_DISABLED
		editor.renderer.animate_edits = false
		editor.data.seed = held_seed
		editor.renderer.rebuild_all()
		editor.water_view.reset(editor.data)
		var initial_volume: float = editor.water_view.published_volume
		var f11: InputEventKey = InputEventKey.new()
		f11.keycode = KEY_F11
		f11.pressed = true
		editor.gameplay.handle_unhandled_input(f11)
		editor.gameplay.shihai_hud.tick_ui(4.0, editor.gameplay.state, editor.gameplay.time_system, editor.gameplay.fishing, editor.data.cells.size(), editor.gameplay.stance, editor.gameplay.wallpaper_mode)
		_freeze_node(editor)
		for kind: String in FLOOD_SHADERS:
			current_shaders[kind] = editor.renderer.materials[kind].shader.code
			baseline_shaders[kind] = _snapshot_source("res://shaders/terrain_editor/" + FLOOD_SHADERS[kind])
		if held_seed == 7301:
			_frame(Vector2(-2, -1), 32, 196, 30)
			await _state_capture("baseline_reverse")
		_inspection_frame(16, 65 if reframed else 50)
		await _state_capture("00_dry_before_lower")
		var changed: Array[int] = []
		for top: float in [3.5, 3.0]:
			editor.data.begin_stroke()
			changed.append(editor.data.apply_brush(Vector2(-7.5, -3.5), 2.2, "lower", false, top, 7, top))
			editor.data.end_stroke()
			editor.renderer.rebuild_all()
			editor.water_view.flush()
		for step: int in 30:
			editor.water_view.tick(.1)
			editor.water_view.flush()
		_freeze_node(editor)
		var flooded_land: Array = []
		for cell: Vector2i in editor.water_view.published_depths:
			if editor.data.cells[cell].water < 0 and editor.water_view.published_depths[cell] > .005:
				flooded_land.append({"cell": [cell.x, cell.y], "depth": editor.water_view.published_depths[cell], "height": editor.data.cells[cell].height})
		terrain_checks.append({"seed": held_seed, "changed_cells_per_stroke": changed, "flooded_formerly_dry_cells": flooded_land, "initial_volume": initial_volume, "retained": editor.water_view.published_volume, "discharged": editor.water_view.published_discharged_volume, "mass_error": absf(initial_volume - editor.water_view.published_volume - editor.water_view.published_discharged_volume)})
		for angle: Dictionary in angles:
			_inspection_frame(angle.yaw, angle.pitch)
			_select_baseline(true)
			await _state_capture("01_before_flooded_" + angle.name)
			_select_baseline(false)
			await _state_capture("02_after_flooded_" + angle.name)
		editor.data.begin_stroke()
		editor.data.apply_brush(Vector2(-3, 0), 16.0, "dry", false, 3.5, 7)
		editor.data.end_stroke()
		editor.renderer.rebuild_all()
		editor.water_view.flush()
		_freeze_node(editor)
		for angle: Dictionary in angles:
			_inspection_frame(angle.yaw, angle.pitch)
			await _state_capture("03_dry_brush_restored_" + angle.name)
		editor.free()
		await process_frame
	FileAccess.open(capture_root.path_join("captures.json") if capture_root != PACKAGE else PACKAGE.path_join("checks/flooded_native_reframed.json" if reframed else "checks/flooded_native.json"), FileAccess.WRITE).store_string(JSON.stringify({"production_source_sha256": production_sources, "sources_unchanged": production_sources == _source_hashes(), "scene": "res://scenes/terrain_editor.tscn", "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "resolution": [SIZE.x, SIZE.y], "phase": PHASE, "day_progress": .29, "water_interval_seconds": 3.0, "drain_method": "existing dry brush, radius 16m", "user_layouts_accessed": false, "captures": captures, "terrain": terrain_checks, "errors": errors}, "\t"))
	viewport.free()
	print("FLOODED NATIVE: ", captures.size(), " captures, ", errors.size(), " errors")
	quit(1 if not errors.is_empty() else 0)
