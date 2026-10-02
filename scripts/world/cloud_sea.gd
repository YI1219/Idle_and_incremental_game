extends Node3D
## Soft stylized cloud sea under the grotto islands. No distant mountains.

const SEA_Y := -3.85
const SPAN := 220.0

var _sea: MeshInstance3D
var _mid: MeshInstance3D
var _wisps: MeshInstance3D


func _ready() -> void:
	name = "CloudSea"
	add_to_group("cloud_sea")
	_sea = _plane("SeaSheet", SEA_Y, SPAN, 40, _sea_material(Color("f7f4ea"), Color("6d7f8a"), 1.0))
	_mid = _plane("MidSheet", SEA_Y - 1.15, SPAN * 0.88, 28, _sea_material(Color("efe8d8"), Color("5d6f7a"), 0.96))
	_wisps = _plane("WispSheet", SEA_Y + 1.05, SPAN * 0.62, 24, _wisp_material())
	add_child(_sea)
	add_child(_mid)
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


func _plane(node_name: String, y: float, size: float, subdiv: int, material: Material) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	mesh.subdivide_width = subdiv
	mesh.subdivide_depth = subdiv
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position.y = y
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _sea_material(base: Color, shade: Color, density: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/world/cloud_sea.gdshader")
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("shade_color", shade)
	material.set_shader_parameter("sun_tint", Color("ffe7b8"))
	material.set_shader_parameter("density", density)
	material.set_shader_parameter("scroll", 0.010)
	return material


func _wisp_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/world/cloud_wisps.gdshader")
	material.set_shader_parameter("wisp_color", Color("fffaf0"))
	material.set_shader_parameter("shade_color", Color("9aaab0"))
	return material
