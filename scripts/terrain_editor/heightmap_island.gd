class_name HeightmapIsland
extends RefCounted
## Playable island shell. One top heightmap plus its footprint, a generated
## underside, and sparse cliff embeds. Contour columns are not this mesh.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")
const Contours = preload("res://scripts/terrain_editor/contour_terrain.gd")

const ROCK_RISE := 0.75
const FOLD_DEPTH := 1.05
const KEEL_Y := -4.6
const UPPER_LEAN := 0.14
const FOLD_LEAN := 0.78
const PROFILE_COUNT := 7

var source: Data
var seed := 0
var revision := 0
var surfaces := {}
var triangle_chunks := {}
var water_regions := {}
var water_anchor_regions := {}
var land_regions := {}
var lawn_boundaries := {}
var splash_points: Array = []
var fall_veils: Array = []
## Placement hook for the sparse cliff embeds. Each entry is a dictionary
## with position, normal, depth, width, height, cell and side.
var embeds: Array = []
var keel_inset_mean := 0.0
var _inset_sum := 0.0
var _inset_count := 0
var _corners := {}
var _boundary: Array = []

static func wall_inset(depth: float) -> float:
	# Positive is inward. The lip leans in slightly, then past the fold the
	# wall breaks and pinches. It never flares outward.
	if depth <= 0.0:
		return 0.0
	if depth < FOLD_DEPTH:
		return depth * UPPER_LEAN
	var past := depth - FOLD_DEPTH
	return FOLD_DEPTH * UPPER_LEAN + past * FOLD_LEAN + past * past * 0.05

func shore_weight(p: Vector2, height: float) -> float:
	return Contours.shore_weight(p, height)

func shore_support(p: Vector2, out: Vector2, height: float, width: float) -> bool:
	for point in [p + out * width, p + out * 0.20]:
		var sample: Dictionary = surface_at(point)
		if sample.is_empty() or int(sample.water) >= 0 or absf(float(sample.height) - height) > 0.08:
			return false
	var wet: Dictionary = surface_at(p - out * 0.30)
	return not wet.is_empty() and int(wet.water) >= 0 and absf(float(wet.height) - height) < 0.08

func surface_at(p: Vector2) -> Dictionary:
	if source == null:
		return {}
	var cell := Vector2i(floori(p.x), floori(p.y))
	if not source.cells.has(cell):
		return {}
	var record: Dictionary = source.cells[cell]
	if int(record.water) >= 0:
		return {"height": float(record.water) * 0.5, "water": int(record.water)}
	return {"height": float(record.height), "water": -1}

func cliff_embed_placements() -> Array:
	return embeds

func refresh(data: Data) -> void:
	source = data
	seed = data.seed
	revision += 1
	splash_points.clear()
	fall_veils.clear()
	embeds.clear()
	land_regions.clear()
	lawn_boundaries.clear()
	water_anchor_regions.clear()
	_corners.clear()
	_boundary.clear()
	_inset_sum = 0.0
	_inset_count = 0
	keel_inset_mean = 0.0
	surfaces.clear()
	for kind in ["grass", "cliff", "water", "waterfall", "lake_bed", "shore", "bank"]:
		surfaces[kind] = Geometry.Surface.new()
	for cell: Vector2i in data.cells:
		_cell(cell)
	_stitch_corners()
	_smooth(surfaces.cliff)
	_embeds()
	_cap()
	_water_loops()
	if _inset_count > 0:
		keel_inset_mean = _inset_sum / float(_inset_count)
	_index()

func build(chunk: Vector2i) -> Dictionary:
	var result := {}
	for kind in surfaces:
		var local = Geometry.Surface.new()
		var mesh_source = surfaces[kind]
		var indices: Array = triangle_chunks.get(chunk, {}).get(kind, [])
		for i in indices:
			var before: int = local.vertices.size()
			local.triangle(mesh_source.vertices[i], mesh_source.vertices[i + 1], mesh_source.vertices[i + 2], mesh_source.colors[i], false)
			if local.vertices.size() == before:
				continue
			for k in 3:
				local.normals[before + k] = mesh_source.normals[i + k]
				local.uv[before + k] = mesh_source.uv[i + k]
				local.colors[before + k] = mesh_source.colors[i + k]
		result[kind] = local.mesh()
	return result

