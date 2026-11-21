extends SceneTree
## Headless: how long the default ponds keep flowing with no source of water.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Flow = preload("res://scripts/terrain_editor/water_flow.gd")
func _initialize() -> void:
	var data := Data.new()
	data.seed = 7301
	data.make_preset(0)
	var flow := Flow.new()
	flow.configure(data)
	var start_volume: float = flow.total_volume()
	var simulated: float = 0.0
	var last_flow_at: float = 0.0
	var began: int = Time.get_ticks_usec()
	var marks: Array[float] = [10.0, 30.0, 60.0, 120.0, 300.0, 600.0, 900.0]
	while simulated < 900.0 and not flow._sleeping:
		flow.step(0.1)
		simulated += 0.1
		if not flow.last_transfers.is_empty():
			last_flow_at = simulated
		if not marks.is_empty() and simulated >= marks[0]:
			var rate: float = 0.0
			for transfer: Dictionary in flow.last_transfers:
				rate = maxf(rate, float(transfer.rate))
			print("RUNOUT t=%5.0f s volume %.2f of %.2f discharged %.2f transfers %d strongest %.4f/s" % [marks.pop_front(), flow.total_volume(), start_volume, flow.discharged_volume, flow.last_transfers.size(), rate])
	print("RUNOUT end t=%.1f s sleeping=%s last transfer at %.1f s volume %.2f; solver wall time %.1f s (%.2f ms per simulated 0.1 s)" % [simulated, flow._sleeping, last_flow_at, flow.total_volume(), (Time.get_ticks_usec() - began) / 1000000.0, (Time.get_ticks_usec() - began) / 1000.0 / (simulated * 10.0)])
	quit()
