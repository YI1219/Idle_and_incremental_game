extends SceneTree
## Headless diagnostic: writes the cliff layout in plan (every column slab,
## shoulder mass and land contour) as JSON, so the arrangement of the rim can be
## drawn and measured without rendering.
## Usage: godot --headless --path . --script <this> -- --out=/abs/file.json [--seed=N --preset=K]
func _initialize() -> void:
	call_deferred("run")

func _v2(p: Vector2) -> Array:
	return [snappedf(p.x, .001), snappedf(p.y, .001)]

func run() -> void:
	var seed_arg: int = 7301
	var preset_arg: int = 0
	var out_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_arg = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--preset="):
			preset_arg = int(arg.trim_prefix("--preset="))
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
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
	var field: RefCounted = deco._column_field
	var columns: Array = []
	for column: Dictionary in deco._columns:
		var pose: Transform3D = column.pose
		var part: Dictionary = deco.assets[column.kind][0]
		var box: AABB = (part.mesh as Mesh).get_aabb()
		var cap: Array = []
		for p: Vector2 in part.get("cap_polygon", PackedVector2Array()):
			var q: Vector3 = pose * Vector3(p.x, 0.0, p.y)
			cap.append(_v2(Vector2(q.x, q.z)))
		# Front face sampled a little under the collar: both ends and the middle.
		var face: Array = []
		for x: float in [-.49, 0.0, .49]:
			var z: float = lerpf(.446, .406, pow(absf(x) / .51, 1.85))
			var q: Vector3 = pose * Vector3(x, -.30, z)
			face.append(_v2(Vector2(q.x, q.z)))
		columns.append({
			"kind": String(column.kind), "step": bool(column.is_step),
			"edge": _v2(column.edge), "out": _v2(Vector2(column.outward.x, column.outward.z)),
			"tan": _v2(Vector2(column.tangent.x, column.tangent.z)),
			"top": pose.origin.y, "w": pose.basis.x.length() * box.size.x,
			"d": pose.basis.z.length() * box.size.z, "h": pose.basis.y.length() * box.size.y,
			"cap": cap, "face": face, "role": String(column.get("role", "")),
			"narrow": float(column.get("narrow_run", 0.0)), "land_span": float(column.get("land_span", 0.0)),
		})
	var masses: Array = []
	for mass: Dictionary in deco._mass:
		var pose: Transform3D = mass.pose
		var part: Dictionary = deco.assets[mass.kind][0]
		var box: AABB = (part.mesh as Mesh).get_aabb()
		var corners: Array = []
		for c: Vector2 in [Vector2(box.position.x, box.position.z), Vector2(box.end.x, box.position.z), Vector2(box.end.x, box.end.z), Vector2(box.position.x, box.end.z)]:
			var q: Vector3 = pose * Vector3(c.x, box.end.y, c.y)
			corners.append(_v2(Vector2(q.x, q.z)))
		masses.append({
			"kind": String(mass.kind), "interior": bool(mass.get("is_interior", false)),
			"top": pose.origin.y, "h": pose.basis.y.length() * box.size.y, "corners": corners,
			"host": _v2(mass.get("host_edge", Vector2.ZERO)),
		})
	var loops: Array = []
	for h: float in field.land_regions:
		for loop: PackedVector2Array in field.land_regions[h]:
			var pts: Array = []
			for p: Vector2 in loop:
				pts.append(_v2(p))
			loops.append({"h": h, "pts": pts})
	var rim: Array = []
	for h: float in field.rim_regions:
		for loop: PackedVector2Array in field.rim_regions[h]:
			var pts: Array = []
			for p: Vector2 in loop:
				pts.append(_v2(p))
			rim.append({"h": h, "pts": pts})
	var result: Dictionary = {"seed": seed_arg, "preset": preset_arg, "columns": columns, "masses": masses, "land": loops, "rim": rim}
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(result))
		file.close()
	print("PLAN columns=%d masses=%d out=%s" % [columns.size(), masses.size(), out_path])
	editor.free()
	quit()
