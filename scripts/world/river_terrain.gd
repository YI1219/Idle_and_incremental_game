class_name RiverTerrain
extends Node3D
## Sparse island top with a smooth, eight-neighbour river and walkable bridge.

const Blob47 := preload("res://scripts/world/blob47.gd")
const WATER_DROP := 0.15
const CLIFF_BOTTOM := -0.72
const BANK_INSET := 0.20

var land_cells: Dictionary = {}
var water_cells: Dictionary = {}
var bridge_cells: Dictionary = {}
var blob_masks: Dictionary = {}

var _land_mesh := MeshInstance3D.new()
var _water_mesh := MeshInstance3D.new()
var _bank_mesh := MeshInstance3D.new()
var _cliff_mesh := MeshInstance3D.new()
var _bridge_mesh := MeshInstance3D.new()
var _river_polygons: Array[PackedVector2Array] = []
var _river_bounds: Array[Rect2] = []
var _river_key := ""
var _river_ready := false
var _shared_shader: Shader
## Counts river outline rebuilds. Land edits that do not touch water reuse the last outline.
var river_geometry_builds := 0


func _ready() -> void:
	_ensure_nodes()


func configure(cells: Array[Vector2i]) -> void:
	land_cells.clear()
	for cell in cells:
		land_cells[cell] = true
	water_cells.clear()
	for cell in _default_river():
		if land_cells.has(cell):
			water_cells[cell] = true
	bridge_cells.clear()
	for cell in [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]:
		if land_cells.has(cell):
			bridge_cells[cell] = true
	rebuild()


func set_water_cell(cell: Vector2i, enabled: bool) -> void:
	if not land_cells.has(cell):
		return
	if enabled:
		water_cells[cell] = true
	else:
		water_cells.erase(cell)
	rebuild()


func rebuild() -> void:
	_ensure_nodes()
	_rebuild_masks()
	var key := _river_dependency_key()
	if not _river_ready or key != _river_key:
		_river_ready = true
		_river_key = key
		river_geometry_builds += 1
		_river_polygons = _make_river_polygons()
		_river_bounds.clear()
		for polygon in _river_polygons:
			_river_bounds.append(_polygon_bounds(polygon).grow(0.02))
		_water_mesh.mesh = _build_water()
		_bank_mesh.mesh = _build_banks()
	_land_mesh.mesh = _build_land()
	_cliff_mesh.mesh = _build_cliffs()
	_bridge_mesh.mesh = _build_bridge()


func world_to_cell(world: Vector3) -> Vector2i:
	return Vector2i(floori(world.x), floori(world.z))


func is_walkable(world: Vector3) -> bool:
	var cell := world_to_cell(world)
	if not land_cells.has(cell):
		return false
	if _has_bridge() and _over_bridge(world):
		return true
	return not water_cells.has(cell)


func _default_river() -> Array[Vector2i]:
	return [
		Vector2i(4, -3), Vector2i(4, -2), Vector2i(4, -1),
		Vector2i(5, -1), Vector2i(5, 0), Vector2i(4, 0),
		Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1),
		Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
		Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3),
	]


func _ensure_nodes() -> void:
	if _land_mesh.get_parent() == self:
		return
	for pair in [
		[_land_mesh, "LandSurface", _land_material()],
		[_water_mesh, "JadeWater", _water_material()],
		[_bank_mesh, "RiverBank", _bank_material()],
		[_cliff_mesh, "IslandCliff", _cliff_material()],
		[_bridge_mesh, "RiverBridge", _bridge_material()],
	]:
		var mesh_instance: MeshInstance3D = pair[0]
		mesh_instance.name = pair[1]
		mesh_instance.material_override = pair[2]
		add_child(mesh_instance)


func _rebuild_masks() -> void:
	blob_masks.clear()
	for cell: Vector2i in water_cells:
		blob_masks[cell] = Blob47.from_cells(cell, water_cells)


func _river_dependency_key() -> String:
	var cells: Array = water_cells.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	var parts := PackedStringArray()
	for cell: Vector2i in cells:
		var border := 0
		if land_cells.has(cell + Vector2i(0, -1)):
			border |= 1
		if land_cells.has(cell + Vector2i(1, 0)):
			border |= 2
		if land_cells.has(cell + Vector2i(0, 1)):
			border |= 4
		if land_cells.has(cell + Vector2i(-1, 0)):
			border |= 8
		parts.append("%d,%d,%d" % [cell.x, cell.y, border])
	return "|".join(parts)