func _cell(cell: Vector2i) -> void:
	var record: Dictionary = source.cells[cell]
	var ring := _ring(cell)
	var top := _top(record)
	if int(record.water) >= 0:
		_fan(surfaces.water, ring, top + 0.045, Color.WHITE, Vector2(top, 1.0))
		_fan(surfaces.lake_bed, ring, float(record.height), Color(float(record.water) / 255.0, 0.0, 0.0, 1.0), Vector2(top, 0.0))
	else:
		_fan(surfaces.grass, ring, top, Color(1, 1, 1, 1), Vector2(0.0, 1.0))
	for side in 4:
		var neighbor: Vector2i = cell + _offset(side)
		if not source.cells.has(neighbor):
			_skirt(cell, side)
		else:
			var drop := top - _top(source.cells[neighbor])
			if drop >= ROCK_RISE:
				_step_wall(cell, side, surfaces.cliff, top, _top(source.cells[neighbor]), true)
			elif drop > 0.04 and int(record.water) < 0:
				_step_wall(cell, side, surfaces.grass, top, _top(source.cells[neighbor]), false)
		if int(record.water) >= 0 and _spills(cell, side):
			_fall(cell, side)
		elif int(record.water) >= 0 and source.cells.has(neighbor):
			_basin(cell, side)

func _ring(cell: Vector2i) -> PackedVector2Array:
	var ring := PackedVector2Array()
	var corners := _corners_of(cell)
	for side in 4:
		ring.append(_corner_xz(corners[side].x, corners[side].y))
		if _notch_on(cell, side):
			var nxt: Vector2i = corners[(side + 1) % 4]
			var a := _corner_xz(corners[side].x, corners[side].y)
			var b := _corner_xz(nxt.x, nxt.y)
			ring.append(_notch(a, b, cell, side))
	return ring

func _fan(surface, ring: PackedVector2Array, y: float, color: Color, uv: Vector2) -> void:
	if ring.size() < 3:
		return
	var center2 := Vector2.ZERO
	for point in ring:
		center2 += point
	center2 /= float(ring.size())
	var center := Vector3(center2.x, y, center2.y)
	for i in ring.size():
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % ring.size()]
		_tri(surface, center, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), color, uv, true)

func _skirt(cell: Vector2i, side: int) -> void:
	var record: Dictionary = source.cells[cell]
	var rim_y := _top(record)
	var outward := Vector2(Geometry.SIDES[side])
	var points := _edge_points(cell, side, true)
	var straight := _straight_points(cell, side)
	var depths := _depths(rim_y)
	var columns: Array = []
	for index in points.size():
		var jagged: Vector2 = points[index]
		var room := _room(jagged, outward)
		var column: Array[Vector3] = []
		for depth in depths:
			column.append(_profile_point(jagged, straight[index], outward, rim_y, float(depth), room))
		columns.append(column)
		_inset_sum += minf(wall_inset(float(depths[depths.size() - 1])), room)
		_inset_count += 1
	for i in columns.size() - 1:
		_column_quads(surfaces.cliff, columns[i], columns[i + 1], depths, outward, rim_y)
	var corners := _corners_of(cell)
	_remember(corners[side], columns[0], outward)
	_remember(corners[(side + 1) % 4], columns[columns.size() - 1], outward)
	_boundary.append({"a": corners[side], "b": corners[(side + 1) % 4], "cell": cell, "side": side, "y": rim_y, "points": points, "straight": straight, "outward": outward})

func _step_wall(cell: Vector2i, side: int, surface, high: float, low: float, rock: bool) -> void:
	var outward := Vector2(Geometry.SIDES[side])
	var points := _edge_points(cell, side, rock)
	var color := Color.WHITE if rock else Color(1, 1, 1, 1)
	var uv := Vector2(high, 1.0 if rock else 0.0)
	for i in points.size() - 1:
		var a := Vector3(points[i].x, high, points[i].y)
		var b := Vector3(points[i + 1].x, high, points[i + 1].y)
		var c := Vector3(points[i + 1].x, low, points[i + 1].y)
		var d := Vector3(points[i].x, low, points[i].y)
		_quad(surface, a, b, c, d, outward, color, uv)

