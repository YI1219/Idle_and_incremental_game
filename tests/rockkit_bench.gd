extends SceneTree
## Stress numbers for the rock-kit underside. Headless VM sample, not target-device evidence.

const IslandGeometry := preload("res://scripts/world/island_geometry.gd")
const RiverTerrain := preload("res://scripts/world/river_terrain.gd")
const RockKit := preload("res://scripts/world/rock_kit.gd")

const REPORT := "res://art/review/island_style/2026-10-02/rockkit_bench.txt"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	print("rockkit_bench: start")
	RockKit.ensure()
	var lines: PackedStringArray = []
	lines.append("Rock-kit underside benchmark")
	lines.append("Godot %s  renderer=%s" % [Engine.get_version_info().get("string", "?"), _renderer()])
	lines.append("This is a development-machine / VM sample. It is not target-laptop evidence.")
	lines.append("")

	var terrain: Node3D = RiverTerrain.new()
	root.add_child(terrain)
	await process_frame

	print("rockkit_bench: playable")
	var starter := _rect(-6, 7, -6, 4)
	terrain.configure(starter)
	await _settle(4)
	terrain.flush_bakes()
	await _settle(2)
	var playable: Dictionary = terrain.rock_stats()
	lines.append(_block("playable courtyard (~130 cells, 1 island)", playable, await _frame_sample(12)))

	print("rockkit_bench: 4x island")
	var large := _rect(-12, 12, -11, 11)
	var t0 := Time.get_ticks_usec()
	terrain.configure(large)
	var large_build_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	print("rockkit_bench: 4x build %.1f ms" % large_build_ms)
	await _settle(2)
	terrain.flush_bakes()
	var large_stats: Dictionary = terrain.rock_stats()
	large_stats["build_ms"] = large_build_ms
	lines.append(_block("4x-area island (%d cells, 1 island)" % large.size(), large_stats, await _frame_sample(12)))

	var grow_cell := Vector2i(12, 0)
	terrain.land_cells[grow_cell] = true
	t0 = Time.get_ticks_usec()
	terrain.rebuild()
	var edit_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	lines.append("coastline-edit rebuild: %.2f ms (logic+mesh+respace)" % edit_ms)
	lines.append("rock respace only: %.2f ms" % float(terrain.last_rock_rebuild_ms))
	lines.append("")

	var multi: Array[Vector2i] = []
	multi.append_array(large)
	var offsets := [
		Vector2i(28, 0), Vector2i(-30, 4), Vector2i(6, 28), Vector2i(-8, -30),
		Vector2i(26, 22), Vector2i(-26, -24), Vector2i(30, -20),
	]
	for off in offsets:
		for cell in _rect(off.x, off.x + 5, off.y, off.y + 4):
			multi.append(cell)
	print("rockkit_bench: multi island")
	t0 = Time.get_ticks_usec()
	terrain.configure(multi)
	var multi_build_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	print("rockkit_bench: multi build %.1f ms" % multi_build_ms)
	await _settle(2)
	terrain.flush_bakes()
	var far := Vector3(80, 12, 80)
	if terrain.has_method("refresh_lod"):
		terrain.refresh_lod(far)
	await _settle(4)
	var multi_stats: Dictionary = terrain.rock_stats()
	multi_stats["build_ms"] = multi_build_ms
	lines.append(_block("4x island + 7 satellites (%d cells, %d islands)" % [multi.size(), int(multi_stats.get("islands", 0))], multi_stats, await _frame_sample(24)))

	var near := Vector3(0, 8, 10)
	if terrain.has_method("refresh_lod"):
		terrain.refresh_lod(near)
	await _settle(4)
	var near_stats: Dictionary = terrain.rock_stats()
	lines.append(_block("same 8 islands, camera near the main island", near_stats, await _frame_sample(24)))

	DirAccess.make_dir_recursive_absolute("res://art/review/island_style/2026-10-02")
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	var text := "\n".join(lines) + "\n"
	if file:
		file.store_string(text)
		file.close()
	print(text)
	terrain.queue_free()
	quit(0)


func _block(title: String, stats: Dictionary, frames: Dictionary) -> String:
	return "\n".join([
		"=== %s ===" % title,
		"islands=%s  pieces=%s  triangles=%s  rock_draw_calls=%s" % [
			stats.get("islands", 0), stats.get("pieces", 0),
			stats.get("triangles", 0), stats.get("draw_calls", 0),
		],
		"build_ms=%s  last_rock_rebuild_ms=%s  bake_ms=%s  hitch_ms=%s  baked_islands=%s" % [
			stats.get("build_ms", "-"), stats.get("rebuild_ms", 0),
			stats.get("bake_ms", "-"), stats.get("hitch_ms", "-"),
			stats.get("baked_islands", 0),
		],
		"process_ms avg/max=%.2f/%.2f  physics_ms avg/max=%.2f/%.2f  fps_est=%.1f" % [
			frames["process_avg"], frames["process_max"],
			frames["render_avg"], frames["render_max"],
			frames["fps"],
		],
		"perf_draw_calls=%.0f  primitives=%.0f" % [
			frames["draw_calls"], frames["primitives"],
		],
		"",
	])


func _frame_sample(n: int) -> Dictionary:
	var process_sum := 0.0
	var process_max := 0.0
	var render_sum := 0.0
	var render_max := 0.0
	var draws := 0.0
	var prims := 0.0
	for i in n:
		await process_frame
		var p := 1000.0 * float(Performance.get_monitor(Performance.TIME_PROCESS))
		var r := 1000.0 * float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		process_sum += p
		process_max = maxf(process_max, p)
		render_sum += r
		render_max = maxf(render_max, r)
		draws += float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims += float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var avg_p := process_sum / float(n)
	return {
		"process_avg": avg_p,
		"process_max": process_max,
		"render_avg": render_sum / float(n),
		"render_max": render_max,
		"fps": 1000.0 / maxf(avg_p, 0.01),
		"draw_calls": draws / float(n),
		"primitives": prims / float(n),
	}


func _rect(x0: int, x1: int, z0: int, z1: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(x0, x1):
		for z in range(z0, z1):
			cells.append(Vector2i(x, z))
	return cells


func _settle(n: int) -> void:
	for i in n:
		await process_frame


func _renderer() -> String:
	var info := RenderingServer.get_video_adapter_name()
	return info if info != "" else "unknown"
