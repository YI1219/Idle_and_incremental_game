extends "res://scripts/terrain_editor/editor.gd"
var process_costs: Array[float] = []
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	super._process(delta)
	process_costs.append(float(Time.get_ticks_usec()-started)/1000.0)
	if process_costs.size()>200:process_costs.pop_front()
