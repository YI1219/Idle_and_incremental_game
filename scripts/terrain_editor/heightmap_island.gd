class_name HeightmapIsland
extends RefCounted
## Playable island shell. One top heightmap plus its footprint.
## Cell-edge rim. Collinear same-height edges stay one wide face, with a
## vertex at every source corner so edit morph matches the grass. Rock groups
## are hashed from a stable world bin, not from whichever cell starts a run.
## Groups vary how far the vertical face sits inland. The rim does not flare
## outward into a shelf. The shared sole closes each land component.
## KEEL_Y is not a full-island lid. Authored face pieces are a separate sample.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")
const Contours = preload("res://scripts/terrain_editor/contour_terrain.gd")

const ROCK_RISE := 0.75
const FOLD_DEPTH := 1.05
const KEEL_Y := -4.6
const RIM_DROP := 2.0
const SHOULDER_LO := 0.46
const SHOULDER_HI := 0.88
const SHELF_LO := 0.34
const SHELF_HI := 0.62
const FOOT_INSET := 0.72
const FOOT_DROP := 1.72
const FOOT_LIP := 0.38
const CORNER_OVERHANG := 0.26
const BAND_DEPTHS: Array[float] = [0.0, 0.70, 1.05, 2.20, 3.60, 5.00, 6.80, 8.80]

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
## Prepared outer rings. Each entry is a CCW PackedVector2Array.
var rim_loops: Array = []
## Same rings, inset by the stone lip. Grass is clipped to these.
var grass_loops: Array = []
## One entry per cliff facet: lip, keel, outward, length, band_xz, cell, side.
var facets: Array = []
## Stable mid-scale groups. Each entry records origin, side and inland depth.
## Editing a distant cell does not rehash these.
var rock_groups: Array = []
var generate_ms := 0.0
var shell_triangles := 0
var _group_cache := {}
var _depth_cache := {}
var _bottom_y := {}
var _inset_sum := 0.0
var _inset_count := 0
var _plateaus: Array = []

static func wall_inset(depth: float) -> float:
	# Positive is inward. Each band is steeper than the one above it, so the
	# wall reads as separate planes folding into a cone. It never flares out.
	if depth <= 0.0:
		return 0.0
	var breaks: Array[float] = [0.70, 1.05, 2.20, 3.60, 5.00, 6.80]
	var slopes: Array[float] = [0.18, 0.42, 0.66, 0.86, 1.02, 1.18, 1.32]
	var cursor := 0.0
	var inset := 0.0
	for index in breaks.size():
		var stop: float = breaks[index]
		if depth <= stop:
			return inset + (depth - cursor) * slopes[index]
		inset += (stop - cursor) * slopes[index]
		cursor = stop
	return inset + (depth - cursor) * slopes[slopes.size() - 1]

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
	water_regions.clear()
	land_regions.clear()
	lawn_boundaries.clear()
	water_anchor_regions.clear()
	rim_loops.clear()
	grass_loops.clear()
	facets.clear()
	rock_groups.clear()
	_group_cache.clear()
	_depth_cache.clear()
	_bottom_y.clear()
	_plateaus.clear()
	_inset_sum = 0.0
	_inset_count = 0
	keel_inset_mean = 0.0
	surfaces.clear()
	for kind in ["grass", "cliff", "water", "waterfall", "lake_bed", "shore", "bank"]:
		surfaces[kind] = Geometry.Surface.new()
	var started := Time.get_ticks_msec()
	if data.cells.is_empty():
		_index()
		generate_ms = float(Time.get_ticks_msec() - started)
		return
	_prepare_shell()
	_fill_tops()
	_cell_rim()
	_interior_hydro()
	_water_loops()
	_index()
	generate_ms = float(Time.get_ticks_msec() - started)

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

func _build_plateaus() -> void:
	var levels: Array[float] = []
	for cell: Vector2i in source.cells:
		var height := _top(source.cells[cell])
		var known := false
		for existing in levels:
			if absf(existing - height) < 0.02:
				known = true
				break
		if not known:
			levels.append(height)
	levels.sort()
	if levels.size() < 2:
		return
	for index in range(1, levels.size()):
		var height: float = levels[index]
		var region := {}
		for cell: Vector2i in source.cells:
			if _top(source.cells[cell]) >= height - 0.02:
				region[cell] = true
		for raw in Contours._outlines(region):
			var loop := _prepare_loop(raw as PackedVector2Array, false)
			if loop.size() >= 3:
				_plateaus.append({"height": height, "loop": loop})

func _fill_tops() -> void:
	for cell: Vector2i in source.cells:
		var record: Dictionary = source.cells[cell]
		var top := _top(record)
		var square := _square(cell)
		if int(record.water) >= 0:
			var bed_color := Color(float(record.water) / 255.0, 0.0, 0.0, 1.0)
			_emit_poly(surfaces.water, square, top + 0.045, Color.WHITE, Vector2(top, 1.0))
			_emit_poly(surfaces.lake_bed, square, float(record.height), bed_color, Vector2(top, 0.0))
			continue
		_emit_land_top(cell, top)
	_grass_risers()

func _prepare_shell() -> void:
	_group_cache.clear()
	_depth_cache.clear()
	_bottom_y.clear()
	var seen := {}
	for cell: Vector2i in source.cells:
		if seen.has(cell):
			continue
		var stack: Array[Vector2i] = [cell]
		var members: Array[Vector2i] = []
		while not stack.is_empty():
			var current: Vector2i = stack.pop_back()
			if seen.has(current) or not source.cells.has(current):
				continue
			seen[current] = true
			members.append(current)
			for side in 4:
				stack.append(current + _offset(side))
		var lowest := 1000.0
		for member: Vector2i in members:
			lowest = minf(lowest, _top(source.cells[member]))
		var floor_y := lowest - 3.05
		for member: Vector2i in members:
			_bottom_y[member] = floor_y

func _emit_land_top(cell: Vector2i, top: float) -> void:
	var boundary: PackedVector2Array = _land_boundary(cell)
	if boundary.size() < 3:
		return
	var points: Array[Vector2] = []
	for point in boundary:
		points.append(point)
	var indices := Geometry2D.triangulate_polygon(boundary)
	var tris: Array = []
	if indices.is_empty():
		return
	for index in range(0, indices.size(), 3):
		tris.append([indices[index], indices[index + 1], indices[index + 2]])
	for corner in _corners_of(cell):
		var spot := Vector2(corner)
		if _boundary_has(boundary, spot):
			continue
		_insert_cap_point(points, tris, spot)
	var uv := Vector2(top, 1.0)
	for tri in tris:
		var ia: int = tri[0]
		var ib: int = tri[1]
		var ic: int = tri[2]
		var pa: Vector2 = points[ia]
		var pb: Vector2 = points[ib]
		var pc: Vector2 = points[ic]
		_tri_colored(surfaces.grass, Vector3(pa.x, top, pa.y), Vector3(pb.x, top, pb.y), Vector3(pc.x, top, pc.y), _cap_color(cell, pa), _cap_color(cell, pb), _cap_color(cell, pc), uv)

func _land_boundary(cell: Vector2i) -> PackedVector2Array:
	var poly := PackedVector2Array()
	var corners := _corners_of(cell)
	for corner_index in 4:
		var prev_side := (corner_index + 3) % 4
		var next_side := corner_index
		var prev_open := not source.cells.has(cell + _offset(prev_side))
		var next_open := not source.cells.has(cell + _offset(next_side))
		var spot := Vector2(corners[corner_index])
		if prev_open and next_open:
			var prev_out := Vector2(_offset(prev_side))
			var next_out := Vector2(_offset(next_side))
			var reach := lerpf(0.34, 0.48, _unit(roundi(spot.x), roundi(spot.y), 27))
			var bulge := lerpf(0.16, 0.28, _unit(roundi(spot.x), roundi(spot.y), 28))
			var incoming := _inward_tangent(prev_side)
			var outgoing := _outward_tangent(next_side)
			# The grid corner stays on the cap so morph still samples it, but it sits
			# in a concave notch between two outer chamfer points.
			poly.append(spot + incoming * reach + prev_out * bulge)
			poly.append(spot)
			poly.append(spot + outgoing * reach + next_out * bulge)
		else:
			poly.append(spot)
	return poly

func _inward_tangent(side: int) -> Vector2:
	# Direction along the side, toward its start corner.
	var forward := _outward_tangent(side)
	return -forward

func _outward_tangent(side: int) -> Vector2:
	var normal := Vector2(_offset(side))
	return Vector2(-normal.y, normal.x)

func _boundary_has(poly: PackedVector2Array, point: Vector2) -> bool:
	for vertex in poly:
		if vertex.distance_to(point) < 0.02:
			return true
	return false

