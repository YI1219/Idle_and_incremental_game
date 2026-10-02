extends Node3D
## One floating island: MultiMesh preview while editing, baked union after settle.

const RockKit := preload("res://scripts/world/rock_kit.gd")
const RockUnderside := preload("res://scripts/world/rock_underside.gd")
const RockBaker := preload("res://scripts/world/rock_baker.gd")

const FAR_ENTER := 36.0
const FAR_LEAVE := 28.0
const BAKE_WAIT := 0.08

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
var bake_result: Dictionary = {}
var last_bake_ms: float = 0.0
var last_hitch_ms: float = 0.0
var baked: bool = false
var _high_node: MeshInstance3D
var _low_node: MeshInstance3D
var _rock_root: Node3D
var _baked_node: MeshInstance3D
var _mmis: Dictionary = {}
var _root_mmi: MultiMeshInstance3D
var _bake_task := -1
var _bake_wait := 0.0
var _bake_pending := false
var _bake_serial := 0
var _job_box: Array = []


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
	_baked_node = MeshInstance3D.new()
	_baked_node.name = "BakedUnderside"
	_baked_node.visible = false
	_baked_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_baked_node)


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
	if _baked_node:
		_baked_node.material_override = RockKit.rock_material if RockKit.rock_material else material


func apply_rocks(state: Dictionary) -> void:
	RockKit.ensure()
	rock_state = state
	rock_seed = int(state.get("seed", rock_seed))
	if _rock_root == null:
		_ready()
	baked = false
	bake_result = {}
	if _baked_node:
		_baked_node.visible = false
	_sync_multimeshes(state, far)
	_bake_serial += 1
	_bake_pending = true
	_bake_wait = BAKE_WAIT


func _process(delta: float) -> void:
	if _bake_pending:
		_bake_wait -= delta
		if _bake_wait <= 0.0:
			_bake_pending = false
			_start_bake()
	if _bake_task != -1 and WorkerThreadPool.is_task_completed(_bake_task):
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1
		if _job_box.size() > 0:
			_apply_bake(_job_box[0])
		elif not rock_state.is_empty():
			_apply_bake(RockBaker.bake(rock_state))


func set_active(active: bool) -> void:
	if active:
		process_mode = Node.PROCESS_MODE_INHERIT
		return
	far = true
	if _bake_pending or _bake_task != -1:
		return
	process_mode = Node.PROCESS_MODE_DISABLED
	if baked:
		return
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
	if far and not _bake_pending and _bake_task == -1:
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		process_mode = Node.PROCESS_MODE_INHERIT
	if baked:
		return true
	if not rock_state.is_empty():
		var outline: PackedVector2Array = rock_state.get("outline", PackedVector2Array())
		if outline.size() >= 3:
			rock_state = RockUnderside.respace(rock_state, outline, rock_seed, far)
		_sync_multimeshes(rock_state, far)
	return true


func current_volume() -> ArrayMesh:
	if baked and _baked_node and _baked_node.mesh:
		return _baked_node.mesh
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


func baked_triangles() -> int:
	return int(bake_result.get("triangles", 0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_bake_pending = false
		if _bake_task != -1:
			WorkerThreadPool.wait_for_task_completion(_bake_task)
			_bake_task = -1


func flush_bake() -> void:
	_bake_pending = false
	if _bake_task != -1:
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1
		if _job_box.size() > 0:
			_apply_bake(_job_box[0])
			return
	if not rock_state.is_empty() and not baked:
		_apply_bake(RockBaker.bake(rock_state))


func _start_bake() -> void:
	if rock_state.is_empty():
		return
	var payload := RockBaker.prepare(rock_state)
	payload["serial"] = _bake_serial
	_job_box = []
	_bake_task = WorkerThreadPool.add_task(Callable(RockBaker, "bake_job_into").bind(payload, _job_box))


func _apply_bake(result: Dictionary) -> void:
	bake_result = result
	_swap_bake()


func _swap_bake() -> void:
	if int(bake_result.get("serial", _bake_serial)) != _bake_serial and bake_result.has("serial"):
		if int(bake_result["serial"]) != _bake_serial:
			return
	if not bool(bake_result.get("ok", false)):
		baked = false
		if _baked_node:
			_baked_node.visible = false
		_show_preview(true)
		return
	var t0 := Time.get_ticks_usec()
	RockKit.ensure()
	if _baked_node == null:
		_ready()
	_baked_node.material_override = RockKit.rock_material
	_baked_node.mesh = RockBaker.make_mesh(bake_result)
	_baked_node.visible = true
	_show_preview(false)
	baked = true
	last_bake_ms = float(bake_result.get("bake_ms", 0.0))
	last_hitch_ms = float(Time.get_ticks_usec() - t0) / 1000.0


func _show_preview(show: bool) -> void:
	if _rock_root:
		_rock_root.visible = show


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
	_rock_root.visible = true


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
