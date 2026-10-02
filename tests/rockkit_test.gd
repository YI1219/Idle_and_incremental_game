extends SceneTree

const IslandGeometry := preload("res://scripts/world/island_geometry.gd")
const RockUnderside := preload("res://scripts/world/rock_underside.gd")
const RockKit := preload("res://scripts/world/rock_kit.gd")
const RockBaker := preload("res://scripts/world/rock_baker.gd")
const RiverTerrain := preload("res://scripts/world/river_terrain.gd")

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	RockKit.ensure()
	check(RockKit.names.size() >= 8, "kit loaded at least eight pieces")
	_deterministic()
	_no_float_after_shrink()
	_bake_clip()
	await _incremental()
	print("ROCK KIT CHECKS: %d/%d passed, failures=%d" % [checks - failures, checks, failures])
	quit(1 if failures else 0)


func _rect(w: int, h: int) -> Dictionary:
	var cells: Dictionary = {}
	for x in w:
		for z in h:
			cells[Vector2i(x, z)] = true
	return cells


func _deterministic() -> void:
	var cells := _rect(6, 5)
	var outline: PackedVector2Array = IslandGeometry.build_island(cells, [], true)["outline"]
	var a: Dictionary = RockUnderside.assemble(outline, 7)
	var b: Dictionary = RockUnderside.assemble(outline, 7)
	check(int(a["piece_count"]) > 8, "seeded island places a ring of rocks")
	check(int(a["piece_count"]) == int(b["piece_count"]), "same seed keeps piece count")
	var same := true
	for i in a["slots"].size():
		var pa: Transform3D = a["slots"][i]["xf"]
		var pb: Transform3D = b["slots"][i]["xf"]
		if not pa.origin.is_equal_approx(pb.origin) or String(a["slots"][i]["piece"]) != String(b["slots"][i]["piece"]):
			same = false
			break
	check(same, "same seed reproduces piece identity and position")
	var other: Dictionary = RockUnderside.assemble(outline, 23)
	check(int(other["piece_count"]) > 0, "a second seed still places rocks")
	var last := ""
	var adjacent_ok := true
	for slot in a["slots"]:
		if int(slot["ring"]) != 0:
			continue
		var name := String(slot["piece"])
		if last != "" and name == last:
			adjacent_ok = false
		last = name
	check(adjacent_ok, "shore ring does not place the same piece twice in a row")


func _no_float_after_shrink() -> void:
	var big := _rect(8, 7)
	var small := _rect(4, 3)
	var big_built: Dictionary = IslandGeometry.build_island(big, [], true)
	var small_built: Dictionary = IslandGeometry.build_island(small, [], true)
	var first: Dictionary = RockUnderside.assemble(big_built["outline"], 11)
	var after: Dictionary = RockUnderside.respace(first, small_built["outline"], 11, false)
	check(not RockUnderside.any_floating(after, small_built["outline"]), "shrinking the coast leaves no floating pieces")
	check(int(after["piece_count"]) < int(first["piece_count"]), "smaller coast uses fewer pieces")
	check(int(after["piece_count"]) >= 3, "shrunk island still has shore rocks")


func _bake_clip() -> void:
	var cells := _rect(6, 5)
	var outline: PackedVector2Array = IslandGeometry.build_island(cells, [], true)["outline"]
	var state: Dictionary = RockUnderside.assemble(outline, 7)
	var poked := false
	for slot in state["slots"]:
		if int(slot.get("ring", 0)) != 0:
			continue
		var xf: Transform3D = slot["xf"]
		var info: Dictionary = RockKit.piece(String(slot["piece"]))
		var mesh: ArrayMesh = info.get("mesh")
		if mesh == null:
			continue
		for v in mesh.get_faces():
			if (xf * v).y > 0.08:
				poked = true
				break
		if poked:
			break
	check(poked, "shore rocks poke above the grass plane before the clip")
	var baked: Dictionary = RockBaker.bake(state)
	check(bool(baked.get("ok", false)), "bake succeeds for a seeded island")
	check(float(baked.get("max_y", 1.0)) <= 0.03, "no baked rock geometry sits above ground height")
	check(RockBaker.max_y(baked) <= 0.03, "baker max_y agrees no geometry is above ground")
	check(RockBaker.is_valid_union(baked), "baked union is closed except the grass cut")
	var report: Dictionary = RockBaker.boundary_report(baked)
	check(int(report.get("odd_not_ground", 1)) == 0, "boundary edges sit only on the grass cut")
	check(int(baked.get("triangles", 0)) > 12, "bake keeps an outer shell")
	check(int(baked.get("triangles", 0)) < RockUnderside.triangle_count(state), "union drops stacked interior faces")
	check(int(baked.get("chunks", 0)) >= 1, "bake reports island sectors")
	check(not RockBaker.is_valid_union(_open_box_result()), "validation rejects a mesh with a side hole")


func _incremental() -> void:
	var terrain: Node3D = RiverTerrain.new()
	root.add_child(terrain)
	var cells: Array[Vector2i] = []
	for x in 4:
		for z in 3:
			cells.append(Vector2i(x, z))
	terrain.configure(cells)
	await process_frame
	terrain.flush_bakes()
	var first: Dictionary = terrain.island_cache.values()[0]
	var seed := int(first.get("rock_seed", 0))
	var count := int(first.get("rocks", {}).get("piece_count", 0))
	terrain.land_cells[Vector2i(4, 1)] = true
	terrain.rebuild()
	var second: Dictionary = terrain.island_cache.values()[0]
	check(int(second.get("rock_seed", -1)) == seed, "growing the same island keeps its seed")
	check(int(second.get("rocks", {}).get("piece_count", 0)) >= count, "growth adds or keeps slots instead of reshuffling from scratch")
	var kept := 0
	var old_keys: Dictionary = {}
	for slot in first["rocks"]["slots"]:
		old_keys[int(slot["ring"]) * 10007 + int(slot["slot"])] = String(slot["piece"])
	for slot in second["rocks"]["slots"]:
		var key := int(slot["ring"]) * 10007 + int(slot["slot"])
		if old_keys.get(key, "") == String(slot["piece"]):
			kept += 1
	check(kept >= 3, "incremental respace keeps existing slot pieces")
	terrain.queue_free()


func _open_box_result() -> Dictionary:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var faces := [
		[Vector3(0, -1, 0), Vector3(1, -1, 0), Vector3(1, -1, 1)],
		[Vector3(0, -1, 0), Vector3(1, -1, 1), Vector3(0, -1, 1)],
		[Vector3(0, -1, 0), Vector3(0, -2, 0), Vector3(1, -2, 0)],
		[Vector3(0, -1, 0), Vector3(1, -2, 0), Vector3(1, -1, 0)],
		[Vector3(1, -1, 0), Vector3(1, -2, 0), Vector3(1, -2, 1)],
		[Vector3(1, -1, 0), Vector3(1, -2, 1), Vector3(1, -1, 1)],
	]
	for face in faces:
		var a: Vector3 = face[0]
		var b: Vector3 = face[1]
		var c: Vector3 = face[2]
		var n := (b - a).cross(c - a).normalized()
		for p in [a, b, c]:
			verts.append(p)
			norms.append(n)
			cols.append(Color(0.5, 0.0, 0.0))
	return {
		"ok": true,
		"vertices": verts,
		"normals": norms,
		"colors": cols,
		"triangles": int(verts.size() / 3),
		"max_y": 0.0,
	}
