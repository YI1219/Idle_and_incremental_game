extends Node3D
## Placeholder Y-fork. Reads WorldSim.trip; does not tick the economy.

const Trip := preload("res://scripts/sim/explore_trip.gd")
const LAYER := 8
const CELL := 1.0

var sim: RefCounted
var _multimesh: MultiMesh
var _markers: Node3D
var _ordered: Array[Vector2i] = []
var _loot_shown := true
var _hud: Label
var _hint: Label


func _ready() -> void:
	add_to_group("explore_shell")
	_build_mesh()
	_markers = Node3D.new()
	_markers.name = "Markers"
	add_child(_markers)
	_build_hud()
	call_deferred("_bind_sim")


func _bind_sim() -> void:
	var island := get_tree().get_first_node_in_group("island_shell")
	if island == null:
		return
	sim = island.sim
	rebuild()


func is_walkable(world: Vector3) -> bool:
	if sim == null or sim.trip == null:
		return true
	return bool(sim.trip.has_cell(world_to_cell(world)))


func world_to_cell(pos: Vector3) -> Vector2i:
	var origin: Vector3 = SpaceState.explore_origin()
	return Vector2i(floori((pos.x - origin.x) / CELL), floori((pos.z - origin.z) / CELL))


func cell_center(c: Vector2i) -> Vector3:
	var origin: Vector3 = SpaceState.explore_origin()
	return origin + Vector3((float(c.x) + 0.5) * CELL, 0.0, (float(c.y) + 0.5) * CELL)


func _process(_delta: float) -> void:
	if not SpaceState.is_exploring() or sim == null or sim.trip == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	sim.trip.touch(sim, world_to_cell(player.global_position))
	if sim.trip.consume_fail():
		var space := get_tree().get_first_node_in_group("space_controller")
		if space and space.has_method("request_transition"):
			space.request_transition("outside")
	if _loot_shown != bool(sim.trip.loot_present):
		_loot_shown = bool(sim.trip.loot_present)
		rebuild()
	_refresh_hud()


func rebuild() -> void:
	if sim == null or sim.trip == null:
		return
	_ordered.clear()
	for key in sim.trip.cells.keys():
		_ordered.append(key)
	_ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	_multimesh.instance_count = _ordered.size()
	for i in _ordered.size():
		var c: Vector2i = _ordered[i]
		var xf := Transform3D()
		xf.origin = cell_center(c) + Vector3(0.0, -0.08, 0.0)
		xf.basis = xf.basis.scaled(Vector3(0.96, 0.16, 0.96))
		_multimesh.set_instance_transform(i, xf)
		_multimesh.set_instance_color(i, _color_for(c))
	_rebuild_markers()
	_set_layers(self)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	layer.visible = false
	add_child(layer)
	_hint = Label.new()
	_hint.offset_left = 16
	_hint.offset_top = 12
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color("2b3530"))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = "走回入口撤离  左路拾取  右路观察  左路尽头是雾  7入包"
	layer.add_child(_hint)
	_hud = Label.new()
	_hud.offset_left = 16
	_hud.offset_top = 40
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_color", Color("2b3530"))
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)


func _refresh_hud() -> void:
	if _hud == null or sim == null or sim.trip == null:
		return
	var lines: PackedStringArray = sim.trip.questions(sim)
	var home := ""
	if sim.craft:
		home = "\n家里仍在转  药草 %d  药品 %d" % [sim.craft.total_herbs(), sim.craft.potions()]
	_hud.text = "%s\n%s\n%s%s" % [lines[0], lines[1], lines[2], home]


func _color_for(c: Vector2i) -> Color:
	if c == Trip.DANGER_CELL:
		return Color("3a3d4a")
	if c == Trip.LOOT_CELL:
		return Color("c4a46a") if bool(sim.trip.loot_present) else Color("7a8a7c")
	if c == Trip.NOTE_CELL:
		return Color("8aa4b8")
	if sim.trip.branch_of(c) == "left":
		return Color("8b7a68")
	if sim.trip.branch_of(c) == "right":
		return Color("6f8690")
	return Color("7d8c84")


func _rebuild_markers() -> void:
	for child in _markers.get_children():
		child.queue_free()
	_pillar(Vector2i(0, 0), Color("9aa7a0"), 0.85)
	if sim.trip.loot_present:
		_pillar(Trip.LOOT_CELL, Color("d7b56a"), 0.55)
	_pillar(Trip.NOTE_CELL, Color("cfe0ea"), 0.5)
	_pillar(Trip.DANGER_CELL, Color("2c3140"), 1.35)


func _pillar(cell: Vector2i, color: Color, height: float) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.42, height, 0.42)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	mesh.mesh = box
	mesh.position = cell_center(cell) + Vector3(0.0, height * 0.5, 0.0)
	_markers.add_child(mesh)


func _build_mesh() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	box.material = mat
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = box
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = _multimesh
	inst.name = "ForkMultiMesh"
	add_child(inst)


func _set_layers(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = LAYER
	for child in node.get_children():
		_set_layers(child)
