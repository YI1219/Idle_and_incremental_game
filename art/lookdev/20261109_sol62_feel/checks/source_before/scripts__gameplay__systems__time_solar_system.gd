class_name TimeSolarSystem
extends RefCounted
## Smooth ancient-Chinese twelve-shichen & solar-term lighting cycle.
## Preserves Song-dynasty celadon matte color blocks (cover_relief = 0) and
## keeps primary light azimuth anchored so composition never spins.

const SHICHEN_NAMES: Array[String] = [
	"子时 · 夜半", "丑时 · 鸡鸣", "寅时 · 平旦", "卯时 · 日出",
	"辰时 · 食时", "巳时 · 隅中", "午时 · 日中", "未时 · 日昳",
	"申时 · 哺时", "酉时 · 日入", "戌时 · 黄昏", "亥时 · 人定",
]

const SOLAR_TERMS: Array[String] = [
	"立春", "春分", "立夏", "夏至", "立秋", "秋分", "立冬", "冬至"
]

const KEYFRAMES: Array[Dictionary] = [
	{
		"at": 0.0,
		"mood": "烟渚星灯",
		"sun_rot": Vector3(-28.0, 28.0, 0.0),
		"sun_color": Color(0.68, 0.82, 0.98),
		"sun_energy": 0.84,
		"sun_angular": 2.8,
		"shadow_opacity": 0.72,
		"fill_rot": Vector3(-48.0, -96.0, 0.0),
		"fill_color": Color(0.46, 0.64, 0.82),
		"fill_energy": 0.14,
		"ambient_color": Color(0.36, 0.50, 0.66),
		"ambient_energy": 0.38,
		"ssao_intensity": 1.08,
		"fog_color": Color(0.32, 0.45, 0.58),
		"fog_density": 0.00056,
		"fog_sun_scatter": 0.22,
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
		"lantern_glow": 0.96,
		"lantern_color": Color(1.0, 0.64, 0.22),
		"contrast": 1.05,
		"saturation": 1.00,
	},
	{
		"at": 0.29,
		"mood": "晨光青绿",
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
		"at": 0.52,
		"mood": "苍黛留白",
		"sun_rot": Vector3(-25.0, 42.0, 0.0),
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
		"fog_color": Color(0.78, 0.82, 0.85),
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
		"at": 0.76,
		"mood": "暖玉流霞",
		"sun_rot": Vector3(-22.0, 34.0, 0.0),
		"sun_color": Color(1.0, 0.80, 0.56),
		"sun_energy": 1.40,
		"sun_angular": 2.0,
		"shadow_opacity": 0.82,
		"fill_rot": Vector3(-45.0, -96.0, 0.0),
		"fill_color": Color(0.75, 0.74, 0.86),
		"fill_energy": 0.07,
		"ambient_color": Color(0.66, 0.64, 0.74),
		"ambient_energy": 0.30,
		"ssao_intensity": 1.20,
		"fog_color": Color(0.71, 0.76, 0.81),
		"fog_density": 0.00048,
		"fog_sun_scatter": 0.48,
		"sky_zenith": Color(0.50, 0.56, 0.72),
		"sky_mid": Color(0.90, 0.76, 0.65),
		"sky_horizon": Color(0.96, 0.83, 0.67),
		"sky_sun_glow": Color(1.0, 0.74, 0.42),
		"sky_sun_core": Color(1.0, 0.90, 0.68),
		"sky_cloud_dark": Color(0.54, 0.60, 0.67),
		"sky_cloud_light": Color(0.98, 0.88, 0.75),
		"mountain_dark": Color(0.46, 0.42, 0.52),
		"mountain_light": Color(0.78, 0.64, 0.52),
		"grass_base": Color(0.25, 0.33, 0.19),
		"grass_highlight": Color(0.43, 0.45, 0.26),
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
		"saturation": 1.02,
	},
]

var day_progress: float = 0.29
var cycle_duration_sec: float = 240.0
var solar_term_index: int = 1
var day_count: int = 1
var paused: bool = false
var _apply_accum: float = 0.0

func tick(delta: float, editor: Node3D) -> void:
	if not paused and delta > 0.0 and cycle_duration_sec > 1.0:
		var next: float = day_progress + delta / cycle_duration_sec
		if next >= 1.0:
			var wraps: int = floori(next)
			next -= float(wraps)
			day_count += wraps
			solar_term_index = (solar_term_index + wraps) % SOLAR_TERMS.size()
		day_progress = next
		_apply_accum += delta
		if _apply_accum >= 0.08:
			_apply_accum = 0.0
			apply_to_scene(editor)

