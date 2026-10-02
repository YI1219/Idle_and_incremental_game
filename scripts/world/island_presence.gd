extends Node3D
## One floating island: rock-kit MultiMeshes, core LOD, paused processing, lazy economy settle.

const RockKit := preload("res://scripts/world/rock_kit.gd")
const RockUnderside := preload("res://scripts/world/rock_underside.gd")

const FAR_ENTER := 36.0
const FAR_LEAVE := 28.0

var island_hash: int = 0
var cell_count: int = 0
var centroid := Vector3.ZERO
var high_volume: ArrayMesh
var low_volume: ArrayMesh
var high_top: ArrayMesh
var far: bool = false
var last_settled_minutes: float = 0.0
var rock_seed: int = 0
var rock_state: Dictionary = {}
var _high_node: MeshInstance3D
var _low_node: MeshInstance3D
var _rock_root: Node3D
var _mmis: Dictionary = {}
var _root_mmi: MultiMeshInstance3D


func _ready() -> void:
	_high_node = MeshInstance3D.new()
	_high_node.name = "HighVolume"
	_high_node.visible = false
	add_child(_high_node)
	_low_node = MeshInstance3D.new()
	_low_node.name = "LowVolume"
	_low_node.visible = false
	add_child(_low_node)
	_rock_root = Node3D.new()
	_rock_root.name = "RockKit"
	add_child(_rock_root)


func configure(p_hash: int, p_centroid: Vector3, p_cells: int, high: ArrayMesh, low: ArrayMesh, top: ArrayMesh = null) -> void:
	island_hash = p_hash
	centroid = p_centroid
	cell_count = p_cells
	high_volume = high
	low_volume = low
	high_top = top
	if _high_node == null:
		_ready()
	_high_node.mesh = high
	_low_node.mesh = low


func set_material(material: Material) -> void:
	if _high_node:
		_high_node.material_override = material
	if _low_node:
		_low_node.material_override = material


func apply_rocks(state: Dictionary) -> void:
	RockKit.ensure()
	rock_state = state
	rock_seed = int(state.get("seed", rock_seed))
	if _rock_root == null:
		_ready()
	_sync_multimeshes(state, far)


func set_active(active: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if not active:
		far = true
		if not rock_state.is_empty():
			_sync_multimeshes(rock_state, true)


func is_active() -> bool:
	return process_mode != Node.PROCESS_MODE_DISABLED and not far


func update_lod(camera_origin: Vector3) -> bool:
	var distance := Vector2(camera_origin.x - centroid.x, camera_origin.z - centroid.z).length()
	var next_far := far
	if far and distance < FAR_LEAVE:
		next_far = false
	elif not far and distance > FAR_ENTER:
		next_far = true
	if next_far == far:
		return false
	far = next_far
	process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if not rock_state.is_empty():
		var outline: PackedVector2Array = rock_state.get("outline", PackedVector2Array())
		if outline.size() >= 3:
			rock_state = RockUnderside.respace(rock_state, outline, rock_seed, far)
		_sync_multimeshes(rock_state, far)
	return true


func current_volume() -> ArrayMesh:
	return low_volume if far else high_volume


func settle(now_minutes: float) -> float:
	var dt := now_minutes - last_settled_minutes
	if dt < 0.0:
		dt = 0.0
	last_settled_minutes = now_minutes
	return dt


func mark_settled(now_minutes: float) -> void:
	last_settled_minutes = now_minutes


func piece_count() -> int:
	return int(rock_state.get("piece_count", 0))


func _sync_multimeshes(state: Dictionary, use_far: bool) -> void:
	var grouped: Dictionary = {}
	for slot in state.get("slots", []):
		var name := String(slot["piece"])
		if not grouped.has(name):
			grouped[name] = []
		(grouped[name] as Array).append(slot)
	for name in RockKit.names:
		var rows: Array = grouped.get(name, [])
		var mmi := _ensure_mmi(name)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = RockKit.piece(name).get("mesh")
		multi.instance_count = rows.size()
		for i in rows.size():
			multi.set_instance_transform(i, rows[i]["xf"])
			multi.set_instance_color(i, Color(float(rows[i].get("jitter", 0.5)), 0.0, 0.0))
		mmi.multimesh = multi
		mmi.visible = rows.size() > 0
	if _root_mmi == null:
		_root_mmi = MultiMeshInstance3D.new()
		_root_mmi.name = "Roots"
		_root_mmi.material_override = RockKit.root_material
		_root_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_rock_root.add_child(_root_mmi)
	var roots: Array = [] if use_far else state.get("roots", [])
	var root_multi := MultiMesh.new()
	root_multi.transform_format = MultiMesh.TRANSFORM_3D
	root_multi.mesh = RockKit.root_mesh
	root_multi.instance_count = roots.size()
	for i in roots.size():
		root_multi.set_instance_transform(i, roots[i])
	_root_mmi.multimesh = root_multi
	_root_mmi.visible = roots.size() > 0


func _ensure_mmi(piece_name: String) -> MultiMeshInstance3D:
	if _mmis.has(piece_name) and is_instance_valid(_mmis[piece_name]):
		return _mmis[piece_name]
	var mmi := MultiMeshInstance3D.new()
	mmi.name = piece_name
	mmi.material_override = RockKit.rock_material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rock_root.add_child(mmi)
	_mmis[piece_name] = mmi
	return mmi
