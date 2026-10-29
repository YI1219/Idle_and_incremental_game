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
	check(_embeds_are_sparse(island), "embeds stay sparse and do not form a stone skirt")
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
	# Fixed sole coordinates from the stage-2 trial profile were replaced.
	# The sole now follows one thickness budget and a shared component floor.
	var wide := Data.new()
	wide.seed = 7301
	for z in 4:
		for x in 10:
			wide.cells[Vector2i(x, z)] = {"height": 2.0, "water": -1}
	var island := Island.new()
	island.refresh(wide)
	check(_has_corner(island.surfaces.cliff, Vector3(7, 2, 0)), "distant lip joint stays on the source corner")
	check(_downward_cover(island, Vector3(4.5, _lowest(island), 1.5)), "the component floor closes under the interior")
	var before := _band(island, 7.0, 8.0)
	wide.begin_stroke()
	var raised := wide.apply_brush(Vector2(4.5, 0.5), 0.4, "raise", true, 2.0, 0)
	wide.end_stroke()
	island.refresh(wide)
	check(raised > 0 and _band(island, 7.0, 8.0) == before, "raising one cell does not rehash a distant rock group")
	check(_depth_varies(island), "a long edge changes inland depth and does not flare outward")
	var step := Data.new()
	step.cells[Vector2i(0, 0)] = {"height": 2.0, "water": -1}
	step.cells[Vector2i(1, 0)] = {"height": 2.5, "water": -1}
	var joined := Island.new()
	joined.refresh(step)
	check(absf(_plane_area(joined, 1.0, 0.0, 1.0, 2.02, 2.48) - 0.5) < 0.05, "a height break does not restitch the interior step")
	var tall := Data.new()
	tall.cells[Vector2i(0, 0)] = {"height": 2.0, "water": -1}
	tall.cells[Vector2i(1, 0)] = {"height": 3.0, "water": -1}
	var taller := Island.new()
	taller.refresh(tall)
	check(absf(_plane_area(taller, 1.0, 0.0, 1.0, 2.05, 2.95) - 1.0) < 0.06, "a taller interior wall is not duplicated by the rim join")
	var first := Data.new()
	first.cells[Vector2i(0, 0)] = {"height": 2.0, "water": -1}
	first.cells[Vector2i(1, 1)] = {"height": 2.0, "water": -1}
	var second := Data.new()
	second.cells[Vector2i(1, 1)] = {"height": 2.0, "water": -1}
	second.cells[Vector2i(0, 0)] = {"height": 2.0, "water": -1}
	var left := Island.new()
	var right := Island.new()
	left.refresh(first)
	right.refresh(second)
	check(not _bridges_diagonal(left) and not _bridges_diagonal(right), "corner-only islands are not welded together")
	check(_geometry_digest(left) == _geometry_digest(right), "the same cells build the same shell regardless of insertion order")
	var thin := Data.new()
	for x in 10:
		thin.cells[Vector2i(x, 0)] = {"height": 2.0, "water": -1}
	var strip := Island.new()
	strip.refresh(thin)
	check(_thin_budget(strip), "a one-cell-wide strip keeps a monotonic inset inside the land")
	var one := Data.new()
	one.cells[Vector2i.ZERO] = {"height": 2.0, "water": -1}
	var single := Island.new()
	single.refresh(one)
	check(_has_thick_corner(single), "a convex corner is a closed wedge with height, not a paper triangle")
	check(_downward_cover(single, Vector3(0.5, _lowest(single), 0.5)), "a single cell has a closed floor")
	var notch := Data.new()
	notch.cells[Vector2i(0, 0)] = {"height": 2.0, "water": -1}
	notch.cells[Vector2i(1, 0)] = {"height": 2.0, "water": -1}
	notch.cells[Vector2i(0, 1)] = {"height": 2.0, "water": -1}
	var bay := Island.new()
	bay.refresh(notch)
	check(not _covers_xz(bay, Vector2(1.5, 1.5)), "a one-cell notch is not sealed by the floor")

func _embeds_are_sparse(island: Island) -> bool:
	if island.embeds.size() > maxi(6, island.facets.size() / 4):
		return false
	for item in island.embeds:
		if int(item.host) < 4:
			return false
	return true

func _lowest(island: Island) -> float:
	var y := 1000.0
	for vertex in island.surfaces.cliff.vertices:
		y = minf(y, vertex.y)
	return y

func _band(island: Island, x0: float, x1: float) -> String:
	var rows := PackedStringArray()
	for vertex in island.surfaces.cliff.vertices:
		if vertex.x < x0 - 0.02 or vertex.x > x1 + 0.02:
			continue
		if vertex.z < -0.7 or vertex.z > 0.95:
			continue
		if vertex.y < 0.4:
			continue
		rows.append("%.3f,%.3f,%.3f" % [vertex.x, vertex.y, vertex.z])
	rows.sort()
	return "\n".join(rows)

