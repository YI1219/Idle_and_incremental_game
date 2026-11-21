extends SceneTree
## Preserve a geometry bug reproducer independently of future art presets.
func _initialize() -> void:
	var source := GDScript.new()
	source.source_code = FileAccess.get_file_as_string("res://art/lookdev/20261114_courtyard_composition/checks/source_before/scripts/terrain_editor/terrain_data.gd").replace("class_name TerrainData\n", "")
	assert(source.reload() == OK)
	var data: RefCounted = source.new()
	data.make_preset(0)
	DirAccess.make_dir_recursive_absolute("res://tests/fixtures")
	var file := FileAccess.open("res://tests/fixtures/partial_crown_terrain.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data.serialize(), "", true, true))
	quit()
