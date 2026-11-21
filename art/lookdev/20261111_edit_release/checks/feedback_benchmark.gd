extends "res://tools/perf/blueprint_benchmark.gd"

func tick() -> void:
	editor.renderer.flush_dirty(6)
	editor.preview.refresh(editor.blueprint_data if editor.blueprint_data != null else editor.data, editor.renderer, editor.blueprint_data != null)
	if not editor.renderer.has_pending_updates():
		editor.water_view.tick(1.0 / 60.0)
	var before: int = Time.get_ticks_usec()
	RenderingServer.force_draw(false)
	await process_frame
	frames.append((Time.get_ticks_usec() - before) / 1000.0)

func run() -> void:
	editor = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.set_process(false)
	editor.camera.set_process(false)
	editor.renderer.terrain_published.connect(on_published)
	for i in 100:
		await tick()
	var report: Dictionary = {"godot": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(), "resolution": [root.size.x, root.size.y], "method": "2K native production release input, normal worker/morph/feedback clocks; explicit draw, no screenshot IO; camera fixed; water pauses only while terrain pending", "cases": []}
	for spec: Dictionary in [{"name": "short_raise", "tool": "raise", "hold": .02}, {"name": "held_raise", "tool": "raise", "hold": 1.2}, {"name": "short_contract", "tool": "contract", "hold": .02}, {"name": "wide_short_raise", "tool": "raise", "hold": .02, "radius": 3.8}]:
		editor.select_preset(0)
		editor.camera._center = Vector2(-2, -1)
		editor.camera._height = 32
		editor.camera._yaw = 16
		editor.camera._pitch = 30
		editor.camera.advance(0.0)
		editor.tool = spec.tool
		editor.radius = spec.get("radius", 2.2)
		for i in 20:
			await tick()
		var cell := Vector2i(-12, -2)
		var point := Vector3(cell.x + .5, editor.data.cells[cell].height, cell.y + .5)
		var started: bool = editor.begin_paint(editor.camera.unproject_position(point))
		var held: int = Time.get_ticks_usec()
		while (Time.get_ticks_usec() - held) / 1000000.0 < float(spec.hold):
			await tick()
		published_at = 0
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		var released: int = Time.get_ticks_usec()
		editor._input(release)
		var commit_ms: float = (Time.get_ticks_usec() - released) / 1000.0
		var immediate: bool = editor.preview.visible and editor.preview.material_override.get_shader_parameter("committed") == 1.0
		var feedback_build_ms: float = editor.preview.last_refresh_ms
		await tick()
		var first_frame_ms: float = (Time.get_ticks_usec() - released) / 1000.0
		while (editor.renderer.has_pending_updates() or editor.renderer.morph_progress < 1.0 or editor.preview.visible) and Time.get_ticks_usec() - released < 12000000:
			await tick()
		var row: Dictionary = {"name": spec.name, "started": started, "feedback_immediate": immediate, "release_callback_ms": commit_ms, "feedback_mesh_ms": feedback_build_ms, "release_to_first_draw_ms": first_frame_ms, "release_to_publication_ms": (published_at - released) / 1000.0, "release_to_complete_ms": (Time.get_ticks_usec() - released) / 1000.0}
		report.cases.append(row)
		print(JSON.stringify(row))
	report.source_sha256 = {}
	for file: String in ["res://scripts/terrain_editor/editor.gd", "res://scripts/terrain_editor/edit_preview.gd", "res://shaders/terrain_editor/edit_preview.gdshader"]:
		report.source_sha256[file] = FileAccess.get_sha256(file)
	FileAccess.open("res://art/lookdev/20261111_edit_release/checks/latency.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	editor.free()
	quit(0)
