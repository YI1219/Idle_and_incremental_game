extends "res://art/lookdev/20261110_interaction_water/checks/capture_flow.gd"
func _capture(label:String,time_progress:float)->void:
	if label=="game":await super._capture(label,time_progress)
