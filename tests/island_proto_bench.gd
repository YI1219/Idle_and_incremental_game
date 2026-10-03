extends SceneTree
## Headless timings for the island prototype. VM numbers, not target hardware.

const OUT := "res://art/review/island_proto/2026-10-02/bench.txt"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var scene: Node3D = load("res://scenes/proto/island_proto.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var full: float = scene.rebuild_full(true)
	var box: AABB = scene.bounds()
	var center := box.get_center()
	var stroke: float = scene.stroke("raise", Vector3(center.x, 0.0, center.z), 2.2, 0.35)
	var dress: float = scene.flush_dress()
	var stroke2: float = scene.stroke("lower", Vector3(center.x + 1.4, 0.0, center.z - 0.6), 1.6, 0.5)
	var dress2: float = scene.flush_dress()
	var rim := Vector3(center.x, 0.0, box.position.z + 0.55)
	var stroke_rim: float = scene.stroke("raise", rim, 1.8, 0.4)
	var dress_rim: float = scene.flush_dress()
	var cells_before: int = scene.field.land_cell_count()
	# On the south lip, inside the allocated grid.
	var lip := Vector3(center.x, 0.0, box.position.z + 0.9)
	var stroke_add: float = scene.stroke("add_land", lip, 1.45, 0.7)
	var dress_add: float = scene.flush_dress()
	var cells_mid: int = scene.field.land_cell_count()
	# Same kind of stroke pushed past the allocated edge, so the field resizes.
	var lip_out := Vector3(center.x + 1.2, 0.0, box.position.z - 0.4)
	var stroke_grow: float = scene.stroke("add_land", lip_out, 2.0, 0.5)
	var dress_grow: float = scene.flush_dress()
	var cells_after: int = scene.field.land_cell_count()
	var row: Dictionary = scene.stats()
	var lines := PackedStringArray()
	lines.append("Island prototype bench")
	lines.append("Godot %s" % Engine.get_version_info().get("string", "?"))
	lines.append("Development VM sample. Not a Windows laptop or MacBook Air result.")
	lines.append("full_rebuild_ms %.2f" % full)
	lines.append("stroke_raise_ms %.2f  dress_ms %.2f" % [stroke, dress])
	lines.append("stroke_lower_ms %.2f  dress_ms %.2f" % [stroke2, dress2])
	lines.append("stroke_rim_ms %.2f  dress_ms %.2f" % [stroke_rim, dress_rim])
	lines.append("stroke_add_land_ms %.2f  dress_ms %.2f  cells %d -> %d" % [stroke_add, dress_add, cells_before, cells_mid])
	lines.append("stroke_add_land_resize_ms %.2f  dress_ms %.2f  cells %d -> %d" % [stroke_grow, dress_grow, cells_mid, cells_after])
	lines.append("land_cells %d  chunks %d" % [int(row["land_cells"]), int(row["chunks"])])
	lines.append("tris top %d  core %d  rocks %d  total %d" % [int(row["top_tris"]), int(row["core_tris"]), int(row["rock_tris"]), int(row["triangles"])])
	lines.append("rocks %d  draws %d  loops %d" % [int(row["rocks"]), int(row["draw_calls"]), scene._loops.size()])
	lines.append("bounds %s" % box)
	var text := "\n".join(lines)
	print(text)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).get_base_dir())
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f:
		f.store_string(text + "\n")
	var bad := 0
	if int(row["top_tris"]) < 100:
		bad += 1
		print("FAIL top mesh is empty")
	if int(row["rocks"]) < 8 or int(row["rock_tris"]) < 100:
		bad += 1
		print("FAIL too few rocks")
	for loop in scene._loops:
		var pts: PackedVector2Array = loop["pts"]
		print("loop hole=%s pts=%d" % [bool(loop["hole"]), pts.size()])
	if int(row["core_tris"]) < 20:
		bad += 1
		print("FAIL core mesh is empty")
	if cells_mid <= cells_before or cells_after <= cells_mid:
		bad += 1
		print("FAIL add_land did not grow the mask")
	if int(row["rock_tris"]) > 40000:
		bad += 1
		print("FAIL rock tris %d" % int(row["rock_tris"]))
	if int(row["draw_calls"]) > 12:
		bad += 1
		print("FAIL draw calls %d" % int(row["draw_calls"]))
	print("PROTO_BENCH failures=%d" % bad)
	quit(bad)
