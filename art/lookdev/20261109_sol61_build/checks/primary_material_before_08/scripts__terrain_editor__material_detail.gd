extends RefCounted
## Shared linear packed maps plus sRGB mineral & hand-painted gouache wash maps.
const GOUACHE_WASH_PATH := "res://assets/terrain_editor/gouache_stone_wash.png"
static var _gouache_wash_tex: Texture2D

static func _get_gouache_wash() -> Texture2D:
	if _gouache_wash_tex != null:
		return _gouache_wash_tex
	var abs_p := ProjectSettings.globalize_path(GOUACHE_WASH_PATH)
	var img := Image.load_from_file(abs_p)
	if img != null and not img.is_empty():
		img.generate_mipmaps()
		_gouache_wash_tex = ImageTexture.create_from_image(img)
		return _gouache_wash_tex
	_gouache_wash_tex = preload("res://assets/textures/terrain/stone_mineral_v1.png")
	return _gouache_wash_tex

static func bind(material: ShaderMaterial) -> void:
	material.set_shader_parameter("stone_detail_map", preload("res://assets/textures/terrain/stone_detail_spall_v3.res"))
	material.set_shader_parameter("stone_mineral_map", preload("res://assets/textures/terrain/stone_mineral_v1.png"))
	material.set_shader_parameter("stone_gouache_map", _get_gouache_wash())
	material.set_shader_parameter("ground_detail_map", preload("res://assets/textures/terrain/ground_detail.png"))
	var route := PackedVector2Array(preload("res://scripts/terrain_editor/terrain_paths.gd").POINTS)
	material.set_shader_parameter("footpath_count", route.size())
	route.resize(8)
	material.set_shader_parameter("footpath_points", route)