func _basin(cell: Vector2i, side: int) -> void:
	var record: Dictionary = source.cells[cell]
	var lip := _top(record)
	var bed := float(record.height)
	if lip - bed < 0.08:
		return
	var neighbor: Dictionary = source.cells[cell + Geometry.SIDES[side]]
	if int(neighbor.water) >= 0 and float(neighbor.height) <= bed + 0.04:
		return
	var outward := Vector2(Geometry.SIDES[side])
	var points := _edge_points(cell, side, false)
	var color := Color(float(record.water) / 255.0, 0.0, 0.0, 1.0)
	for i in points.size() - 1:
		var a := Vector3(points[i].x, lip, points[i].y)
		var b := Vector3(points[i + 1].x, lip, points[i + 1].y)
		var c := Vector3(points[i + 1].x, bed, points[i + 1].y)
		var d := Vector3(points[i].x, bed, points[i].y)
		_quad(surfaces.lake_bed, a, b, c, d, outward, color, Vector2(lip, 0.0))

func _fall(cell: Vector2i, side: int) -> void:
	var here := _top(source.cells[cell]) + 0.04
	var outward := Vector2(Geometry.SIDES[side])
	var points := _edge_points(cell, side, true)
	var end := points.size() - 1
	var a2: Vector2 = points[0].lerp(points[end], 0.16)
	var b2: Vector2 = points[0].lerp(points[end], 0.84)
	var neighbor: Vector2i = cell + _offset(side)
	var external := not source.cells.has(neighbor)
	var dest := maxf(KEEL_Y + 0.8, here - 3.3) if external else _top(source.cells[neighbor]) + 0.06
	var push := 0.42 if external else 0.16
	var n := Vector3(outward.x, 0.0, outward.y)
	var lip_a := Vector3(a2.x, here, a2.y) + n * 0.06
	var lip_b := Vector3(b2.x, here, b2.y) + n * 0.06
	var foot_a := Vector3(a2.x, dest, a2.y) + n * push
	var foot_b := Vector3(b2.x, dest, b2.y) + n * push
	_quad(surfaces.waterfall, lip_a, lip_b, foot_b, foot_a, outward, Color.WHITE, Vector2(here, 1.0))
	var lip := (lip_a + lip_b) * 0.5
	var foot := (foot_a + foot_b) * 0.5
	fall_veils.append({"lip": lip, "foot": foot, "half_width": 0.46, "out": outward, "external": external})
	splash_points.append({"center": foot, "out": outward, "half_width": 0.46})

func _column_quads(surface, left: Array, right: Array, depths: Array, outward: Vector2, rim_y: float) -> void:
	for j in depths.size() - 1:
		_quad(surface, left[j], right[j], right[j + 1], left[j + 1], outward, Color.WHITE, Vector2(rim_y, 1.0))

func _stitch_corners() -> void:
	for key in _corners:
		var group: Array = _corners[key]
		if group.size() < 2:
			continue
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var ao: Vector2 = a.outward
			var bo: Vector2 = b.outward
			return atan2(ao.y, ao.x) < atan2(bo.y, bo.x))
		var best_delta := INF
		var pair: Array = []
		for i in group.size():
			var a: Dictionary = group[i]
			var b: Dictionary = group[(i + 1) % group.size()]
			var ao: Vector2 = a.outward
			var bo: Vector2 = b.outward
			var delta := fposmod(atan2(bo.y, bo.x) - atan2(ao.y, ao.x), TAU)
			if delta < best_delta:
				best_delta = delta
				pair = [a, b]
		if pair.is_empty() or best_delta > PI * 1.15:
			continue
		var hint: Vector2 = pair[0].outward + pair[1].outward
		if hint.length_squared() < 0.0001:
			hint = pair[0].outward
		var left: Array = pair[0].column
		var right: Array = pair[1].column
		var depths: Array = _depths(float(pair[0].y))
		if depths.size() != left.size():
			depths = []
			depths.resize(left.size())
			for j in left.size():
				depths[j] = float(j)
		_column_quads(surfaces.cliff, left, right, depths, hint.normalized(), float(pair[0].y))

