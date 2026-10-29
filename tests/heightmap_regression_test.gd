extends SceneTree
## Behavioral regressions for the editable heightmap shell; no viewport required.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Island = preload("res://scripts/terrain_editor/heightmap_island.gd")
const SIDES := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const EPS := 0.0001
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	_check_dry_wet_wall()
	_check_external_water()
	_check_water_hole_direction()
	_check_empty_cleanup()
	_check_morph_seams()
	_check_brush_history_and_save()
	print("HEIGHTMAP REGRESSIONS: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

func _check_dry_wet_wall() -> void:
	var data := Data.new()
	data.cells[Vector2i.ZERO] = {"height": 3.5, "water": -1}
	data.cells[Vector2i(1, 0)] = {"height": 1.0, "water": 3}
	var island := Island.new()
	island.refresh(data)
	var covered := true
	for z in [0.2, 0.5, 0.8]:
		for y in [1.51, 2.0, 3.0, 3.49]:
			if not _surface_covers(island.surfaces.cliff.vertices, Vector3(1.0, y, z)):
				covered = false
	check(covered, "dry 3.5 / wet 1.5 shared edge has a continuous rock face above water")
	data.cells[Vector2i.ZERO] = {"height": 1.0, "water": 6}
	data.cells[Vector2i(1, 0)] = {"height": 1.5, "water": -1}
	island.refresh(data)
	var rock_support := true
	var grassy_support := false
	for z in [0.2, 0.5, 0.8]:
		for y in [1.51, 2.0, 2.99]:
			var point := Vector3(1.0, y, z)
			if not _surface_covers(island.surfaces.cliff.vertices, point):
				rock_support = false
			if _surface_covers(island.surfaces.grass.vertices, point):
				grassy_support = true
	check(rock_support and not grassy_support, "wet 3.0 / dry 1.5 shared edge has solid rock support, not lawn or only a transparent fall")

func _check_external_water() -> void:
	var one := Data.new()
	one.cells[Vector2i.ZERO] = {"height": 0.0, "water": 3}
	_check_outlets(one, "isolated water cell")
	var end_mouth := _row(10, 2.0)
	end_mouth.cells[Vector2i(9, 0)] = {"height": 1.0, "water": 4}
	_check_outlets(end_mouth, "one-cell outlet at end of ten-cell wall")
	var separate := _row(10, 2.0)
	for x in [3, 6]:
		separate.cells[Vector2i(x, 0)] = {"height": 1.0, "water": 4}
	_check_outlets(separate, "two water outlets separated by dry cells")

func _check_outlets(data: Data, label: String) -> void:
	var island := Island.new()
	island.refresh(data)
	var edges := _exposed_water_edges(data)
	var curtains: Array = []
	for veil: Dictionary in island.fall_veils:
		if bool(veil.get("external", false)):
			curtains.append(veil)
	var all_sources_covered: bool = not edges.is_empty() and not island.surfaces.waterfall.vertices.is_empty()
	for edge: Dictionary in edges:
		var covered := false
		for curtain: Dictionary in curtains:
			if _curtain_matches_line(curtain, edge) and _curtain_edge_overlap(curtain, edge) > EPS:
				covered = true
		if not covered:
			all_sources_covered = false
	var no_dry_crossing := true
	for curtain: Dictionary in curtains:
		var supported_width := 0.0
		for edge: Dictionary in edges:
			if _curtain_matches_line(curtain, edge):
				supported_width += _curtain_edge_overlap(curtain, edge)
		if supported_width + EPS < float(curtain.half_width) * 2.0:
			no_dry_crossing = false
	check(all_sources_covered, "%s: every exposed wet source edge has waterfall geometry" % label)
	check(no_dry_crossing, "%s: no waterfall interval spans dry or missing source edges" % label)
	print("OUTLETS %s: sources=%d curtains=%d" % [label, edges.size(), curtains.size()])

func _exposed_water_edges(data: Data) -> Array:
	var result: Array = []
	for cell: Vector2i in data.cells:
		var record: Dictionary = data.cells[cell]
		if int(record.water) < 0:
			continue
		var corners := [Vector2(cell), Vector2(cell + Vector2i.RIGHT), Vector2(cell + Vector2i.ONE), Vector2(cell + Vector2i.DOWN)]
		for side in 4:
			if data.cells.has(cell + SIDES[side]):
				continue
			result.append({"a": corners[side], "b": corners[(side + 1) % 4], "out": Vector2(SIDES[side]), "height": float(record.water) * 0.5})
	return result

func _curtain_matches_line(curtain: Dictionary, edge: Dictionary) -> bool:
	var out: Vector2 = curtain.out
	var edge_out: Vector2 = edge.out
	var lip: Vector3 = curtain.lip
	var at := Vector2(lip.x, lip.z)
	var start: Vector2 = edge.a
	return out.dot(edge_out) > 0.99 and absf((at - start).dot(edge_out)) < 0.25 and absf(lip.y - float(edge.height)) < 0.15

func _curtain_edge_overlap(curtain: Dictionary, edge: Dictionary) -> float:
	var start: Vector2 = edge.a
	var finish: Vector2 = edge.b
	var tangent := (finish - start).normalized()
	var lip: Vector3 = curtain.lip
	var along := (Vector2(lip.x, lip.z) - start).dot(tangent)
	var half: float = curtain.half_width
	return maxf(0.0, minf(start.distance_to(finish), along + half) - maxf(0.0, along - half))

func _check_water_hole_direction() -> void:
	var data := Data.new()
	for z in 5:
		for x in 5:
			data.cells[Vector2i(x, z)] = {"height": 0.0, "water": 3}
	var dry_cell := Vector2i(2, 2)
	data.cells[dry_cell] = {"height": 1.5, "water": -1}
	var island := Island.new()
	island.refresh(data)
	var outward_is_dry := true
	var hole_edges := 0
	for level in island.water_regions:
		for loop: PackedVector2Array in island.water_regions[level]:
			for i in loop.size():
				var a := loop[i]
				var b := loop[(i + 1) % loop.size()]
				if a.distance_to(b) < EPS:
					continue
				var middle := (a + b) * 0.5
				# This is the outward direction consumed by shore decoration.
				var out := Vector2(b.y - a.y, a.x - b.x).normalized()
				var outside := Vector2i((middle + out * 0.2).floor())
				var inside := Vector2i((middle - out * 0.2).floor())
				if outside == dry_cell or inside == dry_cell:
					hole_edges += 1
				if data.cells.has(outside) and int(data.cells[outside].water) == int(level):
					outward_is_dry = false
	check(hole_edges > 0, "water boundary retains the dry island inside a pond")
	check(outward_is_dry, "every water edge points outward into nonmatching water, including the dry island hole")

func _check_empty_cleanup() -> void:
	var data := Data.new()
	data.cells[Vector2i.ZERO] = {"height": 0.0, "water": 3}
	var island := Island.new()
	island.refresh(data)
	check(not island.water_regions.is_empty(), "cleanup fixture first contains a water region")
	data.cells.clear()
	island.refresh(data)
	var stale := PackedStringArray()
	for key in ["water_regions", "water_anchor_regions", "land_regions", "lawn_boundaries", "rim_loops", "grass_loops", "facets", "fall_veils", "splash_points", "embeds", "triangle_chunks"]:
		var value = island.get(key)
		if not value.is_empty():
			stale.append(key)
	for kind in island.surfaces:
		if not island.surfaces[kind].vertices.is_empty():
			stale.append("surface:" + String(kind))
	check(stale.is_empty(), "empty terrain clears every derived water/shell result; stale=%s" % ", ".join(stale))

func _check_morph_seams() -> void:
	var data := _row(10, 2.0)
	var island := Island.new()
	island.refresh(data)
	var missing := PackedStringArray()
	for x in range(11):
		for z in [0, 1]:
			var point := Vector3(float(x), 2.0, float(z))
			if not _has_vertex(island.surfaces.cliff.vertices, point):
				missing.append(str(point))
	check(missing.is_empty(), "long wall retains source top-edge samples needed by per-cell morph; missing=%s" % ", ".join(missing))

func _check_brush_history_and_save() -> void:
	var data := _row(10, 2.0)
	data.cells[Vector2i(5, 0)].height = 1.5
	var island := Island.new()
	island.refresh(data)
	var before := _geometry_digest(island)
	data.begin_stroke()
	var changed := data.apply_brush(Vector2(5.5, 0.5), 0.4, "raise", true, 2.0, 0)
	data.end_stroke()
	island.refresh(data)
	var after := _geometry_digest(island)
	check(changed == 1 and before != after, "real middle-cell raise changes generated shell geometry")
	var undone := data.undo()
	island.refresh(data)
	check(undone and _geometry_digest(island) == before, "undo restores the generated geometry before the stroke")
	var redone := data.redo()
	island.refresh(data)
	check(redone and _geometry_digest(island) == after, "redo restores the generated geometry after the stroke")
	var restored := Data.new()
	var loaded := restored.deserialize(data.serialize())
	var rebuilt := Island.new()
	rebuilt.refresh(restored)
	check(loaded and _geometry_digest(rebuilt) == after, "serialized terrain rebuilds the same generated geometry")

func _row(count: int, height: float) -> Data:
	var data := Data.new()
	for x in count:
		data.cells[Vector2i(x, 0)] = {"height": height, "water": -1}
	return data

func _surface_covers(vertices: PackedVector3Array, point: Vector3) -> bool:
	for i in range(0, vertices.size(), 3):
		var a := vertices[i]
		var b := vertices[i + 1]
		var c := vertices[i + 2]
		var normal := (b - a).cross(c - a)
		if normal.length_squared() < EPS * EPS:
			continue
		if absf(normal.normalized().dot(point - a)) > EPS:
			continue
		var weights := Geometry3D.get_triangle_barycentric_coords(point, a, b, c)
		if minf(weights.x, minf(weights.y, weights.z)) >= -EPS:
			return true
	return false

func _has_vertex(vertices: PackedVector3Array, point: Vector3) -> bool:
	for vertex in vertices:
		if vertex.distance_squared_to(point) < EPS * EPS:
			return true
	return false

func _geometry_digest(island: Island) -> String:
	# Canonical triangle positions ignore dictionary/triangle emission order.
	var triangles := PackedStringArray()
	for kind in island.surfaces:
		var vertices: PackedVector3Array = island.surfaces[kind].vertices
		for i in range(0, vertices.size(), 3):
			var points := PackedStringArray()
			for j in 3:
				var v := vertices[i + j]
				points.append("%.6f,%.6f,%.6f" % [v.x, v.y, v.z])
			points.sort()
			triangles.append(String(kind) + ":" + ";".join(points))
	triangles.sort()
	return "\n".join(triangles).sha256_text()
