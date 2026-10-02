extends Node3D
## Soft stylized cloud sea under the grotto islands. No distant mountains.

const SEA_Y := -5.15
const SPAN := 220.0

var _sea: MeshInstance3D
var _wisps: MeshInstance3D


func _ready() -> void:
	name = "CloudSea"
	add_to_group("cloud_sea")
	_sea = _plane("SeaSheet", SEA_Y, SPAN, _sea_material())
	_wisps = _plane("WispSheet", SEA_Y + 0.85, SPAN * 0.72, _wisp_material())
	add_child(_sea)
	add_child(_wisps)


func follow_islands(bounds: Array) -> void:
	if _wisps == null:
		return
	var material := _wisps.material_override as ShaderMaterial
	if material == null:
		return
	var packed: Array[Vector4] = []
	for item in bounds:
		if item is Vector4:
			packed.append(item)
	var count := mini(packed.size(), 8)
	packed.resize(8)
	material.set_shader_parameter("island_disks", packed)
	material.set_shader_parameter("island_count", count)


func _plane(node_name: String, y: float, size: float, material: Material) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	mesh.subdivide_width = 8
	mesh.subdivide_depth = 8
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position.y = y
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _sea_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/world/cloud_sea.gdshader")
	material.set_shader_parameter("base_color", Color("e7e4d6"))
	material.set_shader_parameter("shade_color", Color("b7c4c8"))
	material.set_shader_parameter("sun_tint", Color("f3e2c0"))
	material.set_shader_parameter("density", 0.72)
	material.set_shader_parameter("scroll", 0.012)
	return material


func _wisp_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/world/cloud_wisps.gdshader")
	material.set_shader_parameter("wisp_color", Color("f4f1e6"))
	return material
