extends RefCounted
## Shared environment & ancient-Chinese soft color-block style presets (01–04).

const STYLE_PRESETS: Array[Dictionary] = [
	{
		"name": "天青烟岚 · 宋韵青绿",
		"sun_rot": Vector3(-25.5, 38.0, 0.0),
		"sun_color": Color(1.0, 0.94, 0.80),
		"sun_energy": 2.02,
		"sun_angular": 1.15,
		"shadow_opacity": 0.96,
		"fill_rot": Vector3(-24.0, 16.0, 0.0),
		"fill_color": Color(0.54, 0.72, 1.0),
		"fill_energy": 0.22,
		"ambient_color": Color(0.38, 0.54, 0.84),
		"ambient_energy": 0.070,
		"ssao_intensity": 1.24,
		"fog_color": Color(0.78, 0.84, 0.88),
		"fog_density": 0.00016,
		"fog_sun_scatter": 0.58,
		"sky_zenith": Color(0.50, 0.69, 0.79),
		"sky_mid": Color(0.74, 0.84, 0.87),
		"sky_horizon": Color(0.97, 0.91, 0.79),
		"sky_sun_glow": Color(1.0, 0.90, 0.70),
		"sky_sun_core": Color(1.0, 0.97, 0.86),
		"sky_cloud_dark": Color(0.44, 0.58, 0.69),
		"sky_cloud_light": Color(0.97, 0.92, 0.81),
		"mountain_dark": Color(0.33, 0.45, 0.53),
		"mountain_light": Color(0.68, 0.68, 0.60),
		"grass_base": Color(0.238, 0.352, 0.214),
		"grass_highlight": Color(0.442, 0.518, 0.312),
		"ground_fine": 0.05,
		"cover_relief": 0.0,
		"stone_shadow": Color(0.21, 0.27, 0.42),
		"stone_mid": Color(0.49, 0.47, 0.46),
		"stone_lit": Color(0.83, 0.75, 0.63),
		"stone_mist": Color(0.89, 0.89, 0.86),
		"water_deep": Color(0.076, 0.285, 0.258),
		"decor_shadow": Color(0.70, 0.82, 0.93),
		"decor_lit": Color(1.05, 1.02, 0.94),
		"leaf_shadow": Color(0.11, 0.20, 0.16),
		"leaf_mid": Color(0.28, 0.41, 0.26),
		"leaf_lit": Color(0.62, 0.70, 0.48),
		"foliage_dark": Vector3(0.13, 0.22, 0.15),
		"foliage_light": Vector3(0.36, 0.43, 0.27),
		"lantern_glow": 0.08,
		"lantern_color": Color(1.0, 0.76, 0.40),
		"contrast": 1.04,
		"saturation": 0.98,
	},
	{
		"name": "苍黛水墨 · 留白禅境",
		"sun_rot": Vector3(-25.0, 78.0, 0.0),
		"sun_color": Color(1.0, 0.93, 0.80),
		"sun_energy": 1.40,
		"sun_angular": 2.4,
		"shadow_opacity": 0.80,
		"fill_rot": Vector3(-45.0, -96.0, 0.0),
		"fill_color": Color(0.72, 0.75, 0.76),
		"fill_energy": 0.08,
		"ambient_color": Color(0.62, 0.65, 0.64),
		"ambient_energy": 0.32,
		"ssao_intensity": 0.90,
		"fog_color": Color(0.90, 0.88, 0.81),
		"fog_density": 0.00058,
		"fog_sun_scatter": 0.42,
		"sky_zenith": Color(0.77, 0.76, 0.71),
		"sky_mid": Color(0.89, 0.87, 0.80),
		"sky_horizon": Color(0.96, 0.92, 0.84),
		"sky_sun_glow": Color(0.99, 0.92, 0.78),
		"sky_sun_core": Color(1.0, 0.97, 0.90),
		"sky_cloud_dark": Color(0.74, 0.72, 0.67),
		"sky_cloud_light": Color(0.96, 0.93, 0.86),
		"mountain_dark": Color(0.60, 0.59, 0.56),
		"mountain_light": Color(0.86, 0.82, 0.75),
		"grass_base": Color(0.18, 0.27, 0.16),
		"grass_highlight": Color(0.31, 0.39, 0.22),
		"ground_fine": 0.05,
		"cover_relief": 0.0,
		"stone_shadow": Color(0.12, 0.15, 0.18),
		"stone_mid": Color(0.23, 0.26, 0.28),
		"stone_lit": Color(0.43, 0.44, 0.43),
		"stone_mist": Color(0.89, 0.87, 0.80),
		"water_deep": Color(0.07, 0.23, 0.22),
		"decor_shadow": Color(0.80, 0.82, 0.82),
		"decor_lit": Color(0.99, 0.96, 0.90),
		"leaf_shadow": Color(0.10, 0.17, 0.13),
		"leaf_mid": Color(0.18, 0.27, 0.18),
		"leaf_lit": Color(0.33, 0.42, 0.26),
		"foliage_dark": Vector3(0.12, 0.20, 0.14),
		"foliage_light": Vector3(0.26, 0.34, 0.21),
		"lantern_glow": 0.85,
		"lantern_color": Color(1.0, 0.72, 0.34),
		"contrast": 1.03,
		"saturation": 0.91,
	},
	{
		"name": "落日熔金 · 暖玉流霞",
		"sun_rot": Vector3(-22.0, 80.0, 0.0),
		"sun_color": Color(1.0, 0.80, 0.56),
		"sun_energy": 1.42,
		"sun_angular": 2.0,
		"shadow_opacity": 0.84,
		"fill_rot": Vector3(-45.0, -96.0, 0.0),
		"fill_color": Color(0.75, 0.74, 0.86),
		"fill_energy": 0.07,
		"ambient_color": Color(0.66, 0.64, 0.74),
		"ambient_energy": 0.30,
		"ssao_intensity": 1.24,
		"fog_color": Color(0.92, 0.80, 0.68),
		"fog_density": 0.00050,
		"fog_sun_scatter": 0.52,
		"sky_zenith": Color(0.50, 0.56, 0.72),
		"sky_mid": Color(0.92, 0.76, 0.64),
		"sky_horizon": Color(0.98, 0.84, 0.66),
		"sky_sun_glow": Color(1.0, 0.74, 0.42),
		"sky_sun_core": Color(1.0, 0.90, 0.68),
		"sky_cloud_dark": Color(0.62, 0.58, 0.70),
		"sky_cloud_light": Color(0.99, 0.88, 0.74),
		"mountain_dark": Color(0.46, 0.42, 0.52),
		"mountain_light": Color(0.78, 0.64, 0.52),
		"grass_base": Color(0.25, 0.33, 0.19),
		"grass_highlight": Color(0.43, 0.45, 0.26),
		"ground_fine": 0.05,
		"cover_relief": 0.0,
		"stone_shadow": Color(0.22, 0.24, 0.30),
		"stone_mid": Color(0.36, 0.34, 0.33),
		"stone_lit": Color(0.56, 0.48, 0.39),
		"stone_mist": Color(0.92, 0.83, 0.74),
		"water_deep": Color(0.08, 0.31, 0.30),
		"decor_shadow": Color(0.84, 0.82, 0.90),
		"decor_lit": Color(1.05, 0.96, 0.87),
		"leaf_shadow": Color(0.12, 0.18, 0.12),
		"leaf_mid": Color(0.24, 0.31, 0.17),
		"leaf_lit": Color(0.48, 0.48, 0.27),
		"foliage_dark": Vector3(0.15, 0.19, 0.11),
		"foliage_light": Vector3(0.35, 0.36, 0.21),
		"lantern_glow": 0.58,
		"lantern_color": Color(1.0, 0.66, 0.24),
		"contrast": 1.05,
		"saturation": 1.03,
	},
	{
		"name": "暮色苍兰 · 烟渚星灯",
		"sun_rot": Vector3(-28.0, 72.0, 0.0),
		"sun_color": Color(0.68, 0.82, 0.98),
		"sun_energy": 0.86,
		"sun_angular": 2.8,
		"shadow_opacity": 0.72,
		"fill_rot": Vector3(-48.0, -96.0, 0.0),
		"fill_color": Color(0.46, 0.64, 0.82),
		"fill_energy": 0.14,
		"ambient_color": Color(0.36, 0.50, 0.66),
		"ambient_energy": 0.38,
		"ssao_intensity": 1.08,
		"fog_color": Color(0.32, 0.45, 0.58),
		"fog_density": 0.00058,
		"fog_sun_scatter": 0.24,
		"sky_zenith": Color(0.18, 0.28, 0.42),
		"sky_mid": Color(0.30, 0.44, 0.58),
		"sky_horizon": Color(0.44, 0.58, 0.68),
		"sky_sun_glow": Color(0.64, 0.80, 0.92),
		"sky_sun_core": Color(0.88, 0.95, 1.0),
		"sky_cloud_dark": Color(0.24, 0.35, 0.47),
		"sky_cloud_light": Color(0.58, 0.70, 0.80),
		"mountain_dark": Color(0.20, 0.28, 0.38),
		"mountain_light": Color(0.38, 0.50, 0.60),
		"grass_base": Color(0.15, 0.26, 0.22),
		"grass_highlight": Color(0.26, 0.37, 0.30),
		"ground_fine": 0.05,
		"cover_relief": 0.0,
		"stone_shadow": Color(0.16, 0.21, 0.29),
		"stone_mid": Color(0.26, 0.32, 0.39),
		"stone_lit": Color(0.38, 0.44, 0.49),
		"stone_mist": Color(0.42, 0.54, 0.64),
		"water_deep": Color(0.05, 0.22, 0.27),
		"decor_shadow": Color(0.72, 0.82, 0.92),
		"decor_lit": Color(0.88, 0.94, 1.02),
		"leaf_shadow": Color(0.07, 0.14, 0.12),
		"leaf_mid": Color(0.14, 0.23, 0.18),
		"leaf_lit": Color(0.24, 0.35, 0.27),
		"foliage_dark": Vector3(0.09, 0.15, 0.13),
		"foliage_light": Vector3(0.22, 0.31, 0.25),
		"lantern_glow": 1.0,
		"lantern_color": Color(1.0, 0.62, 0.20),
		"contrast": 1.05,
		"saturation": 1.02,
	}
]