func _insert_cap_point(points: Array[Vector2], tris: Array, spot: Vector2) -> void:
	for index in tris.size():
		var tri: Array = tris[index]
		var a: Vector2 = points[int(tri[0])]
		var b: Vector2 = points[int(tri[1])]
		var c: Vector2 = points[int(tri[2])]
		if not _point_in_tri(spot, a, b, c):
			continue
		var added := points.size()
		points.append(spot)
		tris[index] = [tri[0], tri[1], added]
		tris.append([tri[1], tri[2], added])
		tris.append([tri[2], tri[0], added])
		return
	points.append(spot)

func _point_in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var area := (b - a).cross(c - a)
	if absf(area) < 0.000001:
		return false
	var w0 := (b - p).cross(c - p) / area
	var w1 := (c - p).cross(a - p) / area
	var w2 := (a - p).cross(b - p) / area
	return w0 >= -0.001 and w1 >= -0.001 and w2 >= -0.001

func _cap_color(cell: Vector2i, point: Vector2) -> Color:
	var alpha := 1.0
	var corners := _corners_of(cell)
	for side in 4:
		if source.cells.has(cell + _offset(side)):
			continue
		var a := Vector2(corners[side])
		var b := Vector2(corners[(side + 1) % 4])
		if _segment_distance(point, a, b) > 0.62:
			continue
		alpha = minf(alpha, _lip_alpha(cell, side))
	return Color(1, 1, 1, alpha)

func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var span := b - a
	var denom := span.length_squared()
	if denom < 0.000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(span) / denom, 0.0, 1.0)
	return point.distance_to(a + span * t)

func _lip_alpha(cell: Vector2i, side: int) -> float:
	# Turf stays on the lip until a face piece is composed over it. Alpha is
	# only a local contact mask, not a belt and not an upward-shoulder flag.
	var params := _group_params(cell, side)
	return lerpf(0.9, 1.0, float(params.vary))

func _tri_colored(surface, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, uv: Vector2) -> void:
	var before: int = surface.vertices.size()
	surface.triangle(a, b, c, ca, true)
	if surface.vertices.size() == before:
		return
	surface.colors[before] = ca
	surface.colors[before + 1] = cb
	surface.colors[before + 2] = cc
	for index in 3:
		surface.uv[before + index] = uv

func _cell_rim() -> void:
	var edges: Array[Dictionary] = []
	for cell: Vector2i in source.cells:
		var height := _top(source.cells[cell])
		for side in 4:
			if source.cells.has(cell + _offset(side)):
				continue
			var ends := _corners_of(cell)
			edges.append({
				"a": Vector2(ends[side]),
				"b": Vector2(ends[(side + 1) % 4]),
				"outward": Vector2(_offset(side)),
				"height": height,
				"cell": cell,
				"side": side,
			})
	var successor: Array[int] = []
	successor.resize(edges.size())
	for index in edges.size():
		successor[index] = _successor_index(edges, index)
	var by_start := {}
	for index in edges.size():
		var edge: Dictionary = edges[index]
		by_start[_rim_key(edge.a, edge.outward, float(edge.height))] = index
	var used: Array[bool] = []
	used.resize(edges.size())
	used.fill(false)
	var runs: Array[Dictionary] = []
	var edge_run: Array[int] = []
	edge_run.resize(edges.size())
	edge_run.fill(-1)
	for index in edges.size():
		if used[index]:
			continue
		var head := index
		var guard := edges.size() + 1
		while guard > 0:
			guard -= 1
			var current: Dictionary = edges[head]
			var step: Vector2 = current.b - current.a
			var pred_key := _rim_key(current.a - step, current.outward, float(current.height))
			if not by_start.has(pred_key):
				break
			var pred: int = int(by_start[pred_key])
			if pred == head or used[pred]:
				break
			head = pred
		var cursor := head
		var pieces: Array[int] = []
		while not used[cursor]:
			used[cursor] = true
			pieces.append(cursor)
			var piece: Dictionary = edges[cursor]
			var next_key := _rim_key(piece.b, piece.outward, float(piece.height))
			if not by_start.has(next_key):
				break
			var nxt: int = int(by_start[next_key])
			if nxt == cursor or used[nxt]:
				break
			cursor = nxt
		if pieces.is_empty():
			continue
		var run_index := runs.size()
		for piece_index in pieces:
			edge_run[piece_index] = run_index
		var first: Dictionary = edges[pieces[0]]
		var last: Dictionary = edges[pieces[pieces.size() - 1]]
		runs.append({
			"pieces": pieces,
			"start": first.a,
			"finish": last.b,
			"outward": first.outward,
			"height": float(first.height),
			"cell": first.cell,
			"side": int(first.side),
		})
	var seen_group := {}
	for built in runs:
		_emit_rim_run(built, edges)
		var run_pieces: Array = built.pieces
		for piece_index in run_pieces:
			var piece: Dictionary = edges[int(piece_index)]
			var params := _group_params(piece.cell, int(piece.side))
			var key: String = params.key
			if seen_group.has(key):
				continue
			seen_group[key] = true
			rock_groups.append(params)
	for built in runs:
		var run_pieces: Array = built.pieces
		var last_piece: int = int(run_pieces[run_pieces.size() - 1])
		var nxt: int = successor[last_piece]
		if nxt < 0 or edge_run[nxt] < 0:
			continue
		var other: Dictionary = runs[edge_run[nxt]]
		if other == built:
			continue
		_join_runs(built, other, edges[last_piece], edges[nxt])
	_close_bottoms()
	_sparse_embeds(edges)

func _emit_rim_run(run: Dictionary, edges: Array[Dictionary]) -> void:
	var pieces: Array = run.pieces
	var outward: Vector2 = run.outward
	var top := float(run.height)
	var uv := Vector2(top, 1.0)
	for piece_index in pieces:
		var piece: Dictionary = edges[int(piece_index)]
		var left: Array = _edge_profile(piece, piece.a)
		var right: Array = _edge_profile(piece, piece.b)
		for band in 4:
			_flat_quad(surfaces.cliff, left[band], right[band], right[band + 1], left[band + 1], outward, Color.WHITE, uv)
	var edge_list: Array[Dictionary] = []
	for piece_index in pieces:
		edge_list.append(edges[int(piece_index)])
	_shell_fall(edge_list)
	facets.append({
		"a": run.start,
		"b": run.finish,
		"outward": outward,
		"length": run.start.distance_to(run.finish),
		"y": top,
		"ya": top,
		"yb": top,
		"cell": run.cell,
		"side": int(run.side),
		"run": pieces.size(),
	})

func _edge_profile(edge: Dictionary, corner: Vector2) -> Array:
	var cell: Vector2i = edge.cell
	var side := int(edge.side)
	var params := _group_params(cell, side)
	var top := float(edge.height)
	var bottom := float(_bottom_y.get(cell, top - 3.05))
	var sole := _sole_xz(cell, _corner_index(cell, corner))
	var lip := Vector3(corner.x, top, corner.y)
	var drop := float(params.drop)
	# Inland only. Depth changes by group; it never pushes a shelf past the lip.
	var shoulder_xz := corner.lerp(sole, float(params.depth))
	var shoulder := Vector3(shoulder_xz.x, top - drop, shoulder_xz.y)
	var wall_xz := Vector2(shoulder.x, shoulder.z)
	var wall_y := minf(shoulder.y - 0.9, top - 1.05)
	wall_y = maxf(wall_y, bottom + 1.15)
	var wall := Vector3(wall_xz.x, wall_y, wall_xz.y)
	var foot_xz := corner.lerp(sole, 0.62)
	var foot := Vector3(foot_xz.x, lerpf(wall_y, bottom, 0.58), foot_xz.y)
	var sole_p := Vector3(sole.x, bottom, sole.y)
	return [lip, shoulder, wall, foot, sole_p]

func _join_runs(run: Dictionary, other: Dictionary, last_edge: Dictionary, next_edge: Dictionary) -> void:
	var here: Array = _edge_profile(last_edge, last_edge.b)
	var there: Array = _edge_profile(next_edge, next_edge.a)
	var same_face := Vector2(run.outward).distance_to(Vector2(other.outward)) < 0.01
	var hint: Vector2 = Vector2(run.outward) + Vector2(other.outward)
	if hint.length_squared() < 0.0001:
		hint = run.outward
	if same_face:
		var cut := minf(float(run.height), float(other.height))
		for band in 4:
			_quad_below([here[band], there[band], there[band + 1], here[band + 1]], cut, hint)
		return
	_closed_wedge(run, other, last_edge, next_edge, here, there)

func _quad_below(points: Array, y_cut: float, outward: Vector2) -> void:
	var clipped: Array = _clip_below(points, y_cut)
	if clipped.size() < 3:
		return
	var uv := Vector2(y_cut, 1.0)
	var origin: Vector3 = clipped[0]
	for index in range(1, clipped.size() - 1):
		_flat_quad_tri(origin, clipped[index], clipped[index + 1], outward, uv)

