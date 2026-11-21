extends SceneTree
const Env = preload("res://scripts/terrain_editor/terrain_environment.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", label])

func check_palette(editor: Node3D, label: String, palette: Dictionary) -> void:
	var assets: Dictionary = editor.renderer.decoration.assets
	for kind: String in ["grass_clump", "reeds"]:
		var seen: Dictionary = {}
		var shader_ok: bool = true
		var shadow_ok: bool = true
		var lit_ok: bool = true
		for entry: Dictionary in assets.get(kind, []):
			for key: String in ["mesh", "render_mesh"]:
				var mesh := entry.get(key) as Mesh
				if mesh == null or mesh.get_surface_count() == 0:
					continue
				var mat := mesh.surface_get_material(0) as ShaderMaterial
				if mat == null or seen.has(mat.get_instance_id()):
					continue
				seen[mat.get_instance_id()] = true
				shader_ok = shader_ok and mat.shader != null and mat.shader.resource_path.ends_with("decor_vertex_color.gdshader")
				var shadow: Variant = mat.get_shader_parameter("decor_sky_shadow")
				var lit: Variant = mat.get_shader_parameter("decor_sky_lit")
				shadow_ok = shadow_ok and shadow is Color and shadow.is_equal_approx(palette.decor_shadow)
				lit_ok = lit_ok and lit is Color and lit.is_equal_approx(palette.decor_lit)
				print("ROUTE %s kind=%s shader=%s shadow=%s expected_shadow=%s lit=%s expected_lit=%s" % [label, kind, mat.shader.resource_path, str(shadow), str(palette.decor_shadow), str(lit), str(palette.decor_lit)])
		check(not seen.is_empty(), label + " " + kind + " actual materials exist")
		check(shader_ok, label + " " + kind + " uses decor shader")
		check(shadow_ok, label + " " + kind + " receives decor shadow")
		check(lit_ok, label + " " + kind + " receives decor lit")
	var foliage_count: int = 0
	var foliage_ok: bool = true
	for entry: Dictionary in assets.get("grass", []):
		for key: String in ["mesh", "render_mesh"]:
			var mesh := entry.get(key) as Mesh
			if mesh == null or mesh.get_surface_count() == 0:
				continue
			var mat := mesh.surface_get_material(0) as ShaderMaterial
			if mat == null or mat.shader == null or not mat.shader.resource_path.ends_with("foliage.gdshader"):
				continue
			foliage_count += 1
			foliage_ok = foliage_ok and mat.get_shader_parameter("dark_color") == palette.foliage_dark and mat.get_shader_parameter("light_color") == palette.foliage_light
	check(foliage_count > 0, label + " actual foliage material exists")
	check(foliage_ok, label + " foliage retains original dark/light palette")

func run() -> void:
	var editor = load("res://scenes/terrain_editor.tscn").instantiate()
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(editor)
	editor.gameplay.time_system.set_progress(0.02, editor)
	check_palette(editor, "time-night", editor.gameplay.time_system.current_blended_preset())
	Env.apply_style_preset(editor, 0)
	check_palette(editor, "environment-preset0", Env.STYLE_PRESETS[0])
	print("FOLIAGE ROUTE 23: checks=%d failures=%d" % [checks, failures])
	editor.free()
	quit(0 if failures == 0 else 1)
