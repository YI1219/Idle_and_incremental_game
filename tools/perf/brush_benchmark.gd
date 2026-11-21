extends SceneTree
## Brush-stroke frame benchmark on the real scene (windowed, vsync as configured).
## Usage: godot --path . --script tools/perf/brush_benchmark.gd -- [--out=/tmp/brush_bench.json]
## Reports frame intervals during strokes and until each revision publishes,
## worker latency per revision, main-thread publish cost and ghost cost.
## The first ~2 s after launch are idle on purpose: macOS shows one ~1 s
## presentation stall shortly after a window appears, unrelated to editing.
var editor: Node3D
var out_path := "/tmp/brush_bench.json"

func _initialize() -> void:
	call_deferred("run")

static func stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	var s := values.duplicate()
	s.sort()
	return {"n": s.size(), "p50": s[s.size() / 2], "p95": s[int(s.size() * .95)], "p99": s[mini(s.size() - 1, int(s.size() * .99))], "max": s[-1]}

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	# Editor F5 can also pass the entry scene as a positional argument with --script.
	# Remove only that automatic entry instance before creating the benchmark scene.
	var bootstrap_removed: Array[String] = []
	for child: Node in root.get_children():
		if child.scene_file_path == "res://scenes/terrain_editor.tscn":
			bootstrap_removed.append(child.scene_file_path)
			if current_scene == child:
				current_scene = null
			root.remove_child(child)
			child.free()
	editor = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.hud.hide()
	editor.set_process(false)
	for i in 240:
		await process_frame
	var render_size := Vector2i(root.get_texture().get_size())
	var report := {
		"godot": Engine.get_version_info().string,
		"adapter": RenderingServer.get_video_adapter_name(),
		"resolution": [render_size.x, render_size.y],
		"window_size": [root.size.x, root.size.y],
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"bootstrap_removed": bootstrap_removed,
		"strokes": {},
	}
	var strokes := {
		"expand": func(step: int) -> Vector2: return Vector2(-14.0 + step * 0.2, 9.0 + sin(step * .1)),
		"raise": func(step: int) -> Vector2: return Vector2(-8.0 + step * 0.12, -4.0),
		"contract": func(step: int) -> Vector2: return Vector2(8.0 + step * 0.05, 6.0),
	}
	for tool: String in strokes:
		var frames: Array = []
		var workers: Array = []
		var publishes: Array = []
		var ghost: Array = []
		editor.tool = tool
		editor.data.begin_stroke()
		await process_frame
		var last := Time.get_ticks_usec()
		var step := 0
		var settle := 0
		while step < 90 or editor.renderer.has_pending_updates() or not editor.renderer._graveyard.is_empty():
			if step < 90:
				editor.data.apply_brush(strokes[tool].call(step), 1.6, tool, false, 1.5, 3)
				if step == 89:
					editor.data.end_stroke()
			step += 1
			editor.renderer.flush_dirty(6)
			editor.preview.refresh(editor.data, editor.renderer)
			ghost.append(editor.preview.last_refresh_ms)
			if editor.renderer.last_publish_ms > 0.0:
				publishes.append(editor.renderer.last_publish_ms)
				workers.append(editor.renderer.last_worker_ms)
				editor.renderer.last_publish_ms = 0.0
			await process_frame
			var now := Time.get_ticks_usec()
			frames.append((now - last) / 1000.0)
			last = now
			settle += 1
			if settle > 4000:
				break
		report.strokes[tool] = {"frame_ms": stats(frames), "over_16_7ms": frames.filter(func(v): return v > 16.7).size(), "worker_ms": workers, "publish_ms": stats(publishes), "ghost_ms": stats(ghost)}
		print("BRUSH %s: frames %s; >16.7ms %d; worker %s; publish %s" % [tool, str(report.strokes[tool].frame_ms), report.strokes[tool].over_16_7ms, str(workers), str(report.strokes[tool].publish_ms)])
	FileAccess.open(out_path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	quit(0)