func step_shichen(editor: Node3D) -> void:
	var next: float = day_progress + (1.0 / 12.0)
	if next >= 1.0:
		next -= 1.0
		day_count += 1
		solar_term_index = (solar_term_index + 1) % SOLAR_TERMS.size()
	day_progress = next
	apply_to_scene(editor)

func set_progress(progress: float, editor: Node3D = null) -> void:
	day_progress = fposmod(progress, 1.0)
	if editor != null:
		apply_to_scene(editor)

func shichen_index() -> int:
	return int(floori(fposmod(day_progress + 1.0 / 24.0, 1.0) * 12.0)) % 12

func shichen_label() -> String:
	return SHICHEN_NAMES[shichen_index()]

func solar_term_label() -> String:
	return SOLAR_TERMS[clampi(solar_term_index, 0, SOLAR_TERMS.size() - 1)]

func is_night_or_dusk() -> bool:
	return day_progress >= 0.72 or day_progress <= 0.18

func meditation_bonus() -> float:
	var idx: int = shichen_index()
	if idx in [3, 4, 11, 0]:
		return 1.22
	return 1.0

func fishing_bonus() -> float:
	var mult: float = 1.18 if shichen_index() in [3, 8, 9] else 1.0
	if solar_term_index in [1, 5]:
		mult *= 1.12
	return mult

func current_blended_preset() -> Dictionary:
	var p: float = fposmod(day_progress, 1.0)
	var count: int = KEYFRAMES.size()
	for i in count:
		var cur_at: float = float(KEYFRAMES[i]["at"])
		var next_i: int = (i + 1) % count
		var next_at: float = float(KEYFRAMES[next_i]["at"])
		if next_i == 0:
			next_at += 1.0
		var test_p: float = p + (1.0 if p < cur_at and next_i == 0 else 0.0)
		if test_p >= cur_at and test_p <= next_at:
			var span: float = maxf(0.0001, next_at - cur_at)
			var raw_t: float = clampf((test_p - cur_at) / span, 0.0, 1.0)
			var t: float = raw_t * raw_t * (3.0 - 2.0 * raw_t)
			return _blend_dicts(KEYFRAMES[i], KEYFRAMES[next_i], t)
	return _blend_dicts(KEYFRAMES[1], KEYFRAMES[1], 0.0)

func summary_label() -> String:
	var blended: Dictionary = current_blended_preset()
	return "%s · %s · %s" % [solar_term_label(), shichen_label().split(" · ")[0], String(blended["mood"])]

