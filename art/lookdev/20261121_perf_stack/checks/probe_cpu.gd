extends "res://tools/art/capture_lookdev.gd"
## Finds what the main thread spends each frame on. All 3D is hidden so the GPU
## is idle and the frame time is the main-loop time; then the processing of one
## child subtree at a time is switched off and the frame time measured again.
## Usage: godot --path . --disable-vsync --script <this> -- [--size=1920x1080] [--out=/abs/file.json] [--visible]
class FixedQuality:
	extends "res://scripts/terrain_editor/preview_quality.gd"
	func advance(_delta: float, _limit: int = 0) -> void:
		pass

var px := Vector2i(1920, 1080)
var sample_s: float = 2.5
var keep_visible: bool = false

func _wait(seconds: float) -> void:
	var start: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await process_frame

func _sample() -> float:
	var drawn: int = Engine.get_frames_drawn()
	var start: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < int(sample_s * 1000000.0):
		await process_frame
	return (Time.get_ticks_usec() - start) / 1000.0 / maxi(Engine.get_frames_drawn() - drawn, 1)

func _describe(node: Node) -> String:
	var script: Script = node.get_script()
	return "%s (%s%s)" % [node.name, node.get_class(), ", " + script.resource_path.get_file() if script != null else ""]

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts: PackedStringArray = arg.trim_prefix("--size=").split("x")
			px = Vector2i(int(parts[0]), int(parts[1]))
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
		if arg == "--visible":
			keep_visible = true
	root.title = "性能验证 · 自动关闭"
	root.size = Vector2i(1280, 720)
	root.always_on_top = true
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
	editor.preview_quality._scale = 1.0
	editor.preview_quality._apply()
	editor.hud.hide()
	editor.gameplay.time_system.set_progress(.29, editor)
	_frame(Vector2(-2, -1), 32, 16, 30)
	editor.background_view.sync()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _wait(3.0)
	editor.visible = keep_visible
	await _wait(1.0)
	var rows: Array[Dictionary] = []
	var base_a: float = await _sample()
	print("BASE all processing on: %.2f ms" % base_a)
	rows.append({"case": "base", "ms": base_a})
	# Everything under the editor stops processing; rendering continues.
	var saved_mode: int = editor.process_mode
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(.5)
	var off_all: float = await _sample()
	print("ALL OFF editor subtree processing off: %.2f ms" % off_all)
	rows.append({"case": "editor subtree off", "ms": off_all})
	editor.process_mode = saved_mode
	await _wait(.5)
	# The editor's own _process alone.
	editor.set_process(false)
	editor.set_physics_process(false)
	await _wait(.5)
	var own: float = await _sample()
	print("OWN editor._process off (children on): %.2f ms" % own)
	rows.append({"case": "editor own process off", "ms": own})
	editor.set_process(true)
	editor.set_physics_process(true)
	for child: Node in editor.get_children():
		var before: int = child.process_mode
		child.process_mode = Node.PROCESS_MODE_DISABLED
		await _wait(.4)
		var ms: float = await _sample()
		child.process_mode = before
		print("CHILD off %-60s %.2f ms  (%+.2f)" % [_describe(child), ms, ms - base_a])
		rows.append({"case": "child off: " + _describe(child), "ms": ms})
	# Display path: stop showing the viewport texture in the window.
	display.visible = false
	await _wait(.4)
	var no_show: float = await _sample()
	print("WINDOW viewport texture not drawn in the window: %.2f ms" % no_show)
	rows.append({"case": "viewport not shown in window", "ms": no_show})
	display.visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	await _wait(.4)
	var no_render: float = await _sample()
	print("NORENDER scene viewport not rendered at all: %.2f ms" % no_render)
	rows.append({"case": "scene viewport update disabled", "ms": no_render})
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var base_b: float = await _sample()
	print("BASE again: %.2f ms" % base_b)
	rows.append({"case": "base again", "ms": base_b})
	if output != "":
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"resolution": [px.x, px.y], "scene_visible": keep_visible, "rows": rows,
			"method": "normal render loop, no cap or vsync, 2.5 s samples; all 3D hidden unless scene_visible"}, "\t"))
	editor.free()
	viewport.free()
	quit()
