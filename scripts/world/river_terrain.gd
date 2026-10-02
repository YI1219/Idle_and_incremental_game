class_name RiverTerrain
extends Node3D
## Sparse island top with a smooth, eight-neighbour river and walkable bridge.
## Land and cliffs are organic volume meshes; the grid stays the play unit.

const Blob47 := preload("res://scripts/world/blob47.gd")
const IslandGeometry := preload("res://scripts/world/island_geometry.gd")
const IslandPresence := preload("res://scripts/world/island_presence.gd")
const RockUnderside := preload("res://scripts/world/rock_underside.gd")
const RockKit := preload("res://scripts/world/rock_kit.gd")
const WATER_DROP := 0.18
const CLIFF_BOTTOM := -0.72
const BANK_INSET := 0.28
const BANK_WIDTH := 0.40
const COAST_MARGIN := 0.38

var land_cells: Dictionary = {}
var water_cells: Dictionary = {}
var bridge_cells: Dictionary = {}
var blob_masks: Dictionary = {}
var island_rebuilds: int = 0
var island_cache: Dictionary = {}
var last_rock_rebuild_ms: float = 0.0
var _pending_rebuild := false
var _pending_wait := 0.0
const REBUILD_DEBOUNCE := 0.055

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
	_apply_cells(cells)
	_pending_rebuild = false
	rebuild()


func apply_cells_deferred(cells: Array[Vector2i]) -> void:
	_apply_cells(cells)
	_pending_rebuild = true
	_pending_wait = REBUILD_DEBOUNCE


func flush_rebuild() -> void:
	if _pending_rebuild:
		_pending_rebuild = false
		rebuild()
	flush_bakes()


func flush_bakes() -> void:
	for child in _islands_root.get_children():
		if child.has_method("flush_bake"):
			child.flush_bake()
	_assemble_island_meshes()


func _process(delta: float) -> void:
	if not _pending_rebuild:
		return
	_pending_wait -= delta
	if _pending_wait <= 0.0:
		_pending_rebuild = false
		rebuild()


func _apply_cells(cells: Array[Vector2i]) -> void:
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
	_pending_rebuild = false
	_ensure_nodes()
	_rebuild_masks()
	_river_polygons = _make_river_polygons()
	_rebuild_islands()
	_water_mesh.mesh = _build_water()
	_bank_mesh.mesh = _build_banks()
	_bridge_mesh.mesh = _build_bridge()


func island_count() -> int:
	return IslandGeometry.components(land_cells).size()


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
	RockKit.ensure()
	_volume_material = RockKit.rock_material if RockKit.rock_material else _land_material()
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
	_cliff_mesh.visible = false
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
	var coast := IslandGeometry.outline_from_cells(land_cells, true)
	var keepers: Array[PackedVector2Array] = [coast]
	if coast.size() >= 3:
		var inset_coast: Array = Geometry2D.offset_polygon(coast, -COAST_MARGIN, Geometry2D.JOIN_ROUND)
		if not inset_coast.is_empty():
			keepers = []
			for piece: PackedVector2Array in inset_coast:
				if piece.size() >= 3:
					keepers.append(piece)
	var rounded: Array[PackedVector2Array] = []
	for polygon in unioned:
		var body := polygon
		for inset: PackedVector2Array in Geometry2D.offset_polygon(polygon, -BANK_INSET, Geometry2D.JOIN_ROUND):
			if inset.size() >= 3:
				body = inset
				break
		body = IslandGeometry.catmull_rom(IslandGeometry.chaikin(IslandGeometry.simplify_colinear(body), 3), 3)
		if keepers.is_empty():
			if body.size() >= 3:
				rounded.append(body)
			continue
		for keeper in keepers:
			for clipped: PackedVector2Array in Geometry2D.intersect_polygons(body, keeper):
				if clipped.size() >= 3 and IslandGeometry.signed_area(clipped) > 0.0:
					rounded.append(clipped)
	if rounded.is_empty():
		for polygon in unioned:
			if polygon.size() >= 3:
				rounded.append(IslandGeometry.chaikin(polygon, 2))
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


func _rebuild_islands() -> void:
	var next_cache: Dictionary = {}
	island_rebuilds = 0
	var used_old: Dictionary = {}
	var rock_ms := 0.0
	for group in IslandGeometry.components(land_cells):
		var water_in_group: Dictionary = {}
		for cell: Vector2i in water_cells:
			if group.has(cell):
				water_in_group[cell] = true
		var key: int = IslandGeometry.cells_hash(group) * 10007 + IslandGeometry.cells_hash(water_in_group)
		if island_cache.has(key):
			next_cache[key] = island_cache[key]
			used_old[key] = true
			continue
		var built: Dictionary = IslandGeometry.build_island(group, _river_polygons, true, water_cells)
		built["cells"] = group
		var matched := _match_island(group, used_old)
		var seed := int(matched.get("rock_seed", IslandGeometry.cells_hash(group)))
		var t0 := Time.get_ticks_usec()
		if matched.has("rocks") and (matched["rocks"] as Dictionary).has("slots"):
			built["rocks"] = RockUnderside.respace(matched["rocks"], built["outline"], seed, false)
		else:
			built["rocks"] = RockUnderside.assemble(built["outline"], seed, false)
		var cover: PackedVector2Array = RockUnderside.cover_outline(built["outline"], built["rocks"])
		built["top"] = IslandGeometry.build_top(cover, built.get("cutters", []), cover)
		rock_ms += float(Time.get_ticks_usec() - t0) / 1000.0
		built["rock_seed"] = seed
		next_cache[key] = built
		island_rebuilds += 1
	island_cache = next_cache
	last_rock_rebuild_ms = rock_ms
	_sync_presence()
	_assemble_island_meshes()


