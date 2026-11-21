extends "res://tools/art/capture_lookdev.gd"
func _capture(label: String, time_progress: float) -> void:
	if label == "close":
		await super._capture(label,time_progress)
