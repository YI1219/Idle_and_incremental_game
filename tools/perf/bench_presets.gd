extends "res://tools/art/capture_lookdev.gd"
## Frame cost of the named quality tiers on this machine: same scene, same
## views, real fixed pixels, normal render loop.
##
## How it measures. A desktop window presents no faster than its display path
## allows (about 85 frames a second on the development Mac), so a cheap frame
## reads as that ceiling instead of its own cost. The scene is therefore drawn
## into K identical viewports that share one world and the frame time is
## divided by K. K is chosen per size so the frame stays well above the ceiling.
## The ceiling itself is reported as "idle window".
##
## Usage (any machine with Godot 4.7 and this project, on mains power):
##   godot --path . --disable-vsync --script res://tools/perf/bench_presets.gd -- \
##     [--sizes=1920x1080,2560x1440] [--presets=native,balanced,light] [--views=whole,game,reverse] \
##     [--k=0] [--seconds=4] [--out=/abs/file.json]
## --k=0 picks K automatically (3 up to 1080p, 2 up to 1440p, 1 above).
class FixedQuality:
	extends "res://scripts/terrain_editor/preview_quality.gd"
	func advance(_delta: float, _limit: int = 0) -> void:
		pass

const VIEWS: Dictionary = {
	"whole": [Vector2(-2, -1), 32.0, 16.0, 30.0],
	"game": [Vector2(0, -1), 21.0, 16.0, 27.0],
	"reverse": [Vector2(-2, -1), 32.0, 196.0, 30.0],
	"close": [Vector2(-10, -5), 13.0, 16.0, 30.0],
}
var sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1440)]
var presets: PackedStringArray = ["native", "balanced", "light"]
var views: PackedStringArray = ["whole", "game", "reverse"]
var forced_k: int = 0
var warm_s: float = 1.5
var sample_s: float = 4.0
var clones: Array[SubViewport] = []

func _wait(seconds: float) -> void:
	var start: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await process_frame

func _frame_ms() -> float:
	var drawn: int = Engine.get_frames_drawn()
	var start: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < int(sample_s * 1000000.0):
		await process_frame
	return (Time.get_ticks_usec() - start) / 1000.0 / maxi(Engine.get_frames_drawn() - drawn, 1)

func _set_clones(count: int, px: Vector2i) -> void:
	while clones.size() > count:
		var last: SubViewport = clones.pop_back()
		last.queue_free()
	while clones.size() < count:
		var extra := SubViewport.new()
		extra.world_3d = viewport.find_world_3d()
		extra.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var eye := Camera3D.new()
		eye.name = "Eye"
		extra.add_child(eye)
		root.add_child(extra)
		eye.current = true
		clones.append(extra)
	for extra: SubViewport in clones:
		extra.size = px

func _mirror() -> void:
	var source: Camera3D = editor.camera
	for extra: SubViewport in clones:
		extra.msaa_3d = viewport.msaa_3d
		extra.screen_space_aa = viewport.screen_space_aa
		extra.scaling_3d_mode = viewport.scaling_3d_mode
		extra.scaling_3d_scale = viewport.scaling_3d_scale
		extra.use_debanding = viewport.use_debanding
		var eye: Camera3D = extra.get_node("Eye") as Camera3D
		eye.fov = source.fov
		eye.near = source.near
		eye.far = source.far
		eye.attributes = source.attributes
		eye.global_transform = source.global_transform

func _preset(name: String) -> void:
	editor.set_native_preview(name == "native")
	editor.set_light_preview(name == "light")
	editor.preview_quality._scale = 1.0
	editor.preview_quality._apply()
	editor.background_view.sync()
	_mirror()

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sizes="):
			sizes.clear()
			for token: String in arg.trim_prefix("--sizes=").split(","):
				var parts: PackedStringArray = token.split("x")
				sizes.append(Vector2i(int(parts[0]), int(parts[1])))
		if arg.begins_with("--presets="):
			presets = arg.trim_prefix("--presets=").split(",")
		if arg.begins_with("--views="):
			views = arg.trim_prefix("--views=").split(",")
		if arg.begins_with("--k="):
			forced_k = int(arg.trim_prefix("--k="))
		if arg.begins_with("--seconds="):
			sample_s = float(arg.trim_prefix("--seconds="))
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	root.title = "性能验证 · 自动关闭"
	root.size = Vector2i(1280, 720)
	root.always_on_top = true
	viewport = SubViewport.new()
	viewport.size = sizes[0]
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
	editor.hud.hide()
	editor.gameplay.time_system.set_progress(.29, editor)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _wait(3.0)
	while editor.renderer.has_pending_updates():
		await process_frame
	# The display ceiling: nothing 3D drawn.
	editor.visible = false
	await _wait(1.0)
	var idle_ms: float = await _frame_ms()
	editor.visible = true
	print("IDLE WINDOW %.2f ms (%.0f fps): the ceiling of this display path" % [idle_ms, 1000.0 / idle_ms])
	var rows: Array[Dictionary] = []
	for px: Vector2i in sizes:
		var k: int = forced_k if forced_k > 0 else (3 if px.x * px.y <= 1920 * 1080 else (2 if px.x * px.y <= 2560 * 1440 else 1))
		viewport.size = px
		_set_clones(k - 1, px)
		for view: String in views:
			var spec: Array = VIEWS[view]
			_frame(spec[0], spec[1], spec[2], spec[3])
			var order: Array = Array(presets)
			var sums: Dictionary = {}
			for pass_index: int in 2:
				for preset: String in order:
					_preset(preset)
					await _wait(warm_s)
					var ms: float = (await _frame_ms()) / float(k)
					sums[preset] = float(sums.get(preset, 0.0)) + ms * .5
				order.reverse()
			for preset: String in presets:
				var ms: float = sums[preset]
				rows.append({"size": [px.x, px.y], "view": view, "preset": preset, "k": k, "ms": ms, "fps": 1000.0 / ms})
				print("RESULT %4dx%-4d %-8s %-9s %6.2f ms  %6.1f fps  (K=%d)" % [px.x, px.y, view, preset, ms, 1000.0 / ms, k])
	_preset("balanced")
	if output != "":
		var report: Dictionary = {
			"adapter": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
			"os": OS.get_name(), "cpu": OS.get_processor_name(), "godot": Engine.get_version_info().string,
			"refresh_hz": DisplayServer.screen_get_refresh_rate(), "idle_window_ms": idle_ms, "warm_seconds": warm_s, "sample_seconds": sample_s,
			"rows": rows,
			"method": "normal render loop, no cap or vsync; K identical fixed-pixel viewports share one world and the frame time is divided by K; each preset sampled twice (forward then reverse order) per view; full pixels, no dynamic resolution; mains power is the caller's responsibility",
		}
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	editor.free()
	viewport.free()
	quit()