func _embeds() -> void:
	for edge in _boundary:
		var cell: Vector2i = edge.cell
		var side: int = edge.side
		if _unit(cell.x, cell.y, 90 + side) < 0.93:
			continue
		if _spills(cell, side):
			continue
		var outward: Vector2 = edge.outward
		var points: PackedVector2Array = edge.points
		var straight: PackedVector2Array = edge.straight
		var mid: Vector2 = points[mini(1, points.size() - 1)]
		var mid_straight: Vector2 = straight[mini(1, straight.size() - 1)]
		var rim_y: float = edge.y
		var depth := lerpf(1.05, 2.35, _unit(cell.x, cell.y, 91 + side))
		var room := _room(mid, outward)
		var origin := _profile_point(mid, mid_straight, outward, rim_y, depth, room)
		var width := lerpf(0.55, 1.15, _unit(cell.x, cell.y, 92 + side))
		var height := lerpf(0.42, 0.95, _unit(cell.x, cell.y, 93 + side))
		var protrude := lerpf(0.16, 0.42, _unit(cell.x, cell.y, 94 + side))
		var n := Vector3(outward.x, 0.0, outward.y)
		var tangent := Vector3(-outward.y, 0.0, outward.x)
		var front := origin + n * protrude
		var back := origin - n * 0.2
		var up := Vector3.UP * height * 0.5
		var side_v := tangent * width * 0.5
		var uv := Vector2(rim_y, 1.0)
		_tri_facing(surfaces.cliff, front + up, front - up + side_v, front - up - side_v, n, uv)
		_tri_facing(surfaces.cliff, back, front - up - side_v, front + up, -tangent, uv)
		_tri_facing(surfaces.cliff, back, front + up, front - up + side_v, tangent, uv)
		_tri_facing(surfaces.cliff, back, front - up + side_v, front - up - side_v, -n, uv)
		embeds.append({
			"position": front,
			"normal": n,
			"depth": depth,
			"width": width,
			"height": height,
			"cell": cell,
			"side": side,
		})

func _cap() -> void:
	for loop in _trace_loops():
		var poly := PackedVector2Array()
		for edge in loop:
			var points: PackedVector2Array = edge.points
			var straight: PackedVector2Array = edge.straight
			var outward: Vector2 = edge.outward
			var rim_y: float = edge.y
			var room_depth := maxf(rim_y - KEEL_Y, 0.8)
			for index in points.size() - 1:
				var jagged: Vector2 = points[index]
				poly.append(_profile_xz(jagged, straight[index], outward, rim_y, room_depth, _room(jagged, outward)))
		if poly.size() < 3:
			continue
		var indices := Geometry2D.triangulate_polygon(poly)
		for i in range(0, indices.size(), 3):
			var a: Vector2 = poly[indices[i]]
			var b: Vector2 = poly[indices[i + 1]]
			var c: Vector2 = poly[indices[i + 2]]
			_tri(surfaces.cliff, Vector3(a.x, KEEL_Y, a.y), Vector3(c.x, KEEL_Y, c.y), Vector3(b.x, KEEL_Y, b.y), Color.WHITE, Vector2(KEEL_Y, -1.0), false)

func _water_loops() -> void:
	water_regions = {}
	var groups := {}
	for cell: Vector2i in source.cells:
		var level := int(source.cells[cell].water)
		if level < 0:
			continue
		if not groups.has(level):
			groups[level] = {}
		groups[level][cell] = true
	for level in groups:
		water_regions[level] = _outline_loops(groups[level])