func _clip_below(points: Array, y_cut: float) -> Array:
	var output: Array[Vector3] = []
	var count := points.size()
	for index in count:
		var current: Vector3 = points[index]
		var prev: Vector3 = points[(index + count - 1) % count]
		var current_in := current.y <= y_cut + 0.0001
		var prev_in := prev.y <= y_cut + 0.0001
		if current_in:
			if not prev_in:
				output.append(_cross_y(prev, current, y_cut))
			output.append(current)
		elif prev_in:
			output.append(_cross_y(prev, current, y_cut))
	return output

func _cross_y(a: Vector3, b: Vector3, y_cut: float) -> Vector3:
	var span := b.y - a.y
	if absf(span) < 0.000001:
		return Vector3(a.x, y_cut, a.z)
	var t := clampf((y_cut - a.y) / span, 0.0, 1.0)
	return a.lerp(b, t)

func _flat_quad_tri(a: Vector3, b: Vector3, c: Vector3, outward: Vector2, uv: Vector2) -> void:
	_tri_facing(surfaces.cliff, a, b, c, Vector3(outward.x, 0.0, outward.y), uv)

func _closed_wedge(run: Dictionary, other: Dictionary, last_edge: Dictionary, next_edge: Dictionary, here: Array, there: Array) -> void:
	var corner: Vector2 = last_edge.b
	var incoming: Vector2 = Vector2(run.finish) - Vector2(run.start)
	var outgoing: Vector2 = Vector2(other.finish) - Vector2(other.start)
	if incoming.length_squared() < 0.0001 or outgoing.length_squared() < 0.0001:
		return
	incoming = incoming.normalized()
	outgoing = outgoing.normalized()
	if incoming.cross(outgoing) <= 0.05:
		for band in 4:
			_flat_quad(surfaces.cliff, here[band], there[band], there[band + 1], here[band + 1], Vector2(run.outward) + Vector2(other.outward), Color.WHITE, Vector2(float(run.height), 1.0))
		return
	var reach := 0.42
	var bulge := 0.22
	var back := corner - incoming * reach + Vector2(run.outward) * bulge
	var fore := corner + outgoing * reach + Vector2(other.outward) * bulge
	var top := float(run.height)
	var sole_a: Vector3 = here[4]
	var sole_b: Vector3 = there[4]
	var hi_a := Vector3(back.x, top - 0.1, back.y)
	var hi_b := Vector3(fore.x, top - 0.1, fore.y)
	var lo_a := Vector3(back.x, sole_a.y, back.y)
	var lo_b := Vector3(fore.x, sole_b.y, fore.y)
	var hint := Vector2(run.outward) + Vector2(other.outward)
	var uv := Vector2(top, 1.0)
	_flat_quad(surfaces.cliff, hi_a, hi_b, lo_b, lo_a, hint, Color.WHITE, uv)
	_flat_quad(surfaces.cliff, here[0], hi_a, lo_a, sole_a, hint, Color.WHITE, uv)
	_flat_quad(surfaces.cliff, there[0], sole_b, lo_b, hi_b, hint, Color.WHITE, uv)
	_tri_facing(surfaces.cliff, here[0], hi_a, hi_b, Vector3(hint.x, 0.35, hint.y), uv)

func _close_bottoms() -> void:
	for cell: Vector2i in source.cells:
		var y := float(_bottom_y.get(cell, _top(source.cells[cell]) - 3.05))
		var poly := PackedVector2Array()
		var corners := _corners_of(cell)
		for corner_index in 4:
			poly.append(_sole_xz(cell, corner_index))
		_emit_down(poly, y)

func _emit_down(poly: PackedVector2Array, y: float) -> void:
	if poly.size() < 3:
		return
	var indices := Geometry2D.triangulate_polygon(poly)
	var uv := Vector2(y, -1.0)
	if indices.is_empty():
		return
	for index in range(0, indices.size(), 3):
		var a: Vector2 = poly[indices[index]]
		var b: Vector2 = poly[indices[index + 1]]
		var c: Vector2 = poly[indices[index + 2]]
		var pa := Vector3(a.x, y, a.y)
		var pb := Vector3(b.x, y, b.y)
		var pc := Vector3(c.x, y, c.y)
		var before: int = surfaces.cliff.vertices.size()
		_tri(surfaces.cliff, pa, pc, pb, Color.WHITE, uv, false)
		var after: int = surfaces.cliff.vertices.size()
		for vertex in range(before, after):
			surfaces.cliff.normals[vertex] = Vector3.DOWN
			surfaces.cliff.uv[vertex] = uv

func _sole_xz(cell: Vector2i, corner_index: int) -> Vector2:
	var corners := _corners_of(cell)
	var spot := Vector2(corners[corner_index])
	var prev_side := (corner_index + 3) % 4
	var next_side := corner_index
	var prev_open := not source.cells.has(cell + _offset(prev_side))
	var next_open := not source.cells.has(cell + _offset(next_side))
	var shift := Vector2.ZERO
	if prev_open:
		shift += Vector2(-_offset(prev_side)) * _inner_distance(cell, prev_side)
	if next_open:
		shift += Vector2(-_offset(next_side)) * _inner_distance(cell, next_side)
	if prev_open and next_open:
		var room := minf(_budget(cell, prev_side), _budget(cell, next_side))
		if shift.length() > room and shift.length_squared() > 0.000001:
			shift = shift.normalized() * room
	return spot + shift

func _inner_distance(cell: Vector2i, side: int) -> float:
	return _budget(cell, side) * 0.82

func _budget(cell: Vector2i, side: int) -> float:
	return minf(0.9, _edge_depth(cell, side) * 0.40)

func _edge_depth(cell: Vector2i, side: int) -> float:
	var key := "%d,%d,%d" % [cell.x, cell.y, side]
	if _depth_cache.has(key):
		return float(_depth_cache[key])
	var inward := Vector2(-_offset(side))
	var mid := _edge_midpoint(cell, side)
	var center := Vector2(cell) + Vector2(0.5, 0.5)
	var last := 0.0
	var dist := 0.12
	while dist < 6.0:
		var probe := mid + inward * dist
		if dist < 0.5:
			probe = probe * 0.72 + center * 0.28
		var owner := Vector2i(floori(probe.x), floori(probe.y))
		if not source.cells.has(owner):
			break
		last = dist
		dist += 0.1
	if last < 0.2:
		last = 0.45
	_depth_cache[key] = last
	return last

func _edge_midpoint(cell: Vector2i, side: int) -> Vector2:
	var ends := _corners_of(cell)
	return (Vector2(ends[side]) + Vector2(ends[(side + 1) % 4])) * 0.5

func _corner_index(cell: Vector2i, point: Vector2) -> int:
	var corners := _corners_of(cell)
	var best := 0
	var best_d := 1000.0
	for index in 4:
		var dist := Vector2(corners[index]).distance_to(point)
		if dist < best_d:
			best_d = dist
			best = index
	return best

func _group_params(cell: Vector2i, side: int) -> Dictionary:
	var along := cell.x if side % 2 == 0 else cell.y
	var fixed := cell.y if side % 2 == 0 else cell.x
	var origin := _group_origin_along(along, fixed, side)
	var key := "%d,%d,%d" % [origin, fixed, side]
	if _group_cache.has(key):
		return _group_cache[key]
	var params := {
		"key": key,
		"origin": origin,
		"fixed": fixed,
		"side": side,
		"depth": lerpf(0.08, 0.42, _unit(origin, fixed, 31 + side)),
		"drop": lerpf(0.34, 0.8, _unit(origin, fixed, 21 + side)),
		"vary": _unit(origin, fixed, 51 + side),
	}
	_group_cache[key] = params
	return params

func _group_origin_along(along: int, fixed: int, side: int) -> int:
	var cursor := -180
	var guard := 0
	while cursor <= along and guard < 420:
		guard += 1
		var length := 2 + int(floor(_unit(cursor, fixed, 17 + side) * 4.0))
		if along < cursor + length:
			return cursor
		cursor += length
	return along

func _successor_index(edges: Array[Dictionary], index: int) -> int:
	var edge: Dictionary = edges[index]
	var incoming: Vector2 = edge.b - edge.a
	var best := -1
	var best_sweep := 100.0
	var best_rank := 1 << 30
	for other_index in edges.size():
		if other_index == index:
			continue
		var other: Dictionary = edges[other_index]
		if Vector2(other.a).distance_to(Vector2(edge.b)) > 0.02:
			continue
		var outgoing: Vector2 = other.b - other.a
		var sweep := _ccw_sweep(incoming, outgoing)
		var rank: int = int(other.cell.x) * 4000 + int(other.cell.y) * 8 + int(other.side)
		if sweep < best_sweep - 0.0001 or (absf(sweep - best_sweep) <= 0.0001 and rank < best_rank):
			best_sweep = sweep
			best_rank = rank
			best = other_index
	return best

func _ccw_sweep(incoming: Vector2, outgoing: Vector2) -> float:
	var turn := atan2(outgoing.y, outgoing.x) - atan2(incoming.y, incoming.x)
	while turn < -0.0001:
		turn += TAU
	if turn < 0.0:
		turn = 0.0
	return turn

