extends SceneTree
## Adjacent terrace faces must retain one shared edge after mantle recession.
## A face-local cap height previously split that edge by up to 0.68 metres.
const Surface = preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface
const Mantle = preload("res://art/lookdev/20261111_cliff_repair/checks/source_before/block_mantle.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fixture(reverse: bool, mixed_vertex_caps: bool, support_height: float = NAN) -> void:
	var source := Surface.new()
	var a := Vector3(0, 1.5, 0)
	var b := Vector3(0, .5, 0)
	var left: Array[Vector3] = [a, b, Vector3(-1, .5, 0)]
	var right: Array[Vector3] = [a, Vector3(0, .5, -1), b]
	var triangles: Array = [right, left] if reverse else [left, right]
	for triangle: Array in triangles:
		var start: int = source.vertices.size()
		source.triangle(triangle[0], triangle[1], triangle[2], Color.WHITE)
		var cap: float = 3.5 if triangle == left else 1.5
		for j: int in 3:
			source.uv[start+j] = Vector2(cap, 1.0)
		# Real contour triangles may have different cap metadata at each end.
		if mixed_vertex_caps:
			source.uv[start].x = 3.5
			for j: int in 3:
				if source.vertices[start+j] == b: source.uv[start+j].x = .5
	var cells: Dictionary = {}
	if is_finite(support_height):
		for z: int in range(-2,3):
			for x: int in range(-2,3):
				cells[Vector2i(x,z)] = {"height":support_height,"water":-1}
	var result: Dictionary = Mantle.build(source, {}, cells)
	var positions: Dictionary = {}
	var split: int = 0
	for i: int in source.vertices.size():
		var p: Vector3 = source.vertices[i]
		var q: Vector3 = result.backing.vertices[i]
		if positions.has(p) and positions[p].distance_to(q) > .00001: split += 1
		positions[p] = q
	check(split == 0, "shared terrace edge split into %d positions (reverse=%s mixed=%s)" % [split, reverse, mixed_vertex_caps])
	# The lower cap endpoint must remain seated on the receiving surface.
	if mixed_vertex_caps:
		check(positions[b].distance_to(b) < .00001, "per-vertex lower cap ignored in a mixed-height face")
	else:
		check(positions[a].distance_to(a) < .00001, "lower terrace cap pulled away from its exact boundary")
	if is_finite(support_height):
		if support_height > 1.5:
			check(positions[b].distance_to(b) > .5, "higher neighbouring land must not override the shared lower cap")
		else:
			check(positions[b].distance_to(b) < .00001, "wall foot stays seated on its lower receiving land")
	check(result.backing.vertices.size() == 6, "both adjacent wall triangles survive recession")

func _initialize() -> void:
	for reverse: bool in [false, true]:
		fixture(reverse, false)
		fixture(reverse, true)
		fixture(reverse, false, 2.0)
		fixture(reverse, false, .5)
	print("CLIFF MANTLE SEAM: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