static func setup(parent: Node3D, landscape: Node3D, sunlight_energy: float = 1.46, fill_energy: float = 0.04, ambient_energy: float = 0.28, background_haze: float = 0.68) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-24.0, 80.0, 0.0)
	sun.light_color = Color("ffe6b8")
	sun.light_energy = sunlight_energy
	sun.light_specular = 0.20
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 78
	sun.directional_shadow_split_1 = 0.14
	sun.directional_shadow_split_2 = 0.34
	sun.directional_shadow_split_3 = 0.62
	sun.light_angular_distance = 1.15
	sun.shadow_opacity = 0.93
	sun.shadow_bias = 0.055
	sun.shadow_normal_bias = 1.18
	sun.directional_shadow_blend_splits = true
	parent.add_child(sun)
	landscape.set_sun_direction(sun.transform.basis.z)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-46.0, -96.0, 0.0)
	fill.light_color = Color("a3ccdc")
	fill.light_energy = fill_energy
	fill.shadow_enabled = false
	parent.add_child(fill)

	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/terrain_editor/sky.gdshader")
	sky_material.set_shader_parameter("haze", background_haze)
	var backdrop: Texture2D = load("res://assets/terrain_editor/cloud_backdrop_v01.png")
	var bitmap := backdrop.get_image()
	if bitmap.generate_mipmaps() == OK:
		backdrop = ImageTexture.create_from_image(bitmap)
	sky_material.set_shader_parameter("cloud_backdrop", backdrop)
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.environment.sky = sky

	var settings := env.environment
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	settings.ambient_light_color = Color("708fc2")
	settings.ambient_light_sky_contribution = 0.34
	settings.ambient_light_energy = ambient_energy
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = 1.05
	settings.tonemap_white = 5.2
	settings.ssao_enabled = true
	settings.ssao_radius = 1.25
	settings.ssao_intensity = 0.95
	settings.ssao_power = 1.25
	settings.ssao_detail = 0.0
	settings.ssao_horizon = 0.28
	settings.ssao_sharpness = 0.98
	settings.ssao_light_affect = 0.04
	settings.ssil_enabled = true
	settings.ssil_radius = 3.0
	settings.ssil_intensity = 0.40
	settings.ssil_sharpness = 0.92
	settings.ssil_normal_rejection = 0.80
	settings.glow_enabled = true
	settings.glow_intensity = 0.76
	settings.glow_bloom = 0.080
	settings.glow_hdr_threshold = 0.80
	settings.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	for level in 7:
		settings.set_glow_level(level, [0.0, 0.0, 0.6, 1.0, 0.8, 0.5, 0.0][level])
	settings.adjustment_enabled = true
	settings.adjustment_contrast = 1.04
	settings.adjustment_saturation = 1.02
	settings.fog_enabled = true
	settings.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	settings.fog_light_color = Color("e3e8de")
	settings.fog_light_energy = 1.0
	settings.fog_sun_scatter = 0.38
	settings.fog_density = 0.00042
	settings.fog_sky_affect = 0.0
	parent.add_child(env)
	apply_style_preset(parent, 0)

