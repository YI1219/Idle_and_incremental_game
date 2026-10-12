extends RefCounted
## Linear packed value/slope/roughness maps shared by all assembled surfaces.
static func bind(material:ShaderMaterial)->void:
 material.set_shader_parameter("stone_detail_map",preload("res://assets/textures/terrain/stone_detail.png"))
 material.set_shader_parameter("ground_detail_map",preload("res://assets/textures/terrain/ground_detail.png"))