func _sparse_embeds(edges: Array[Dictionary]) -> void:
	var seen := {}
	for edge in edges:
		var params := _group_params(edge.cell, int(edge.side))
		var key: String = params.key
		if seen.has(key):
			continue
		seen[key] = true
		var host := 0
		for other in edges:
			var other_params := _group_params(other.cell, int(other.side))
			if String(other_params.key) == key:
				host += 1
		if host < 4:
			continue
		if float(params.vary) < 0.9:
			continue
		var mid := (Vector2(edge.a) + Vector2(edge.b)) * 0.5
		var outward: Vector2 = edge.outward
		var top := float(edge.height)
		var y := top - float(params.drop) - 0.55
		var tangent := Vector2(-outward.y, outward.x)
		var left := mid - tangent * 0.28 + outward * 0.02
		var right := mid + tangent * 0.28 + outward * 0.02
		var nose := mid + outward * 0.18
		var uv := Vector2(top, 1.0)
		_tri_facing(surfaces.cliff, Vector3(left.x, y, left.y), Vector3(right.x, y, right.y), Vector3(nose.x, y - 0.35, nose.y), Vector3(outward.x, 0.0, outward.y), uv)
		embeds.append({"cell": edge.cell, "side": int(edge.side), "host": host, "width": 0.56})

func _rim_key(point: Vector2, outward: Vector2, height: float) -> String:
	return "%d,%d,%d,%d,%d" % [roundi(point.x), roundi(point.y), roundi(outward.x), roundi(outward.y), roundi(height * 2.0)]

func _clip_plateaus(cell: Vector2i, top: float, polys: Array) -> Array:
	var current: Array = polys
	for plateau in _plateaus:
		var height: float = plateau.height
		var loop: PackedVector2Array = plateau.loop
		var next: Array = []
		if top >= height - 0.02:
			if not _has_lower_neighbor(cell):
				next = current
			else:
				var low := _lower_beside(cell, top)
				for poly in current:
					var shape: PackedVector2Array = poly
					for piece: PackedVector2Array in _intersect_one(shape, loop):
						next.append(piece)
					if _has_lower_neighbor(cell):
						for piece: PackedVector2Array in _difference(shape, loop):
							_emit_poly(surfaces.grass, piece, low, Color(1, 1, 1, 1), Vector2(0.0, 1.0))
		else:
			for poly in current:
				var shape: PackedVector2Array = poly
				for piece: PackedVector2Array in _difference(shape, loop):
					next.append(piece)
		current = next
	return current

func _terrace_bulges() -> void:
	# Where the terrace chord leaves the high cells, fill up to that chord so
	# the lip is the outline and the old stair becomes an internal edge.
	for plateau in _plateaus:
		var height: float = plateau.height
		var loop: PackedVector2Array = plateau.loop
		var count := loop.size()
		for index in count:
			var a: Vector2 = loop[index]
			var b: Vector2 = loop[(index + 1) % count]
			var outward := _edge_outward(a, b)
			if outward.length_squared() < 0.000001:
				continue
			var mid := (a + b) * 0.5
			var outside := _record_near(mid + outward * 0.45)
			if outside.is_empty() or height - _top(outside) < ROCK_RISE:
				continue
			var under := Vector2i(floori(mid.x), floori(mid.y))
			if source.cells.has(under) and _top(source.cells[under]) >= height - 0.02:
				continue
			var host := _nearest_high(mid - outward * 0.55, height)
			if host.x == 99999:
				continue
			var anchor := Vector2(host) + Vector2(0.5, 0.5)
			var tri := PackedVector2Array([anchor, a, b])
			for piece in _clip_to_rings(tri, grass_loops):
				var shape: PackedVector2Array = piece
				_emit_poly(surfaces.grass, shape, height, Color(1, 1, 1, 1), Vector2(0.0, 1.0))

func _bulges() -> void:
	for loop in grass_loops:
		var ring: PackedVector2Array = loop
		var count := ring.size()
		for index in count:
			var a: Vector2 = ring[index]
			var b: Vector2 = ring[(index + 1) % count]
			var mid := (a + b) * 0.5
			if source.cells.has(Vector2i(floori(mid.x), floori(mid.y))):
				continue
			var host := _nearest_cell(mid)
			if host.x == 99999:
				continue
			var record: Dictionary = source.cells[host]
			var top := _top(record)
			var anchor := Vector2(host) + Vector2(0.5, 0.5)
			if int(record.water) >= 0:
				var bed_color := Color(float(record.water) / 255.0, 0.0, 0.0, 1.0)
				_tri(surfaces.water, Vector3(anchor.x, top + 0.045, anchor.y), Vector3(a.x, top + 0.045, a.y), Vector3(b.x, top + 0.045, b.y), Color.WHITE, Vector2(top, 1.0), true)
				_tri(surfaces.lake_bed, Vector3(anchor.x, float(record.height), anchor.y), Vector3(a.x, float(record.height), a.y), Vector3(b.x, float(record.height), b.y), bed_color, Vector2(top, 0.0), true)
			else:
				_tri(surfaces.grass, Vector3(anchor.x, top, anchor.y), Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Color(1, 1, 1, 1), Vector2(0.0, 1.0), true)

func _grass_risers() -> void:
	for cell: Vector2i in source.cells:
		var record: Dictionary = source.cells[cell]
		var top := _top(record)
		for side in 4:
			var neighbor: Vector2i = cell + _offset(side)
			if not source.cells.has(neighbor):
				continue
			var drop := top - _top(source.cells[neighbor])
			if drop <= 0.04:
				continue
			var ends := _corners_of(cell)
			var a := Vector2(ends[side])
			var b := Vector2(ends[(side + 1) % 4])
			var low := _top(source.cells[neighbor])
			var outward := Vector2(_offset(side))
			var wet_edge := int(record.water) >= 0 or int(source.cells[neighbor].water) >= 0
			if drop >= ROCK_RISE or wet_edge:
				# The step is the shared cell edge. Its height is the cell delta,
				# including water's display level. Underwater basin sides stop at
				# the lower display level; transparent falls are separate overlays.
				_flat_quad(surfaces.cliff, Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(b.x, low, b.y), Vector3(a.x, low, a.y), outward, Color.WHITE, Vector2(top, 1.0))
			else:
				_flat_quad(surfaces.grass, Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), Vector3(b.x, low, b.y), Vector3(a.x, low, a.y), outward, Color(1, 1, 1, 1), Vector2(0.0, 1.0))

func _terrace_walls() -> void:
	for plateau in _plateaus:
		var height: float = plateau.height
		var loop: PackedVector2Array = plateau.loop
		var count := loop.size()
		for index in count:
			var a: Vector2 = loop[index]
			var b: Vector2 = loop[(index + 1) % count]
			var outward := _edge_outward(a, b)
			if outward.length_squared() < 0.000001:
				continue
			var mid := (a + b) * 0.5
			var outside: Dictionary = _record_near(mid + outward * 0.45)
			if outside.is_empty():
				continue
			var low := _top(outside)
			if height - low < ROCK_RISE:
				continue
			var lean := minf(0.22, (height - low) * 0.1)
			var inset_a := a - outward * lean
			var inset_b := b - outward * lean
			var uv := Vector2(height, 1.0)
			if a.distance_to(b) > 3.6:
				var mid_t := lerpf(0.38, 0.62, _unit(floori(a.x + b.x), floori(a.y + b.y), 71))
				var top_m := a.lerp(b, mid_t)
				var bot_m := inset_a.lerp(inset_b, mid_t) - outward * lerpf(0.0, 0.16, _unit(floori(top_m.x), floori(top_m.y), 73))
				var break_y := lerpf(low + (height - low) * 0.35, low + (height - low) * 0.62, _unit(floori(b.x), floori(a.y), 79))
				_flat_quad(surfaces.cliff, Vector3(a.x, height, a.y), Vector3(top_m.x, height, top_m.y), Vector3(bot_m.x, break_y, bot_m.y), Vector3(inset_a.x, low, inset_a.y), outward, Color.WHITE, uv)
				_flat_quad(surfaces.cliff, Vector3(top_m.x, height, top_m.y), Vector3(b.x, height, b.y), Vector3(inset_b.x, low, inset_b.y), Vector3(bot_m.x, break_y, bot_m.y), outward, Color.WHITE, uv)
			else:
				_flat_quad(surfaces.cliff, Vector3(a.x, height, a.y), Vector3(b.x, height, b.y), Vector3(inset_b.x, low, inset_b.y), Vector3(inset_a.x, low, inset_a.y), outward, Color.WHITE, uv)

