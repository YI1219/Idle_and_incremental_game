extends SceneTree

const Blob47 := preload("res://scripts/world/blob47.gd")
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
	_blob_normalization()
	_corner_rules()
	_matching_edges()
	await _terrain_queries_and_refresh()
	print("TERRAIN CHECKS: %d/%d passed, failures=%d" % [checks - failures, checks, failures])
	quit(1 if failures else 0)


func _blob_normalization() -> void:
	var variants: Dictionary = {}
	for mask in 256:
		var normalized: int = Blob47.normalize(mask)
		variants[normalized] = true
		check(Blob47.normalize(normalized) == normalized, "normalized mask is stable: %d" % mask)
	check(variants.size() == 47, "all 256 masks normalize to exactly 47 variants")


func _corner_rules() -> void:
	check((Blob47.normalize(Blob47.NE) & Blob47.NE) == 0, "NE is removed without cardinals")
	check((Blob47.normalize(Blob47.N | Blob47.E | Blob47.NE) & Blob47.NE) != 0, "NE survives with N and E")
	check((Blob47.normalize(Blob47.N | Blob47.NE) & Blob47.NE) == 0, "NE needs both adjacent cardinals")
	check((Blob47.normalize(Blob47.S | Blob47.W | Blob47.SW) & Blob47.SW) != 0, "SW survives with S and W")


func _matching_edges() -> void:
	for mask in 256:
		var a: int = Blob47.normalize(mask | Blob47.E)
		var mirrored: int = Blob47.mirror_x(a)
		check((a & Blob47.E) != 0 and (mirrored & Blob47.W) != 0, "east/west edge mirrors: %d" % mask)
		check(Blob47.mirror_x(mirrored) == a, "horizontal mirror is reversible: %d" % mask)


