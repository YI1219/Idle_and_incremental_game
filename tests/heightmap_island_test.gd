extends SceneTree
## Heightmap shell: cell-edge rim, full cell tops, stage-2 blunt feet. No viewport.
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
	_check_blunt_feet()
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

func _check_blunt_feet() -> void:
	var data := Data.new()
	for z in 4:
		for x in 4:
			data.cells[Vector2i(x, z)] = {"height": 2.0, "water": -1}
	var island := Island.new()
	island.refresh(data)
	var foot_y := 2.0 - Island.RIM_DROP - Island.FOOT_DROP
	var foot := Vector3(2.0, foot_y, Island.FOOT_INSET)
	var inner := Vector3(2.0, foot_y, Island.FOOT_INSET + Island.FOOT_LIP)
	check(_has_corner(island.surfaces.cliff, Vector3(2, 2, 0)), "blunt wall keeps the grass-lip morph joint")
	check(not _has_corner(island.surfaces.cliff, Vector3(2, 0, 0)), "the 2m wall does not end as an open skirt on the lip")
	check(_has_corner(island.surfaces.cliff, foot), "straight wall foot sits inward of the lip")
	check(_has_corner(island.surfaces.cliff, inner), "straight wall has a thick underside past the foot")
	var underside := Vector3(2.5, foot_y, Island.FOOT_INSET + Island.FOOT_LIP * 0.5)
	check(_downward_cover(island, underside), "underside faces down and closes under the wall")
	check(_has_corner(island.surfaces.cliff, Vector3(Island.FOOT_INSET, foot_y, Island.FOOT_INSET)), "adjacent runs weld the blunt foot at the convex corner")
	check(_covers(island, (Vector3(1, foot_y, Island.FOOT_INSET) + foot) * 0.5), "blunt feet connect along a straight run")
	check(_has_shoulder(island), "the grass break has an inset shoulder above the vertical face")
	data.begin_stroke()
	var raised := data.apply_brush(Vector2(2.5, 0.5), 0.4, "raise", true, 2.0, 0)
	data.end_stroke()
	island.refresh(data)
	var raised_y := 2.5 - Island.RIM_DROP - Island.FOOT_DROP
	check(raised > 0 and _has_corner(island.surfaces.cliff, foot), "raise keeps the unraised foot on the same inward line")
	check(_has_corner(island.surfaces.cliff, Vector3(2, raised_y, Island.FOOT_INSET)), "raise lifts that cell's blunt foot without sliding it")
	var before := _low_signature(island)
	data.begin_stroke()
	var expanded := data.apply_brush(Vector2(0.5, -0.5), 0.55, "expand", true, 2.0, 0)
	data.end_stroke()
	island.refresh(data)
	check(expanded > 0 and data.cells.has(Vector2i(0, -1)) and _low_signature(island) != before, "expand changes blunt-foot connectivity")
	var notch := Data.new()
	notch.cells[Vector2i(0, 0)] = {"height": 2.0, "water": -1}
	notch.cells[Vector2i(1, 0)] = {"height": 2.0, "water": -1}
	notch.cells[Vector2i(0, 1)] = {"height": 2.0, "water": -1}
	var open_bay := Island.new()
	open_bay.refresh(notch)
	check(not _foot_in_bay(open_bay), "a one-cell notch does not grow a blunt foot across the bay")

func _has_shoulder(island: Island) -> bool:
	var vertices: PackedVector3Array = island.surfaces.cliff.vertices
	for vertex in vertices:
		if absf(vertex.x - 2.0) > 0.02:
			continue
		if vertex.z < 0.2 or vertex.z > 0.75:
			continue
		if vertex.y < 2.0 - 1.05 or vertex.y > 2.0 - 0.3:
			continue
		return true
	return false

func _downward_cover(island: Island, point: Vector3) -> bool:
	var vertices: PackedVector3Array = island.surfaces.cliff.vertices
	var normals: PackedVector3Array = island.surfaces.cliff.normals
	for index in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var c: Vector3 = vertices[index + 2]
		var normal := -((b - a).cross(c - a))
		if normal.length_squared() < 0.00000001:
			continue
		if absf(normal.normalized().dot(point - a)) > 0.02:
			continue
		var weights := Geometry3D.get_triangle_barycentric_coords(point, a, b, c)
		if minf(weights.x, minf(weights.y, weights.z)) < -0.02:
			continue
		if normals[index].y < -0.5:
			return true
	return false

func _covers(island: Island, point: Vector3) -> bool:
	var vertices: PackedVector3Array = island.surfaces.cliff.vertices
	for index in range(0, vertices.size(), 3):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[index + 1]
		var c: Vector3 = vertices[index + 2]
		var normal := (b - a).cross(c - a)
		if normal.length_squared() < 0.00000001:
			continue
		if absf(normal.normalized().dot(point - a)) > 0.02:
			continue
		var weights := Geometry3D.get_triangle_barycentric_coords(point, a, b, c)
		if minf(weights.x, minf(weights.y, weights.z)) >= -0.02:
			return true
	return false

func _low_signature(island: Island) -> String:
	var rows := PackedStringArray()
	var vertices: PackedVector3Array = island.surfaces.cliff.vertices
	for vertex in vertices:
		if vertex.y > -0.8:
			continue
		rows.append("%.2f,%.2f,%.2f" % [vertex.x, vertex.y, vertex.z])
	rows.sort()
	return "\n".join(rows)

func _foot_in_bay(island: Island) -> bool:
	var vertices: PackedVector3Array = island.surfaces.cliff.vertices
	for vertex in vertices:
		if vertex.y < 1.0 and vertex.x > 1.08 and vertex.z > 1.08:
			return true
	return false

func _empty_neighbor(data: Data) -> Vector2i:
	for cell: Vector2i in data.cells:
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not data.cells.has(neighbor):
				return neighbor
	return Vector2i(99999, 99999)
