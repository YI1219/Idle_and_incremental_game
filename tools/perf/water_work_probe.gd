extends SceneTree
## Deterministic CPU work, no rendering, same water steps in both variants.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Renderer = preload("res://scripts/terrain_editor/terrain_renderer.gd")
var output: String = "/tmp/water_work.json"
func _initialize() -> void: call_deferred("run")
func mean(values: Array[float]) -> float:
	var total: float = 0
	for value: float in values: total += value
	return total / maxf(1, values.size())
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	var rows: Array[Dictionary] = []
	for preset: int in [0, 1, 2]:
		var data: RefCounted = Data.new(); data.make_preset(preset)
		var terrain: Node3D = Renderer.new(); root.add_child(terrain); terrain.configure(data)
		var water: Node3D = load("res://scripts/terrain_editor/water_renderer.gd").new()
		terrain.add_child(water); water.configure(data, terrain)
		var worker: Array[float] = []; var publish: Array[float] = []; var stages: Dictionary = {}
		var start: int = Time.get_ticks_usec()
		for step: int in 100:
			water.tick(.1); water.flush()
			worker.append(water.last_worker_ms); publish.append(water.last_publish_ms)
			for key: String in water.last_worker_stages:
				stages[key] = float(stages.get(key,0.0)) + float(water.last_worker_stages[key]) / 100.0
		rows.append({"preset":preset,"total_ms":(Time.get_ticks_usec()-start)/1000.0,"worker_mean_ms":mean(worker),"publish_mean_ms":mean(publish),"stages_mean_ms":stages,"volume":water.published_volume,"discharged":water.published_discharged_volume,"publications":water.publication_revision,"simulated_seconds":water.simulated_seconds})
		terrain.free()
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	print(JSON.stringify(rows)); quit()