func _terrain_queries_and_refresh() -> void:
	var terrain: Node3D = RiverTerrain.new()
	root.add_child(terrain)
	var cells: Array[Vector2i] = []
	for x in range(-6, 7):
		for z in range(-6, 4):
			cells.append(Vector2i(x, z))
	terrain.configure(cells)
	await process_frame
	check(terrain.water_cells.size() > 0, "configured island receives eastern river")
	var water_cell: Vector2i = terrain.water_cells.keys()[0]
	check(not terrain.is_walkable(Vector3(water_cell.x + 0.5, 0, water_cell.y + 0.5)), "water blocks walking")
	check(terrain.is_walkable(Vector3(4.5, 0, 1.5)), "bridge allows crossing the river")
	check(terrain.is_walkable(Vector3(6.05, 0, 1.5)), "bridge reaches a dry eastern bank")
	check(terrain.is_walkable(Vector3(6.24, 0, 1.31)), "bridge leaves clearance for a radius .2 body")
	var bridge_faces: PackedVector3Array = terrain.get_node("RiverBridge").mesh.get_faces()
	var bridge_min_y := INF
	var bridge_max_y := -INF
	for vertex in bridge_faces:
		bridge_min_y = minf(bridge_min_y, vertex.y)
		bridge_max_y = maxf(bridge_max_y, vertex.y)
	check(absf(bridge_max_y - .006) < .0001, "bridge surface stays at foot plane with only a tiny groove line")
	check(bridge_min_y < -.1, "bridge beams remain below the walking plane")
	check(not terrain.is_walkable(Vector3(20, 0, 20)), "missing land blocks walking")
	check(terrain.is_walkable(Vector3(-1.5, 0, 2.5)), "ordinary configured land is walkable")
	check(terrain.world_to_cell(Vector3(-0.01, 0, -0.01)) == Vector2i(-1, -1), "world mapping uses floor like the simulation")
	var center := Vector2i(0, 0)
	terrain.set_water_cell(center, true)
	terrain.set_water_cell(Vector2i(1, 0), true)
	check((int(terrain.blob_masks[center]) & Blob47.E) != 0, "adding water refreshes the western neighbor")
	terrain.set_water_cell(Vector2i(1, 0), false)
	check((int(terrain.blob_masks[center]) & Blob47.E) == 0, "removing water refreshes the western neighbor")
	check(terrain.get_child_count() <= 8, "terrain uses a few merged nodes rather than one node per cell")
	check(terrain.get_node("IslandCliff").mesh != null, "missing-cell boundary has one merged cliff mesh")
	check(terrain.get_node("JadeWater").mesh.get_surface_count() == 1, "smooth river is one merged mesh surface")
	var curved_points := 0
	for polygon: PackedVector2Array in terrain._river_polygons:
		for point in polygon:
			if not is_equal_approx(point.x, roundf(point.x)) and not is_equal_approx(point.y, roundf(point.y)):
				curved_points += 1
	check(curved_points >= 8, "river outline contains analytic rounded-corner points")
	check(terrain.get_node("LandSurface").mesh.get_faces().size() > 300, "land remains a filled merged top around the river cutout")
	var land_arrays: Array = terrain.get_node("LandSurface").mesh.surface_get_arrays(0)
	check(land_arrays[Mesh.ARRAY_INDEX].size() > land_arrays[Mesh.ARRAY_VERTEX].size(), "courtyard land welds shared corners")
	var cliff_arrays: Array = terrain.get_node("IslandCliff").mesh.surface_get_arrays(0)
	check(cliff_arrays[Mesh.ARRAY_VERTEX].size() < 80, "straight cliff runs collapse to a few quads, verts=%d" % cliff_arrays[Mesh.ARRAY_VERTEX].size())
	var cached_builds: int = terrain.river_geometry_builds
	terrain.rebuild()
	check(terrain.river_geometry_builds == cached_builds, "repeating a rebuild reuses the river outline")
	_mesh_budget()
	terrain.land_cells.erase(Vector2i(3, 1))
	terrain.rebuild()
	check(terrain.get_node("RiverBridge").mesh.get_surface_count() == 0, "removing a bridge anchor removes the whole deck")
	check(not terrain.is_walkable(Vector3(4.5, 0, 1.5)), "hidden bridge cannot leave water walkable")
	var isolated: Node3D = RiverTerrain.new()
	root.add_child(isolated)
	var small: Array[Vector2i] = []
	for x in 3:
		for z in 3: small.append(Vector2i(x, z))
	isolated.configure(small)
	isolated.set_water_cell(Vector2i(1, 1), true)
	var grass_over_center := false
	var land_faces: PackedVector3Array = isolated.get_node("LandSurface").mesh.get_faces()
	for i in range(0, land_faces.size(), 3):
		var tri := PackedVector2Array([Vector2(land_faces[i].x, land_faces[i].z), Vector2(land_faces[i + 1].x, land_faces[i + 1].z), Vector2(land_faces[i + 2].x, land_faces[i + 2].z)])
		grass_over_center = grass_over_center or Geometry2D.is_point_in_polygon(Vector2(1.5, 1.5), tri)
	check(not grass_over_center, "isolated mask 0 water center is not occluded by a filled grass hole")
	check(isolated.get_node("JadeWater").mesh.get_faces().size() > 0, "isolated mask 0 still renders water")
	check(not _point_on_land(terrain.get_node("LandSurface").mesh, Vector2(4.5, 2.5)), "river center stays clear of the land mesh")
	check(_point_on_land(terrain.get_node("LandSurface").mesh, Vector2(-1.5, 2.5)), "dry courtyard cells stay covered")
	isolated.queue_free()
	terrain.queue_free()


func _mesh_budget() -> void:
	var strip: Node3D = RiverTerrain.new()
	root.add_child(strip)
	var cells: Array[Vector2i] = []
	for x in 8:
		cells.append(Vector2i(x, 8))
	strip.configure(cells)
	var faces: int = strip.get_node("IslandCliff").mesh.get_faces().size()
	check(faces == 24, "a straight rim merges into four cliff quads, faces=%d" % faces)
	var land_arrays: Array = strip.get_node("LandSurface").mesh.surface_get_arrays(0)
	check(land_arrays[Mesh.ARRAY_INDEX].size() == 48, "dry cells keep two triangles each")
	check(land_arrays[Mesh.ARRAY_VERTEX].size() < land_arrays[Mesh.ARRAY_INDEX].size(), "dry land welds shared corners")
	var builds: int = strip.river_geometry_builds
	strip.rebuild()
	strip.land_cells.erase(Vector2i(0, 8))
	strip.rebuild()
	check(strip.river_geometry_builds == builds, "dry land edits reuse the cached river outline")
	strip.queue_free()


func _point_on_land(mesh: Mesh, point: Vector2) -> bool:
	var faces: PackedVector3Array = mesh.get_faces()
	for i in range(0, faces.size(), 3):
		var tri := PackedVector2Array([
			Vector2(faces[i].x, faces[i].z),
			Vector2(faces[i + 1].x, faces[i + 1].z),
			Vector2(faces[i + 2].x, faces[i + 2].z),
		])
		if Geometry2D.is_point_in_polygon(point, tri):
			return true
	return false
