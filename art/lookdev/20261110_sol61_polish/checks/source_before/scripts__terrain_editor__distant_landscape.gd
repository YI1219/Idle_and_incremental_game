class_name DistantLandscape
extends Node3D
## Distant, non-interactive shanshui scroll mountain scenery (层峦叠嶂 · 天际留白 · 烟海流云).
## Never supplies courtyard land. Uses cullable angular sectors; no shadows or colliders.
const Surface = preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface
const Normals = preload("res://scripts/terrain_editor/stone_normals.gd")

const CLOUD_DECKS := [
	{"height": -8.2, "uv_scale": .0104, "coverage": .48, "opacity": .26, "inner_clear": 18.2, "fade": 96.0, "offset": Vector2(.22, .49)},
	{"height": -13.8, "uv_scale": .0072, "coverage": .52, "opacity": .28, "inner_clear": 19.5, "fade": 185.0, "offset": Vector2(.44, .62)},
	{"height": -28.0, "uv_scale": .0032, "coverage": .46, "opacity": .28, "inner_clear": 50.0, "fade": 2900.0, "offset": Vector2(.31, .18)},
	{"height": -125.0, "uv_scale": .0018, "coverage": .30, "opacity": .92, "inner_clear": 0.0, "fade": 2900.0, "offset": Vector2(.13, .71)},
	{"height": -245.0, "uv_scale": .0013, "coverage": .24, "opacity": .96, "inner_clear": 0.0, "fade": 2900.0, "offset": Vector2(.58, .29)},
	{"height": -390.0, "uv_scale": .00095, "coverage": .18, "opacity": .99, "inner_clear": 0.0, "fade": 2900.0, "offset": Vector2(.81, .47)},
]

var material := ShaderMaterial.new()
var cloud_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 721035
	material.shader = load("res://shaders/terrain_editor/distant_mountain.gdshader")
	_cloud_decks()
	# Three overlapping Song-shanshui mountain rings:
	# Seated lower so the upper ~30% of game/whole views stays open celadon sky (画境留白)!
	const RING_COUNTS := [30, 34, 38]
	const RING_RADII := [460.0, 740.0, 1060.0]
	for variant in 3:
		var mesh := _mountain(variant)
		mesh.surface_set_material(0, material)
		var poses: Array[Transform3D] = []
		var count: int = RING_COUNTS[variant]
		var base_r: float = RING_RADII[variant]
		for i in count:
			var u := float(i) / float(count)
			# Group ranges into poetic clusters with open misty sea-of-clouds vistas between them
			var cluster_wave := sin(u * TAU * 3.0 + float(variant) * 1.8)
			var angle := TAU * u + cluster_wave * .042 + variant * .27 + rng.randf_range(-.032, .032)
			var radius := base_r + rng.randf_range(-38.0, 44.0)
			var presence := clampf(.52 + .48 * sin(angle * 3.0 - .4 + variant * 1.9) * cos(angle * 2.0 + variant * .7), .18, 1.0)
			var scale_factor := radius / 210.0
			# Sculpted Song-shanshui peak stature (Europa / Qianli Jiangshan Tu) while keeping top ~26% sky open (画境留白):
			var right_lift := lerpf(0.92, 1.36, clampf((sin(angle) + .12) / 1.12, 0.0, 1.0))
			var height := rng.randf_range(31.0, 45.0) * scale_factor * lerpf(.84, 1.24, presence) * right_lift
			var span_w := rng.randf_range(68.0, 102.0) * scale_factor * lerpf(.92, 1.24, presence)
			var span_d := rng.randf_range(28.0, 42.0) * scale_factor
			var base_y := minf(-162.0, -radius * rng.randf_range(.28, .40)) - height * rng.randf_range(.16, .24)
			var at := Vector3(sin(angle) * radius, base_y, cos(angle) * radius)
			var yaw := angle + PI + rng.randf_range(-.32, .32)
			var flip_x := -1.0 if rng.randf() < .5 else 1.0
			var basis := Basis(Vector3.UP, yaw).scaled_local(Vector3(span_w * flip_x, height, span_d))
			poses.append(Transform3D(basis, at))
		for sector in 8:
			var start := sector * count / 8
			var finish := (sector + 1) * count / 8
			if finish <= start:
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = finish - start
			for i in range(start, finish):
				mm.set_instance_transform(i - start, poses[i])
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = mm
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)

func set_sun_direction(toward_sun: Vector3) -> void:
	material.set_shader_parameter("sun_direction", toward_sun)
	for deck in cloud_materials:
		deck.set_shader_parameter("sun_direction", toward_sun)

func _cloud_decks() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 4127
	noise.frequency = .016
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_gain = .50
	var image := noise.get_seamless_image(256, 256)
	image.generate_mipmaps()
	var billow := ImageTexture.create_from_image(image)
	var plane := PlaneMesh.new()
	plane.size = Vector2(6800, 6800)
	var shader := load("res://shaders/terrain_editor/cloud_deck.gdshader")
	for spec: Dictionary in CLOUD_DECKS:
		var deck_material := ShaderMaterial.new()
		deck_material.shader = shader
		deck_material.set_shader_parameter("billow", billow)
		deck_material.set_shader_parameter("uv_scale", spec.uv_scale)
		deck_material.set_shader_parameter("coverage", spec.coverage)
		deck_material.set_shader_parameter("opacity", spec.opacity)
		deck_material.set_shader_parameter("fade_radius", float(spec.get("fade", 2200.0)))
		deck_material.set_shader_parameter("inner_clear_radius", float(spec.get("inner_clear", 0.0)))
		deck_material.set_shader_parameter("uv_offset", spec.offset)
		cloud_materials.append(deck_material)
		var deck := MeshInstance3D.new()
		deck.mesh = plane
		deck.material_override = deck_material
		deck.position.y = spec.height
		deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(deck)

