extends SceneTree
const OUT := "res://art/review/terrain_fidelity/2026-10-06/"
var tag := "baseline"
var movie := false
var views: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "motion": movie = true
		else: tag = arg
	call_deferred("run")

# Inspection poses only: gameplay still uses horizontal pan and wheel height.
func pose(camera: Camera3D, center: Vector2, height: float, yaw: float) -> void:
	var offset := height / tan(deg_to_rad(27.0))
	camera.position = Vector3(center.x + sin(deg_to_rad(yaw))*offset, height, center.y + cos(deg_to_rad(yaw))*offset)
	camera.rotation_degrees = Vector3(-27, yaw, 0)

func shot(editor, label: String, center: Vector2, height: float, yaw: float) -> void:
	while editor.renderer.has_pending_updates():
		editor.renderer.flush_dirty(2)
		await process_frame
	pose(editor.camera, center, height, yaw)
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT+tag+"_"+label+".png")
	if error != OK: push_error("Capture failed: "+label); quit(1)
	views.append({"name":label,"center":[center.x,center.y],"height":height,"yaw":yaw,"pitch":27,"fov":31})

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var editor = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.hud.hide()
	editor.brush.hide()
	editor.set_process(false)
	editor.camera.set_process(false)
	if movie:
		# Real runtime frames: water time advances normally at fixed 60 Hz.
		for frame in 300:
			var t := float(frame)/60.0
			var center := Vector2(1.4*sin(t*.7),-1+sin(t*.5))
			pose(editor.camera,center,21.0-2.0*sin(t*.6),16.0+24.0*sin(t*.8))
			await process_frame
		print("LOOKDEV MOTION: 300 runtime frames, pan/zoom and inspection rotation")
		quit()
		return
	await shot(editor,"composition",Vector2(0,-1),21,16)
	await shot(editor,"left",Vector2(0,-1),21,-22)
	await shot(editor,"right",Vector2(0,-1),21,50)
	await shot(editor,"contact",Vector2(7.2,-1.8),21*pow(1.12,-5),16)
	var initial: Dictionary = editor.data.serialize()
	var edits: Array = []
	for spec in [["raise",Vector2(-13,2),2.3],["lower",Vector2(13,7),2.0],["expand",Vector2(18,4),2.6],["contract",Vector2(3,7),2.2]]:
		editor.data.deserialize(initial)
		editor.data.begin_stroke()
		var changed: int = editor.data.apply_brush(spec[1],spec[2],spec[0],false,1.5,3)
		editor.data.end_stroke()
		if changed == 0: push_error("Edit did not change cells"); quit(1); return
		await shot(editor,spec[0],Vector2(0,-1),21,16)
		edits.append({"operation":spec[0],"changed_cells":changed})
	editor.data.deserialize(initial)
	editor.renderer.rebuild_all()
	await shot(editor,"regenerated",Vector2(0,-1),21,16)
	var file := FileAccess.open(OUT+tag+"_captures.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":"actual Godot runtime","engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"resolution":[root.size.x,root.size.y],"views":views,"edits":edits,"rotation":"inspection only; gameplay controls preserved"},"\t"))
	print("LOOKDEV CAPTURES: ", JSON.stringify(edits))
	quit()
