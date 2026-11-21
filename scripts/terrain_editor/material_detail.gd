extends RefCounted
## Shared linear packed maps plus sRGB mineral & hand-painted gouache wash maps.
const GOUACHE_WASH: Texture2D = preload("res://assets/terrain_editor/gouache_stone_sol61.png")

static func bind(material: ShaderMaterial) -> void:
	material.set_shader_parameter("stone_detail_map", preload("res://assets/textures/terrain/stone_detail_spall_v3.res"))
	material.set_shader_parameter("stone_mineral_map", preload("res://assets/textures/terrain/stone_mineral_v1.png"))
	material.set_shader_parameter("stone_gouache_map", GOUACHE_WASH)
	material.set_shader_parameter("ground_detail_map", preload("res://assets/textures/terrain/ground_detail.png"))
	var route := PackedVector2Array(preload("res://scripts/terrain_editor/terrain_paths.gd").POINTS)
	material.set_shader_parameter("footpath_count", route.size())
	route.resize(8)
	material.set_shader_parameter("footpath_points", route)
