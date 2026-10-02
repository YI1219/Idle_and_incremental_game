class_name RiverTerrain
extends Node3D
## Sparse island top with a smooth, eight-neighbour river and walkable bridge.
## Land and cliffs are organic volume meshes; the grid stays the play unit.

const Blob47 := preload("res://scripts/world/blob47.gd")
const IslandGeometry := preload("res://scripts/world/island_geometry.gd")
const IslandPresence := preload("res://scripts/world/island_presence.gd")
const WATER_DROP := 0.15
const CLIFF_BOTTOM := -0.72
const BANK_INSET := 0.20

var land_cells: Dictionary = {}
var water_cells: Dictionary = {}
var bridge_cells: Dictionary = {}
var blob_masks: Dictionary = {}
var island_rebuilds: int = 0
var island_cache: Dictionary = {}

var _land_mesh := MeshInstance3D.new()
var _water_mesh := MeshInstance3D.new()
var _bank_mesh := MeshInstance3D.new()
var _cliff_mesh := MeshInstance3D.new()
var _bridge_mesh := MeshInstance3D.new()
var _islands_root := Node3D.new()
var _river_polygons: Array[PackedVector2Array] = []
var _volume_material: ShaderMaterial


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
	_refresh_masks_around(cell)
	rebuild()


func rebuild() -> void:
	_ensure_nodes()
	_rebuild_masks()
	_river_polygons = _make_river_polygons()
	_rebuild_islands()
	_water_mesh.mesh = _build_water()
	_bank_mesh.mesh = _build_banks()
	_bridge_mesh.mesh = _build_bridge()


func island_count() -> int:
	return island_cache.size()


func island_disks() -> Array[Vector4]:
	var disks: Array[Vector4] = []
	for key in island_cache.keys():
		var row: Dictionary = island_cache[key]
		var center: Vector3 = row.get("centroid", Vector3.ZERO)
		var radius := 4.0 + sqrt(float(int(row.get("cell_count", 1)))) * 0.85
		disks.append(Vector4(center.x, center.z, radius, 0.0))
	return disks


func refresh_lod(camera_origin: Vector3) -> void:
	var changed := false
	for child in _islands_root.get_children():
		if child.has_method("update_lod") and child.update_lod(camera_origin):
			changed = true
	if changed:
		_assemble_island_meshes()


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
	_volume_material = _land_material()
	for pair in [
		[_land_mesh, "LandSurface", _volume_material],
		[_water_mesh, "JadeWater", _water_material()],
		[_bank_mesh, "RiverBank", _bank_material()],
		[_cliff_mesh, "IslandCliff", _volume_material],
		[_bridge_mesh, "RiverBridge", _bridge_material()],
	]:
		var mesh_instance: MeshInstance3D = pair[0]
		mesh_instance.name = pair[1]
		mesh_instance.material_override = pair[2]
		add_child(mesh_instance)
	_islands_root.name = "Islands"
	add_child(_islands_root)


func _rebuild_masks() -> void:
	blob_masks.clear()
	for cell: Vector2i in water_cells:
		blob_masks[cell] = Blob47.from_cells(cell, water_cells)


func _refresh_masks_around(cell: Vector2i) -> void:
	for z in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			var neighbor := Vector2i(x, z)
			if water_cells.has(neighbor):
				blob_masks[neighbor] = Blob47.from_cells(neighbor, water_cells)
			else:
				blob_masks.erase(neighbor)


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


func _rebuild_islands() -> void:
	var next_cache: Dictionary = {}
	island_rebuilds = 0
	for group in IslandGeometry.components(land_cells):
		var water_in_group: Dictionary = {}
		for cell: Vector2i in water_cells:
			if group.has(cell):
				water_in_group[cell] = true
		var key: int = IslandGeometry.cells_hash(group) * 10007 + IslandGeometry.cells_hash(water_in_group)
		if island_cache.has(key):
			next_cache[key] = island_cache[key]
			continue
		var built: Dictionary = IslandGeometry.build_island(group, _river_polygons, true, water_cells)
		built["cells"] = group
		next_cache[key] = built
		island_rebuilds += 1
	island_cache = next_cache
	_sync_presence()
	_assemble_island_meshes()


