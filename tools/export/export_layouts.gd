extends SceneTree
## Writes the cells of the four review layouts for the runtime's studies.
## Pure data, so it runs headless:
##   godot --headless --path . --script tools/export/export_layouts.gd -- --out=runtime/data/reference
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
## [seed, terrain preset], the layouts every lookdev round has been reviewed on.
const LAYOUTS: Array = [[7301, 0], [2104, 0], [4242, 1], [913, 2]]

func _initialize() -> void:
	var out: String = "runtime/data/reference"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var directory: String = out if out.is_absolute_path() else ProjectSettings.globalize_path("res://" + out)
	DirAccess.make_dir_recursive_absolute(directory)
	for layout: Array in LAYOUTS:
		var data: RefCounted = Data.new()
		data.make_preset(int(layout[1]))
		data.seed = int(layout[0])
		var payload: Dictionary = data.serialize()
		payload["preset"] = int(layout[1])
		var path: String = directory.path_join("layout_%d_%d.json" % [int(layout[0]), int(layout[1])])
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write " + path)
			quit(1)
			return
		file.store_string(JSON.stringify(payload, "", true, true))
		file.close()
		print("LAYOUT ", path, " cells=", (payload.cells as Array).size())
	quit(0)
