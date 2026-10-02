extends SceneTree

const IslandGeometry := preload("res://scripts/world/island_geometry.gd")
const IslandPresence := preload("res://scripts/world/island_presence.gd")
const RiverTerrain := preload("res://scripts/world/river_terrain.gd")
const RockUnderside := preload("res://scripts/world/rock_underside.gd")
const RockBaker := preload("res://scripts/world/rock_baker.gd")

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
	_geometry()
	_presence()
	await _terrain_islands()
	print("ISLAND VOLUME CHECKS: %d/%d passed, failures=%d" % [checks - failures, checks, failures])
	quit(1 if failures else 0)


func _geometry() -> void:
	var rect: Dictionary = {}
	for x in range(0, 4):
		for z in range(0, 3):
			rect[Vector2i(x, z)] = true
	var built: Dictionary = IslandGeometry.build_island(rect, [], true)
	check(built.outline.size() > 8, "smoothed coastline has more than the raw rectangle corners")
	check(not IslandGeometry.has_rectangular_top(built.top), "top outline is not a raw rectangle")
	var rocks: Dictionary = RockUnderside.assemble(built.outline, 7)
	var baked: Dictionary = RockBaker.bake(rocks)
	check(int(rocks.piece_count) > 8, "rock kit hangs under the top")
	check(bool(baked.get("ok", false)), "underside bake produces a mesh")
	check(float(baked.get("max_y", 1.0)) <= 0.03, "baked rock stays at or below the grass plane")
	check(RockBaker.is_valid_union(baked), "baked underside is manifold except the grass cut")
	check(int(RockBaker.boundary_report(baked).get("odd_not_ground", 1)) == 0, "baked underside has no side holes")
	check(IslandGeometry.lowest_y(RockBaker.make_mesh(baked)) < -1.6, "baked volume hangs below the slab")
	var two: Dictionary = {}
	for cell in [Vector2i(0, 0), Vector2i(8, 8)]:
		two[cell] = true
	check(IslandGeometry.components(two).size() == 2, "disconnected cells are separate islands")
	check(IslandGeometry.component_size_after_add([Vector2i(0, 0)], Vector2i(1, 0)) == 2, "adding an edge cell joins the island")
	check(IslandGeometry.component_size_after_add([Vector2i(0, 0)], Vector2i(5, 5)) == 1, "far cell starts a new island")
	check(is_equal_approx(IslandGeometry.cell_volume(), 4.0), "cost volume is area times thickness")


func _presence() -> void:
	var node: Node3D = IslandPresence.new()
	root.add_child(node)
	var dummy := ArrayMesh.new()
	node.configure(1, Vector3.ZERO, 4, dummy, dummy)
	node.mark_settled(10.0)
	check(is_equal_approx(node.settle(16.0), 6.0), "revisit settles by elapsed minutes")
	check(node.update_lod(Vector3(40, 4, 0)), "far camera switches LOD")
	check(node.far, "far flag latches past the enter distance")
	check(node.process_mode == Node.PROCESS_MODE_DISABLED, "far island pauses processing")
	check(not node.update_lod(Vector3(40, 4, 0)), "unchanged LOD does not rebuild")
	node.set_active(false)
	check(node.process_mode == Node.PROCESS_MODE_DISABLED, "inactive island pauses processing")
	node.free()


func _terrain_islands() -> void:
	var terrain: Node3D = RiverTerrain.new()
	root.add_child(terrain)
	var cells: Array[Vector2i] = []
	for x in range(0, 3):
		for z in range(0, 3):
			cells.append(Vector2i(x, z))
	terrain.configure(cells)
	await process_frame
	var first_rebuilds: int = terrain.island_rebuilds
	check(terrain.island_count() == 1, "starter block is one island")
	terrain.flush_bakes()
	var presence: Node3D = terrain.get_node("Islands").get_child(0)
	if bool(presence.get("baked")):
		check(RockBaker.is_valid_union(presence.bake_result), "swapped bake passed union validation")
		check(IslandGeometry.lowest_y(presence.current_volume()) < -1.6, "baked cliff is a hanging volume")
	else:
		check(presence.get_node("RockKit").visible, "invalid bake keeps the MultiMesh assembly")
		check(int(presence.rock_state.get("piece_count", 0)) > 0, "MultiMesh fallback still hangs rocks under the slab")
	terrain.land_cells[Vector2i(12, 12)] = true
	terrain.rebuild()
	check(terrain.island_count() == 2, "a distant cell is a second island")
	check(terrain.island_rebuilds == 1, "only the changed island rebuilds")
	var dirty_rebuilds: int = terrain.island_rebuilds
	terrain.rebuild()
	check(terrain.island_rebuilds == 0 and terrain.island_count() == 2, "unchanged land skips mesh rebuild")
	check(first_rebuilds >= 1 and dirty_rebuilds == 1, "rebuild counters distinguish dirty and clean passes")
	terrain.queue_free()
