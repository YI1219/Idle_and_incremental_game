extends SceneTree
## Headless: what one background water cycle costs and how often it runs.
## Usage: godot --headless --path . --script <this> -- [--seconds=8]
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var seconds: float = 8.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
	var editor: Node3D = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	for index: int in 30:
		await process_frame
	var water: Node3D = editor.water_view
	var start: int = Time.get_ticks_usec()
	var cycles: int = 0
	var last_sim: float = water.simulated_seconds
	var sums: Dictionary = {"solver": 0.0, "mesh": 0.0, "images": 0.0, "worker": 0.0}
	var frames: int = 0
	var unchanged: int = 0
	while Time.get_ticks_usec() - start < int(seconds * 1000000.0):
		await process_frame
		frames += 1
		if water.simulated_seconds != last_sim:
			last_sim = water.simulated_seconds
			cycles += 1
			var stages: Dictionary = water.last_advance_stages
			sums.solver += float(stages.get("solver", 0.0))
			sums.mesh += float(stages.get("mesh", 0.0))
			sums.images += float(stages.get("images", 0.0))
			sums.worker += float(water.last_advance_worker_ms)
			if float(stages.get("mesh", 0.0)) == 0.0 and float(stages.get("images", 0.0)) == 0.0:
				unchanged += 1
	var elapsed: float = (Time.get_ticks_usec() - start) / 1000000.0
	print("WATER elapsed %.1f s frames %d cycles %d (%.1f per second) unchanged %d" % [elapsed, frames, cycles, cycles / elapsed, unchanged])
	if cycles > 0:
		print("WATER per cycle: worker %.2f ms = solver %.2f + mesh %.2f + images %.2f" % [sums.worker / cycles, sums.solver / cycles, sums.mesh / cycles, sums.images / cycles])
		print("WATER worker time per wall second: %.1f ms (%.1f%% of one core)" % [sums.worker / elapsed, sums.worker / elapsed / 10.0])
	print("WATER volume %.3f discharged %.3f simulated %.2f s" % [water.published_volume, water.flow.discharged_volume, water.simulated_seconds])
	editor.free()
	quit()
