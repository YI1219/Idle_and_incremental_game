extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var editor: Node3D = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.set_process(false)
	editor.camera.set_process(false)
	editor.data.cells.clear()
	for z: int in range(-2, 3):
		for x: int in range(-2, 3):
			editor.data.cells[Vector2i(x,z)] = {"height":4.0,"water":-1,"water_volume":0.0}
	for z: int in range(3, 6):
		for x: int in range(-2, 3):
			editor.data.cells[Vector2i(x,z)] = {"height":1.5,"water":-1,"water_volume":0.0}
	editor.renderer.rebuild_all()
	editor.water_view.reset(editor.data)
	editor.camera._center = Vector2(0,1)
	editor.camera._height = 21
	editor.camera._pitch = 35
	editor.camera.advance(0)
	editor.radius = 1.1
	var start: Vector2 = editor.camera.unproject_position(Vector3(.5,4,.5))
	for tool: String in ["raise","lower","contract","water"]:
		editor.tool = tool
		editor.build_height = 1.5
		editor.water_level = 7
		if tool == "water":
			editor.water_level = 7
			# A wet brush must still show the selected top even if this height
			# cannot accept the chosen water preset. Inspect hover in that case.
			editor._update_brush(start)
			check(absf(editor.brush.position.y - 4.06) < .01, "water hover follows the height-map top")
			continue
		check(editor.begin_paint(start), tool + " starts at upper ground")
		check(absf(editor.build_height - 4.0) < .001, tool + " takes the displayed starting plane as its target")
		var end: Vector2 = editor.camera.unproject_position(Vector3(2.5,1.5,4.5))
		var origin: Vector3 = editor.camera.project_ray_origin(end)
		var ray: Vector3 = editor.camera.project_ray_normal(end)
		var projected: Vector3 = origin + ray * ((4.0-origin.y)/ray.y)
		var hit: Dictionary = editor._pointer(end)
		check(absf(hit.position.y - 4.0) < .001 and Vector2(hit.position.x,hit.position.z).distance_to(Vector2(projected.x,projected.z)) < .001, tool + " drag keeps the original plane and ray projection")
		editor.cancel_input()
	editor.tool = "expand"
	editor.radius = .49
	editor.build_height = 1.5
	check(editor.begin_paint(start), "expansion can sample upper ground before moving to an empty edge")
	if editor.blueprint_data != null:
		check(editor.blueprint_data.serialize() == editor.data.serialize(), "sampling an occupied expansion origin leaves terrain unchanged")
		editor.cancel_input()
	editor.radius = 1.1
	editor.tool = "expand"
	editor.build_height = 1.5
	var edge: Vector2 = editor.camera.unproject_position(Vector3(-2.5,4,.5))
	check(editor.begin_paint(edge), "upper-edge expansion starts")
	if editor.blueprint_data != null:
		var valid := true
		var count := 0
		for cell: Vector2i in editor.blueprint_data.cells:
			if editor.data.cells.has(cell):
				continue
			count += 1
			valid = valid and absf(editor.blueprint_data.cells[cell].height-4.0) < .001
		check(count > 0 and valid, "every expanded cell uses the starting plane")
		editor.cancel_input()
	var hud: Control = editor.gameplay.shihai_hud
	var extra_tool := false
	for item: Dictionary in hud.SCULPT_TOOLS:
		extra_tool = extra_tool or item.id == "level"
	check(not extra_tool, "alignment is shared input behavior with no extra level tool")
	editor.free()
	print("STROKE PLANE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