func _cone() -> void:
	for loop in rim_loops:
		var ring: PackedVector2Array = loop
		var count := ring.size()
		if count < 3:
			continue
		var columns: Array = []
		var bisectors: Array = []
		var rooms: Array = []
		var heights: Array = []
		var leans: Array[float] = []
		for index in count:
			var point: Vector2 = ring[index]
			var bis := _bisector(ring, index)
			var edge_n := _edge_outward(ring[(index + count - 1) % count], point)
			if edge_n.length_squared() < 0.000001:
				edge_n = bis
			var lip_y := _height_near(point) - _lip_drop(point, bis)
			var total := maxf(lip_y - KEEL_Y, 0.8)
			var room := _room_along(point, -bis)
			var wobble := lerpf(0.86, 1.16, _unit(floori(point.x), floori(point.y), 17 + index))
			var lean := lerpf(0.84, 1.18, _unit(floori(point.x * 0.5), floori(point.y * 0.5), 19))
			var tangent := Vector2(-bis.y, bis.x)
			columns.append(_column(point, bis, edge_n, tangent, lip_y, total, room, wobble, lean, index))
			bisectors.append(bis)
			rooms.append(room)
			heights.append(lip_y)
			leans.append(lean)
		for index in count:
			var nxt := (index + 1) % count
			var left: Array = columns[index]
			var right: Array = columns[nxt]
			var a: Vector2 = ring[index]
			var b: Vector2 = ring[nxt]
			var outward := _edge_outward(a, b)
			var ya: float = heights[index]
			var yb: float = heights[nxt]
			var bands := mini(left.size(), right.size())
			for band in bands - 1:
				var la: Vector3 = left[band]
				var ra: Vector3 = right[band]
				var rb: Vector3 = right[band + 1]
				var lb: Vector3 = left[band + 1]
				var uv := Vector2(maxf(ya, yb), 1.0)
				if a.distance_to(b) > 3.3 and _unit(index * 5 + band, floori(a.x + b.y), 61) > 0.38:
					var push := lerpf(0.18, 0.42, _unit(index + band, floori(b.x - a.y), 67))
					_bulged_quad(surfaces.cliff, la, ra, rb, lb, outward, uv, push)
				else:
					_flat_quad(surfaces.cliff, la, ra, rb, lb, outward, Color.WHITE, uv)
			var lip := (Vector2(left[0].x, left[0].z) + Vector2(right[0].x, right[0].z)) * 0.5
			var keel := (Vector2(left[left.size() - 1].x, left[left.size() - 1].z) + Vector2(right[right.size() - 1].x, right[right.size() - 1].z)) * 0.5
			var band_xz: Array = []
			for band in bands:
				var sample: Vector3 = left[band]
				var other: Vector3 = right[band]
				band_xz.append((Vector2(sample.x, sample.z) + Vector2(other.x, other.z)) * 0.5)
			var mid := (a + b) * 0.5 - outward * 0.35
			var owner := _nearest_cell(mid)
			var moved := (lip - keel).dot(outward)
			_inset_sum += maxf(moved, 0.0)
			_inset_count += 1
			facets.append({
				"a": a,
				"b": b,
				"outward": outward,
				"length": a.distance_to(b),
				"y": (ya + yb) * 0.5,
				"ya": ya,
				"yb": yb,
				"lip": lip,
				"keel": keel,
				"band_xz": band_xz,
				"bis_a": bisectors[index],
				"bis_b": bisectors[nxt],
				"room_a": rooms[index],
				"room_b": rooms[nxt],
				"lean_a": leans[index],
				"lean_b": leans[nxt],
				"cell": owner,
				"side": _side_of(outward),
			})
		var cap := PackedVector2Array()
		for column in columns:
			var pts: Array = column
			var last: Vector3 = pts[pts.size() - 1]
			cap.append(Vector2(last.x, last.z))
		_emit_cap(cap)

func _shell_fall(run: Array[Dictionary]) -> void:
	# Rock faces can merge dry and wet cells at the same display height.
	# Water outlets must keep the actual contiguous wet source-edge runs.
	var first := -1
	for index in range(run.size() + 1):
		var wet := false
		if index < run.size():
			var edge: Dictionary = run[index]
			var cell: Vector2i = edge.cell
			wet = int(source.cells[cell].water) >= 0 and not source.cells.has(cell + _offset(int(edge.side)))
		if wet:
			if first < 0:
				first = index
		elif first >= 0:
			var start: Dictionary = run[first]
			var finish: Dictionary = run[index - 1]
			_outer_fall(start.a, finish.b, start.outward, float(start.height))
			first = -1

func _outer_fall(a: Vector2, b: Vector2, outward: Vector2, lip_y: float) -> void:
	# Keep a small rock shoulder at each outlet without extending over dry
	# source edges. Its destination is open space, never a nearest land cell.
	var length := a.distance_to(b)
	if length <= 0.0001:
		return
	var inset := minf(0.16, length * 0.16) / length
	var a2 := a.lerp(b, inset)
	var b2 := a.lerp(b, 1.0 - inset)
	var dest := lip_y - 3.3
	var n := Vector3(outward.x, 0.0, outward.y)
	var lip_a := Vector3(a2.x, lip_y + 0.04, a2.y) + n * 0.06
	var lip_b := Vector3(b2.x, lip_y + 0.04, b2.y) + n * 0.06
	var foot_a := Vector3(a2.x, dest, a2.y) + n * 0.42
	var foot_b := Vector3(b2.x, dest, b2.y) + n * 0.42
	_flat_quad(surfaces.waterfall, lip_a, lip_b, foot_b, foot_a, outward, Color.WHITE, Vector2(lip_y, 1.0))
	var lip := (lip_a + lip_b) * 0.5
	var foot := (foot_a + foot_b) * 0.5
	var half := a2.distance_to(b2) * 0.5
	fall_veils.append({"lip": lip, "foot": foot, "half_width": half, "out": outward, "external": true})
	splash_points.append({"center": foot, "out": outward, "half_width": half})

func _interior_hydro() -> void:
	for cell: Vector2i in source.cells:
		var record: Dictionary = source.cells[cell]
		if int(record.water) < 0:
			continue
		for side in 4:
			var neighbor: Vector2i = cell + _offset(side)
			if not source.cells.has(neighbor):
				continue
			if _spills(cell, side):
				_fall(cell, side)
			else:
				_basin(cell, side)

func _fall(cell: Vector2i, side: int) -> void:
	var here := _top(source.cells[cell]) + 0.04
	var outward := Vector2(_offset(side))
	var ends := _corners_of(cell)
	var a2 := Vector2(ends[side]).lerp(Vector2(ends[(side + 1) % 4]), 0.16)
	var b2 := Vector2(ends[side]).lerp(Vector2(ends[(side + 1) % 4]), 0.84)
	var neighbor: Vector2i = cell + _offset(side)
	var dest := _top(source.cells[neighbor]) + 0.06
	var n := Vector3(outward.x, 0.0, outward.y)
	var lip_a := Vector3(a2.x, here, a2.y) + n * 0.04
	var lip_b := Vector3(b2.x, here, b2.y) + n * 0.04
	var foot_a := Vector3(a2.x, dest, a2.y) + n * 0.16
	var foot_b := Vector3(b2.x, dest, b2.y) + n * 0.16
	_flat_quad(surfaces.waterfall, lip_a, lip_b, foot_b, foot_a, outward, Color.WHITE, Vector2(here, 1.0))
	var lip := (lip_a + lip_b) * 0.5
	var foot := (foot_a + foot_b) * 0.5
	fall_veils.append({"lip": lip, "foot": foot, "half_width": 0.46, "out": outward, "external": false})
	splash_points.append({"center": foot, "out": outward, "half_width": 0.46})

func _basin(cell: Vector2i, side: int) -> void:
	var record: Dictionary = source.cells[cell]
	var lip := _top(record)
	var bed := float(record.height)
	if lip - bed < 0.08:
		return
	var neighbor: Dictionary = source.cells[cell + _offset(side)]
	if int(neighbor.water) >= 0 and float(neighbor.height) <= bed + 0.04:
		return
	var outward := Vector2(_offset(side))
	var ends := _corners_of(cell)
	var a := Vector2(ends[side])
	var b := Vector2(ends[(side + 1) % 4])
	var color := Color(float(record.water) / 255.0, 0.0, 0.0, 1.0)
	_flat_quad(surfaces.lake_bed, Vector3(a.x, lip, a.y), Vector3(b.x, lip, b.y), Vector3(b.x, bed, b.y), Vector3(a.x, bed, a.y), outward, color, Vector2(lip, 0.0))

