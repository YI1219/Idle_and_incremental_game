extends SceneTree
## Authoring guards for broad editable terraces, planted groups and a readable route.
## Art acceptance still requires actual Godot views.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Field = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration = preload("res://scripts/terrain_editor/terrain_decoration.gd")
const Paths = preload("res://scripts/terrain_editor/terrain_paths.gd")
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func largest_patch(cells: Dictionary) -> int:
	var remaining: Dictionary = cells.duplicate()
	var largest: int = 0
	while not remaining.is_empty():
		var queue: Array[Vector2i] = [remaining.keys()[0]]
		remaining.erase(queue[0])
		var index: int = 0
		while index < queue.size():
			var cell: Vector2i = queue[index]
			index += 1
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = cell + step
				if remaining.has(next):
					queue.append(next)
					remaining.erase(next)
		largest = maxi(largest, queue.size())
	return largest

func route_distance(p: Vector2) -> float:
	var best: float = INF
	for i: int in Paths.POINTS.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, Paths.POINTS[i], Paths.POINTS[i + 1])))
	return best

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var old_source := GDScript.new()
	old_source.source_code = FileAccess.get_file_as_string("res://art/lookdev/20261114_courtyard_composition/checks/source_before/scripts/terrain_editor/terrain_data.gd").replace("class_name TerrainData\n", "")
	check(old_source.reload() == OK, "task-start terrain fixture must load")
	var original: RefCounted = old_source.new()
	original.make_preset(0)
	var historic := Data.new()
	check(historic.deserialize(original.serialize()) and historic.cells == original.cells, "loading a saved courtyard preserves its authored elevations")
	for kind: int in [1, 2]:
		var prior: RefCounted = old_source.new()
		prior.make_preset(kind)
		var other := Data.new()
		other.make_preset(kind)
		check(other.cells == prior.cells, "other terrain presets retain their authored data")
	for seed_value: int in [7301, 2104, 4242]:
		var data := Data.new()
		data.seed = seed_value
		data.make_preset(0)
		var bands: Dictionary = {}
		var water_ok: bool = true
		for cell: Vector2i in data.cells:
			var rec: Dictionary = data.cells[cell]
			var prior: Dictionary = original.cells.get(cell, {})
			if int(rec.water) >= 0 or int(prior.get("water", -1)) >= 0:
				water_ok = water_ok and rec == prior
			if int(rec.water) < 0:
				var h: float = rec.height
				if not bands.has(h): bands[h] = {}
				bands[h][cell] = true
		check(water_ok and data.cells.size() == original.cells.size(), "preserve pond beds, outlets and original outer footprint")
		var broad_bands: int = 0
		for h: float in bands:
			if largest_patch(bands[h]) >= 12: broad_bands += 1
		check(broad_bands >= 4, "composition needs several broad contiguous terraces, not isolated rock bumps")
		var field := Field.new()
		field.refresh(data)
		var route_ok: bool = true
		for i: int in Paths.POINTS.size() - 1:
			var previous: Dictionary = {}
			for j: int in 16:
				var p: Vector2 = Paths.POINTS[i].lerp(Paths.POINTS[i + 1], float(j) / 15)
				var surface: Dictionary = field.surface_at(p)
				route_ok = route_ok and not surface.is_empty() and int(surface.get("water", 0)) < 0
				if not previous.is_empty() and not surface.is_empty():
					route_ok = route_ok and absf(float(surface.height) - float(previous.height)) <= .5
				previous = surface
		check(route_ok, "stepping route stays on supported dry land without a new cliff across it")
		var decoration := Decoration.new()
		decoration.contours = field
		decoration.load_assets()
		var trees: Array[Transform3D] = []
		var planting_clear: bool = true
		var roots: Dictionary = {}
		for kind: String in ["bush", "flower", "grass_clump"]:
			roots[kind] = PackedVector3Array()
			for part: Dictionary in decoration.assets[kind]:
				var mesh: Mesh = part.mesh
				var box: AABB = mesh.get_aabb()
				for vertex: Vector3 in Geometry.arrays_of(mesh)[Mesh.ARRAY_VERTEX]:
					if vertex.y <= box.position.y + box.size.y * .08:
						roots[kind].append(part.pose * vertex)
		var chunks: Dictionary = {}
		for cell: Vector2i in data.cells: chunks[Data.chunk_of(cell)] = true
		for chunk: Vector2i in chunks:
			var placements: Dictionary = decoration.placements(data, chunk)
			trees.append_array(placements.tree)
			trees.append_array(placements.tree_b)
			for kind: String in ["bush", "flower", "grass_clump"]:
				for pose: Transform3D in placements[kind]:
					for root_point: Vector3 in roots[kind]:
						var world: Vector3 = pose * root_point
						planting_clear = planting_clear and route_distance(Vector2(world.x, world.z)) >= .6
		check(planting_clear, "actual plant root vertices stay outside the paving corridor")
		var neighbors: int = 0
		var clear_and_supported: bool = true
		for tree: Transform3D in trees:
			var p := Vector2(tree.origin.x, tree.origin.z)
			var surface: Dictionary = field.surface_at(p)
			clear_and_supported = clear_and_supported and not surface.is_empty() and int(surface.get("water", 0)) < 0 and route_distance(p) > 1.1
			var near: int = 0
			for other: Transform3D in trees:
				if other != tree and Vector2(other.origin.x, other.origin.z).distance_to(p) < 4.6: near += 1
			neighbors = maxi(neighbors, near)
		check(neighbors >= 2, "at least one planted tree group has a main tree and two companions")
		check(clear_and_supported, "tree stems stay supported and leave the route open")
		var saved: Dictionary = data.serialize()
		var loaded := Data.new()
		check(loaded.deserialize(saved) and loaded.cells == data.cells, "authored terrace data roundtrips through existing terrain format")
		var center := Vector2(-15.5, -8.5)
		var height: float = float(data.cells[Vector2i(center.floor())].height)
		data.begin_stroke()
		data.apply_brush(center, 2.2, "lower", false, height, 7, height)
		data.end_stroke()
		var edited: bool = data.cells != loaded.cells
		data.undo()
		check(edited and data.cells == loaded.cells, "new terrace remains editable and undoable in authoritative terrain")
		if not trees.is_empty():
			var p := Vector2(trees[0].origin.x, trees[0].origin.z)
			var cell := Vector2i(p.floor())
			var support_height: float = data.cells[cell].height
			data.begin_stroke()
			data.apply_brush(Vector2(cell) + Vector2(.5, .5), .55, "contract", false, support_height, 7, support_height)
			data.end_stroke()
			field.refresh(data)
			var updated: Dictionary = decoration.placements(data, Data.chunk_of(cell))
			var kept: bool = false
			for kind: String in ["tree", "tree_b"]:
				for pose: Transform3D in updated[kind]:
					if Vector2(pose.origin.x, pose.origin.z).distance_to(p) < .01: kept = true
			check(not kept, "editing away a grouped tree's support removes its independent placement")
	print("courtyard_composition: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
