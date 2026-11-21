extends "res://tools/art/capture_lookdev.gd"
## Separates the per-frame floor of this machine (window presentation, main
## loop) from the real cost of rendering the scene once.
##
## The scene is drawn into K identical fixed-pixel viewports that share one
## world, for K = 1..N, in the normal render loop. Frame time grows by one scene
## render for every extra viewport, so the slope of time against K is the cost
## of one render (shadows included, they are redrawn per viewport) and the
## intercept is the floor. The same ladder is repeated with every 3D node
## hidden, which gives the cost of an empty viewport with sky and post effects.
##
## Usage: godot --path . --disable-vsync --script <this> -- [--size=1920x1080] [--max=4] [--rounds=2]
##   [--mode=balanced|native|light] [--out=/abs/file.json]
class FixedQuality:
	extends "res://scripts/terrain_editor/preview_quality.gd"
	func advance(_delta: float, _limit: int = 0) -> void:
		pass

var px := Vector2i(1920, 1080)
var max_k: int = 4
var rounds: int = 2
var mode: String = "balanced"
var warm_s: float = 1.5
var sample_s: float = 4.0
var clones: Array[SubViewport] = []
var holder: Control

func _wait(seconds: float) -> void:
	var start: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await process_frame

func _sample() -> Dictionary:
	var drawn: int = Engine.get_frames_drawn()
	var start: int = Time.get_ticks_usec()
	var process_ms: float = 0.0
	var setup_ms: float = 0.0
	var cpu_ms: float = 0.0
	var gpu_ms: float = 0.0
	var count: int = 0
	while Time.get_ticks_usec() - start < int(sample_s * 1000000.0):
		await process_frame
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		setup_ms += RenderingServer.get_frame_setup_time_cpu()
		cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid())
		gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
		count += 1
	var elapsed: float = (Time.get_ticks_usec() - start) / 1000000.0
	var rendered: int = Engine.get_frames_drawn() - drawn
	return {"ms": elapsed * 1000.0 / maxi(rendered, 1), "rendered": rendered, "process_ms": process_ms / count, "setup_cpu_ms": setup_ms / count,
		"viewport_cpu_ms": cpu_ms / count, "viewport_gpu_ms": gpu_ms / count}

func _set_clones(count: int) -> void:
	while clones.size() > count:
		var last: SubViewport = clones.pop_back()
		last.queue_free()
	while clones.size() < count:
		var extra := SubViewport.new()
		extra.size = px
		extra.world_3d = viewport.find_world_3d()
		extra.msaa_3d = viewport.msaa_3d
		extra.scaling_3d_mode = viewport.scaling_3d_mode
		extra.scaling_3d_scale = viewport.scaling_3d_scale
		extra.use_debanding = viewport.use_debanding
		extra.screen_space_aa = viewport.screen_space_aa
		extra.use_taa = viewport.use_taa
		extra.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var eye := Camera3D.new()
		var source: Camera3D = editor.camera
		eye.fov = source.fov
		eye.near = source.near
		eye.far = source.far
		eye.attributes = source.attributes
		extra.add_child(eye)
		root.add_child(extra)
		eye.global_transform = source.global_transform
		eye.current = true
		clones.append(extra)

func _light_mode() -> void:
	# Candidate low tier, measurement only: no MSAA, no screen-space AO or indirect
	# light, no depth of field, 2048 shadow atlas with the plain filter.
	var env: Environment = (editor.get_node("WorldEnvironment") as WorldEnvironment).environment
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	env.ssao_enabled = false
	env.ssil_enabled = false
	(editor.camera.attributes as CameraAttributesPractical).dof_blur_far_enabled = false
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(1)

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts: PackedStringArray = arg.trim_prefix("--size=").split("x")
			px = Vector2i(int(parts[0]), int(parts[1]))
		if arg.begins_with("--max="):
			max_k = int(arg.trim_prefix("--max="))
		if arg.begins_with("--rounds="):
			rounds = int(arg.trim_prefix("--rounds="))
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
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
	editor.preview_quality.native = mode == "native"
	editor.preview_quality._last_native = mode == "native"
	editor.preview_quality._apply()
	editor.hud.hide()
	editor.gameplay.time_system.set_progress(.29, editor)
	_frame(Vector2(-2, -1), 32, 16, 30)
	editor.background_view.sync()
	if mode == "light":
		_light_mode()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	await _wait(3.0)
	print("INFO size=", px, " mode=", mode, " msaa=", viewport.msaa_3d, " scale=", viewport.scaling_3d_scale, " bg_active=", editor.background_view.is_active(), " refresh=", DisplayServer.screen_get_refresh_rate())
	var rows: Array[Dictionary] = []
	for round_index: int in rounds:
		for scene_on: bool in [true, false]:
			editor.visible = scene_on
			var ladder: Array = range(1, max_k + 1)
			if round_index % 2 == 1:
				ladder.reverse()
			for k: int in ladder:
				_set_clones(k - 1)
				await _wait(warm_s)
				var row: Dictionary = await _sample()
				row["k"] = k
				row["scene"] = scene_on
				row["round"] = round_index
				rows.append(row)
				print("SAMPLE scene=%s k=%d %.2f ms  process %.2f  setup_cpu %.2f  vp_cpu %.2f  vp_gpu %.2f" % [scene_on, k, row.ms, row.process_ms, row.setup_cpu_ms, row.viewport_cpu_ms, row.viewport_gpu_ms])
		editor.visible = true
	_set_clones(0)
	var fits: Dictionary = {}
	for scene_on: bool in [true, false]:
		# Least squares of ms against k.
		var n: float = 0.0
		var sx: float = 0.0
		var sy: float = 0.0
		var sxx: float = 0.0
		var sxy: float = 0.0
		for row: Dictionary in rows:
			if bool(row.scene) != scene_on:
				continue
			n += 1.0
			sx += float(row.k)
			sy += float(row.ms)
			sxx += float(row.k) * float(row.k)
			sxy += float(row.k) * float(row.ms)
		var slope: float = (n * sxy - sx * sy) / (n * sxx - sx * sx)
		var intercept: float = (sy - slope * sx) / n
		fits["scene" if scene_on else "empty"] = {"ms_per_render": slope, "floor_ms": intercept}
		print("FIT %-5s  one render %.2f ms   floor %.2f ms" % ["scene" if scene_on else "empty", slope, intercept])
	if output != "":
		var report: Dictionary = {"adapter": RenderingServer.get_video_adapter_name(), "resolution": [px.x, px.y], "mode": mode, "rounds": rounds, "warm_seconds": warm_s,
			"sample_seconds": sample_s, "fits": fits, "samples": rows,
			"method": "K identical fixed-pixel viewports sharing one world in the normal render loop, visible 1280x720 window, no cap or vsync; slope of frame time against K is one scene render, intercept is the machine floor; repeated with all 3D nodes hidden"}
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	editor.free()
	viewport.free()
	quit()
