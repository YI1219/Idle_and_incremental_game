extends "res://tools/art/capture_lookdev.gd"
func _capture(label: String, time_progress: float) -> void:
	if label != "cliff_close":
		return
	var sun: DirectionalLight3D = editor.get_node("SunLight")
	sun.shadow_bias = .10
	for normal_bias: float in [.70, 1.0, 1.5, 2.0, 3.0]:
		sun.shadow_normal_bias = normal_bias
		await super._capture("normal_%03d" % roundi(normal_bias * 100.0), time_progress)
