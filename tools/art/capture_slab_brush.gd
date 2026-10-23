extends SceneTree
## Headless captures of the hard-slab study. Does not touch the courtyard scene.
## Linux llvmpipe frames are a form check. Re-capture on Mac Metal before calling the look final.

var viewport: SubViewport
var study
var output := "res://art/slab_brush"

func _initialize() -> void:
	call_deferred("run")

func _settle() -> void:
	for _i in 8:
		await process_frame
	for _i in 12:
		RenderingServer.force_draw(false)
		await process_frame

func _save(label: String, shots: Array) -> void:
	RenderingServer.force_draw(false)
	var image := viewport.get_texture().get_image()
	var path := output.path_join(label + ".png")
	var err := image.save_png(path)
	shots.append({
		"file": label + ".png",
		"error": err,
		"camera": str(study.camera.position),
		"focus": str(study._focus),
		"yaw": study._yaw,
		"pitch": study._pitch,
		"distance": study._distance,
		"fov": study.camera.fov,
		"modules": study.field.modules.size(),
	})
	print("SLAB CAPTURE ", label, " err=", err, " modules=", study.field.modules.size())

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	study = load("res://scenes/slab_brush_study.tscn").instantiate()
	viewport.add_child(study)
	study.set_process(false)
	study.status.visible = false
	await process_frame
	var shots: Array = []
	study.show_one()
	await _settle()
	await _save("fix_one_stone", shots)
	study.show_two()
	await _settle()
	await _save("fix_two_stones", shots)
	study.show_island()
	await _settle()
	await _save("fix_small_island", shots)
	var report := {
		"scene": "res://scenes/slab_brush_study.tscn",
		"godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"resolution": [1280, 720],
		"sample_seed": 7301,
		"courtyard_scene_untouched": true,
		"art_accepted": false,
		"captures": shots,
	}
	FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t", true, true))
	var valid := true
	for item: Dictionary in shots:
		valid = valid and item["error"] == OK and int(item["modules"]) >= 1
	quit(0 if valid else 1)