func _embeds() -> void:
	for facet in facets:
		var length: float = facet.length
		if length < 2.15:
			continue
		var cell: Vector2i = facet.cell
		if cell.x == 99999:
			continue
		var side: int = facet.side
		if _unit(cell.x, cell.y, 90 + side) < 0.70:
			continue
		if _facet_spills(cell, facet.outward):
			continue
		var outward: Vector2 = facet.outward
		var ya: float = facet.ya
		var yb: float = facet.yb
		var depth := lerpf(1.7, 2.7, _unit(cell.x, cell.y, 91 + side))
		var total := maxf(maxf(ya, yb) - KEEL_Y, 0.8)
		depth = clampf(depth, 1.15, total - 0.35)
		var a: Vector2 = facet.a
		var b: Vector2 = facet.b
		var along := lerpf(0.38, 0.62, _unit(cell.x, cell.y, 92 + side))
		var origin := _facet_point(facet, along, depth)
		var width := lerpf(0.85, 1.45, _unit(cell.x, cell.y, 93 + side))
		var height := lerpf(0.48, 1.05, _unit(cell.x, cell.y, 94 + side))
		var protrude := lerpf(0.16, 0.40, _unit(cell.x, cell.y, 95 + side))
		var n := Vector3(outward.x, 0.0, outward.y)
		var tangent := Vector3(-outward.y, 0.0, outward.x)
		var front := origin + n * protrude
		var back := origin - n * 0.22
		var up := Vector3.UP * height * 0.5
		var side_v := tangent * width * 0.5
		var uv := Vector2(maxf(ya, yb), 1.0)
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

func _emit_cap(poly: PackedVector2Array) -> void:
	if poly.size() < 3:
		return
	var indices := Geometry2D.triangulate_polygon(poly)
	if indices.is_empty():
		var center2 := Vector2.ZERO
		for point in poly:
			center2 += point
		center2 /= float(poly.size())
		var center := Vector3(center2.x, KEEL_Y, center2.y)
		for index in poly.size():
			var a: Vector2 = poly[index]
			var b: Vector2 = poly[(index + 1) % poly.size()]
			_tri(surfaces.cliff, center, Vector3(b.x, KEEL_Y, b.y), Vector3(a.x, KEEL_Y, a.y), Color.WHITE, Vector2(KEEL_Y, -1.0), false)
		return
	for index in range(0, indices.size(), 3):
		var a: Vector2 = poly[indices[index]]
		var b: Vector2 = poly[indices[index + 1]]
		var c: Vector2 = poly[indices[index + 2]]
		_tri(surfaces.cliff, Vector3(a.x, KEEL_Y, a.y), Vector3(c.x, KEEL_Y, c.y), Vector3(b.x, KEEL_Y, b.y), Color.WHITE, Vector2(KEEL_Y, -1.0), false)

func _column(point: Vector2, bis: Vector2, edge_n: Vector2, tangent: Vector2, rim_y: float, total: float, room: float, wobble: float, lean: float, salt: int) -> Array:
	# Four shared samples so neighbors meet. The two middle breaks wander,
	# and the seam leans as it drops, so the wall is not a stack of rings.
	var upper := clampf(lerpf(0.55, minf(3.8, total * 0.58), _unit(floori(point.x), floori(point.y), 43 + salt)), 0.45, total * 0.7)
	var lower := clampf(lerpf(upper + 1.1, minf(upper + 3.4, total * 0.86), _unit(floori(point.y), floori(point.x), 47 + salt)), upper + 0.8, maxf(total - 0.15, upper + 0.4))
	var depths: Array[float] = [0.0, upper, lower, total]
	var sway := lerpf(-0.55, 0.55, _unit(floori(point.x * 2.0), floori(point.y * 2.0), 41 + salt))
	var column: Array = []
	for depth in depths:
		var along := tangent * sway * (depth / maxf(total, 0.8))
		var placed := _inset_point(point, bis, edge_n, rim_y, depth, room, lean)
		column.append(placed + Vector3(along.x, 0.0, along.y))
	return column

func _inset_point(point: Vector2, bis: Vector2, edge_n: Vector2, rim_y: float, depth: float, room: float, lean: float) -> Vector3:
	var denom := maxf(bis.dot(edge_n), 0.42)
	var target := wall_inset(depth) * lean
	var used := minf(target, room * denom)
	var scale := clampf(used / denom, 0.0, room)
	scale = minf(scale, target * 1.35)
	var xz := point - bis * scale
	return Vector3(xz.x, rim_y - depth, xz.y)

func _facet_point(facet: Dictionary, along: float, depth: float) -> Vector3:
	var a: Vector2 = facet.a
	var b: Vector2 = facet.b
	var bis_a: Vector2 = facet.bis_a
	var bis_b: Vector2 = facet.bis_b
	var ya: float = facet.ya
	var yb: float = facet.yb
	var edge_n: Vector2 = facet.outward
	var left := _inset_point(a, bis_a, edge_n, ya, depth, float(facet.room_a), float(facet.lean_a))
	var right := _inset_point(b, bis_b, edge_n, yb, depth, float(facet.room_b), float(facet.lean_b))
	return left.lerp(right, along)

func _point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var span := b - a
	var denom := span.length_squared()
	if denom < 0.000001:
		return point.distance_to(a)
	var weight := clampf((point - a).dot(span) / denom, 0.0, 1.0)
	return point.distance_to(a + span * weight)

func _segment_weight(point: Vector2, a: Vector2, b: Vector2) -> float:
	var span := b - a
	var denom := span.length_squared()
	if denom < 0.000001:
		return 0.0
	return (point - a).dot(span) / denom

func _lip_metrics(point: Vector2, bis: Vector2) -> Dictionary:
	var room := _room_along(point, -bis)
	var width := 0.0
	var drop := 0.0
	if room >= 0.22:
		width = minf(0.05 + _unit(floori(point.x * 2.0), floori(point.y * 2.0), 31) * 0.06, room * 0.16)
		if width < 0.04:
			width = 0.0
		else:
			drop = 0.04 * (width / 0.08)
	return {"width": width, "drop": drop, "inner": point - bis * width}