## Serpentine Chinese Shanshui Mountain Range Ribbon (远山如黛 · 峥嵘秀脊 · 凹坡支脉):
## Continuous undulating ridge spine with concave slopes and 3D descending spur folds
## so directional sunlight carves crisp lit vs celadon-shaded facets like Qianli Jiangshan Tu!
static func _peak_bell(u: float, center: float, width: float, power: float = 1.68) -> float:
	var du := sqrt((u - center) * (u - center) + 0.0032) / width
	return exp(-pow(du, power))

static func _crest_height(variant: int, u: float) -> float:
	var env := pow(maxf(0.0, 1.0 - u * u), 0.85)
	if env <= 0.0001:
		return 0.0
	var h := 0.0
	if variant == 0:
		# 主峰耸翠 · 秀脊叠嶂: Graceful Shanshui summit crest with secondary shoulders (Europa / Song Shanshui)
		h += 0.96 * _peak_bell(u, -0.16, 0.28, 1.66)
		h += 0.68 * _peak_bell(u, 0.38, 0.27, 1.72)
		h += 0.44 * _peak_bell(u, -0.64, 0.25, 1.74)
		h += 0.30 * _peak_bell(u, 0.72, 0.23, 1.76)
	elif variant == 1:
		# 双峰夹涧 · 云壑藏幽: Sculpted twin crests framing a misty valley saddle
		h += 0.92 * _peak_bell(u, -0.34, 0.27, 1.66)
		h += 0.80 * _peak_bell(u, 0.30, 0.28, 1.70)
		h += 0.38 * _peak_bell(u, 0.68, 0.24, 1.74)
		h += 0.34 * _peak_bell(u, -0.72, 0.23, 1.74)
	else:
		# 平远横黛 · 连绵群岫: Broad undulating horizon range with rhythmic ridge saddles
		h += 0.82 * _peak_bell(u, 0.04, 0.32, 1.72)
		h += 0.68 * _peak_bell(u, -0.48, 0.28, 1.70)
		h += 0.60 * _peak_bell(u, 0.52, 0.27, 1.70)
		h += 0.22 * (0.5 + 0.5 * cos(u * 7.2 + 0.6)) * env
	var micro := 0.020 * sin(u * 8.5 + float(variant) * 2.1)
	return clampf((h + micro * env) * env, 0.0, 1.05)

func _mountain(variant: int) -> ArrayMesh:
	var surface := Surface.new()
	const NX := 144
	const NZ := 36
	var grid: Array = []
	var ridge_ratios: Array = []

	for ix in range(NX + 1):
		var u := (float(ix) / float(NX)) * 2.0 - 1.0 # -1 .. +1 along mountain length
		var ch := _crest_height(variant, u)
		var spine_z := 0.15 * sin(u * 2.8 + float(variant) * 1.4) + 0.045 * cos(u * 5.8 - float(variant))
		var row_pts: Array[Vector3] = []
		var row_rat: Array[float] = []
		for iz in range(NZ + 1):
			var v := (float(iz) / float(NZ)) * 2.0 - 1.0 # -1 (back) .. +1 (front)
			var d := clampf(sqrt(v * v + 0.0020) - 0.044, 0.0, 1.0)
			# Smooth painterly shanshui slope + organic 3D descending spur ridges (zero pyramid creases!):
			var base_slope := pow(maxf(0.0, 1.0 - d), 1.42)
			var spur_phase := u * 7.4 + float(variant) * 1.85 + v * 1.15
			var spur_fold := 0.11 * pow(maxf(0.0, 0.5 + 0.5 * sin(spur_phase)), 2.0) * d * pow(maxf(0.0, 1.0 - d), 0.85) * 2.4
			var y := maxf(0.0, ch * (base_slope + spur_fold))
			var width_env := 0.35 + 0.65 * sqrt(maxf(0.0, 1.0 - u * u))
			var z := spine_z * (1.0 - 0.55 * d) + v * width_env
			var x := u * 1.45
			row_pts.append(Vector3(x, y, z))
			row_rat.append(clampf(1.0 - absf(v), 0.0, 1.0))
		grid.append(row_pts)
		ridge_ratios.append(row_rat)

	for ix in NX:
		for iz in NZ:
			var p00: Vector3 = grid[ix][iz]
			var p10: Vector3 = grid[ix + 1][iz]
			var p01: Vector3 = grid[ix][iz + 1]
			var p11: Vector3 = grid[ix + 1][iz + 1]
			if p00.y < 0.002 and p10.y < 0.002 and p01.y < 0.002 and p11.y < 0.002:
				continue
			var r00 := Color(float(ridge_ratios[ix][iz]), p00.y, float(variant) * 0.33, 1.0)
			var r10 := Color(float(ridge_ratios[ix + 1][iz]), p10.y, float(variant) * 0.33, 1.0)
			var r01 := Color(float(ridge_ratios[ix][iz + 1]), p01.y, float(variant) * 0.33, 1.0)
			var r11 := Color(float(ridge_ratios[ix + 1][iz + 1]), p11.y, float(variant) * 0.33, 1.0)
			if (-(p10 - p00).cross(p01 - p00)).y < 0.0:
				surface.triangle(p00, p01, p10, r00)
				surface.triangle(p10, p01, p11, r11)
			else:
				surface.triangle(p00, p10, p01, r00)
				surface.triangle(p10, p11, p01, r11)

	# Continuous smooth normals across dense curved spine give crisp sunlit/shaded slopes with zero low-poly facets!
	return Normals.soften(surface.mesh(), 78.0, 0.96)
