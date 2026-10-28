extends SceneTree
## Heightmap shell: brushes, inward fold, sparse embeds. No viewport.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Island = preload("res://scripts/terrain_editor/heightmap_island.gd")
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
	check(Island.wall_inset(0.0) == 0.0, "rim inset starts at the footprint")
	check(Island.wall_inset(0.6) > 0.04, "upper wall leans instead of dropping straight")
	check(Island.wall_inset(FOLD()) > Island.wall_inset(0.6), "fold is deeper than the lip")
	var before := Island.wall_inset(FOLD())
	var after := Island.wall_inset(FOLD() + 1.2)
	check(after > before + 0.5, "past the threshold the wall pinches inward")
	check(Island.wall_inset(4.0) > 0.0, "inset never flares outward")
	var data := Data.new()
	data.make_preset(0)
	var island := Island.new()
	island.refresh(data)
	check(island.surfaces.grass.vertices.size() > 30, "heightmap top has a grass surface")
	check(island.surfaces.cliff.vertices.size() > 30, "heightmap builds a cliff shell")
	check(island.keel_inset_mean > 0.2, "preset underside regenerates inside the rim")
	check(island.embeds.size() >= 3 and island.embeds.size() <= 8, "preset places a sparse embed set")
	check(island.cliff_embed_placements() == island.embeds, "embed placement hook returns the same set")
	var inward := 0
	var flared := 0
	var nonmono := 0
	var length_sum := 0.0
	var short := 0
	var axis := 0
	var min_len := 999.0
	var max_len := 0.0
	var buckets: Array[int] = [0, 0, 0, 0, 0]
	var facet_count := 0
	for facet in island.facets:
		facet_count += 1
		var length: float = facet.length
		length_sum += length
		min_len = minf(min_len, length)
		max_len = maxf(max_len, length)
		var bucket := 4
		if length < 2.5:
			bucket = 0
		elif length < 3.2:
			bucket = 1
		elif length < 3.8:
			bucket = 2
		elif length < 4.5:
			bucket = 3
		buckets[bucket] += 1
		if length < 1.9:
			short += 1
		var end_a: Vector2 = facet.a
		var end_b: Vector2 = facet.b
		var dir := end_b - end_a
		if dir.length_squared() > 0.000001:
			dir = dir.normalized()
			if absf(dir.x) < 0.12 or absf(dir.y) < 0.12:
				axis += 1
		var outward_dir: Vector2 = facet.outward
		var lip: Vector2 = facet.lip
		var keel: Vector2 = facet.keel
		var moved := (lip - keel).dot(outward_dir)
		if moved > 0.15:
			inward += 1
		if moved < -0.02:
			flared += 1
		var previous := -0.02
		for sample in facet.band_xz:
			var xz: Vector2 = sample
			var inset := (lip - xz).dot(outward_dir)
			if inset < previous - 0.08:
				nonmono += 1
			previous = maxf(previous, inset)
	var rim_points := 0
	var lattice := 0
	var grid_line := 0
	for loop in island.rim_loops:
		var ring: PackedVector2Array = loop
		for point in ring:
			rim_points += 1
			var on_x := absf(point.x - roundf(point.x)) < 0.08
			var on_y := absf(point.y - roundf(point.y)) < 0.08
			if on_x or on_y:
				grid_line += 1
			if on_x and on_y:
				lattice += 1
	var mean := length_sum / float(maxi(facet_count, 1))
	var teeth := _grass_teeth(island)
	var turn_sum := 0.0
	var hard_turns := 0
	var turn_count := 0
	for loop in island.rim_loops:
		var ring: PackedVector2Array = loop
		var count := ring.size()
		for index in count:
			var turn := absf(atan2((ring[index] - ring[(index + count - 1) % count]).normalized().cross((ring[(index + 1) % count] - ring[index]).normalized()), (ring[index] - ring[(index + count - 1) % count]).normalized().dot((ring[(index + 1) % count] - ring[index]).normalized())))
			turn_sum += turn
			turn_count += 1
			if turn > 0.22:
				hard_turns += 1
	print("RIM facets=%d min=%.2f mean=%.2f max=%.2f buckets=%s short=%d axis=%d lattice=%d/%d gridline=%d/%d inward=%d flared=%d nonmono=%d embeds=%d teeth=%d hard_turns=%d/%d mean_turn=%.1fdeg" % [facet_count, min_len, mean, max_len, str(buckets), short, axis, lattice, rim_points, grid_line, rim_points, inward, flared, nonmono, island.embeds.size(), teeth, hard_turns, turn_count, rad_to_deg(turn_sum / float(maxi(turn_count, 1)))])
	check(facet_count >= 36 and facet_count <= 52 and mean >= 2.3 and mean <= 4.2, "cliff has many wide panels, mean %.2f over %d" % [mean, facet_count])
	check(min_len >= 1.95 and max_len <= 4.6 and short == 0, "rim panels stay wide and stair-free, %.2f..%.2f" % [min_len, max_len])
	check(rim_points > 8 and lattice * 5 < rim_points, "rim vertices leave the integer grid")
	check(inward > 8 and flared == 0 and nonmono == 0, "faceted underside folds inward and does not flare")
	check(teeth == 0, "grass stays inside the stone lip")
	var occupied := data.cells.size()
	var empty := _empty_neighbor(data)
	check(empty != Vector2i(99999, 99999), "preset has a cell outside the footprint")
	data.begin_stroke()
	var expanded := data.apply_brush(Vector2(empty) + Vector2(0.5, 0.5), 0.55, "expand", true, 2.0, 0)
	data.end_stroke()
	check(expanded > 0 and data.cells.size() > occupied, "expand grows the footprint")
	island.refresh(data)
	check(island.keel_inset_mean > 0.2, "underside rebuilds after expand")
	var raised_cell: Vector2i = empty
	var raised_before: float = data.cells[raised_cell].height
	data.begin_stroke()
	var raised := data.apply_brush(Vector2(raised_cell) + Vector2(0.5, 0.5), 0.4, "raise", true, 2.0, 0)
	data.end_stroke()
	check(raised > 0 and data.cells[raised_cell].height == raised_before + 0.5, "raise edits height only")
	data.begin_stroke()
	var lowered := data.apply_brush(Vector2(raised_cell) + Vector2(0.5, 0.5), 0.4, "lower", true, 2.0, 0)
	data.end_stroke()
	check(lowered > 0 and is_equal_approx(data.cells[raised_cell].height, raised_before), "lower restores the brushed height")
	data.begin_stroke()
	var shrunk := data.apply_brush(Vector2(raised_cell) + Vector2(0.5, 0.5), 0.4, "contract", true, 2.0, 0)
	data.end_stroke()
	check(shrunk > 0 and not data.cells.has(raised_cell), "shrink removes footprint")
	island.refresh(data)
	check(island.keel_inset_mean > 0.2, "underside rebuilds after shrink")
	check(_has_rock_step(data), "preset keeps a steep step that reads as a rock wall")
	print("HEIGHTMAP ISLAND: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

func FOLD() -> float:
	return Island.FOLD_DEPTH

func _shown(record: Dictionary) -> float:
	return float(record.water) * 0.5 if int(record.water) >= 0 else float(record.height)

func _has_rock_step(data: Data) -> bool:
	for cell: Vector2i in data.cells:
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not data.cells.has(neighbor):
				continue
			if absf(_shown(data.cells[cell]) - _shown(data.cells[neighbor])) >= Island.ROCK_RISE:
				return true
	return false

func _grass_teeth(island: Island) -> int:
	var teeth := 0
	var seen := {}
	var vertices: PackedVector3Array = island.surfaces.grass.vertices
	for vertex in vertices:
		var key := Vector2i(roundi(vertex.x * 25.0), roundi(vertex.z * 25.0))
		if seen.has(key):
			continue
		seen[key] = true
		var point := Vector2(vertex.x, vertex.z)
		var inside := false
		var near := false
		for loop in island.grass_loops:
			var ring: PackedVector2Array = loop
			if Geometry2D.is_point_in_polygon(point, ring):
				inside = true
				break
			if _near_ring(point, ring, 0.2):
				near = true
		if not inside and not near:
			teeth += 1
	return teeth

func _near_ring(point: Vector2, ring: PackedVector2Array, limit: float) -> bool:
	var count := ring.size()
	for index in count:
		var a: Vector2 = ring[index]
		var b: Vector2 = ring[(index + 1) % count]
		var span := b - a
		var denom := span.length_squared()
		var weight := 0.0 if denom < 0.000001 else clampf((point - a).dot(span) / denom, 0.0, 1.0)
		if point.distance_to(a + span * weight) <= limit:
			return true
	return false

func _empty_neighbor(data: Data) -> Vector2i:
	for cell: Vector2i in data.cells:
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not data.cells.has(neighbor):
				return neighbor
	return Vector2i(99999, 99999)