func _sync_presence() -> void:
	var kept: Dictionary = {}
	for child in _islands_root.get_children():
		if int(child.get("island_hash")) in island_cache:
			kept[int(child.get("island_hash"))] = child
		else:
			child.free()
	for key in island_cache.keys():
		var row: Dictionary = island_cache[key]
		var node: Node3D = kept.get(key)
		if node == null:
			node = IslandPresence.new()
			node.name = "Island_%s" % key
			_islands_root.add_child(node)
		node.configure(int(key), row.get("centroid", Vector3.ZERO), int(row.get("cell_count", 0)), row.get("volume"), row.get("low_volume"), row.get("top"))
		if node.has_method("set_material"):
			node.set_material(_volume_material)


func _assemble_island_meshes() -> void:
	var tops: Array = []
	var volumes: Array = []
	for child in _islands_root.get_children():
		var key := int(child.get("island_hash"))
		if not island_cache.has(key):
			continue
		var row: Dictionary = island_cache[key]
		tops.append(row.get("top"))
		if child.has_method("current_volume"):
			volumes.append(child.current_volume())
		else:
			volumes.append(row.get("volume"))
	if tops.is_empty():
		for key in island_cache.keys():
			tops.append(island_cache[key].get("top"))
			volumes.append(island_cache[key].get("volume"))
	_land_mesh.mesh = IslandGeometry.combine_meshes(tops)
	_cliff_mesh.mesh = IslandGeometry.combine_meshes(volumes)


func _build_land() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in land_cells:
		if water_cells.has(cell):
			_add_cut_land_cell(st, cell)
		else:
			_add_polygon_top(st, _cell_polygon(cell), 0.0)
	return st.commit()


func _add_cut_land_cell(st: SurfaceTool, cell: Vector2i) -> void:
	# Clip small convex patches. A river contour cannot be wholly enclosed by
	# these patches, so each remainder is a simple polygon with no hole contour.
	const CUTS := 4
	var step := 1.0 / CUTS
	for z in CUTS:
		for x in CUTS:
			var lo := Vector2(cell.x + x * step, cell.y + z * step)
			var hi := lo + Vector2(step, step)
			var pieces: Array[PackedVector2Array] = [PackedVector2Array([lo, Vector2(lo.x, hi.y), hi, Vector2(hi.x, lo.y)])]
			for river in _river_polygons:
				var clipped: Array[PackedVector2Array] = []
				for piece in pieces:
					for remainder: PackedVector2Array in Geometry2D.clip_polygons(piece, river):
						if remainder.size() >= 3:
							clipped.append(remainder)
				pieces = clipped
			for piece in pieces:
				_add_polygon_top(st, piece, 0.0)


func _build_water() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon in _river_polygons:
		_add_polygon_top(st, polygon, -WATER_DROP)
	return st.commit()


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
	return st.commit()


func _build_cliffs() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in land_cells:
		for side in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			if land_cells.has(cell + side):
				continue
			var a: Vector2
			var b: Vector2
			if side == Vector2i(0, -1): a = Vector2(cell.x + 1, cell.y); b = Vector2(cell.x, cell.y)
			elif side == Vector2i(1, 0): a = Vector2(cell.x + 1, cell.y + 1); b = Vector2(cell.x + 1, cell.y)
			elif side == Vector2i(0, 1): a = Vector2(cell.x, cell.y + 1); b = Vector2(cell.x + 1, cell.y + 1)
			else: a = Vector2(cell.x, cell.y); b = Vector2(cell.x, cell.y + 1)
			_add_wall(st, a, b, -WATER_DROP if water_cells.has(cell) else 0.0, CLIFF_BOTTOM)
	return st.commit()


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
	var shader := Shader.new()
	shader.code = """
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
	material.shader = shader
	material.set_shader_parameter("low_color", low)
	material.set_shader_parameter("high_color", high)
	material.set_shader_parameter("variation", variation)
	material.set_shader_parameter("shimmer", shimmer)
	return material
