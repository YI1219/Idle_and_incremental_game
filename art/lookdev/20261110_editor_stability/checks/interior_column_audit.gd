extends "res://tests/interior_terrain_edit_test.gd"
const OUT := "res://art/lookdev/20261110_editor_stability/checks"

func run() -> void:
	var original_script := GDScript.new()
	original_script.source_code = FileAccess.get_file_as_string(OUT.path_join("source_before/interior_crack_fix/terrain_decoration.gd")).replace("class_name TerrainDecoration\n", "")
	if original_script.reload() != OK:
		quit(1)
		return
	var original: RefCounted = original_script.new()
	original.load_assets()
	var current := Decoration.new()
	current.assets = original.assets
	var records: Array = []
	for seed_value: int in [7301, 2104, 4242]:
		var data := Data.new()
		data.seed = seed_value
		data.make_preset(0)
		var old_field := Field.new()
		old_field.refresh(data)
		original._column_layout(old_field, data.seed)
		var before := column_poses(original)
		var exterior := column_poses(original, true)
		var new_field := Field.new()
		new_field.refresh(data)
		current._column_layout(new_field, data.seed)
		var after := column_poses(current)
		var removed: Array = []
		for anchor: Vector3 in before:
			if not after.has(anchor): removed.append(str(anchor))
		var entry: Dictionary = {"seed": seed_value, "before": before.size(), "after": after.size(), "removed": removed, "exterior_unchanged": exterior == column_poses(current, true)}
		print(entry)
		records.append(entry)
	FileAccess.open(OUT.path_join("interior_column_audit.json"), FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
	quit()
