extends SceneTree
## Headless diagnostic: lists every cliff column and shoulder mass of the
## current layout with its world size, so narrow pieces can be found by number.
## Usage: godot --headless --path . --script <this> -- [--seed=N --preset=K]
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var seed_arg: int = 7301
	var preset_arg: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_arg = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--preset="):
			preset_arg = int(arg.trim_prefix("--preset="))
	var editor: Node3D = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	if preset_arg != 0 or seed_arg != 7301:
		editor.data.seed = seed_arg
		editor.select_preset(preset_arg)
	for index: int in 20:
		await process_frame
	while editor.renderer.has_pending_updates():
		await process_frame
	var deco: RefCounted = editor.renderer.decoration
	var rows: Array[Dictionary] = []
	for column: Dictionary in deco._columns:
		var pose: Transform3D = column.pose
		var part: Dictionary = deco.assets[column.kind][0]
		var box: AABB = (part.mesh as Mesh).get_aabb()
		rows.append({"kind": String(column.kind).trim_prefix("cliff_column") + (" N%.2f" % float(column.get("narrow_run", 0.0)) if float(column.get("narrow_run", 0.0)) > 0.0 else ""), "step": bool(column.is_step), "w": pose.basis.x.length() * box.size.x, "d": pose.basis.z.length() * box.size.z, "h": pose.basis.y.length() * box.size.y, "x": pose.origin.x, "z": pose.origin.z, "top": pose.origin.y})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.w < b.w)
	print("COLUMNS ", rows.size())
	for row: Dictionary in rows:
		print("COL kind=%-9s step=%-5s w=%5.2f d=%5.2f h=%5.2f top=%4.1f at(%6.1f,%6.1f)" % [row.kind, row.step, row.w, row.d, row.h, row.top, row.x, row.z])
	var masses: int = 0
	for mass: Dictionary in deco._mass:
		var pose: Transform3D = mass.pose
		var part: Dictionary = deco.assets[mass.kind][0]
		var box: AABB = (part.mesh as Mesh).get_aabb()
		masses += 1
		print("MASS kind=%-18s interior=%-5s w=%5.2f d=%5.2f h=%5.2f top=%4.1f at(%6.1f,%6.1f)" % [mass.kind, mass.get("is_interior", false), pose.basis.x.length() * box.size.x, pose.basis.z.length() * box.size.z, pose.basis.y.length() * box.size.y, pose.origin.y, pose.origin.x, pose.origin.z])
	print("MASSES ", masses)
	editor.free()
	quit()