func _match_island(group: Dictionary, used_old: Dictionary) -> Dictionary:
	var best := {}
	var best_n := 0
	var best_key := 0
	for key in island_cache.keys():
		if used_old.has(key):
			continue
		var prev: Dictionary = island_cache[key]
		var cells: Dictionary = prev.get("cells", {})
		var n := 0
		for cell: Vector2i in group:
			if cells.has(cell):
				n += 1
		if n > best_n:
			best_n = n
			best = prev
			best_key = int(key)
	if best_n > 0:
		used_old[best_key] = true
	return best


func rock_stats() -> Dictionary:
	var pieces := 0
	var tris := 0
	var draw := 0
	var bake_ms := 0.0
	var hitch_ms := 0.0
	var baked_n := 0
	for child in _islands_root.get_children():
		var state: Dictionary = child.get("rock_state") if child.get("rock_state") != null else {}
		if state.is_empty():
			var key := int(child.get("island_hash"))
			state = island_cache.get(key, {}).get("rocks", {})
		pieces += int(state.get("piece_count", 0))
		if bool(child.get("baked")):
			baked_n += 1
			tris += int(child.baked_triangles()) if child.has_method("baked_triangles") else 0
			bake_ms = maxf(bake_ms, float(child.get("last_bake_ms")))
			hitch_ms = maxf(hitch_ms, float(child.get("last_hitch_ms")))
			var baked_node := child.get_node_or_null("BakedUnderside")
			if baked_node and baked_node.visible:
				draw += 1
		else:
			tris += RockUnderside.triangle_count(state)
			var kit := child.get_node_or_null("RockKit")
			if kit:
				for mmi in kit.get_children():
					if mmi is MultiMeshInstance3D and (mmi as MultiMeshInstance3D).visible:
						draw += 1
	if _cliff_mesh and _cliff_mesh.visible and _cliff_mesh.mesh and _cliff_mesh.mesh.get_surface_count() > 0:
		draw += 1
		tris += int(_cliff_mesh.mesh.get_faces().size() / 3)
	return {
		"islands": island_count(),
		"pieces": pieces,
		"triangles": tris,
		"draw_calls": draw,
		"rebuild_ms": last_rock_rebuild_ms,
		"bake_ms": bake_ms,
		"hitch_ms": hitch_ms,
		"baked_islands": baked_n,
	}


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
		if node.has_method("apply_rocks"):
			node.apply_rocks(row.get("rocks", {}))


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
	_cliff_mesh.visible = false


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
		if polygon.size() < 3:
			continue
		var lip := PackedVector2Array()
		lip.resize(polygon.size())
		for i in polygon.size():
			lip[i] = polygon[i] + IslandGeometry.vertex_outward(polygon, i) * BANK_WIDTH
		for i in polygon.size():
			var j := (i + 1) % polygon.size()
			var water_a := Vector3(polygon[i].x, -WATER_DROP, polygon[i].y)
			var water_b := Vector3(polygon[j].x, -WATER_DROP, polygon[j].y)
			var mid_a := Vector3(lerpf(polygon[i].x, lip[i].x, 0.55), -WATER_DROP * 0.35, lerpf(polygon[i].y, lip[i].y, 0.55))
			var mid_b := Vector3(lerpf(polygon[j].x, lip[j].x, 0.55), -WATER_DROP * 0.35, lerpf(polygon[j].y, lip[j].y, 0.55))
			var grass_a := Vector3(lip[i].x, 0.012, lip[i].y)
			var grass_b := Vector3(lip[j].x, 0.012, lip[j].y)
			_bank_tri(st, water_a, water_b, mid_b, 0.08)
			_bank_tri(st, water_a, mid_b, mid_a, 0.08)
			_bank_tri(st, mid_a, mid_b, grass_b, 0.55)
			_bank_tri(st, mid_a, grass_b, grass_a, 0.72)
	st.generate_normals()
	return st.commit()


func _bank_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, turf: float) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-10:
		return
	normal = normal.normalized()
	for p in [a, b, c]:
		st.set_normal(normal)
		st.set_color(Color(turf, 0.16, 0.08))
		st.set_uv(Vector2(p.x, p.z) * 0.12)
		st.add_vertex(p)


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