func _trace_loops() -> Array:
	var outgoing := {}
	for edge in _boundary:
		var a: Vector2i = edge.a
		if not outgoing.has(a):
			outgoing[a] = []
		outgoing[a].append(edge)
	var seen := {}
	var loops: Array = []
	for edge in _boundary:
		var id := "%s|%s" % [edge.a, edge.b]
		if seen.has(id):
			continue
		var loop: Array = []
		var guard := 0
		var current = edge
		while guard < 8000:
			guard += 1
			var current_id := "%s|%s" % [current.a, current.b]
			if seen.has(current_id):
				break
			seen[current_id] = true
			loop.append(current)
			if not outgoing.has(current.b):
				break
			var options: Array = outgoing[current.b]
			var incoming := Vector2(current.b - current.a)
			var best := -INF
			var pick = null
			for candidate in options:
				var candidate_id := "%s|%s" % [candidate.a, candidate.b]
				if seen.has(candidate_id):
					continue
				var turn := atan2(incoming.cross(Vector2(candidate.b - candidate.a)), incoming.dot(Vector2(candidate.b - candidate.a)))
				if turn > best:
					best = turn
					pick = candidate
			if pick == null:
				break
			current = pick
		if loop.size() >= 3:
			loops.append(loop)
	return loops

func _outline_loops(occupied: Dictionary) -> Array:
	var edges := {}
	var keys: Array = occupied.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for cell: Vector2i in keys:
		for side in 4:
			if occupied.has(cell + Geometry.SIDES[side]):
				continue
			var ends: Array = Geometry._edge(cell, side)
			var a := Vector2i(int(ends[0].x), int(ends[0].z))
			var b := Vector2i(int(ends[1].x), int(ends[1].z))
			if not edges.has(a):
				edges[a] = []
			edges[a].append(b)
	var loops: Array = []
	while not edges.is_empty():
		var start: Vector2i = edges.keys()[0]
		var current := start
		var previous := start - Vector2i.RIGHT
		var points := PackedVector2Array()
		var safety := edges.size() * 4 + 4
		while safety > 0:
			safety -= 1
			points.append(Vector2(current))
			if not edges.has(current):
				break
			var options: Array = edges[current]
			var next: Vector2i = options[0]
			var best := -INF
			var incoming := Vector2(current - previous)
			for candidate: Vector2i in options:
				var outgoing := Vector2(candidate - current)
				var turn := atan2(incoming.cross(outgoing), incoming.dot(outgoing))
				if turn > best:
					best = turn
					next = candidate
			options.erase(next)
			if options.is_empty():
				edges.erase(current)
			previous = current
			current = next
			if current == start:
				break
		if points.size() >= 3:
			var area := 0.0
			for i in points.size():
				area += points[i].cross(points[(i + 1) % points.size()])
			if area < 0.0:
				points.reverse()
			loops.append(points)
	return loops

func _index() -> void:
	triangle_chunks.clear()
	for kind in surfaces:
		var vertices: PackedVector3Array = surfaces[kind].vertices
		for i in range(0, vertices.size(), 3):
			var center := (vertices[i] + vertices[i + 1] + vertices[i + 2]) / 3.0
			var chunk := Data.chunk_of(Vector2i(floori(center.x), floori(center.z)))
			if not triangle_chunks.has(chunk):
				triangle_chunks[chunk] = {}
			if not triangle_chunks[chunk].has(kind):
				triangle_chunks[chunk][kind] = []
			triangle_chunks[chunk][kind].append(i)

func _smooth(surface) -> void:
	var sums := {}
	var vertices: PackedVector3Array = surface.vertices
	for i in range(0, vertices.size(), 3):
		var weighted: Vector3 = -(vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i])
		for point in [vertices[i], vertices[i + 1], vertices[i + 2]]:
			var key := Vector3i(roundi(point.x * 80.0), roundi(point.y * 80.0), roundi(point.z * 80.0))
			sums[key] = sums.get(key, Vector3.ZERO) + weighted
	for i in vertices.size():
		var point: Vector3 = vertices[i]
		var key := Vector3i(roundi(point.x * 80.0), roundi(point.y * 80.0), roundi(point.z * 80.0))
		var sum: Vector3 = sums[key]
		if sum.length_squared() > 0.00000001:
			surface.normals[i] = sum.normalized()

