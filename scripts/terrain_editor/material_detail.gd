extends RefCounted
## Linear packed value/slope/roughness maps shared by all assembled surfaces.
static func bind(material:ShaderMaterial)->void:
 material.set_shader_parameter("stone_detail_map",preload("res://assets/textures/terrain/stone_detail.png"))
 material.set_shader_parameter("ground_detail_map",preload("res://assets/textures/terrain/ground_detail.png"))
 var route:=PackedVector2Array(preload("res://scripts/terrain_editor/terrain_paths.gd").POINTS)
 material.set_shader_parameter("footpath_count",route.size())
 route.resize(8)
 material.set_shader_parameter("footpath_points",route)
