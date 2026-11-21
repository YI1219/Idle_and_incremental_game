extends SceneTree

var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func start_raise(editor: Node3D, cell: Vector2i) -> bool:
	var height: float = editor.data.cells[cell].height
	var screen: Vector2 = editor.camera.unproject_position(Vector3(cell.x + .5, height, cell.y + .5))
	return editor.begin_paint(screen)

func run() -> void:
	var editor: Node3D = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.set_process(false)
	editor.camera.set_process(false)
	editor.renderer.set_process(false)
	editor.water_view.set_process(false)
	editor.preview.set_process(false)
	editor.tool = "raise"
	editor.radius = .49
	editor.snap = true
	var cell := Vector2i(9, -3)
	var original: Dictionary = editor.data.serialize()
	check(start_raise(editor, cell), "fixture starts a real blueprint")
	editor.preview.refresh(editor.blueprint_data, editor.renderer, true)
	check(editor.preview.visible, "held blueprint is visible")
	editor.commit_blueprint()
	check(editor.preview.visible, "release keeps immediate geometry feedback visible")
	var material: ShaderMaterial = editor.preview.material_override
	check(material.get_shader_parameter("committed") == 1.0, "release switches feedback immediately before a worker result exists")
	check(editor.renderer.has_pending_updates(), "fixture keeps the real terrain build pending")
	if editor.preview.has_method("_process"):
		var committed: Dictionary = editor.data.serialize()
		var mesh: Mesh = editor.preview.mesh
		editor.preview._process(.12)
		check(float(material.get_shader_parameter("commit_phase")) > .0, "feedback advances while real terrain is pending")
		editor.preview.refresh(editor.data, editor.renderer)
		check(editor.preview.mesh == mesh, "pending frames reuse the cheap feedback mesh")
		editor.preview._process(2.0)
		check(editor.preview.visible, "slow terrain generation keeps visible feedback past the opening animation")
		check(editor.data.serialize() == committed, "feedback animation does not mutate authored terrain or water")
		editor.renderer.flush_dirty(1 << 20)
		editor.preview.refresh(editor.data, editor.renderer)
		check(editor.preview.visible, "publication preserves continuous feedback")
		editor.preview._process(.08)
		check(material.get_shader_parameter("commit_alpha") == 1.0, "feedback covers the early partially revealed real terrain")
		editor.renderer._process(1.0)
		editor.preview.refresh(editor.data, editor.renderer)
		editor.preview._process(.08)
		var alpha: float = material.get_shader_parameter("commit_alpha")
		check(alpha > .0 and alpha < 1.0, "published geometry fades the feedback over several frames")
		editor.preview._process(.2)
		check(not editor.preview.visible, "fast publication clears feedback without an imposed minimum wait")
		editor.renderer._process(1.0)
		check(start_raise(editor, cell), "another edit can start after handoff")
		editor.commit_blueprint()
		var pending: Dictionary = editor.data.serialize()
		check(start_raise(editor, Vector2i(8, -3)), "next draft can begin while previous commit is pending")
		editor.preview.refresh(editor.blueprint_data, editor.renderer, true)
		editor.cancel_input()
		check(editor.data.serialize() == pending, "canceling the next draft preserves the previous commit")
		check(editor.preview.visible and material.get_shader_parameter("committed") == 1.0, "cancel returns to the pending committed feedback")
		editor.data.undo()
		editor.data.undo()
		editor.preview.refresh(editor.data, editor.renderer)
		check(editor.data.serialize() == original, "undo restores the original authored terrain")
		var colors: PackedColorArray = editor.preview.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		var removal_only: bool = not colors.is_empty()
		for color: Color in colors:
			removal_only = removal_only and is_equal_approx(color.r, 1.0)
		check(editor.preview.visible and removal_only, "undo replaces stale growth feedback with the latest removal difference")
	else:
		check(false, "release feedback has an animation clock")
	editor.free()
	print("TERRAIN RELEASE FEEDBACK %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
