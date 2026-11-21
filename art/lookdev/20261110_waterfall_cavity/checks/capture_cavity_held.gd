extends "res://art/lookdev/20261110_waterfall_cavity/checks/capture_cavity.gd"
func _capture(label:String,time_progress:float)->void:
 if label in ['game','reverse']:await super._capture(label,time_progress)