func _remember(key: Vector2i, column: Array, outward: Vector2) -> void:
	if not _corners.has(key):
		_corners[key] = []
	_corners[key].append({"column": column, "outward": outward, "y": column[0].y})

func _profile_point(jagged: Vector2, straight: Vector2, outward: Vector2, rim_y: float, depth: float, room: float) -> Vector3:
	var xz := _profile_xz(jagged, straight, outward, rim_y, depth, room)
	return Vector3(xz.x, rim_y - depth, xz.y)

func _profile_xz(jagged: Vector2, straight: Vector2, outward: Vector2, rim_y: float, depth: float, room: float) -> Vector2:
	# The lip keeps the rugged plan. Below the fold the ribs fade so the cliff
	# reads as one stone mass, then the mouth pinches inward.
	var total := maxf(rim_y - KEEL_Y, 0.8)
	var used := clampf(depth, 0.0, total)
	var fade := clampf(1.0 - used / FOLD_DEPTH, 0.0, 1.0)
	var xz := straight.lerp(jagged, fade)
	return xz - outward * minf(wall_inset(used), room)

func _sample(base: Vector2, outward: Vector2, rim_y: float, depth: float) -> Vector3:
	var xz := _displace(base, outward, rim_y, depth)
	return Vector3(xz.x, rim_y - depth, xz.y)

func _displace(base: Vector2, outward: Vector2, rim_y: float, depth: float) -> Vector2:
	var total := maxf(rim_y - KEEL_Y, 0.8)
	var used := clampf(depth, 0.0, total)
	return base - outward * minf(wall_inset(used), _room(base, outward))

func _straight_points(cell: Vector2i, side: int) -> PackedVector2Array:
	var corners := _corners_of(cell)
	var a := Vector2(corners[side])
	var b := Vector2(corners[(side + 1) % 4])
	var points := PackedVector2Array()
	points.append(a)
	points.append(a.lerp(b, 0.5))
	points.append(b)
	return points

func _depths(rim_y: float) -> Array:
	var total := maxf(rim_y - KEEL_Y, 0.8)
	var raw: Array[float] = [0.0, 0.42, 0.9, minf(FOLD_DEPTH, total * 0.5), minf(FOLD_DEPTH + 0.85, total * 0.72), minf(FOLD_DEPTH + 1.9, total * 0.88), total]
	var result: Array[float] = []
	var previous := -1.0
	for value in raw:
		var depth := clampf(value, 0.0, total)
		if depth <= previous + 0.025:
			continue
		result.append(depth)
		previous = depth
	while result.size() < PROFILE_COUNT and result.size() >= 2:
		var last: float = result[result.size() - 1]
		var before: float = result[result.size() - 2]
		result.insert(result.size() - 1, (before + last) * 0.5)
	return result

func _room(xz: Vector2, outward: Vector2) -> float:
	var inward := -outward
	var reached := 0.0
	for step in range(1, 24):
		var p := xz + inward * (float(step) * 0.5)
		if not source.cells.has(Vector2i(floori(p.x), floori(p.y))):
			break
		reached = float(step) * 0.5
	return clampf(reached * 0.34, 0.22, 2.35)

func _edge_points(cell: Vector2i, side: int, notched: bool) -> PackedVector2Array:
	var corners := _corners_of(cell)
	var a := _corner_xz(corners[side].x, corners[side].y)
	var b := _corner_xz(corners[(side + 1) % 4].x, corners[(side + 1) % 4].y)
	var points := PackedVector2Array()
	points.append(a)
	if notched:
		points.append(_notch(a, b, cell, side))
	points.append(b)
	return points

func _notch_on(cell: Vector2i, side: int) -> bool:
	var neighbor: Vector2i = cell + _offset(side)
	if not source.cells.has(neighbor):
		return true
	return absf(_top(source.cells[cell]) - _top(source.cells[neighbor])) >= ROCK_RISE

