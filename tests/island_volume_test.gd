extends SceneTree

const IslandGeometry := preload("res://scripts/world/island_geometry.gd")
const IslandHeightfield := preload("res://scripts/world/island_heightfield.gd")
const Heightfield := preload("res://scripts/world/heightfield.gd")
const HeightfieldMesh := preload("res://scripts/world/heightfield_mesh.gd")
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
	var field: Heightfield = Heightfield.from_play_cells(rect, 0.5, -4.0, 7, 1)
	check(field.land_cell_count() >= 4 * 3 * 4, "play cells expand to a 0.5 m height mask")
	check(is_equal_approx(field.total_volume(), 48.0), "starter 4x3x4 m island is 48 m3")
	var payload: Dictionary = HeightfieldMesh.build_chunk(field, Vector2i(0, 0), "full")
	check(int(payload.get("triangles", 0)) > 20, "heightfield emits a closed body")
	check(HeightfieldMesh.lowest_y(payload) < -3.5, "flat bottom hangs at y_bottom")
	check(HeightfieldMesh.is_closed(payload), "island body is a closed mesh")
	var two: Dictionary = {}
	for cell in [Vector2i(0, 0), Vector2i(8, 8)]:
		two[cell] = true
	check(IslandGeometry.components(two).size() == 2, "disconnected cells are separate islands")
	check(IslandGeometry.component_size_after_add([Vector2i(0, 0)], Vector2i(1, 0)) == 2, "adding an edge cell joins the island")
	check(IslandGeometry.component_size_after_add([Vector2i(0, 0)], Vector2i(5, 5)) == 1, "far cell starts a new island")
	check(is_equal_approx(IslandGeometry.cell_volume(), 4.0), "cost volume is area times thickness")


func _presence() -> void:
	var node: Node3D = IslandHeightfield.new()
	root.add_child(node)
	var cells: Dictionary = {}
	for x in 3:
		for z in 3:
			cells[Vector2i(x, z)] = true
	var field: Heightfield = Heightfield.from_play_cells(cells, 0.5, -4.0, 1, 1)
	node.configure(1, Vector3.ZERO, 9, field)
	node.mark_settled(10.0)
	check(is_equal_approx(node.settle(16.0), 6.0), "revisit settles by elapsed minutes")
	check(node.update_lod(Vector3(50, 4, 0)), "far camera switches LOD")
	check(node.far, "far flag latches past the enter distance")
	check(node.process_mode == Node.PROCESS_MODE_DISABLED, "far island pauses processing")
	check(not node.update_lod(Vector3(50, 4, 0)), "unchanged LOD does not rebuild")
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
	terrain.flush_rebuild()
	var presence: Node3D = terrain.get_node("Islands").get_child(0)
	check(presence.field != null, "island owns a heightfield")
	check(presence.field.total_volume() > 20.0, "heightfield volume is the hanging body")
	var mesh: ArrayMesh = presence.current_volume()
	check(mesh != null and mesh.get_surface_count() > 0, "island mesh is present")
	check(IslandGeometry.lowest_y(mesh) < -3.5, "heightfield underside reaches the flat bottom")
	terrain.land_cells[Vector2i(12, 12)] = true
	terrain.rebuild()
	check(terrain.island_count() == 2, "a distant cell is a second island")
	check(terrain.island_rebuilds == 1, "only the changed island rebuilds")
	var dirty_rebuilds: int = terrain.island_rebuilds
	terrain.rebuild()
	check(terrain.island_rebuilds == 0 and terrain.island_count() == 2, "unchanged land skips mesh rebuild")
	check(first_rebuilds >= 1 and dirty_rebuilds == 1, "rebuild counters distinguish dirty and clean passes")
	terrain.queue_free()
