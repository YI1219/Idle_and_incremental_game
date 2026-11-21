extends "res://tools/art/capture_lookdev.gd"

var records: Array[Dictionary] = []
var temporary: String = "/tmp/scroll_release_feedback_20261111"

func photo(label: String, seconds: float) -> void:
	for i in 2:
		RenderingServer.force_draw(false)
		await process_frame
	viewport.get_texture().get_image().save_png(output.path_join(label + ".png"))
	records.append({"file": label + ".png", "seconds": seconds, "size": [viewport.size.x, viewport.size.y], "position": _vector(editor.camera.position), "rotation": _vector(editor.camera.rotation_degrees), "data_sha256": JSON.stringify(editor.data.serialize(), "", true, true).sha256_text(), "preview_visible": editor.preview.visible, "morph": editor.renderer.morph_progress})

func run() -> void:
	if not _read_options():
		quit(1)
		return
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(output)):
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	DirAccess.make_dir_recursive_absolute(temporary)
	var before: Dictionary = _source_hashes()
	var extra: Dictionary = {}
	for file: String in ["res://scripts/terrain_editor/edit_preview.gd", "res://shaders/terrain_editor/edit_preview.gdshader"]:
		extra[file] = FileAccess.get_sha256(file)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for operation: String in ["raise", "contract"]:
		for variant: String in ["before", "after"]:
			viewport.size = Vector2i(1280, 720)
			editor = load("res://scenes/terrain_editor.tscn").instantiate()
			if variant == "before":
				var baseline := GDScript.new()
				baseline.source_code = FileAccess.get_file_as_string("res://art/lookdev/20261111_edit_release/checks/source_before/scripts/terrain_editor/edit_preview.gd") + "\nfunc commit(draft, renderer) -> void:\n\trefresh(draft, renderer, true)\n"
				if baseline.reload() != OK:
					quit(1)
					return
				editor.preview.set_script(baseline)
			viewport.add_child(editor)
			editor.set_process(false)
			editor.camera.set_process(false)
			editor.renderer.set_process(false)
			editor.water_view.set_process(false)
			editor.preview.set_process(false)
			editor.gameplay.time_system.set_progress(.29, editor)
			editor.gameplay.stance = "sculpt"
			editor.gameplay.shihai_hud.hide()
			editor.hud.hide()
			var shader := Shader.new()
			var shader_path: String = "res://shaders/terrain_editor/edit_preview.gdshader" if variant == "after" else "res://art/lookdev/20261111_edit_release/checks/source_before/shaders/terrain_editor/edit_preview.gdshader"
			shader.code = FileAccess.get_file_as_string(shader_path).replace("TIME", "feedback_clock").replace("uniform vec3 form_color", "uniform float feedback_clock = 1.25;\nuniform vec3 form_color")
			editor.preview.material_override.shader = shader
			_frame(Vector2(-15, -2), 15, 16, 43)
			_freeze_node(editor)
			editor.tool = operation
			editor.radius = 2.2
			var cell := Vector2i(-13, -2) if operation == "raise" else Vector2i(-18, -3)
			var height: float = editor.data.cells[cell].height
			var screen: Vector2 = editor.camera.unproject_position(Vector3(cell.x + .5, height, cell.y + .5))
			var input := InputEventMouseButton.new()
			input.button_index = MOUSE_BUTTON_LEFT
			input.position = screen
			input.pressed = true
			viewport.push_input(input, true)
			if not editor.painting:
				errors.append("Real press failed " + operation)
			editor.preview.refresh(editor.blueprint_data, editor.renderer, true)
			input.pressed = false
			viewport.push_input(input, true)
			editor.process_mode = Node.PROCESS_MODE_DISABLED
			editor.brush.visible = false
			for index: int in 32:
				var seconds: float = index * .05
				if index == 14:
					editor.renderer.flush_dirty(1 << 20)
					_freeze_node(editor.renderer)
				if index > 0:
					editor.renderer._process(.05)
					editor.preview.refresh(editor.data, editor.renderer)
					if variant == "after":
						editor.preview._process(.05)
				editor.preview.material_override.set_shader_parameter("feedback_clock", PHASE + seconds)
				RenderingServer.force_draw(false)
				await process_frame
				viewport.get_texture().get_image().save_png(temporary.path_join("%s_%s_%03d.png" % [operation, variant, index]))
				if index in [0, 5, 14, 17, 31]:
					viewport.size = SIZE
					await photo("%s_%s_%03d" % [operation, variant, index], seconds)
					viewport.size = Vector2i(1280, 720)
			if editor.gameplay.actor != null:
				errors.append("Actor present")
			viewport.remove_child(editor)
			editor.free()
	var stable: bool = before == _source_hashes()
	for file: String in extra:
		stable = stable and extra[file] == FileAccess.get_sha256(file)
	if not stable:
		errors.append("Source changed during capture")
	FileAccess.open(output.path_join("captures.json"), FileAccess.WRITE).store_string(JSON.stringify({"valid": errors.is_empty(), "errors": errors, "source_stable": stable, "source_sha256": before, "extra_sources": extra, "records": records, "method": "Controlled native comparison. Same actual release input and data. Renderer publication held to t=0.70s in both variants; production morph and preview clocks stepped by .05s. TIME frozen except preview clock. Before uses task-start preview script plus inert commit adapter, and task-start shader. 2K stills;720p raw animation."}, "\t"))
	print("RELEASE CAPTURE ", errors.is_empty(), " ", errors)
	viewport.queue_free()
	quit(1 if not errors.is_empty() else 0)