func _make_river_polygons() -> Array[PackedVector2Array]:
	var unioned: Array[PackedVector2Array] = []
	for cell: Vector2i in water_cells:
		unioned = _union_shape(unioned, _cell_polygon(cell))
	var rounded: Array[PackedVector2Array] = []
	for polygon in unioned:
		for inset: PackedVector2Array in Geometry2D.offset_polygon(polygon, -BANK_INSET, Geometry2D.JOIN_ROUND):
			if inset.size() >= 3:
				rounded.append(_chaikin(inset, 1))
	# At an island edge, the cliff terminates water rather than a grassy beach.
	for cell: Vector2i in water_cells:
		for side in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			if not land_cells.has(cell + side):
				rounded = _union_shape(rounded, _edge_strip(cell, side))
	return rounded


func _chaikin(polygon: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var result := polygon
	for iteration in iterations:
		var next := PackedVector2Array()
		for i in result.size():
			var a := result[i]
			var b := result[(i + 1) % result.size()]
			next.append(a * .75 + b * .25)
			next.append(a * .25 + b * .75)
		result = next
	return result


func _union_shape(polygons: Array[PackedVector2Array], addition: PackedVector2Array) -> Array[PackedVector2Array]:
	if polygons.is_empty():
		return [addition]
	var pending := addition
	var result: Array[PackedVector2Array] = []
	for polygon in polygons:
		var merged := Geometry2D.merge_polygons(polygon, pending)
		if merged.size() == 1:
			pending = merged[0]
		else:
			result.append(polygon)
	result.append(pending)
	return result


func _cell_polygon(cell: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(cell.x, cell.y), Vector2(cell.x, cell.y + 1),
		Vector2(cell.x + 1, cell.y + 1), Vector2(cell.x + 1, cell.y),
	])


func _edge_strip(cell: Vector2i, side: Vector2i) -> PackedVector2Array:
	if side.x < 0:
		return PackedVector2Array([Vector2(cell.x, cell.y), Vector2(cell.x, cell.y + 1), Vector2(cell.x + BANK_INSET + .01, cell.y + 1), Vector2(cell.x + BANK_INSET + .01, cell.y)])
	if side.x > 0:
		return PackedVector2Array([Vector2(cell.x + 1 - BANK_INSET - .01, cell.y), Vector2(cell.x + 1 - BANK_INSET - .01, cell.y + 1), Vector2(cell.x + 1, cell.y + 1), Vector2(cell.x + 1, cell.y)])
	if side.y < 0:
		return PackedVector2Array([Vector2(cell.x, cell.y), Vector2(cell.x, cell.y + BANK_INSET + .01), Vector2(cell.x + 1, cell.y + BANK_INSET + .01), Vector2(cell.x + 1, cell.y)])
	return PackedVector2Array([Vector2(cell.x, cell.y + 1 - BANK_INSET - .01), Vector2(cell.x, cell.y + 1), Vector2(cell.x + 1, cell.y + 1), Vector2(cell.x + 1, cell.y + 1 - BANK_INSET - .01)])


func _build_land() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in land_cells:
		if water_cells.has(cell):
			_add_cut_land_cell(st, cell)
		else:
			_add_polygon_top(st, _cell_polygon(cell), 0.0)
	return _commit_indexed(st)


func _add_cut_land_cell(st: SurfaceTool, cell: Vector2i) -> void:
	if not _add_boolean_land(st, _cell_polygon(cell)):
		_add_grid_land(st, cell)


func _add_boolean_land(st: SurfaceTool, polygon: PackedVector2Array) -> bool:
	var pieces := _subtract_rivers(polygon)
	if pieces.is_empty():
		return true
	var areas: PackedFloat32Array = PackedFloat32Array()
	var centroids: PackedVector2Array = PackedVector2Array()
	areas.resize(pieces.size())
	centroids.resize(pieces.size())
	for i in pieces.size():
		areas[i] = _polygon_area(pieces[i])
		centroids[i] = _centroid(pieces[i])
	var outers: Array[int] = []
	var holes: Array[int] = []
	for i in pieces.size():
		var nested := false
		for j in pieces.size():
			if i == j or areas[j] <= areas[i]:
				continue
			if Geometry2D.is_point_in_polygon(centroids[i], pieces[j]):
				nested = true
				break
		if nested:
			holes.append(i)
		else:
			outers.append(i)
	var accepted: Array[PackedVector2Array] = []
	for outer_index in outers:
		var shape := pieces[outer_index]
		for hole_index in holes:
			if Geometry2D.is_point_in_polygon(centroids[hole_index], shape):
				shape = _bridge_hole(shape, pieces[hole_index])
		if Geometry2D.triangulate_polygon(shape).is_empty():
			return false
		accepted.append(shape)
	for shape in accepted:
		_add_polygon_top(st, shape, 0.0)
	return true