func _depth_varies(island: Island) -> bool:
	# North lip of the 10x4 block is z = 0. The vertical band stays inland of
	# that lip. Facing downward is allowed; an outward shelf is not.
	var bins: Array[float] = []
	var counts: Array[int] = []
	bins.resize(8)
	counts.resize(8)
	for index in 8:
		bins[index] = 0.0
		counts[index] = 0
	for vertex in island.surfaces.cliff.vertices:
		if vertex.x < 1.2 or vertex.x > 8.8:
			continue
		if vertex.y < 0.55 or vertex.y > 1.65:
			continue
		if vertex.z < -0.04:
			return false
		var bin := clampi(int(floor(vertex.x)) - 1, 0, 7)
		bins[bin] += vertex.z
		counts[bin] += 1
	var lo := 10.0
	var hi := -10.0
	var seen := 0
	for index in 8:
		if counts[index] == 0:
			continue
		var mean := bins[index] / float(counts[index])
		lo = minf(lo, mean)
		hi = maxf(hi, mean)
		seen += 1
	return seen >= 4 and hi - lo > 0.04 and lo > 0.0

func _plane_area(island: Island, x: float, z0: float, z1: float, y0: float, y1: float) -> float:
	var area := 0.0
	var pool: Array[PackedVector3Array] = [island.surfaces.cliff.vertices, island.surfaces.grass.vertices]
	for vertices in pool:
		for index in range(0, vertices.size(), 3):
			var on := true
			var cz := 0.0
			var cy := 0.0
			for corner in 3:
				var vertex: Vector3 = vertices[index + corner]
				if absf(vertex.x - x) > 0.04:
					on = false
				cz += vertex.z
				cy += vertex.y
			if not on:
				continue
			cz /= 3.0
			cy /= 3.0
			if cz < z0 - 0.02 or cz > z1 + 0.02 or cy < y0 or cy > y1:
				continue
			var a: Vector3 = vertices[index]
			var b: Vector3 = vertices[index + 1]
			var c: Vector3 = vertices[index + 2]
			area += (b - a).cross(c - a).length() * 0.5
	return area

func _bridges_diagonal(island: Island) -> bool:
	var vertices: PackedVector3Array = island.surfaces.cliff.vertices
	for index in range(0, vertices.size(), 3):
		var near_a := false
		var near_b := false
		for corner in 3:
			var vertex: Vector3 = vertices[index + corner]
			if vertex.x < 0.75 and vertex.z < 0.75:
				near_a = true
			if vertex.x > 1.25 and vertex.z > 1.25:
				near_b = true
		if near_a and near_b:
			return true
	return false

func _geometry_digest(island: Island) -> String:
	var triangles := PackedStringArray()
	for kind in island.surfaces:
		var vertices: PackedVector3Array = island.surfaces[kind].vertices
		for index in range(0, vertices.size(), 3):
			var points := PackedStringArray()
			for corner in 3:
				var vertex: Vector3 = vertices[index + corner]
				points.append("%.4f,%.4f,%.4f" % [vertex.x, vertex.y, vertex.z])
			points.sort()
			triangles.append(String(kind) + ":" + ";".join(points))
	triangles.sort()
	return "\n".join(triangles).sha256_text()

func _thin_budget(island: Island) -> bool:
	# North side of the one-cell strip only. The south sole is a different wall.
	var foot_z := -1.0
	var sole_z := -1.0
	for vertex in island.surfaces.cliff.vertices:
		if absf(vertex.x - 5.0) > 0.08 or vertex.z < 0.0 or vertex.z > 0.46:
			continue
		if vertex.y < 0.0 and vertex.y > -0.7:
			foot_z = maxf(foot_z, vertex.z)
		if vertex.y < -0.7:
			sole_z = maxf(sole_z, vertex.z)
	return foot_z > 0.02 and sole_z + 0.001 >= foot_z and sole_z < 0.48

func _has_thick_corner(island: Island) -> bool:
	var vertices: PackedVector3Array = island.surfaces.cliff.vertices
	for index in range(0, vertices.size(), 3):
		var low := 100.0
		var high := -100.0
		var outside := false
		for corner in 3:
			var vertex: Vector3 = vertices[index + corner]
			low = minf(low, vertex.y)
			high = maxf(high, vertex.y)
			if vertex.x < -0.05 or vertex.z < -0.05 or vertex.x > 1.05 or vertex.z > 1.05:
				outside = true
		if outside and high - low > 1.2:
			return true
	return false

func _covers_xz(island: Island, point: Vector2) -> bool:
	var vertices: PackedVector3Array = island.surfaces.cliff.vertices
	var normals: PackedVector3Array = island.surfaces.cliff.normals
	for index in range(0, vertices.size(), 3):
		if normals[index].y > -0.5:
			continue
		var a := Vector2(vertices[index].x, vertices[index].z)
		var b := Vector2(vertices[index + 1].x, vertices[index + 1].z)
		var c := Vector2(vertices[index + 2].x, vertices[index + 2].z)
		if _point_in_tri(point, a, b, c):
			return true
	return false

func _point_in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var area := (b - a).cross(c - a)
	if absf(area) < 0.000001:
		return false
	var w0 := (b - p).cross(c - p) / area
	var w1 := (c - p).cross(a - p) / area
	var w2 := (a - p).cross(b - p) / area
	return w0 >= -0.02 and w1 >= -0.02 and w2 >= -0.02

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