func _notch(a: Vector2, b: Vector2, cell: Vector2i, side: int) -> Vector2:
	var neighbor: Vector2i = cell + _offset(side)
	var amp := 0.38
	var key_cell := cell
	var key_side := side
	var push := Vector2(Geometry.SIDES[side])
	if source.cells.has(neighbor):
		amp = 0.18
		if neighbor.x < cell.x or (neighbor.x == cell.x and neighbor.y < cell.y):
			key_cell = neighbor
			key_side = (side + 2) % 4
		var high: Vector2i = cell if _top(source.cells[cell]) >= _top(source.cells[neighbor]) else neighbor
		var high_side := side if high == cell else (side + 2) % 4
		push = Vector2(Geometry.SIDES[high_side])
	var along := _unit(key_cell.x, key_cell.y, 40 + key_side)
	var side_h := _unit(key_cell.x, key_cell.y, 41 + key_side)
	var tangent := Vector2(-push.y, push.x)
	var lo := a if (a.x < b.x or (is_equal_approx(a.x, b.x) and a.y <= b.y)) else b
	var hi := b if lo == a else a
	return lo.lerp(hi, 0.34 + along * 0.32) + push * ((side_h - 0.5) * amp) + tangent * ((_unit(key_cell.x, key_cell.y, 42 + key_side) - 0.5) * amp * 0.28)

func _corner_xz(ix: int, iz: int) -> Vector2:
	var base := Vector2(float(ix), float(iz))
	var count := 0
	var empty := Vector2.ZERO
	for dz in [-1, 0]:
		for dx in [-1, 0]:
			if source.cells.has(Vector2i(ix + dx, iz + dz)):
				count += 1
			else:
				empty += Vector2(float(dx) + 0.5, float(dz) + 0.5)
	if count == 0 or count == 4:
		return base
	var jag := Vector2(_unit(ix, iz, 11) - 0.5, _unit(ix, iz, 12) - 0.5) * 0.34
	if empty.length_squared() > 0.0001:
		jag += empty.normalized() * (0.05 + _unit(ix, iz, 13) * 0.16)
	return base + jag

func _offset(side: int) -> Vector2i:
	return Geometry.SIDES[side] as Vector2i

func _corners_of(cell: Vector2i) -> Array[Vector2i]:
	return [Vector2i(cell.x, cell.y), Vector2i(cell.x + 1, cell.y), Vector2i(cell.x + 1, cell.y + 1), Vector2i(cell.x, cell.y + 1)]

func _spills(cell: Vector2i, side: int) -> bool:
	var record: Dictionary = source.cells[cell]
	if int(record.water) < 0:
		return false
	var here := _top(record)
	var neighbor: Vector2i = cell + _offset(side)
	if not source.cells.has(neighbor):
		return true
	return here - _top(source.cells[neighbor]) > 0.35

func _top(record: Dictionary) -> float:
	if int(record.water) >= 0:
		return float(record.water) * 0.5
	return float(record.height)

func _unit(x: int, z: int, salt: int) -> float:
	var value := (x * 374761393 + z * 668265263 + seed * 69069 + salt * 144269) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return float(value) / 2147483647.0

func _quad(surface, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector2, color: Color, uv: Vector2) -> void:
	var hint := Vector3(outward.x, 0.0, outward.y)
	var normal := -(b - a).cross(c - a)
	if normal.dot(hint) < 0.0:
		_tri(surface, a, c, b, color, uv, false)
		_tri(surface, a, d, c, color, uv, false)
	else:
		_tri(surface, a, b, c, color, uv, false)
		_tri(surface, a, c, d, color, uv, false)

func _tri_facing(surface, a: Vector3, b: Vector3, c: Vector3, facing: Vector3, uv: Vector2) -> void:
	if (-(b - a).cross(c - a)).dot(facing) < 0.0:
		_tri(surface, a, c, b, Color.WHITE, uv, false)
	else:
		_tri(surface, a, b, c, Color.WHITE, uv, false)

func _tri(surface, a: Vector3, b: Vector3, c: Vector3, color: Color, uv: Vector2, up: bool) -> void:
	var before: int = surface.vertices.size()
	surface.triangle(a, b, c, color, up)
	if surface.vertices.size() == before:
		return
	for index in range(before, surface.vertices.size()):
		surface.uv[index] = uv
		surface.colors[index] = color
