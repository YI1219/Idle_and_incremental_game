extends SceneTree
const OUT := "res://art/review/terrain_fidelity/2026-10-06/rework/"
var tag := "baseline"
var movie := false
var views: Array = []
var render_view: SubViewport

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
	print("SHOT BEGIN: ",label)
	while editor.renderer.has_pending_updates():
		editor.renderer.flush_dirty(2)
		await process_frame
	print("SHOT PUBLISHED: ",label)
	for chunk:Node3D in editor.renderer.chunks.values():
		for node in chunk.get_children():
			if node is MeshInstance3D:
				if "no_falls" in tag and node.name in ["waterfall","bank"]:node.hide()
				if "clay" in tag and node.name=="cliff":
					var clay:=StandardMaterial3D.new()
					clay.albedo_color=Color(.50,.53,.56)
					clay.roughness=1.0
					node.material_override=clay
	pose(editor.camera, center, height, yaw)
	for i in 60:
		RenderingServer.force_draw(false)
		await process_frame
	RenderingServer.force_draw(false)
	var error := render_view.get_texture().get_image().save_png(OUT+tag+"_"+label+".png")
	if error != OK: push_error("Capture failed: "+label); quit(1)
	views.append({"name":label,"center":[center.x,center.y],"height":height,"yaw":yaw,"pitch":27,"fov":31})

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# Always render the actual 3D scene even if the native window loses focus.
	# Capture a real SubViewport at identical size/MSAA; no compositor timing claims.
	render_view=SubViewport.new()
	render_view.size=root.size
	render_view.own_world_3d=true
	render_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	render_view.msaa_3d=root.msaa_3d
	render_view.screen_space_aa=root.screen_space_aa
	render_view.use_taa=root.use_taa
	root.add_child(render_view)
	var preview:=TextureRect.new()
	preview.texture=render_view.get_texture()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(preview)
	var editor = load("res://scenes/terrain_editor.tscn").instantiate()
	render_view.add_child(editor)
	editor.hud.hide()
	editor.brush.hide()
	editor.set_process(false)
	editor.camera.set_process(false)
	editor.set_process_input(false)
	editor.set_process_unhandled_input(false)
	editor.camera.set_process_input(false)
	editor.camera.set_process_unhandled_input(false)
	if "flat_normal" in tag or "flat_color" in tag:
		var shader:=Shader.new()
		var code:String=editor.renderer.materials.water.shader.code
		if "flat_normal" in tag:code=code.replace("NORMAL = normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);","NORMAL = normalize((VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz);")
		else:
			var start:=code.find("ALBEDO =")
			var end:=code.find(";",start)
			if start<0 or end<0:push_error("Water color isolation target missing");quit(1);return
			code=code.left(start)+"ALBEDO = vec3(.02,.22,.38);"+code.substr(end+1)
		shader.code=code
		editor.renderer.materials.water.shader=shader
	if "clay" in tag:
		var clay:=StandardMaterial3D.new()
		clay.albedo_color=Color(.50,.53,.56)
		clay.roughness=1.0
		for chunk:Node3D in editor.renderer.chunks.values():
			for node in chunk.get_children():
				if (node is MeshInstance3D and node.name=="cliff") or (node is MultiMeshInstance3D and str(node.name).begins_with("cliff_rock")):node.material_override=clay
	if "no_shadow" in tag:
		for node in editor.get_children():
			if node is DirectionalLight3D:node.shadow_enabled=false
	if movie:
		# Capture every actual rendered viewport frame, independent of native
		# presentation/skipped swaps. This is a fixed 60 Hz inspection sequence.
		var folder:=OUT+tag+"_motion_frames/"
		DirAccess.make_dir_recursive_absolute(folder)
		pose(editor.camera,Vector2(0,-1),21,16)
		for warmup in 60:
			await process_frame
			RenderingServer.force_draw(false)
		for frame in 300:
			var t := float(frame)/60.0
			var center := Vector2(1.4*sin(t*.7),-1+sin(t*.5))
			pose(editor.camera,center,21.0-2.0*sin(t*.6),16.0+24.0*sin(t*.8))
			await process_frame
			RenderingServer.force_draw(false)
			var error:=render_view.get_texture().get_image().save_png(folder+"frame_%04d.png"%frame)
			if error!=OK:push_error("Motion frame save failed");quit(1);return
		print("LOOKDEV MOTION: 300 runtime frames, pan/zoom and inspection rotation")
		quit()
		return
	await shot(editor,"composition",Vector2(0,-1),21,16)
	await shot(editor,"left",Vector2(0,-1),21,-22)
	await shot(editor,"right",Vector2(0,-1),21,50)
	await shot(editor,"contact",Vector2(7.2,-1.8),21*pow(1.12,-5),16)
	if "flat_normal" in tag or "flat_color" in tag or ("clay" in tag and not "stress" in tag) or "no_shadow" in tag:
		print("REWORK DIAGNOSTIC CAPTURES: ",tag)
		quit()
		return
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
	# New geometry stress views use the same authoritative cells and publication.
	if "final" in tag:
		for cell:Vector2i in editor.data.cells:
			editor.data.cells[cell]={"height":-4.0,"water":-1}
		editor.data.revision+=1
		editor.renderer.rebuild_all()
		await shot(editor,"minimum_height",Vector2(0,-1),21,16)
		var minimum_pick:Dictionary=editor.renderer.pick(Vector3(-10.5,20,-5.5),Vector3.DOWN)
		if minimum_pick.is_empty() or absf(minimum_pick.position.y+4.0)>.01:push_error("Minimum-height surface/picking failed");quit(1);return
		editor.data.deserialize(initial)
		editor.data.begin_stroke()
		for spec in [[Vector2(-13,-3),1.9],[Vector2(12,4),2.0],[Vector2(-3,3),1.7]]:
			editor.data.apply_brush(spec[0],spec[1],"contract",false,1.5,3)
		editor.data.apply_brush(Vector2(19,4),2.5,"expand",false,1.5,3)
		editor.data.end_stroke()
		await shot(editor,"irregular",Vector2(0,-1),21,16)
		await shot(editor,"irregular_rotated",Vector2(0,-1),21,50)
		var saved:Dictionary=editor.data.serialize()
		var save_path:="user://terrain_editor/rework_capture_test.json"
		if editor.save_layout(save_path)!=OK:push_error("Capture layout save failed");quit(1);return
		editor.free()
		editor=load("res://scenes/terrain_editor.tscn").instantiate()
		render_view.add_child(editor)
		editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
		editor.set_process_input(false);editor.set_process_unhandled_input(false)
		editor.camera.set_process_input(false);editor.camera.set_process_unhandled_input(false)
		if editor.load_layout(save_path)!=OK or editor.data.serialize()!=saved:push_error("Fresh editor reopen differs");quit(1);return
		await shot(editor,"reopened_irregular",Vector2(0,-1),21,16)
		DirAccess.remove_absolute(save_path)
		editor.data.deserialize(initial)
		editor.renderer.rebuild_all()
		await shot(editor,"reopened_default",Vector2(0,-1),21,16)
	var file := FileAccess.open(OUT+tag+"_captures.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":"actual Godot runtime; real SubViewport, native window focus independent","engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"resolution":[root.size.x,root.size.y],"views":views,"edits":edits,"rotation":"inspection only; gameplay controls preserved"},"\t"))
	print("LOOKDEV CAPTURES: ", JSON.stringify(edits))
	quit()
