extends Node3D
class_name DemoCottage

const COTTAGE_SCENE := preload("res://assets/buildings/cottage/cottage_tripo.glb")

@export var roof_visible := true:
	set(value):
		roof_visible = value
		_apply_roof_visibility()

func _ready() -> void:
	name = "DemoCottage"
	position = Vector3(0.0, 0.0, -2.2)
	set_meta("door_width", 1.608)
	set_meta("door_height", 1.8294)
	set_meta("door_local_z", 2.2)

	var model := COTTAGE_SCENE.instantiate()
	model.name = "CottageModel"
	# Tripo front is +X; align the off-center doorway with the existing world entrance.
	model.rotation.y = -PI / 2.0
	model.position = Vector3(-0.624, 0.0, 0.2)
	add_child(model)
	_add_colliders()
	_apply_roof_visibility()

func _add_colliders() -> void:
	var body := StaticBody3D.new()
	body.name = "CottageCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)

	# Boxes match the measured Tripo wall footprint; gap follows the widened mesh doorway.
	_add_wall_box(body, "BackWall", Vector3(-0.624, 1.0, -1.92), Vector3(4.5, 2.0, 0.28))
	_add_wall_box(body, "LeftWall", Vector3(-2.72, 1.0, 0.10), Vector3(0.26, 2.0, 4.2))
	_add_wall_box(body, "RightWall", Vector3(1.47, 1.0, 0.10), Vector3(0.26, 2.0, 4.2))
	_add_wall_box(body, "FrontWallLeft", Vector3(-1.827, 0.91, 2.22), Vector3(2.046, 1.82, 0.25))
	_add_wall_box(body, "FrontWallRight", Vector3(1.202, 0.91, 2.22), Vector3(0.796, 1.82, 0.25))
	_add_wall_box(body, "FrontHeader", Vector3(0.0, 1.94, 2.22), Vector3(1.608, 0.22, 0.25))

func _add_wall_box(parent: StaticBody3D, box_name: String, center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.name = box_name
	collider.position = center
	collider.shape = shape
	parent.add_child(collider)

func _apply_roof_visibility() -> void:
	if not is_inside_tree():
		return
	var model := get_node_or_null("CottageModel")
	if model == null:
		return
	_set_roof_nodes_visible(model)

func _set_roof_nodes_visible(node: Node) -> void:
	for child in node.get_children():
		if child is Node3D and (child.name.begins_with("Roof") or child.name.begins_with("Ridge") or child.name.begins_with("Eave")):
			child.visible = roof_visible
		_set_roof_nodes_visible(child)
