extends SceneTree

const IslandGeometry := preload("res://scripts/world/island_geometry.gd")
const RockUnderside := preload("res://scripts/world/rock_underside.gd")
const RockKit := preload("res://scripts/world/rock_kit.gd")
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


func _incremental() -> void:
	var terrain: Node3D = RiverTerrain.new()
	root.add_child(terrain)
	var cells: Array[Vector2i] = []
	for x in 4:
		for z in 3:
			cells.append(Vector2i(x, z))
	terrain.configure(cells)
	await process_frame
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
