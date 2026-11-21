extends MultiMeshInstance3D
## Subtle drifting morning pollen motes and sunlit leaflets above the courtyard.

const MOTE_COUNT := 88
var material: ShaderMaterial

func _init() -> void:
	name = "AmbientMotes"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = 74.0
	visibility_range_end_margin = 8.0
	visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/terrain_editor/ambient_motes.gdshader")

	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.material = material

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = MOTE_COUNT
	multimesh = mm

func rebuild_from_data(data: RefCounted) -> void:
	if multimesh == null or data == null:
		return
	var land_pts: Array[Vector3] = []
	for cell_var: Variant in data.cells.keys():
		var cell: Vector2i = cell_var as Vector2i
		var rec: Dictionary = data.cells[cell]
		var h: float = float(rec.get("height", 1.5))
		var w: int = int(rec.get("water", -1))
		var surf_y: float = maxf(h, float(w) * 0.5) if w >= 0 else h
		land_pts.append(Vector3(float(cell.x) + 0.5, surf_y, float(cell.y) + 0.5))

	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.seed) * 131 + 9107
	for i in MOTE_COUNT:
		var anchor := Vector3(rng.randf_range(-10.0, 10.0), 2.4, rng.randf_range(-9.0, 9.0))
		if not land_pts.is_empty():
			var base: Vector3 = land_pts[rng.randi_range(0, land_pts.size() - 1)]
			var is_leaf_slot: bool = i >= int(MOTE_COUNT * 0.78)
			var y_lift: float = rng.randf_range(1.65, 4.10) if is_leaf_slot else rng.randf_range(0.75, 3.35)
			anchor = base + Vector3(rng.randf_range(-0.65, 0.65), y_lift, rng.randf_range(-0.65, 0.65))
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, anchor))
		var kind_val: float = 0.88 if i >= int(MOTE_COUNT * 0.78) else rng.randf_range(0.0, 0.70)
		multimesh.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), kind_val))

func set_frozen_time(t: float) -> void:
	if material != null:
		material.set_shader_parameter("mote_time", t)

func apply_style_palette(p: Dictionary) -> void:
	if material == null:
		return
	if p.has("sun_color"):
		var sc: Color = p["sun_color"] as Color
		material.set_shader_parameter("pollen_color", sc.lightened(0.24))
	if p.has("leaf_lit"):
		var lc: Color = p["leaf_lit"] as Color
		material.set_shader_parameter("leaflet_color", lc.lightened(0.14))

func apply_time_palette(p: Dictionary, daylight: float) -> void:
	if material == null:
		return
	apply_style_palette(p)
	var op: float = lerpf(0.32, 0.92, clampf(daylight, 0.0, 1.0))
	material.set_shader_parameter("opacity_scale", op)
