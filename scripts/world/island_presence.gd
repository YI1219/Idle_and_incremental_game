extends Node3D
## One floating island's runtime: LOD swap, paused processing, lazy economy settle.

const FAR_ENTER := 24.0
const FAR_LEAVE := 18.0

var island_hash: int = 0
var cell_count: int = 0
var centroid := Vector3.ZERO
var high_volume: ArrayMesh
var low_volume: ArrayMesh
var high_top: ArrayMesh
var far: bool = false
var last_settled_minutes: float = 0.0
var _high_node: MeshInstance3D
var _low_node: MeshInstance3D


func _ready() -> void:
	_high_node = MeshInstance3D.new()
	_high_node.name = "HighVolume"
	_high_node.visible = false
	add_child(_high_node)
	_low_node = MeshInstance3D.new()
	_low_node.name = "LowVolume"
	_low_node.visible = false
	add_child(_low_node)


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


func set_active(active: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if not active:
		far = true


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
