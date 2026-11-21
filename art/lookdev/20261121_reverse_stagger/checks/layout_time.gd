extends SceneTree
## Headless: cold cliff layout time for the default island, five fresh builds.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration = preload("res://scripts/terrain_editor/terrain_decoration.gd")
func _initialize() -> void:
	var times: Array[float] = []
	for round_index: int in 6:
		var data := Data.new()
		data.seed = 7301
		data.make_preset(0)
		var field := Contours.new()
		field.refresh(data)
		var decoration := Decoration.new()
		decoration.load_assets()
		decoration._column_layout(field, data.seed)
		if round_index > 0:
			times.append(decoration.layout_ms)
		if round_index == 5:
			print("STAGES ", decoration.layout_stages)
	times.sort()
	print("LAYOUT_MS min=%.1f median=%.1f max=%.1f columns" % [times[0], times[2], times[4]])
	quit()
