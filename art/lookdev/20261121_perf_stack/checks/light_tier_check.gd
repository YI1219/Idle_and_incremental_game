extends SceneTree
## Headless: the light tier through the editor's own entry points, in the real scene.
func _initialize() -> void:
	call_deferred("run")

func _state(editor: Node3D) -> Array:
	var view: Viewport = editor.get_viewport()
	var env: Environment = (editor.get_node("WorldEnvironment") as WorldEnvironment).environment
	return [view.msaa_3d, view.screen_space_aa, env.ssao_enabled, env.ssil_enabled, (editor.camera.attributes as CameraAttributesPractical).dof_blur_far_enabled, editor.preview_quality.native, editor.preview_quality.light]

func run() -> void:
	var editor: Node3D = load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	for index: int in 10:
		await process_frame
	var failures: int = 0
	var start: Array = _state(editor)
	print("START   ", start)
	editor.set_light_preview(true)
	await process_frame
	var light: Array = _state(editor)
	print("LIGHT   ", light)
	if light != [Viewport.MSAA_DISABLED, Viewport.SCREEN_SPACE_AA_SMAA, false, false, false, false, true]:
		failures += 1
		push_error("light tier state is wrong")
	editor.set_native_preview(true)
	await process_frame
	var native: Array = _state(editor)
	print("NATIVE  ", native)
	if not (native[2] and native[3] and native[4] and native[5] and not native[6] and native[1] == start[1]):
		failures += 1
		push_error("native tier did not restore what the light tier switched off")
	editor.set_native_preview(false)
	await process_frame
	var back: Array = _state(editor)
	print("DEFAULT ", back)
	if back != start:
		failures += 1
		push_error("default tier differs after a round trip")
	print("LIGHT TIER CHECK failures=", failures)
	editor.free()
	quit(1 if failures else 0)