func _add_grid_land(st: SurfaceTool, cell: Vector2i) -> void:
	# Fallback when a river contour encloses a patch. Small convex pieces cannot
	# contain that hole, so each remainder stays a simple polygon.
	const CUTS := 4
	var step := 1.0 / CUTS
	for z in CUTS:
		for x in CUTS:
			var lo := Vector2(cell.x + x * step, cell.y + z * step)
			var hi := lo + Vector2(step, step)
			for piece in _subtract_rivers(PackedVector2Array([lo, Vector2(lo.x, hi.y), hi, Vector2(hi.x, lo.y)])):
				_add_polygon_top(st, piece, 0.0)


func _subtract_rivers(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [polygon]
	var bounds := _polygon_bounds(polygon)
	for i in _river_polygons.size():
		if not bounds.intersects(_river_bounds[i]):
			continue
		var next: Array[PackedVector2Array] = []
		for piece in pieces:
			for remainder: PackedVector2Array in Geometry2D.clip_polygons(piece, _river_polygons[i]):
				if remainder.size() >= 3:
					next.append(remainder)
		pieces = next
		if pieces.is_empty():
			return pieces
	return pieces


func _bridge_hole(outer: PackedVector2Array, hole: PackedVector2Array) -> PackedVector2Array:
	var best_o := 0
	var best_h := 0
	var best_d := INF
	for i in hole.size():
		for j in outer.size():
			var distance := outer[j].distance_squared_to(hole[i])
			if distance < best_d:
				best_d = distance
				best_o = j
				best_h = i
	var bridged := PackedVector2Array()
	for j in best_o + 1:
		bridged.append(outer[j])
	for k in hole.size():
		bridged.append(hole[(best_h + k) % hole.size()])
	bridged.append(hole[best_h])
	for j in range(best_o, outer.size()):
		bridged.append(outer[j])
	return bridged


func _centroid(polygon: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	return center / polygon.size()


func _polygon_area(polygon: PackedVector2Array) -> float:
	var sum := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b: Vector2 = polygon[(i + 1) % polygon.size()]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	return bounds


func _build_water() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon in _river_polygons:
		_add_polygon_top(st, polygon, -WATER_DROP)
	return _commit_indexed(st)


func _add_polygon_top(st: SurfaceTool, polygon: PackedVector2Array, y: float) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	for index: int in indices:
		var p := polygon[index]
		st.set_normal(Vector3.UP)
		st.set_uv(p * 0.12)
		st.add_vertex(Vector3(p.x, y, p.y))


func _build_banks() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon in _river_polygons:
		for i in polygon.size():
			var a := polygon[i]
			var b := polygon[(i + 1) % polygon.size()]
			if not _segment_on_island_edge(a, b):
				_add_wall(st, a, b, 0.0, -WATER_DROP)
	return _commit_indexed(st)


func _build_cliffs() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var groups: Dictionary = {}
	for cell: Vector2i in land_cells:
		var top := -WATER_DROP if water_cells.has(cell) else 0.0
		for side in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			if land_cells.has(cell + side):
				continue
			var line := cell.x if side.x != 0 else cell.y
			var origin := cell.y if side.x != 0 else cell.x
			var key := "%d,%d,%d,%d" % [side.x, side.y, line, 1 if water_cells.has(cell) else 0]
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append(origin)
	for key: String in groups:
		var parts := key.split(",")
		var side := Vector2i(int(parts[0]), int(parts[1]))
		var line := int(parts[2])
		var top := -WATER_DROP if parts[3] == "1" else 0.0
		var origins: Array = groups[key]
		origins.sort()
		var run_start: int = origins[0]
		var run_end := run_start + 1
		for i in range(1, origins.size()):
			var origin: int = origins[i]
			if origin < run_end:
				continue
			if origin == run_end:
				run_end = origin + 1
			else:
				_add_cliff_run(st, side, line, run_start, run_end, top)
				run_start = origin
				run_end = origin + 1
		_add_cliff_run(st, side, line, run_start, run_end, top)
	return _commit_indexed(st)


func _add_cliff_run(st: SurfaceTool, side: Vector2i, line: int, start: int, end: int, top: float) -> void:
	var a: Vector2
	var b: Vector2
	if side == Vector2i(0, -1):
		a = Vector2(end, line)
		b = Vector2(start, line)
	elif side == Vector2i(1, 0):
		a = Vector2(line + 1, end)
		b = Vector2(line + 1, start)
	elif side == Vector2i(0, 1):
		a = Vector2(start, line + 1)
		b = Vector2(end, line + 1)
	else:
		a = Vector2(line, start)
		b = Vector2(line, end)
	_add_wall(st, a, b, top, CLIFF_BOTTOM)


func _segment_on_island_edge(a: Vector2, b: Vector2) -> bool:
	var middle := (a + b) * .5
	var tangent := (b - a).normalized()
	var normal := Vector2(-tangent.y, tangent.x) * .02
	var one := Vector2i(floori(middle.x + normal.x), floori(middle.y + normal.y))
	var two := Vector2i(floori(middle.x - normal.x), floori(middle.y - normal.y))
	return land_cells.has(one) != land_cells.has(two)


func _add_wall(st: SurfaceTool, a: Vector2, b: Vector2, top: float, bottom: float) -> void:
	var p0 := Vector3(a.x, top, a.y)
	var p1 := Vector3(b.x, top, b.y)
	var p2 := Vector3(b.x, bottom, b.y)
	var p3 := Vector3(a.x, bottom, a.y)
	var normal := Vector3(p1.z - p0.z, 0, p0.x - p1.x).normalized()
	for p in [p0, p1, p2, p0, p2, p3]:
		st.set_normal(normal)
		st.add_vertex(p)


func _build_bridge() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if not _has_bridge():
		return st.commit()
	var y := -.06
	_add_box(st, Vector3(4.525, y, 1.5), Vector3(3.45, .12, .72))
	_add_box(st, Vector3(4.525, -.13, 1.10), Vector3(3.45, .14, .10))
	_add_box(st, Vector3(4.525, -.13, 1.90), Vector3(3.45, .14, .10))
	for i in 13:
		_add_box(st, Vector3(2.9 + i * .265, .003, 1.5), Vector3(.022, .006, .72))
	st.generate_normals()
	return _commit_indexed(st)


func _commit_indexed(st: SurfaceTool) -> ArrayMesh:
	var arrays := st.commit_to_arrays()
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	if vertices == null or vertices.is_empty():
		return ArrayMesh.new()
	st.index()
	st.optimize_indices_for_cache()
	return st.commit()


func _add_rect(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	for p in [Vector3(a.x,a.y,a.z), Vector3(b.x,a.y,b.z), Vector3(b.x,a.y,a.z), Vector3(a.x,a.y,a.z), Vector3(a.x,a.y,b.z), Vector3(b.x,a.y,b.z)]:
		st.set_uv(Vector2(p.x, p.z) * .12)
		st.add_vertex(p)


func _add_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var h := size * .5
	var c := [center + Vector3(-h.x,-h.y,-h.z), center + Vector3(h.x,-h.y,-h.z), center + Vector3(h.x,-h.y,h.z), center + Vector3(-h.x,-h.y,h.z), center + Vector3(-h.x,h.y,-h.z), center + Vector3(h.x,h.y,-h.z), center + Vector3(h.x,h.y,h.z), center + Vector3(-h.x,h.y,h.z)]
	for face in [[4,6,5,4,7,6], [0,1,2,0,2,3], [0,4,5,0,5,1], [3,2,6,3,6,7], [1,5,6,1,6,2], [0,3,7,0,7,4]]:
		for index: int in face:
			st.add_vertex(c[index])


func _over_bridge(world: Vector3) -> bool:
	return world.x >= 2.8 and world.x <= 6.25 and world.z >= 1.14 and world.z <= 1.86


func _has_bridge() -> bool:
	for cell in [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]:
		if not land_cells.has(cell):
			return false
	return water_cells.has(Vector2i(3, 1)) and water_cells.has(Vector2i(4, 1)) and water_cells.has(Vector2i(5, 1))


func _land_material() -> ShaderMaterial: return _shader_material(Color("#758d6c"), Color("#829b78"), .05, 0.0)
func _water_material() -> ShaderMaterial: return _shader_material(Color("#568b89"), Color("#629f9d"), .10, .55)
func _bank_material() -> ShaderMaterial: return _shader_material(Color("#536b5b"), Color("#667e67"), .04, 0.0)
func _cliff_material() -> ShaderMaterial: return _shader_material(Color("#3f5046"), Color("#58695b"), .04, 0.0)
func _bridge_material() -> ShaderMaterial: return _shader_material(Color("#956f48"), Color("#c39862"), .06, 0.0)


func _shader_material(low: Color, high: Color, variation: float, shimmer: float) -> ShaderMaterial:
	if _shared_shader == null:
		_shared_shader = Shader.new()
		_shared_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 low_color : source_color;
uniform vec4 high_color : source_color;
uniform float variation;
uniform float shimmer;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(floor(p * 1.7), vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float broad = sin(world_position.x * .43 + world_position.z * .31) * .5 + .5;
	float grain = hash(world_position.xz) - .5;
	float flow = sin(world_position.x * 2.1 + world_position.z * 1.4 + TIME * .45) * shimmer;
	ALBEDO = mix(low_color.rgb, high_color.rgb, clamp(broad + grain * variation + flow * .08, 0.0, 1.0));
	ROUGHNESS = mix(.86, .38, shimmer);
	SPECULAR = .18 + shimmer * .25;
}
"""
	var material := ShaderMaterial.new()
	material.shader = _shared_shader
	material.set_shader_parameter("low_color", low)
	material.set_shader_parameter("high_color", high)
	material.set_shader_parameter("variation", variation)
	material.set_shader_parameter("shimmer", shimmer)
	return material