static func apply_style_preset(editor: Node3D, index: int) -> void:
	var idx := clampi(index, 0, STYLE_PRESETS.size() - 1)
	var p: Dictionary = STYLE_PRESETS[idx]

	var sun := editor.get_node_or_null("SunLight") as DirectionalLight3D
	if sun != null:
		sun.rotation_degrees = p.sun_rot
		sun.light_color = p.sun_color
		sun.light_energy = p.sun_energy
		sun.light_angular_distance = p.sun_angular
		sun.shadow_opacity = p.shadow_opacity

	var fill := editor.get_node_or_null("FillLight") as DirectionalLight3D
	if fill != null:
		fill.rotation_degrees = p.fill_rot
		fill.light_color = p.fill_color
		fill.light_energy = p.fill_energy

	var env_node := editor.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node != null and env_node.environment != null:
		var settings := env_node.environment
		settings.ambient_light_color = p.ambient_color
		settings.ambient_light_energy = p.ambient_energy
		settings.ssao_intensity = p.ssao_intensity
		settings.fog_light_color = p.fog_color
		settings.fog_density = p.fog_density
		settings.fog_sun_scatter = p.fog_sun_scatter
		settings.adjustment_contrast = p.contrast
		settings.adjustment_saturation = p.saturation
		if settings.sky != null and settings.sky.sky_material is ShaderMaterial:
			var sky_mat := settings.sky.sky_material as ShaderMaterial
			sky_mat.set_shader_parameter("sky_zenith", p.sky_zenith)
			sky_mat.set_shader_parameter("sky_mid", p.sky_mid)
			sky_mat.set_shader_parameter("sky_horizon", p.sky_horizon)
			sky_mat.set_shader_parameter("sky_sun_glow", p.sky_sun_glow)
			sky_mat.set_shader_parameter("sky_sun_core", p.sky_sun_core)
			sky_mat.set_shader_parameter("sky_cloud_dark", p.sky_cloud_dark)
			sky_mat.set_shader_parameter("sky_cloud_light", p.sky_cloud_light)

	var landscape = editor.get("landscape")
	if landscape != null:
		if sun != null:
			landscape.set_sun_direction(sun.transform.basis.z)
		if landscape.material is ShaderMaterial:
			var m_mat := landscape.material as ShaderMaterial
			m_mat.set_shader_parameter("mountain_dark", p.mountain_dark)
			m_mat.set_shader_parameter("mountain_light", p.mountain_light)
			m_mat.set_shader_parameter("sky_zenith", p.sky_zenith)
			m_mat.set_shader_parameter("sky_mid", p.sky_mid)
			m_mat.set_shader_parameter("sky_horizon", p.sky_horizon)
			m_mat.set_shader_parameter("sky_sun_glow", p.sky_sun_glow)
			m_mat.set_shader_parameter("sky_sun_core", p.sky_sun_core)
		for deck_mat in landscape.cloud_materials:
			if deck_mat is ShaderMaterial:
				deck_mat.set_shader_parameter("cloud_shade_color", p.sky_cloud_dark)
				deck_mat.set_shader_parameter("cloud_lit_color", p.sky_cloud_light)
				deck_mat.set_shader_parameter("sky_zenith", p.sky_zenith)
				deck_mat.set_shader_parameter("sky_mid", p.sky_mid)
				deck_mat.set_shader_parameter("sky_horizon", p.sky_horizon)
				deck_mat.set_shader_parameter("sky_sun_glow", p.sky_sun_glow)
				deck_mat.set_shader_parameter("sky_sun_core", p.sky_sun_core)

	var renderer = editor.get("renderer")
	if renderer != null:
		for key in ["grass", "rim_green", "shore", "sculpted_terrain", "grass_blades"]:
			if renderer.materials.has(key):
				var mat: ShaderMaterial = renderer.materials[key]
				mat.set_shader_parameter("grass_base", p.grass_base)
				mat.set_shader_parameter("grass_highlight", p.grass_highlight)
				mat.set_shader_parameter("ground_fine_strength", p.ground_fine)
				mat.set_shader_parameter("lantern_glow_strength", p.lantern_glow)
				mat.set_shader_parameter("lantern_glow_color", p.lantern_color)
				if key == "grass":
					mat.set_shader_parameter("cover_relief", p.cover_relief)
		for key in ["grass", "cliff", "sculpted_rock", "stone_mantle", "sculpted_terrain"]:
			if renderer.materials.has(key):
				var mat: ShaderMaterial = renderer.materials[key]
				mat.set_shader_parameter("stone_shadow_color", p.stone_shadow)
				mat.set_shader_parameter("stone_mid_color", p.stone_mid)
				mat.set_shader_parameter("stone_lit_color", p.stone_lit)
				if p.has("stone_mist"):
					mat.set_shader_parameter("stone_mist_color", p.stone_mist)
		if renderer.materials.has("water"):
			renderer.materials.water.set_shader_parameter("water_deep", p.water_deep)
		if renderer.get("mist") != null and renderer.mist.multimesh != null and renderer.mist.multimesh.mesh != null:
			var mist_mat := renderer.mist.multimesh.mesh.material as ShaderMaterial
			if mist_mat != null and p.has("stone_mist"):
				mist_mat.set_shader_parameter("mist_color", (p.stone_mist as Color).lerp(p.sky_cloud_light as Color, 0.45))

		if renderer.decoration != null and renderer.decoration.get("assets") is Dictionary:
			var assets: Dictionary = renderer.decoration.assets
			for kind in assets:
				for entry: Dictionary in assets[kind]:
					for mesh_key in ["mesh", "render_mesh"]:
						if not entry.has(mesh_key) or entry[mesh_key] == null:
							continue
						var m: Mesh = entry[mesh_key]
						if m.get_surface_count() == 0:
							continue
						var sm := m.surface_get_material(0) as ShaderMaterial
						if sm == null:
							continue
						if kind.begins_with("cliff_column") or kind.begins_with("underside_rock") or kind in ["cliff_rock", "surface_rock", "shore_rock", "shore_boulder", "shore_pebble", "rim_outcrop", "rim_shelf", "path"]:
							sm.set_shader_parameter("stone_shadow_color", p.stone_shadow)
							sm.set_shader_parameter("stone_mid_color", p.stone_mid)
							sm.set_shader_parameter("stone_lit_color", p.stone_lit)
							if p.has("stone_mist"):
								sm.set_shader_parameter("stone_mist_color", p.stone_mist)
						elif sm.shader != null and sm.shader.resource_path.ends_with("foliage.gdshader"):
							sm.set_shader_parameter("dark_color", p.foliage_dark)
							sm.set_shader_parameter("light_color", p.foliage_light)
						elif sm.shader != null and sm.shader.resource_path.ends_with("foliage_cards.gdshader"):
							var is_pine: bool = kind == "tree_b"
							var is_bush: bool = kind == "bush"
							var sh_col: Color = p.leaf_shadow.darkened(0.04 if is_bush else (0.10 if is_pine else 0.0))
							var mid_col: Color = p.leaf_mid.lightened(0.02) if is_bush else p.leaf_mid.darkened(0.08 if is_pine else 0.0)
							var lit_col: Color = p.leaf_lit.lightened(0.04) if is_bush else p.leaf_lit.darkened(0.06 if is_pine else 0.0)
							sm.set_shader_parameter("leaf_shadow", sh_col)
							sm.set_shader_parameter("leaf_mid", mid_col)
							sm.set_shader_parameter("leaf_lit", lit_col)
						else:
							sm.set_shader_parameter("decor_sky_shadow", p.decor_shadow)
							sm.set_shader_parameter("decor_sky_lit", p.decor_lit)

		if renderer.props != null and renderer.props.has_method("apply_style_preset"):
			renderer.props.apply_style_preset(idx, p)
	if editor.get("motes") != null and editor.motes.has_method("apply_style_palette"):
		editor.motes.apply_style_palette(p)
