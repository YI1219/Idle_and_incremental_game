extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var editor: Node3D = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.set_process(false)
	var water: Variant = editor.get("water_view")
	check(water != null, "normal scene owns live conservative water")
	if water != null:
		var initial: float = water.published_volume
		water.tick(.2)
		water.flush()
		check(water.published_volume < initial, "normal preset loses finite water through its open outlets")
		check(absf(water.published_volume + water.published_discharged_volume - initial) < .00000001, "normal scene retains plus discharges its initial volume")
		var baseline_water: Texture2D = editor.renderer.materials.water.get_shader_parameter("shore_field")
		check(baseline_water == water.shore_texture, "live field owns production water material")
		editor.data.begin_stroke()
		editor.data.apply_brush(Vector2(-12,-9), .49, "raise", true, 1.5, 3)
		editor.data.end_stroke()
		editor.renderer.rebuild_all()
		water.flush()
		check(editor.renderer.materials.water.get_shader_parameter("shore_field") == water.shore_texture, "terrain publication restores live field instead of nominal water")
		var path: String = "user://water_integration_test.json"
		check(editor.save_layout(path) == OK, "live continuous water can be saved")
		var saved: float = water.published_volume
		editor.select_preset(2)
		check(water.published_volume == 0.0 and water.fall_veils.is_empty(), "dry preset resets live water and falls")
		check(editor.load_layout(path) == OK, "live continuous water can be loaded")
		check(absf(water.published_volume - saved) < .00000001, "load restores saved volume without refilling")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Undoing a bed edit must not rewind the simulation's finite volume.
	var sample: RefCounted = load("res://scripts/terrain_editor/terrain_data.gd").new()
	sample.cells[Vector2i.ZERO]={"height":0.0,"water":2,"water_volume":1.0}
	var flow: RefCounted=load("res://scripts/terrain_editor/water_flow.gd").new()
	flow.configure(sample)
	sample.begin_stroke()
	sample.apply_brush(Vector2(.5,.5),.49,"raise",true,1.5,3)
	sample.end_stroke()
	flow.sync(sample)
	flow.step(.2)
	flow.write_to_data(sample)
	var retained: float=flow.total_volume()
	sample.undo()
	flow.sync(sample)
	check(absf(flow.total_volume()-retained)<.00000001,"undo of a bed edit keeps current water rather than refilling from history")
	sample.redo()
	flow.sync(sample)
	check(absf(flow.total_volume()-retained)<.00000001,"redo of a bed edit keeps current finite water")
	editor.free()
	print("TERRAIN WATER INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
