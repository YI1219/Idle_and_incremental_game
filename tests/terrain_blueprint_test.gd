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

func run() -> void:
	var editor: Node3D = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.set_process(false)
	editor.camera.set_process(false)
	editor.tool = "raise"
	editor.radius = .49
	editor.snap = true
	var cell := Vector2i(9, -3)
	var before: Dictionary = editor.data.serialize()
	var height: float = editor.data.cells[cell].height
	var screen: Vector2 = editor.camera.unproject_position(Vector3(9.5, height, -2.5))
	check(editor.begin_paint(screen), "valid land starts a blueprint")
	check(editor.data.serialize() == before, "held stroke leaves authoritative terrain unchanged")
	check(not editor.renderer.has_pending_updates(), "held stroke does not rebuild actual terrain")
	check(editor.get("blueprint_data") != null, "held stroke has independent draft data")
	if editor.has_method("commit_blueprint"):
		editor.commit_blueprint()
		check(editor.data.cells[cell].height == height + .5, "release commits the planned height")
		check(editor.data.undo() and editor.data.serialize() == before, "one undo reverses the entire blueprint")
		editor.renderer.rebuild_all()
		editor.begin_paint(screen)
		var cancel := InputEventMouseButton.new()
		cancel.button_index = MOUSE_BUTTON_RIGHT
		cancel.pressed = true
		editor._input(cancel)
		check(not editor.painting and editor.data.serialize() == before, "right click cancels draft without changing terrain")
		check(editor.get("blueprint_data") == null, "cancel drops draft")
		check(not editor.renderer.has_pending_updates(), "cancel does not schedule a rebuild")
	else:
		check(false, "release has a blueprint commit entry point")
	if editor.data.has_method("can_apply_brush"):
		check(not editor.data.can_apply_brush(Vector2(500, 500), .49, "contract", true, 1.5, 3), "empty space is invalid for removal")
		check(not editor.data.can_apply_brush(Vector2(9.5, -2.5), .49, "expand", true, 1.5, 3), "occupied land is invalid for expansion")
	else:
		check(false, "cursor can query a brush operation before committing")
	editor.tool="lower"
	editor.begin_paint(screen)
	editor.preview.refresh(editor.blueprint_data,editor.renderer,true)
	var preview_vertices:PackedVector3Array=editor.preview.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var highest:float=-INF
	for v:Vector3 in preview_vertices:highest=maxf(highest,v.y)
	check(highest>height,"lower draft is visible above the original surface")
	editor.cancel_input()
	editor.tool="expand"
	var invalid_hit:Dictionary={"position":Vector3(9.5,height,-2.5),"cell":cell}
	check(not editor._brush_valid(invalid_hit),"occupied expansion cursor is invalid")
	editor.free()
	print("TERRAIN BLUEPRINT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
