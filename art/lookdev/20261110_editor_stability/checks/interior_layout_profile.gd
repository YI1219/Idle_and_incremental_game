extends "res://tests/interior_terrain_edit_test.gd"
const OUT := "res://art/lookdev/20261110_editor_stability/checks"
func run() -> void:
	var original_script := GDScript.new()
	original_script.source_code = FileAccess.get_file_as_string(OUT.path_join("source_before/interior_crack_fix/terrain_decoration.gd")).replace("class_name TerrainDecoration\n", "")
	if original_script.reload() != OK:
		quit(1)
		return
	var loader := Decoration.new()
	loader.load_assets()
	var records: Array = []
	for fixture: String in ["baseline", "upper_four", "lower_four"]:
		var data := Data.new()
		data.make_preset(0)
		if fixture != "baseline":
			for i: int in 4: lower(data, Vector2(-8,-5) if fixture == "upper_four" else Vector2(13,0), 3.8)
		for implementation: String in ["before", "after"]:
			var decoration: RefCounted = original_script.new() if implementation == "before" else Decoration.new()
			decoration.assets = loader.assets
			var field := Field.new()
			for i: int in 3:
				field.refresh(data)
				decoration._column_layout(field, data.seed)
				var item: Dictionary = {"fixture": fixture, "implementation": implementation, "pass": i, "layout_ms": decoration.layout_ms, "stages": decoration.layout_stages.duplicate(), "hits": decoration.layout_hits, "misses": decoration.layout_misses}
				print(item)
				records.append(item)
	FileAccess.open(OUT.path_join("interior_layout_profile.json"), FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
	quit()
