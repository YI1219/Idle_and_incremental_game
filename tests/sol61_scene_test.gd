extends SceneTree
## Stage-one scene contract: no humanoid exists, including after a preset rebuild.
const ActorScript = preload("res://scripts/gameplay/entities/cultivator_actor.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("ok: ", message)

func count_actors(node: Node) -> int:
	var count: int = 1 if node.get_script() == ActorScript else 0
	for child: Node in node.get_children():
		count += count_actors(child)
	return count

func run() -> void:
	var editor: Node3D = (load("res://scenes/terrain_editor.tscn") as PackedScene).instantiate()
	root.add_child(editor)
	await process_frame
	editor.set_process(false)
	check(count_actors(editor) == 0 and editor.gameplay.actor == null, "normal scene contains no humanoid instance")
	check(editor.gameplay.stance == "sculpt", "stage-one scene starts with terrain camera control")
	var f11 := InputEventKey.new()
	f11.keycode = KEY_F11
	f11.pressed = true
	check(editor.gameplay.handle_unhandled_input(f11) and editor.gameplay.wallpaper_mode, "production F11 wallpaper mode works without actor")
	editor.gameplay.tick(0.016)
	editor.select_preset(1)
	editor.gameplay.tick(0.016)
	check(count_actors(editor) == 0 and editor.gameplay.actor == null, "preset rebuild and tick do not recreate humanoid")
	check(editor.renderer.props.get_node_or_null("ReferenceCottage") == null, "scene keeps deleted cottage absent")
	editor.gameplay.time_system.set_progress(0.29,editor)
	var water:ShaderMaterial=editor.renderer.materials.water
	var direction:Variant=water.get_shader_parameter("sun_direction")
	check(direction is Vector3 and (direction as Vector3).is_equal_approx(editor.get_node("SunLight").transform.basis.z.normalized()), "water highlights follow the actual scene light")
	var day_glint:Variant=water.get_shader_parameter("glint_energy")
	editor.gameplay.time_system.set_progress(0.0,editor)
	var night_glint:Variant=water.get_shader_parameter("glint_energy")
	check(day_glint is float and night_glint is float and float(night_glint)<float(day_glint)*0.35, "night water does not retain daytime highlight energy")
	print("SOL61 SCENE: ", checks, " checks, ", failures, " failures")
	editor.free()
	quit(1 if failures > 0 else 0)
