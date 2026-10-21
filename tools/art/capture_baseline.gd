extends SceneTree
## Native baseline capture. Never reads or writes a user layout.
var viewport: SubViewport
var editor: Node3D
var output := "res://art/baseline/current"
var captures: Array[Dictionary] = []

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

func capture(label: String) -> void:
	for i in 20:
		RenderingServer.force_draw(false)
		await process_frame
	RenderingServer.force_draw(false)
	var result := viewport.get_texture().get_image().save_png(output.path_join(label + ".png"))
	captures.append({"file": label + ".png", "error": result, "position": str(editor.camera.position), "rotation": str(editor.camera.rotation_degrees), "fov": editor.camera.fov})

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	if FileAccess.file_exists(output.path_join("captures.json")):
		push_error("Capture directory already contains evidence; choose a new --out directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
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
	var data_hash := JSON.stringify(editor.data.serialize(), "", true, true).sha256_text()
	frame(Vector2(0, -1), 21, 16, 27)
	await capture("game")
	frame(Vector2(-2, -1), 32, 16, 30)
	await capture("whole")
	frame(Vector2(-2, -1), 32, 196, 30)
	await capture("reverse")
	frame(Vector2(-10, -5), 13, 16, 30)
	await capture("close")
	var has_house := editor.renderer.props.get_node_or_null("ReferenceCottage") != null
	var unchanged := data_hash == JSON.stringify(editor.data.serialize(), "", true, true).sha256_text()
	var valid := not has_house and unchanged
	for item: Dictionary in captures:
		valid = valid and item.error == OK
	var report := {"scene": "res://scenes/terrain_editor.tscn", "godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "resolution": [1280, 720], "seed": editor.data.seed, "phase": 1.25, "house_absent": not has_house, "data_unchanged": unchanged, "data_sha256": data_hash, "captures": captures, "valid": valid, "art_accepted": false, "user_layouts_accessed": false}
	FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t", true, true))
	print("BASELINE CAPTURE: ", captures.size(), " frames; house_absent=", not has_house, "; data_unchanged=", unchanged)
	viewport.remove_child(editor)
	editor.free()
	await process_frame
	RenderingServer.force_draw(false)
	viewport.queue_free()
	await process_frame
	quit(0 if valid else 1)
