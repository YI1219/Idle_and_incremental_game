extends SceneTree
## Headless contract check for the user's argon art direction, not visual acceptance.
## Run: godot --headless --path . --script tests/argon_world_lock_test.gd

const TerrainEnvironment = preload("res://scripts/terrain_editor/terrain_environment.gd")
const TimeSystem = preload("res://scripts/gameplay/systems/time_solar_system.gd")

var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("ok: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func _locked_yaw(yaw: float) -> bool:
	return yaw >= 28.0 - 0.001 and yaw <= 42.0 + 0.001

func _cool_silver(fog: Color) -> bool:
	# Allow lookdev adjustments inside cool, low-chroma silver-grey; reject warm/pink fog.
	return fog.r >= 0.65 and fog.g >= fog.r and fog.b >= fog.g \
		and fog.b - fog.r >= 0.02 and fog.b - fog.r <= 0.18

func run() -> void:
	var preset: Dictionary = TerrainEnvironment.STYLE_PRESETS[0]
	check(String(preset["name"]).replace(" ", "") == "天青烟岚·宋韵青绿",
		"preset 0 remains 天青烟岚 · 宋韵青绿")
	check(_locked_yaw((preset["sun_rot"] as Vector3).y),
		"preset 0 sun yaw is 28..42 degrees (actual %.2f)" % (preset["sun_rot"] as Vector3).y)
	check(_cool_silver(preset["fog_color"] as Color),
		"preset 0 morning fog remains cool silver-grey (actual %s)" % str(preset["fog_color"]))
	check(is_zero_approx(float(preset["cover_relief"])) and is_equal_approx(float(preset["ground_fine"]), 0.05),
		"preset 0 keeps cover_relief=0 and ground_fine=0.05")

	var bad_keys: Array[String] = []
	for keyframe: Dictionary in TimeSystem.KEYFRAMES:
		var yaw: float = (keyframe["sun_rot"] as Vector3).y
		if not _locked_yaw(yaw):
			bad_keys.append("at=%.2f yaw=%.2f" % [float(keyframe["at"]), yaw])
	check(bad_keys.is_empty(), "all day/night light keyframes respect yaw 28..42: %s" % str(bad_keys))

	var editor := (load("res://scenes/terrain_editor.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(editor)
	editor.process_mode = Node.PROCESS_MODE_DISABLED
	var time: TimeSystem = editor.gameplay.time_system
	var sun := editor.get_node("SunLight") as DirectionalLight3D
	var environment: Environment = (editor.get_node("WorldEnvironment") as WorldEnvironment).environment
	var grass: ShaderMaterial = editor.renderer.materials["grass"]
	var bad_hours: Array[String] = []
	var bad_matte_hours: Array[int] = []
	for hour: int in 12:
		time.set_progress(float(hour) / 12.0, editor)
		if not _locked_yaw(sun.rotation_degrees.y):
			bad_hours.append("hour=%d yaw=%.2f" % [hour, sun.rotation_degrees.y])
		if not is_zero_approx(float(grass.get_shader_parameter("cover_relief"))) \
				or not is_equal_approx(float(grass.get_shader_parameter("ground_fine_strength")), 0.05):
			bad_matte_hours.append(hour)
	check(bad_hours.is_empty(), "all twelve shichen apply yaw 28..42 to the scene: %s" % str(bad_hours))
	check(bad_matte_hours.is_empty(), "all twelve shichen preserve matte lawn parameters: %s" % str(bad_matte_hours))
	time.set_progress(0.29, editor)
	check(_cool_silver(environment.fog_light_color),
		"time cycle applies cool silver-grey morning fog (actual %s)" % str(environment.fog_light_color))
	check(environment.ssil_enabled and environment.ssil_intensity > 0.0,
		"scene retains enabled SSIL with a positive intensity")

	root.remove_child(editor)
	editor.free()
	await process_frame
	print("ARGON WORLD LOCK: %d/%d passed; %d failures" % [checks - failures, checks, failures])
	quit(0 if failures == 0 else 1)