static func _blend_dicts(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out: Dictionary = {}
	for key: String in a.keys():
		if key == "at":
			continue
		if key == "mood":
			out[key] = a[key] if t < 0.5 else b[key]
			continue
		var va: Variant = a[key]
		var vb: Variant = b[key]
		if va is float:
			out[key] = lerpf(float(va), float(vb), t)
		elif va is Color:
			out[key] = (va as Color).lerp(vb as Color, t)
		elif va is Vector3:
			out[key] = (va as Vector3).lerp(vb as Vector3, t)
		else:
			out[key] = va
	out["ground_fine"] = 0.05
	out["cover_relief"] = 0.0
	return out

func apply_to_scene(editor: Node3D) -> void:
	if editor == null:
		return
	var p: Dictionary = current_blended_preset()
	var sun := editor.get_node_or_null("SunLight") as DirectionalLight3D
	if sun != null:
		sun.rotation_degrees = p["sun_rot"] as Vector3
		sun.light_color = p["sun_color"] as Color
		sun.light_energy = float(p["sun_energy"])
		sun.light_angular_distance = float(p["sun_angular"])
		sun.shadow_opacity = float(p["shadow_opacity"])

	var fill := editor.get_node_or_null("FillLight") as DirectionalLight3D
	if fill != null:
		fill.rotation_degrees = p["fill_rot"] as Vector3
		fill.light_color = p["fill_color"] as Color
		fill.light_energy = float(p["fill_energy"])

	var env_node := editor.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node != null and env_node.environment != null:
		var settings: Environment = env_node.environment
		settings.ambient_light_color = p["ambient_color"] as Color
		settings.ambient_light_energy = float(p["ambient_energy"])
		settings.ssao_intensity = float(p["ssao_intensity"])
		settings.fog_light_color = p["fog_color"] as Color
		settings.fog_density = float(p["fog_density"])
		settings.fog_sun_scatter = float(p["fog_sun_scatter"])
		settings.adjustment_contrast = float(p["contrast"])
		settings.adjustment_saturation = float(p["saturation"])
		if settings.sky != null and settings.sky.sky_material is ShaderMaterial:
			var sky_mat := settings.sky.sky_material as ShaderMaterial
			sky_mat.set_shader_parameter("sky_zenith", p["sky_zenith"])
			sky_mat.set_shader_parameter("sky_mid", p["sky_mid"])
			sky_mat.set_shader_parameter("sky_horizon", p["sky_horizon"])
			sky_mat.set_shader_parameter("sky_sun_glow", p["sky_sun_glow"])
			sky_mat.set_shader_parameter("sky_sun_core", p["sky_sun_core"])
			sky_mat.set_shader_parameter("sky_cloud_dark", p["sky_cloud_dark"])
			sky_mat.set_shader_parameter("sky_cloud_light", p["sky_cloud_light"])

	var landscape: Variant = editor.get("landscape")
	if landscape != null:
		if sun != null:
			landscape.set_sun_direction(sun.transform.basis.z)
		if landscape.material is ShaderMaterial:
			var m_mat := landscape.material as ShaderMaterial
			m_mat.set_shader_parameter("mountain_dark", p["mountain_dark"])
			m_mat.set_shader_parameter("mountain_light", p["mountain_light"])
			m_mat.set_shader_parameter("sky_zenith", p["sky_zenith"])
			m_mat.set_shader_parameter("sky_mid", p["sky_mid"])
			m_mat.set_shader_parameter("sky_horizon", p["sky_horizon"])
			m_mat.set_shader_parameter("sky_sun_glow", p["sky_sun_glow"])
			m_mat.set_shader_parameter("sky_sun_core", p["sky_sun_core"])
		for deck_mat: Variant in landscape.cloud_materials:
			if deck_mat is ShaderMaterial:
				var dm := deck_mat as ShaderMaterial
				dm.set_shader_parameter("cloud_shade_color", p["sky_cloud_dark"])
				dm.set_shader_parameter("cloud_lit_color", p["sky_cloud_light"])
				dm.set_shader_parameter("sky_zenith", p["sky_zenith"])
				dm.set_shader_parameter("sky_mid", p["sky_mid"])
				dm.set_shader_parameter("sky_horizon", p["sky_horizon"])
				dm.set_shader_parameter("sky_sun_glow", p["sky_sun_glow"])
				dm.set_shader_parameter("sky_sun_core", p["sky_sun_core"])

	var renderer: Variant = editor.get("renderer")
	if renderer != null:
		var mats: Dictionary = renderer.materials
		for key: String in ["grass", "rim_green", "shore", "sculpted_terrain", "grass_blades"]:
			if mats.has(key):
				var mat := mats[key] as ShaderMaterial
				mat.set_shader_parameter("grass_base", p["grass_base"])
				mat.set_shader_parameter("grass_highlight", p["grass_highlight"])
				mat.set_shader_parameter("ground_fine_strength", float(p["ground_fine"]))
				mat.set_shader_parameter("lantern_glow_strength", float(p["lantern_glow"]))
				mat.set_shader_parameter("lantern_glow_color", p["lantern_color"])
				if key == "grass":
					mat.set_shader_parameter("cover_relief", float(p["cover_relief"]))
		for key: String in ["grass", "cliff", "sculpted_rock", "stone_mantle", "sculpted_terrain"]:
			if mats.has(key):
				var mat := mats[key] as ShaderMaterial
				mat.set_shader_parameter("stone_shadow_color", p["stone_shadow"])
				mat.set_shader_parameter("stone_mid_color", p["stone_mid"])
				mat.set_shader_parameter("stone_lit_color", p["stone_lit"])
				if p.has("stone_mist"):
					mat.set_shader_parameter("stone_mist_color", p["stone_mist"])
		if mats.has("water"):
			var water_mat := mats["water"] as ShaderMaterial
			water_mat.set_shader_parameter("water_deep", p["water_deep"])
			water_mat.set_shader_parameter("sun_direction", sun.transform.basis.z.normalized())
			water_mat.set_shader_parameter("glint_color", p["sun_color"])
			water_mat.set_shader_parameter("glint_energy", pow(clampf(float(p["sun_energy"])/2.02,0.0,1.0),2.0)*0.45)
		if mats.has("waterfall"):
			(mats["waterfall"] as ShaderMaterial).set_shader_parameter("sun_direction", sun.transform.basis.z.normalized())
		if renderer.get("mist") != null and renderer.mist.multimesh != null and renderer.mist.multimesh.mesh != null:
			var mist_mat := renderer.mist.multimesh.mesh.material as ShaderMaterial
			if mist_mat != null and p.has("stone_mist"):
				mist_mat.set_shader_parameter("mist_color", (p["stone_mist"] as Color).lerp(p["sky_cloud_light"] as Color, 0.45))

		if renderer.decoration != null and renderer.decoration.get("assets") is Dictionary:
			var assets: Dictionary = renderer.decoration.assets
			for kind: String in assets:
				for entry: Dictionary in assets[kind]:
					for mesh_key: String in ["mesh", "render_mesh"]:
						if not entry.has(mesh_key) or entry[mesh_key] == null:
							continue
						var m := entry[mesh_key] as Mesh
						if m.get_surface_count() == 0:
							continue
						var sm := m.surface_get_material(0) as ShaderMaterial
						if sm == null:
							continue
						if kind.begins_with("cliff_column") or kind.begins_with("underside_rock") or kind in ["cliff_rock", "surface_rock", "shore_rock", "shore_boulder", "shore_pebble", "rim_outcrop", "rim_shelf", "path"]:
							sm.set_shader_parameter("stone_shadow_color", p["stone_shadow"])
							sm.set_shader_parameter("stone_mid_color", p["stone_mid"])
							sm.set_shader_parameter("stone_lit_color", p["stone_lit"])
							if p.has("stone_mist"):
								sm.set_shader_parameter("stone_mist_color", p["stone_mist"])
						elif sm.shader != null and sm.shader.resource_path.ends_with("foliage.gdshader"):
							sm.set_shader_parameter("dark_color", p["foliage_dark"])
							sm.set_shader_parameter("light_color", p["foliage_light"])
						elif sm.shader != null and sm.shader.resource_path.ends_with("foliage_cards.gdshader"):
							var is_pine: bool = kind == "tree_b"
							var is_bush: bool = kind == "bush"
							var sh_col: Color = (p["leaf_shadow"] as Color).darkened(0.04 if is_bush else (0.10 if is_pine else 0.0))
							var mid_col: Color = (p["leaf_mid"] as Color).lightened(0.02) if is_bush else (p["leaf_mid"] as Color).darkened(0.08 if is_pine else 0.0)
							var lit_col: Color = (p["leaf_lit"] as Color).lightened(0.04) if is_bush else (p["leaf_lit"] as Color).darkened(0.06 if is_pine else 0.0)
							sm.set_shader_parameter("leaf_shadow", sh_col)
							sm.set_shader_parameter("leaf_mid", mid_col)
							sm.set_shader_parameter("leaf_lit", lit_col)
						else:
							sm.set_shader_parameter("decor_sky_shadow", p["decor_shadow"])
							sm.set_shader_parameter("decor_sky_lit", p["decor_lit"])

		if renderer.props != null and renderer.props.has_method("apply_style_preset"):
			renderer.props.apply_style_preset(0, p)
	if editor.get("motes") != null and editor.motes.has_method("apply_time_palette"):
		editor.motes.apply_time_palette(p, clampf(float(p.get("sun_energy", 1.24)) / 1.24, 0.0, 1.0))

func serialize() -> Dictionary:
	return {
		"day_progress": snappedf(day_progress, 0.001),
		"solar_term_index": solar_term_index,
		"day_count": day_count,
		"paused": paused,
	}

func deserialize(payload: Dictionary, editor: Node3D = null) -> void:
	if payload.is_empty():
		return
	day_progress = fposmod(float(payload.get("day_progress", 0.29)), 1.0)
	solar_term_index = clampi(int(payload.get("solar_term_index", 1)), 0, SOLAR_TERMS.size() - 1)
	day_count = maxi(1, int(payload.get("day_count", 1)))
	paused = bool(payload.get("paused", false))
	if editor != null:
		apply_to_scene(editor)
