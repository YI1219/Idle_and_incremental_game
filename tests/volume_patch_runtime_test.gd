extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred('run')
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene = load('res://scenes/volume_patch_study.tscn').instantiate()
	viewport.add_child(scene)
	for i: int in 3: await physics_frame
	check(scene.body.mesh.get_faces().size() > 100 and scene.water.visible, 'Actual scene publishes solid collision and valid water')
	var font: Font = load('res://assets/fonts/YunluVolumeUI-Regular.res')
	var glyphs_ok := font != null
	for code: int in FileAccess.get_file_as_string('res://scripts/terrain_volume/patch_study.gd').to_utf32_buffer().to_int32_array():
		if code > 127: glyphs_ok = glyphs_ok and font.has_char(code)
	check(glyphs_ok, 'Packaged font covers study Chinese without system-font lookup')
	var before: Dictionary = scene.document.serialize()
	var pixel: Vector2 = scene.camera.unproject_position(Vector3(.8,1.5,1.8))
	var hit: Dictionary = scene.hit_at(pixel)
	check(not hit.is_empty(), 'Screen ray picks the real published solid')
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = pixel
	down.pressed = true
	viewport.push_input(down, true)
	var up := down.duplicate()
	up.pressed = false
	viewport.push_input(up, true)
	for i: int in 3: await physics_frame
	check(scene.document.serialize() != before, 'Public mouse input carves actual density')
	check(scene.collision.shape.get_faces() == scene.body.mesh.get_faces(), 'Collision and displayed triangles publish together')
	var undo := InputEventKey.new()
	undo.keycode = KEY_Z
	undo.ctrl_pressed = true
	undo.pressed = true
	viewport.push_input(undo, true)
	check(scene.document.serialize() == before, 'Public Ctrl+Z restores the full stroke')
	var redo := undo.duplicate()
	redo.keycode = KEY_Y
	viewport.push_input(redo, true)
	check(scene.document.serialize() != before, 'Public Ctrl+Y restores carving')
	var leak_vertices := 0
	for p: Vector3 in scene.water.mesh.get_faces():
		if scene.document.field.value_at(p) < -.0001: leak_vertices += 1
	check(leak_vertices == 0, 'Visible lake clips to the same volume at its exact sample plane')
	check(scene.SAVE == 'user://volume_patch_study/layout.json', 'Study save is independent of formal and rejected variant saves')
	scene.document.begin_stroke()
	for x: float in [-3.,0.,3.]:
		for y: float in [0.,2.]:
			for z: float in [-1.,1.]: scene.document.apply_brush(Vector3(x,y,z),2.5,'rock_cut')
	scene.document.end_stroke()
	scene.rebuild()
	for i: int in 3: await physics_frame
	check(scene.body.mesh.get_surface_count() == 0 and scene.collision.shape == null and not scene.water.visible, 'Erasing the island publishes empty display, collision and water together')
	scene.undo()
	for i: int in 3: await physics_frame
	check(scene.body.mesh.get_surface_count() > 0 and scene.collision.shape != null, 'Undo restores the real solid after total erasure')
	print('VOLUME PATCH RUNTIME: ', checks-failures, '/', checks)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
