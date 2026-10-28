extends SceneTree
## Heightmap shell, stage 1: cell-edge rim, full cell tops. No viewport.
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
	check(island.keel_inset_mean == 0.0, "stage 1 does not rebuild the keel cap")
	check(island.embeds.is_empty(), "stage 1 does not scatter embeds")
	check(island.cliff_embed_placements() == island.embeds, "embed placement hook returns the same set")
	var wide := 0
	var diagonal := 0
	var off_grid := 0
	var max_len := 0.0
	for facet in island.facets:
		var length: float = facet.length
		max_len = maxf(max_len, length)
		if length >= 2.0 - 0.01:
			wide += 1
		var end_a: Vector2 = facet.a
		var end_b: Vector2 = facet.b
		if absf(end_a.x - end_b.x) > 0.01 and absf(end_a.y - end_b.y) > 0.01:
			diagonal += 1
		if not _on_lattice(end_a) or not _on_lattice(end_b):
			off_grid += 1
	print("RIM facets=%d wide=%d max=%.2f diagonal=%d off_grid=%d embeds=%d" % [island.facets.size(), wide, max_len, diagonal, off_grid, island.embeds.size()])
	check(wide > 0 and diagonal == 0 and off_grid == 0, "preset rim is merged cell edges on the grid")
	check(is_equal_approx(_rim_length(island), float(_exposed_count(data))), "preset wall length matches exposed cell edges")
	_check_straight_run()
	_check_step_and_brushes()
	var occupied := data.cells.size()
	var empty := _empty_neighbor(data)
	check(empty != Vector2i(99999, 99999), "preset has a cell outside the footprint")
	data.begin_stroke()
	var expanded := data.apply_brush(Vector2(empty) + Vector2(0.5, 0.5), 0.55, "expand", true, 2.0, 0)
	data.end_stroke()
	check(expanded > 0 and data.cells.size() > occupied, "expand grows the footprint")
	island.refresh(data)
	check(is_equal_approx(_rim_length(island), float(_exposed_count(data))), "expand wall length matches the new footprint")
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
	check(is_equal_approx(_rim_length(island), float(_exposed_count(data))), "contract wall length matches the shrunk footprint")
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

func _check_straight_run() -> void:
	var row := Data.new()
	for x in 3:
		row.cells[Vector2i(x, 0)] = {"height": 2.0, "water": -1}
	var island := Island.new()
	island.refresh(row)
	check(_facet_length(island, Vector2(0, -1), 2.0) == 3.0, "three collinear cells share one north wall")
	check(_facet_length(island, Vector2(0, 1), 2.0) == 3.0, "three collinear cells share one south wall")
	check(_has_corner(island.surfaces.grass, Vector3(0, 2, 0)), "grass keeps the cell corner")
	check(_has_corner(island.surfaces.grass, Vector3(3, 2, 0)), "grass reaches the far cell corner")
	var one := Data.new()
	one.cells[Vector2i.ZERO] = {"height": 1.5, "water": -1}
	var single := Island.new()
	single.refresh(one)
	check(_steep_face(single, 0) and _steep_face(single, 2), "single cell has an east and a south steep face")

func _check_step_and_brushes() -> void:
	var data := Data.new()
	data.cells[Vector2i(0, 0)] = {"height": 2.0, "water": -1}
	data.cells[Vector2i(1, 0)] = {"height": 2.0, "water": -1}
	data.cells[Vector2i(0, 1)] = {"height": 2.0, "water": -1}
	var island := Island.new()
	island.refresh(data)
	check(_facet_length(island, Vector2(0, -1), 2.0) == 2.0, "the straight coast stays one face")
	check(_has_segment(island, Vector2(2, 1), Vector2(1, 1)), "the one-cell step keeps its own edge")
	var diagonal := 0
	for facet in island.facets:
		var end_a: Vector2 = facet.a
		var end_b: Vector2 = facet.b
		if absf(end_a.x - end_b.x) > 0.01 and absf(end_a.y - end_b.y) > 0.01:
			diagonal += 1
	check(diagonal == 0, "a footprint step is not bridged by a diagonal")
	data.cells[Vector2i(0, 1)].height = 3.5
	island.refresh(data)
	check(_interior_span(island, 3.5, 2.0), "an interior step spans the cell height delta")
	data.begin_stroke()
	var raised := data.apply_brush(Vector2(0.5, 0.5), 0.4, "raise", true, 2.0, 0)
	data.end_stroke()
	island.refresh(data)
	check(raised > 0 and _facet_length(island, Vector2(0, -1), 2.5) == 1.0, "raise lifts only that cell's wall")
	check(_facet_length(island, Vector2(0, -1), 2.0) == 1.0, "the unraised neighbor wall stays put")

func _facet_length(island: Island, outward: Vector2, height: float) -> float:
	for facet in island.facets:
		var dir: Vector2 = facet.outward
		var top: float = facet.y
		if dir.distance_to(outward) < 0.01 and absf(top - height) < 0.01:
			return float(facet.length)
	return -1.0

func _has_segment(island: Island, a: Vector2, b: Vector2) -> bool:
	for facet in island.facets:
		var end_a: Vector2 = facet.a
		var end_b: Vector2 = facet.b
		if end_a.distance_to(a) < 0.01 and end_b.distance_to(b) < 0.01:
			return true
	return false

func _rim_length(island: Island) -> float:
	var total := 0.0
	for facet in island.facets:
		total += float(facet.length)
	return total

func _exposed_count(data: Data) -> int:
	var count := 0
	for cell: Vector2i in data.cells:
		for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			if not data.cells.has(cell + offset):
				count += 1
	return count

func _interior_span(island: Island, high: float, low: float) -> bool:
	var vertices: PackedVector3Array = island.surfaces.cliff.vertices
	for index in range(0, vertices.size(), 3):
		var top_y := -100.0
		var bot_y := 100.0
		for corner in 3:
			var y: float = vertices[index + corner].y
			top_y = maxf(top_y, y)
			bot_y = minf(bot_y, y)
		if absf(top_y - high) < 0.05 and absf(bot_y - low) < 0.05:
			return true
	return false

func _steep_face(island: Island, axis: int) -> bool:
	var vertices: PackedVector3Array = island.surfaces.cliff.vertices
	for index in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var c: Vector3 = vertices[index + 2]
		var normal := -((b - a).cross(c - a))
		if normal.length_squared() < 0.00000001:
			continue
		normal = normal.normalized()
		var center := (a + b + c) / 3.0
		if normal[axis] > 0.7 and center.y > 0.0 and center.y < 1.3:
			return true
	return false

func _has_corner(surface, point: Vector3) -> bool:
	var vertices: PackedVector3Array = surface.vertices
	for vertex in vertices:
		if vertex.distance_to(point) < 0.02:
			return true
	return false

func _on_lattice(point: Vector2) -> bool:
	return absf(point.x - roundf(point.x)) < 0.02 and absf(point.y - roundf(point.y)) < 0.02

func _empty_neighbor(data: Data) -> Vector2i:
	for cell: Vector2i in data.cells:
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not data.cells.has(neighbor):
				return neighbor
	return Vector2i(99999, 99999)
