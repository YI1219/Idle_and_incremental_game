extends SceneTree
## Real final triangles must cover lowered land and seal its interior rock wall.
## These checks catch exposed source sides, missing generated support and lost undo.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Field = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration = preload("res://scripts/terrain_editor/terrain_decoration.gd")
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")
var checks: int = 0
var failures: int = 0
var downward_rays: int = 0
var horizontal_rays: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func first_hit(vertices: PackedVector3Array, origin: Vector3, direction: Vector3) -> Vector3:
	var nearest: float = INF
	var result := Vector3(INF, INF, INF)
	for i: int in range(0, vertices.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, vertices[i], vertices[i + 1], vertices[i + 2])
		if hit != null and origin.distance_squared_to(hit) < nearest:
			nearest = origin.distance_squared_to(hit)
			result = hit
	return result

func column_faces(decoration: RefCounted) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for column: Dictionary in decoration._columns:
		var faces: PackedVector3Array = Geometry.faces_of(decoration.assets[column.kind][0].render_mesh)
		for point: Vector3 in faces:
			vertices.append(column.pose * point)
	return vertices

func column_poses(decoration: RefCounted, exterior_only: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for column: Dictionary in decoration._columns:
		if exterior_only and column.is_step: continue
		result[Vector3(column.edge.x, column.pose.origin.y, column.edge.y)] = [column.kind, column.pose]
	return result

func lower(data: RefCounted, center: Vector2, radius: float) -> void:
	var height: float = Data._record_top(data.cells[Vector2i(center.floor())])
	data.begin_stroke()
	data.apply_brush(center, radius, "lower", false, height, 7, height)
	data.end_stroke()

func verify_reported_rays(decoration: RefCounted) -> void:
	var data := Data.new()
	data.make_preset(0)
	for iteration: int in 4:
		lower(data, Vector2(-8, -5), 3.8)
	var field := Field.new()
	field.refresh(data)
	decoration._column_layout(field, data.seed)
	var vertices := column_faces(decoration)
	var frame := Basis.from_euler(Vector3(deg_to_rad(-55), deg_to_rad(196), 0))
	var horizontal: float = 8.0 / tan(deg_to_rad(55))
	var origin := Vector3(-8 + sin(deg_to_rad(196)) * horizontal, 8, -5 + cos(deg_to_rad(196)) * horizontal)
	for pixel: Vector2 in [Vector2(1500, 850), Vector2(2200, 800)]:
		var scale: float = tan(deg_to_rad(15.5))
		var direction: Vector3 = frame * Vector3((pixel.x / 2560 * 2 - 1) * (2560.0 / 1440) * scale, (1 - pixel.y / 1440 * 2) * scale, -1).normalized()
		var hit := first_hit(vertices, origin, direction)
		var above_lower: bool = hit.is_finite() and hit.y > 1.65 and hit.y < 3.4 and hit.distance_to(origin) < 10.0
		check(not above_lower, "reported lowered lawn exposes source side sheet at pixel %s, hit %s" % [pixel, hit])

func verify_lawn_grid(data: RefCounted, field: RefCounted, source_faces: PackedVector3Array, center: Vector2, radius: float) -> void:
	var vertices: PackedVector3Array = field.surfaces.grass.vertices.duplicate()
	vertices.append_array(field.surfaces.cliff.vertices)
	vertices.append_array(source_faces)
	var rays: int = 0
	var missing: int = 0
	var raised: int = 0
	for z: int in range(floori(center.y - radius), ceili(center.y + radius)):
		for x: int in range(floori(center.x - radius), ceili(center.x + radius)):
			var p := Vector2(x + .5, z + .5)
			if p.distance_to(center) > radius - .6: continue
			var record: Dictionary = data.cells.get(Vector2i(x, z), {})
			if record.is_empty() or int(record.water) >= 0: continue
			var support: Dictionary = field.surface_at(p)
			if support.is_empty() or absf(float(support.height) - float(record.height)) > .01: continue
			var hit := first_hit(vertices, Vector3(p.x, 10.0, p.y), Vector3.DOWN)
			rays += 1
			if not hit.is_finite() or hit.y < float(record.height) - .08: missing += 1
			elif hit.y > float(record.height) + .15:
				raised += 1
				print("RAISED ", p, " want ", record.height, " hit ", hit)
	downward_rays += rays
	check(rays >= 12 and missing == 0, "lowered ground ray grid has %d holes among %d rays near %s" % [missing, rays, center])
	check(raised == 0, "lowered ground ray grid retains %d raised source/cap fragments near %s" % [raised, center])

func verify_wall_support(field: RefCounted, center: Vector2, radius: float) -> void:
	var rays: int = 0
	var gaps: int = 0
	var top_gap: int = 0
	var foot_gap: int = 0
	for height: float in field.land_regions:
		for loop: PackedVector2Array in field.land_regions[height]:
			for i: int in loop.size():
				var a: Vector2 = loop[i]
				var b: Vector2 = loop[(i + 1) % loop.size()]
				var p: Vector2 = (a + b) * .5
				if p.distance_to(center) > radius + .5 or a.distance_to(b) < .12: continue
				var direction: Vector2 = (b - a).normalized()
				var outward := Vector2(direction.y, -direction.x)
				var receiver: Dictionary = field.surface_at(p + outward * .3)
				var upper: Dictionary = field.surface_at(p - outward * .25)
				if receiver.is_empty() or upper.is_empty() or int(receiver.water) >= 0 or int(upper.water) >= 0: continue
				var bottom: float = receiver.height
				if absf(float(upper.height) - height) > .01 or height - bottom < .4: continue
				for y: float in [height - .025, (height + bottom) * .5, bottom + .025]:
					var origin := Vector3(p.x + outward.x * 2.0, y, p.y + outward.y * 2.0)
					var hit := first_hit(field.surfaces.cliff.vertices, origin, Vector3(-outward.x, 0.0, -outward.y))
					rays += 1
					if not hit.is_finite() or origin.distance_to(hit) > 3.5:
						gaps += 1
						print("SUPPORT GAP ", p, " top ", height, " bottom ", bottom, " ray_y ", y, " hit ", hit)
						if y > height - .04: top_gap += 1
						if y < bottom + .04: foot_gap += 1
	horizontal_rays += rays
	check(rays >= 9 and gaps == 0, "continuous wall loses %d of %d support rays near %s (top %d, foot %d)" % [gaps, rays, center, top_gap, foot_gap])

func verify_fixture(decoration: RefCounted, seed_value: int, center: Vector2, strokes: int, notch: bool = false) -> void:
	var data := Data.new()
	data.seed = seed_value
	data.make_preset(0)
	var field := Field.new()
	field.refresh(data)
	decoration._column_layout(field, data.seed)
	var before := column_poses(decoration)
	for iteration: int in strokes:
		lower(data, center, 3.8)
		field.refresh(data)
		decoration._column_layout(field, data.seed)
	if notch:
		for iteration: int in strokes:
			lower(data, center + Vector2(-5, -4), 3.8)
		field.refresh(data)
		decoration._column_layout(field, data.seed)
	if notch:
		var holes: int = 0
		for loop: PackedVector2Array in field.land_regions[3.5]:
			if Field._area(loop) < 0.0: holes += 1
		check(holes == 0, "second lowering joins the enclosed upper hole to the outer edge")
	var source_faces := column_faces(decoration)
	verify_lawn_grid(data, field, source_faces, center, 3.8)
	verify_wall_support(field, center, 3.8)
	var fresh := Field.new()
	fresh.refresh(data)
	var fresh_decoration := Decoration.new()
	fresh_decoration.assets = decoration.assets
	fresh_decoration._column_layout(fresh, data.seed)
	verify_lawn_grid(data, fresh, column_faces(fresh_decoration), center, 3.8)
	verify_wall_support(fresh, center, 3.8)
	for iteration: int in strokes * (2 if notch else 1):
		data.undo()
	field.refresh(data)
	decoration._column_layout(field, data.seed)
	check(column_poses(decoration) == before, "undo restores the initial supported crown layout seed %d near %s" % [seed_value, center])
	print("INTERIOR FIXTURE seed ", seed_value, " center ", center, " strokes ", strokes, " joined ", notch)

func verify_through_hole(decoration: RefCounted) -> void:
	var data := Data.new()
	data.make_preset(2)
	var field := Field.new()
	field.refresh(data)
	decoration._column_layout(field, data.seed)
	var vertices: PackedVector3Array = field.surfaces.grass.vertices.duplicate()
	vertices.append_array(field.surfaces.cliff.vertices)
	var hit := first_hit(vertices, Vector3(-4, 10, 0), Vector3.DOWN)
	check(not hit.is_finite(), "intentional through-hole remains physically open")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var decoration := Decoration.new()
	decoration.load_assets()
	verify_reported_rays(decoration)
	for seed_value: int in [7301, 2104, 4242]:
		verify_fixture(decoration, seed_value, Vector2(-8, -5), 4)
		verify_fixture(decoration, seed_value, Vector2(13, 0), 4)
	verify_fixture(decoration, 7301, Vector2(-8, -5), 8)
	verify_fixture(decoration, 7301, Vector2(-8, -5), 4, true)
	verify_through_hole(decoration)
	print("INTERIOR TERRAIN EDIT: %d checks, %d failures, %d downward rays, %d horizontal support rays" % [checks, failures, downward_rays, horizontal_rays])
	quit(1 if failures > 0 else 0)