func _inset_ring(loop: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for index in loop.size():
		var point: Vector2 = loop[index]
		var metrics: Dictionary = _lip_metrics(point, _bisector(loop, index))
		out.append(metrics.inner as Vector2)
	return out

func _lip_drop(point: Vector2, bis: Vector2) -> float:
	return float(_lip_metrics(point, bis).drop)

func _lip_bevel() -> void:
	var rings := mini(rim_loops.size(), grass_loops.size())
	for ring_index in rings:
		var outer: PackedVector2Array = rim_loops[ring_index]
		var inner: PackedVector2Array = grass_loops[ring_index]
		if outer.size() != inner.size() or outer.size() < 3:
			continue
		var count := outer.size()
		for index in count:
			var nxt := (index + 1) % count
			var outer_a: Vector2 = outer[index]
			var outer_b: Vector2 = outer[nxt]
			var inner_a: Vector2 = inner[index]
			var inner_b: Vector2 = inner[nxt]
			if outer_a.distance_to(inner_a) < 0.05 and outer_b.distance_to(inner_b) < 0.05:
				continue
			var outward := _edge_outward(outer_a, outer_b)
			if outward.length_squared() < 0.000001:
				continue
			var ya := _height_near(outer_a)
			var yb := _height_near(outer_b)
			var drop_a := _lip_drop(outer_a, _bisector(outer, index))
			var drop_b := _lip_drop(outer_b, _bisector(outer, nxt))
			var grass_a := _height_near(inner_a)
			var grass_b := _height_near(inner_b)
			_flat_quad(surfaces.cliff, Vector3(outer_a.x, ya - drop_a, outer_a.y), Vector3(outer_b.x, yb - drop_b, outer_b.y), Vector3(inner_b.x, grass_b, inner_b.y), Vector3(inner_a.x, grass_a, inner_a.y), outward, Color.WHITE, Vector2(maxf(ya, yb), 1.0))

func _prepare_loop(raw: PackedVector2Array, rugged: bool) -> PackedVector2Array:
	# Douglas-Peucker removes stair wiggles first. The outer ring is then
	# resampled along that clean arc into wide panels. No second Chaikin.
	var guide := _dedupe(raw)
	if guide.size() < 3:
		return guide
	if Contours._area(guide) < 0.0:
		guide.reverse()
	var perimeter := _perimeter(guide)
	if perimeter < 18.0 or guide.size() < 10:
		return guide
	var loop := _dp_closed(guide, 1.05)
	if rugged:
		loop = _panelize(loop, guide)
		loop = _collapse_slivers(loop, 2.7)
		loop = _ruggedize(loop)
		loop = _dedupe(loop)
		loop = _collapse_slivers(loop, 2.35)
	else:
		loop = _split_long(loop, guide)
		loop = _collapse_slivers(loop, 3.0)
	return loop

func _dp_closed(loop: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	var count := loop.size()
	var start := 0
	var best_turn := -1.0
	for index in count:
		var turn := _turn(loop[(index + count - 1) % count], loop[index], loop[(index + 1) % count])
		if turn > best_turn:
			best_turn = turn
			start = index
	var open := PackedVector2Array()
	for index in count:
		open.append(loop[(start + index) % count])
	open.append(loop[start])
	var simplified := _dp_open(open, epsilon)
	if simplified.size() > 1 and simplified[0].distance_squared_to(simplified[simplified.size() - 1]) < 0.0001:
		simplified.remove_at(simplified.size() - 1)
	return simplified if simplified.size() >= 3 else loop


func _dp_open(pts: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var max_d := 0.0
	var index := 0
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[pts.size() - 1]
	for i in range(1, pts.size() - 1):
		var dist := _point_segment_distance(pts[i], a, b)
		if dist > max_d:
			max_d = dist
			index = i
	if max_d <= epsilon:
		var ends := PackedVector2Array()
		ends.append(a)
		ends.append(b)
		return ends
	var left := _dp_open(pts.slice(0, index + 1), epsilon)
	var right := _dp_open(pts.slice(index, pts.size()), epsilon)
	var out := left.slice(0, left.size() - 1)
	out.append_array(right)
	return out


func _split_long(loop: PackedVector2Array, guide: PackedVector2Array) -> PackedVector2Array:
	# Long chords become several hard faces only along their own contour arc.
	# A point elsewhere on the island must not be pulled in as a shortcut.
	var blocked := {}
	var guard := 0
	while loop.size() < 42 and guard < 80:
		guard += 1
		var count := loop.size()
		var edge := -1
		var longest := 0.0
		for index in count:
			if blocked.has(index):
				continue
			var length := loop[index].distance_to(loop[(index + 1) % count])
			var limit := lerpf(4.0, 6.0, _unit(index * 5 + count, int(roundf(loop[index].x + loop[index].y)), 11))
			if length > limit and length > longest:
				longest = length
				edge = index
		if edge < 0:
			break
		var a: Vector2 = loop[edge]
		var b: Vector2 = loop[(edge + 1) % count]
		var best_d := 0.20
		var best := Vector2.ZERO
		var found := false
		for point in _arc_between(guide, a, b):
			var weight := _segment_weight(point, a, b)
			if weight < 0.22 or weight > 0.78:
				continue
			if minf(weight, 1.0 - weight) * longest < 3.05:
				continue
			var dist := _point_segment_distance(point, a, b)
			if dist > best_d:
				best_d = dist
				best = point
				found = true
		if not found:
			blocked[edge] = true
			continue
		loop.insert(edge + 1, best)
		blocked.clear()
	return loop

func _arc_between(guide: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	var count := guide.size()
	var arc := PackedVector2Array()
	if count == 0:
		return arc
	var start := _nearest_index(guide, a)
	var end := _nearest_index(guide, b)
	var index := start
	for _step in count + 1:
		arc.append(guide[index])
		if index == end:
			break
		index = (index + 1) % count
	return arc

func _nearest_index(loop: PackedVector2Array, point: Vector2) -> int:
	var best := 0
	var best_d := INF
	for index in loop.size():
		var dist := loop[index].distance_squared_to(point)
		if dist < best_d:
			best_d = dist
			best = index
	return best

func _panelize(loop: PackedVector2Array, guide: PackedVector2Array) -> PackedVector2Array:
	# After the stairs are gone, every long side becomes several wide faces.
	# Samples stay on the smooth arc, so the lip does not snap back to the grid.
	var out := PackedVector2Array()
	var count := loop.size()
	for index in count:
		var a: Vector2 = loop[index]
		var b: Vector2 = loop[(index + 1) % count]
		out.append(a)
		var arc := _arc_between(guide, a, b)
		if arc.size() < 3:
			continue
		var lengths := _arc_lengths(arc)
		var total := float(lengths[lengths.size() - 1])
		var chord := a.distance_to(b)
		var span := maxf(chord, total)
		var cap := int(floor(span / 3.6))
		if cap < 2:
			continue
		var target := lerpf(3.8, 5.6, _unit(index * 7 + count, int(roundf(a.x * 3.0 + a.y)), 11))
		var pieces := clampi(mini(int(round(span / target)), cap), 2, 6)
		var outward := _edge_outward(a, b)
		var last := a
		for step in range(1, pieces):
			var jitter := lerpf(-0.06, 0.06, _unit(index * 13 + step, int(roundf(b.y - b.x)), 23))
			var dist := clampf((float(step) + jitter) / float(pieces) * total, 0.0, total)
			var point := _sample_arc(arc, lengths, dist)
			if _point_segment_distance(point, a, b) < 0.12 and outward.length_squared() > 0.5:
				var amp := lerpf(0.1, 0.24, _unit(index * 17 + step, floori(point.x + point.y), 29))
				point += outward * amp
			if _on_lattice(point):
				point += outward * 0.16
			if last.distance_to(point) < 3.05 or point.distance_to(b) < 3.05:
				continue
			out.append(point)
			last = point
	return out

func _arc_lengths(arc: PackedVector2Array) -> PackedFloat32Array:
	var lengths := PackedFloat32Array()
	lengths.append(0.0)
	for index in range(1, arc.size()):
		lengths.append(lengths[index - 1] + arc[index - 1].distance_to(arc[index]))
	return lengths

func _sample_arc(arc: PackedVector2Array, lengths: PackedFloat32Array, distance: float) -> Vector2:
	for index in range(1, arc.size()):
		if lengths[index] + 0.00001 >= distance:
			var span := lengths[index] - lengths[index - 1]
			var weight := 0.0 if span < 0.0001 else (distance - lengths[index - 1]) / span
			return arc[index - 1].lerp(arc[index], clampf(weight, 0.0, 1.0))
	return arc[arc.size() - 1]

func _on_lattice(point: Vector2) -> bool:
	return absf(point.x - roundf(point.x)) < 0.1 and absf(point.y - roundf(point.y)) < 0.1

func _ruggedize(loop: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := loop.size()
	for index in count:
		var point: Vector2 = loop[index]
		var outward := _bisector(loop, index)
		var jag := _unit(index * 5 + floori(point.x), floori(point.y * 2.0), 21) - 0.5
		var wave := sin(point.x * 0.37 + point.y * 0.29 + float(seed) * 0.01)
		out.append(point + outward * (0.22 * jag + 0.05 * wave))
	return out

func _collapse_slivers(loop: PackedVector2Array, minimum: float) -> PackedVector2Array:
	var blocked := {}
	var guard := 0
	while loop.size() > 8 and guard < 100:
		guard += 1
		var count := loop.size()
		var edge := -1
		var shortest := minimum
		for index in count:
			if blocked.has(index):
				continue
			var length := loop[index].distance_to(loop[(index + 1) % count])
			if length < shortest:
				shortest = length
				edge = index
		if edge < 0:
			break
		var right := (edge + 1) % count
		var left_error := _chord_error(loop, edge)
		var right_error := _chord_error(loop, right)
		if shortest >= 2.2 and minf(left_error, right_error) > 1.15:
			blocked[edge] = true
			continue
		loop.remove_at(edge if left_error <= right_error else right)
		blocked.clear()
	return loop

func _chord_error(loop: PackedVector2Array, index: int) -> float:
	var count := loop.size()
	var prev: Vector2 = loop[(index + count - 1) % count]
	var point: Vector2 = loop[index]
	var next: Vector2 = loop[(index + 1) % count]
	var span := next - prev
	var denom := span.length_squared()
	if denom < 0.000001:
		return point.distance_to(prev)
	var weight := clampf((point - prev).dot(span) / denom, 0.0, 1.0)
	return point.distance_to(prev + span * weight)

func _clip_loops(square: PackedVector2Array, loops: Array, keep_inside: bool) -> Array:
	var acc: Array = []
	for loop in loops:
		var ring: PackedVector2Array = loop
		if keep_inside:
			for piece: PackedVector2Array in _intersect_one(square, ring):
				acc.append(piece)
		else:
			for piece: PackedVector2Array in _difference(square, ring):
				acc.append(piece)
	if acc.is_empty() and keep_inside:
		var center := (square[0] + square[2]) * 0.5
		for loop in loops:
			var ring: PackedVector2Array = loop
			if Geometry2D.is_point_in_polygon(center, ring):
				acc.append(square)
				break
	return acc

func _inside_loops(point: Vector2, loops: Array) -> bool:
	for loop in loops:
		var ring: PackedVector2Array = loop
		if ring.size() >= 3 and Geometry2D.is_point_in_polygon(point, ring):
			return true
	return false

func _clip_to_rings(square: PackedVector2Array, loops: Array) -> Array:
	if loops.is_empty():
		return [square]
	var acc: Array = []
	var crosses := false
	for loop in loops:
		var ring: PackedVector2Array = loop
		for corner in square:
			if not Geometry2D.is_point_in_polygon(corner, ring):
				crosses = true
				break
		if crosses:
			break
	if not crosses:
		return [square]
	for loop in loops:
		var ring: PackedVector2Array = loop
		for piece: PackedVector2Array in _intersect_one(square, ring):
			acc.append(piece)
	return acc


func _intersect_one(poly: PackedVector2Array, loop: PackedVector2Array) -> Array:
	var pieces: Array = []
	if poly.size() < 3 or loop.size() < 3:
		return pieces
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(poly, loop):
		if piece.size() >= 3:
			pieces.append(piece)
	# A failed clip must not restore a square that hangs past the ring.
	if pieces.is_empty():
		var outside := false
		for corner in poly:
			if not Geometry2D.is_point_in_polygon(corner, loop):
				outside = true
				break
		if not outside:
			pieces.append(poly)
	return pieces

func _difference(poly: PackedVector2Array, loop: PackedVector2Array) -> Array:
	var pieces: Array = []
	if poly.size() < 3 or loop.size() < 3:
		pieces.append(poly)
		return pieces
	for piece: PackedVector2Array in Geometry2D.clip_polygons(poly, loop):
		if piece.size() >= 3:
			pieces.append(piece)
	if pieces.is_empty():
		var center := _centroid(poly)
		if not Geometry2D.is_point_in_polygon(center, loop):
			pieces.append(poly)
	return pieces

func _emit_poly(surface, poly: PackedVector2Array, y: float, color: Color, uv: Vector2) -> void:
	if poly.size() < 3:
		return
	var indices := Geometry2D.triangulate_polygon(poly)
	if indices.is_empty():
		var center2 := _centroid(poly)
		var center := Vector3(center2.x, y, center2.y)
		for index in poly.size():
			var a: Vector2 = poly[index]
			var b: Vector2 = poly[(index + 1) % poly.size()]
			_tri(surface, center, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), color, uv, true)
		return
	for index in range(0, indices.size(), 3):
		var a: Vector2 = poly[indices[index]]
		var b: Vector2 = poly[indices[index + 1]]
		var c: Vector2 = poly[indices[index + 2]]
		_tri(surface, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), color, uv, true)

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
			# Source edges keep water on their left. Preserve hole winding so
			# consumers' right-hand outward normal points toward the dry bank.
			loops.append(points)
	return loops

func _index() -> void:
	triangle_chunks.clear()
	shell_triangles = 0
	for kind in surfaces:
		shell_triangles += surfaces[kind].vertices.size() / 3
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

func _room_along(xz: Vector2, inward: Vector2) -> float:
	if inward.length_squared() < 0.000001:
		return 0.16
	var dir := inward.normalized()
	var reached := 0.0
	for step in range(1, 28):
		var probe := xz + dir * (float(step) * 0.45)
		if not source.cells.has(Vector2i(floori(probe.x), floori(probe.y))):
			break
		reached = float(step) * 0.45
	return clampf(reached * 0.45, 0.16, 5.4)

func _bisector(loop: PackedVector2Array, index: int) -> Vector2:
	var count := loop.size()
	var prev: Vector2 = loop[(index + count - 1) % count]
	var point: Vector2 = loop[index]
	var next: Vector2 = loop[(index + 1) % count]
	var d0 := point - prev
	var d1 := next - point
	if d0.length_squared() < 0.000001 or d1.length_squared() < 0.000001:
		var fallback := d1 if d0.length_squared() < 0.000001 else d0
		if fallback.length_squared() < 0.000001:
			return Vector2.RIGHT
		fallback = fallback.normalized()
		return Vector2(fallback.y, -fallback.x)
	d0 = d0.normalized()
	d1 = d1.normalized()
	var n0 := Vector2(d0.y, -d0.x)
	var n1 := Vector2(d1.y, -d1.x)
	var bis := n0 + n1
	if bis.length_squared() < 0.0001:
		return n0
	return bis.normalized()

func _edge_outward(a: Vector2, b: Vector2) -> Vector2:
	var dir := b - a
	if dir.length_squared() < 0.000001:
		return Vector2.ZERO
	dir = dir.normalized()
	return Vector2(dir.y, -dir.x)

func _turn(a: Vector2, b: Vector2, c: Vector2) -> float:
	var left := b - a
	var right := c - b
	if left.length_squared() < 0.000001 or right.length_squared() < 0.000001:
		return 0.0
	left = left.normalized()
	right = right.normalized()
	return absf(atan2(left.cross(right), left.dot(right)))

func _perimeter(loop: PackedVector2Array) -> float:
	var total := 0.0
	for index in loop.size():
		total += loop[index].distance_to(loop[(index + 1) % loop.size()])
	return total

func _dedupe(loop: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in loop:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(point) > 0.0004:
			out.append(point)
	if out.size() > 1 and out[0].distance_squared_to(out[out.size() - 1]) < 0.0004:
		out.remove_at(out.size() - 1)
	return out

func _centroid(poly: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in poly:
		center += point
	return center / float(maxi(poly.size(), 1))

func _square(cell: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(float(cell.x), float(cell.y)),
		Vector2(float(cell.x + 1), float(cell.y)),
		Vector2(float(cell.x + 1), float(cell.y + 1)),
		Vector2(float(cell.x), float(cell.y + 1)),
	])

func _open_side(cell: Vector2i) -> bool:
	for side in 4:
		if not source.cells.has(cell + _offset(side)):
			return true
	return false

func _has_lower_neighbor(cell: Vector2i) -> bool:
	var top := _top(source.cells[cell])
	for side in 4:
		var neighbor: Vector2i = cell + _offset(side)
		if source.cells.has(neighbor) and top - _top(source.cells[neighbor]) >= ROCK_RISE:
			return true
	return false

func _has_higher_neighbor(cell: Vector2i) -> bool:
	var top := _top(source.cells[cell])
	for side in 4:
		var neighbor: Vector2i = cell + _offset(side)
		if source.cells.has(neighbor) and _top(source.cells[neighbor]) - top >= ROCK_RISE:
			return true
	return false

func _lower_beside(cell: Vector2i, top: float) -> float:
	var best := top
	var found := false
	for side in 4:
		var neighbor: Vector2i = cell + _offset(side)
		if not source.cells.has(neighbor):
			continue
		var height := _top(source.cells[neighbor])
		if top - height < ROCK_RISE:
			continue
		if not found or height > best:
			best = height
			found = true
	return best if found else top - ROCK_RISE

func _height_near(point: Vector2) -> float:
	var record := _record_near(point)
	if record.is_empty():
		return 1.5
	return _top(record)

func _record_near(point: Vector2) -> Dictionary:
	var cell := Vector2i(floori(point.x), floori(point.y))
	if source.cells.has(cell):
		return source.cells[cell]
	var host := _nearest_cell(point)
	if host.x == 99999:
		return {}
	return source.cells[host]

func _nearest_high(point: Vector2, height: float) -> Vector2i:
	var best := Vector2i(99999, 99999)
	var best_d := INF
	var base := Vector2i(floori(point.x), floori(point.y))
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var cell := base + Vector2i(dx, dz)
			if not source.cells.has(cell) or _top(source.cells[cell]) < height - 0.02:
				continue
			var distance := point.distance_squared_to(Vector2(cell) + Vector2(0.5, 0.5))
			if distance < best_d:
				best_d = distance
				best = cell
	return best

func _nearest_cell(point: Vector2) -> Vector2i:
	var best := Vector2i(99999, 99999)
	var best_d := INF
	var base := Vector2i(floori(point.x), floori(point.y))
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			var cell := base + Vector2i(dx, dz)
			if not source.cells.has(cell):
				continue
			var distance := point.distance_squared_to(Vector2(cell) + Vector2(0.5, 0.5))
			if distance < best_d:
				best_d = distance
				best = cell
	return best

func _facet_spills(cell: Vector2i, outward: Vector2) -> bool:
	if not source.cells.has(cell):
		return false
	var record: Dictionary = source.cells[cell]
	if int(record.water) < 0:
		return false
	var ahead := Vector2(cell) + Vector2(0.5, 0.5) + outward * 1.15
	var neighbor := Vector2i(floori(ahead.x), floori(ahead.y))
	if not source.cells.has(neighbor):
		return true
	return _top(record) - _top(source.cells[neighbor]) > 0.35

func _side_of(outward: Vector2) -> int:
	if absf(outward.x) >= absf(outward.y):
		return 1 if outward.x >= 0.0 else 3
	return 2 if outward.y >= 0.0 else 0

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

func _bulged_quad(surface, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector2, uv: Vector2, push: float) -> void:
	var center := (a + b + c + d) * 0.25
	center += Vector3(outward.x, 0.15, outward.y) * push
	var hint := Vector3(outward.x, 0.0, outward.y)
	_tri_facing(surface, a, b, center, hint, uv)
	_tri_facing(surface, b, c, center, hint, uv)
	_tri_facing(surface, c, d, center, hint, uv)
	_tri_facing(surface, d, a, center, hint, uv)

func _flat_quad(surface, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector2, color: Color, uv: Vector2) -> void:
	var before: int = surface.vertices.size()
	_quad(surface, a, b, c, d, outward, color, uv)
	var after: int = surface.vertices.size()
	if after <= before + 2:
		return
	var origin: Vector3 = surface.vertices[before]
	var left: Vector3 = surface.vertices[before + 1]
	var right: Vector3 = surface.vertices[before + 2]
	var normal := -(left - origin).cross(right - origin)
	if normal.length_squared() < 0.00000001:
		return
	normal = normal.normalized()
	if uv.y < -0.5 and normal.y > 0.0:
		normal = -normal
	for index in range(before, after):
		surface.normals[index] = normal

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
