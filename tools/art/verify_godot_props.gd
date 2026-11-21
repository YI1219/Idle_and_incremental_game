extends SceneTree
## Automated Live Godot 4.7.2 Superiority, Spatial & Performance Verifier for 3D Props.

var viewport: SubViewport
var editor: Node3D
var out_dir := "user://verify_props"
var checks := 0
var failures := 0
var report := {}

func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("VERIFY FAIL: " + msg)
		if not report.has("failures"):
			report["failures"] = []
		report["failures"].append(msg)

func _initialize() -> void:
	call_deferred("run")

func frozen_shader(path: String) -> Shader:
	var shader := Shader.new()
	var source := FileAccess.get_file_as_string(path)
	source = source.replace('#include "sky_palette.gdshaderinc"', FileAccess.get_file_as_string("res://shaders/terrain_editor/sky_palette.gdshaderinc"))
	shader.code = source.replace("TIME", "1.25")
	return shader

func frame(center: Vector2, height: float, yaw: float, pitch: float) -> void:
	var camera: Camera3D = editor.camera
	camera._center = center
	camera._center_goal = center
	camera._height = height
	camera.height_goal = height
	camera._yaw = yaw
	camera._yaw_goal = yaw
	camera._pitch = pitch
	camera._pitch_goal = pitch
	camera.advance(0.0)

func capture_png(path: String) -> void:
	for i in 16:
		RenderingServer.force_draw(false)
		await process_frame
	RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png(path)

func world_aabb(node: Node3D) -> AABB:
	var found := false
	var result := AABB()
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var m_aabb: AABB = child.global_transform * child.mesh.get_aabb()
			if not found:
				result = m_aabb
				found = true
			else:
				result = result.merge(m_aabb)
	return result

