extends "res://art/lookdev/20261114_courtyard_composition/checks/capture.gd"

func _source_hashes() -> Dictionary:
	var hashes: Dictionary = super._source_hashes()
	hashes["res://art/lookdev/20261114_cliff_optimization/checks/capture.gd"] = FileAccess.get_sha256("res://art/lookdev/20261114_cliff_optimization/checks/capture.gd")
	return hashes

func _capture(label: String, time_progress: float) -> void:
	await super._capture(label, time_progress)
	if label == "close":
		_frame(Vector2(-3.0, -2.0), 12.5, 28.0, 26.0)
		await super._capture("terrace_close", time_progress)
		_frame(Vector2(3.0, 4.0), 13.5, 344.0, 18.0)
		await super._capture("outer_hull", time_progress)
