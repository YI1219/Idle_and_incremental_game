extends SceneTree

func _initialize() -> void:
	var data := preload("res://scripts/terrain_editor/terrain_data.gd").new()
	data.make_preset(0)
	for z: int in range(-13, 12):
		var line: String = "%3d " % z
		for x: int in range(-22, 20):
			var rec: Dictionary = data.cells.get(Vector2i(x, z), {})
			line += " " if rec.is_empty() else ("~" if int(rec.water) >= 0 else str(roundi(float(rec.height))))
		print(line)
	quit()