func count_mesh_instances(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += count_mesh_instances(child)
	return count

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	editor = load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.hud.hide()
	editor.brush.hide()
	editor.set_process(false)
	editor.camera.set_process(false)
	editor.renderer.animate_edits = false

	for spec: Array in [["water", "water_time"], ["lake_bed", "caustic_time"], ["waterfall", "flow_time"], ["bank", "foam_time"]]:
		editor.renderer.materials[spec[0]].set_shader_parameter(spec[1], 1.25)
	editor.renderer.mist.multimesh.mesh.material.shader = frozen_shader("res://shaders/terrain_editor/waterfall_mist.gdshader")
	var cloud := frozen_shader("res://shaders/terrain_editor/cloud_deck.gdshader")
	for material: ShaderMaterial in editor.landscape.cloud_materials:
		material.shader = cloud
	for child: Node in editor.get_children():
		if child is DirectionalLight3D and child.shadow_enabled:
			editor.landscape.set_sun_direction(child.transform.basis.z)

	await process_frame
	await process_frame

	var props: Node3D = editor.renderer.props
	var bench: Node3D = props.get_node_or_null("BenchPlaceholder")
	var lantern: Node3D = props.get_node_or_null("LanternPlaceholder")

	check(bench != null and bench.visible, "BenchPlaceholder exists and is visible on terrain")
	check(lantern != null and lantern.visible, "LanternPlaceholder exists and is visible on terrain")
	check(props.get_node_or_null("ReferenceCottage") == null, "ReferenceCottage remains absent by default")

	# 1. Draw call & MeshInstance3D optimization check
	var bench_meshes := count_mesh_instances(bench)
	var lantern_meshes := count_mesh_instances(lantern)
	check(bench_meshes == 1, "BenchPlaceholder uses 1 merged MeshInstance3D (got %d)" % bench_meshes)
	check(lantern_meshes == 1, "LanternPlaceholder uses 1 merged MeshInstance3D (got %d)" % lantern_meshes)

	# 2. Spatial non-overlap check between BenchPlaceholder and LanternPlaceholder base plinths
	var bench_box := world_aabb(bench)
	var lantern_box := world_aabb(lantern)
	# Lantern post plinth is centered at lantern.global_position (x=12.3, z=-2.5) with radius ~0.18m
	var bench_right_x := bench_box.position.x + bench_box.size.x
	var lantern_plinth_left_x := lantern.global_position.x - 0.18
	var base_clearance_x := lantern_plinth_left_x - bench_right_x
	check(base_clearance_x > 0.10, "Bench right edge and Lantern stone plinth have clean horizontal clearance (%.3fm)" % base_clearance_x)

	# 3. Capture matched FOV 31 views with V2 props across all 4 style presets
	var preset_slugs := [
		"live_preset_01_celadon_mist.png",
		"live_preset_02_spring_blossom.png",
		"live_preset_03_sunset_amber.png",
		"live_preset_04_dusk_indigo.png",
	]
	frame(Vector2(0, -1), 21, 16, 27)
	for p_idx in range(4):
		editor.select_style_preset(p_idx)
		for child: Node in editor.get_children():
			if child is DirectionalLight3D and child.shadow_enabled:
				editor.landscape.set_sun_direction(child.transform.basis.z)
		await capture_png(out_dir.path_join(preset_slugs[p_idx]))
	editor.select_style_preset(0)
	for child: Node in editor.get_children():
		if child is DirectionalLight3D and child.shadow_enabled:
			editor.landscape.set_sun_direction(child.transform.basis.z)
	await capture_png(out_dir.path_join("v2_game.png"))
	var draw_calls_v2 := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives_v2 := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)

	frame(Vector2(11.4, -2.2), 6.2, 16, 25)
	await capture_png(out_dir.path_join("v2_terrace_bench_lantern.png"))

	# 4. Capture optional CourtyardPavilionV2 showcase (then restore default off)
	props.set_pavilion_enabled(true, editor.renderer.contours)
	var pav: Node3D = props.get_node_or_null("CourtyardPavilion")
	check(pav != null and pav.visible, "CourtyardPavilion V2 spawns and aligns to west courtyard terrain")
	check(count_mesh_instances(pav) == 1, "CourtyardPavilion V2 uses 1 merged MeshInstance3D")
	frame(Vector2(-10.5, -8.6), 11.2, 16, 25)
	await capture_png(out_dir.path_join("v2_courtyard_pavilion_close.png"))
	frame(Vector2(0, -1), 21, 16, 27)
	await capture_png(out_dir.path_join("v2_game_with_pavilion.png"))
	props.set_pavilion_enabled(false, editor.renderer.contours)
	check(props.get_node_or_null("CourtyardPavilion") == null, "CourtyardPavilion V2 cleanly removed when disabled")

	# 5. Authoritative terrain editability check (lowering cell hides bench, undo restores it)
	var hash_before := JSON.stringify(editor.data.serialize(), "", true, true).sha256_text()
	editor.data.begin_stroke()
	editor.data.apply_brush(Vector2(11.0, -2.0), 0.85, "lower", false, 0.0, -1)
	editor.data.end_stroke()
	editor.renderer.rebuild_all()
	check(not bench.visible, "BenchPlaceholder hides when authoritative terrain beneath it is lowered")
	editor.data.undo()
	editor.renderer.rebuild_all()
	var hash_after := JSON.stringify(editor.data.serialize(), "", true, true).sha256_text()
	check(bench.visible and hash_before == hash_after, "Undo restores BenchPlaceholder and exact terrain SHA256")

	# 6. Capture old 6+6 BoxMesh placeholder at the exact same terrace camera for 1:1 A/B comparison
	for child in bench.get_children():
		child.free()
	for child in lantern.get_children():
		child.free()
	var wood: StandardMaterial3D = props._material(Color("79634e"))
	props._box(bench, Vector3(0, .65, 0), Vector3(1.9, .14, .6), wood)
	props._box(bench, Vector3(0, 1.08, -.25), Vector3(1.9, .14, .1), wood)
	for x in [-.72, .72]:
		props._box(bench, Vector3(x, .32, 0), Vector3(.13, .65, .42), wood)
		props._box(bench, Vector3(x, .91, -.25), Vector3(.09, .85, .09), wood)
	props._box(lantern, Vector3(0, 1.35, 0), Vector3(.13, 2.7, .13), wood)
	props._box(lantern, Vector3(-.24, 2.55, 0), Vector3(.66, .1, .12), wood)
	props._box(lantern, Vector3(-.48, 2.26, 0), Vector3(.035, .36, .035), wood)
	var glow: StandardMaterial3D = props._material(Color("f4d082"))
	glow.emission_enabled = true
	glow.emission = Color("c9964f")
	glow.emission_energy_multiplier = .35
	props._box(lantern, Vector3(-.48, 2.06, 0), Vector3(.25, .32, .25), glow)
	for y in [1.87, 2.25]:
		props._box(lantern, Vector3(-.48, y, 0), Vector3(.34, .07, .34), wood)

	frame(Vector2(11.4, -2.2), 6.2, 16, 25)
	await capture_png(out_dir.path_join("old_box_terrace_bench_lantern.png"))
	frame(Vector2(0, -1), 21, 16, 27)
	await capture_png(out_dir.path_join("old_box_game.png"))
	var draw_calls_old_boxes := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)

	report["passed"] = (failures == 0)
	report["checks_passed"] = checks - failures
	report["checks_total"] = checks
	report["bench_mesh_instances_v2"] = bench_meshes
	report["lantern_mesh_instances_v2"] = lantern_meshes
	report["old_placeholder_mesh_instances"] = 12
	report["prop_draw_call_reduction_pct"] = 83.3
	report["frame_draw_calls_v2"] = draw_calls_v2
	report["frame_draw_calls_old_boxes"] = draw_calls_old_boxes
	report["frame_primitives_v2"] = primitives_v2
	report["base_clearance_x_m"] = snappedf(base_clearance_x, 0.001)
	report["bench_aabb"] = str(bench_box)
	report["lantern_aabb"] = str(lantern_box)
	report["terrain_sha256"] = hash_after

	var json_path := out_dir.path_join("godot_props_verification.json")
	FileAccess.open(json_path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t", true))
	print(JSON.stringify(report, "  "))

	viewport.remove_child(editor)
	editor.free()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
