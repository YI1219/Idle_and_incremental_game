extends "res://tools/art/capture_lookdev.gd"

func _capture(label: String, time_progress: float) -> void:
	await super._capture(label, time_progress)
	if label == "reverse":
		_frame(Vector2(-2, -1), 32, 106, 30)
		await super._capture("side_106", time_progress)
		_frame(Vector2(-2, -1), 32, 286, 30)
		await super._capture("side_286", time_progress)
	if label == "cliff_close":
		_frame(Vector2(-8, 6), 13, 16, 24)
		await super._capture("foot_front", time_progress)
		_frame(Vector2(-2, -1), 17, 196, 18)
		await super._capture("foot_reverse", time_progress)
