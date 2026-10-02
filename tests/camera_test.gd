extends SceneTree
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node = load("res://scenes/play.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var rig: Node3D = get_first_node_in_group("camera_rig")
	rig.set_physics_process(false)
	rig.snap_to_target()
	var initial: Vector3 = rig.global_position
	rig.nudge_zoom(-100)
	check(rig._distance == rig.min_distance and rig.global_position == initial, "滚轮只改变目标，不直接跳镜头")
	rig._apply(false, 1.0 / 60)
	check(rig._smooth_distance > rig.min_distance and rig._smooth_distance < rig.default_distance, "首帧平滑趋近")
	for i in 90:
		rig._apply(false, 1.0 / 60)
	var near: Vector3 = rig.global_position
	check(absf(rig._smooth_distance - rig.min_distance) < 0.001 and rig._smooth_pitch < 39, "近景降低俯角")
	rig.nudge_zoom(100)
	var previous: float = rig._smooth_distance
	var monotone := true
	for i in 120:
		rig._apply(false, 1.0 / 60)
		monotone = monotone and rig._smooth_distance >= previous and rig._smooth_distance <= rig.max_distance
		previous = rig._smooth_distance
	check(monotone and rig._smooth_pitch > 57, "远景平稳抬升无过冲")
	check(Vector2(rig.global_position.x, rig.global_position.z).distance_to(Vector2(near.x, near.z)) > 5, "缩放含真实水平位移")
	rig.pan_by_pixels(Vector2(640, 360), Vector2(100, 30))
	check(rig._pan_goal.length() > 0.5 and is_zero_approx(rig._pan_goal.y), "中键沿地面平移")
	rig._apply(false, 1.0 / 60)
	check(rig._smooth_pan.length() > 0 and rig._smooth_pan.length() < rig._pan_goal.length(), "平移同样缓动")
	rig.recenter()
	for i in 100:
		rig._apply(false, 1.0 / 60)
	check(rig._smooth_pan.length() < 0.001, "回中平滑收敛")
	print("CAMERA CHECKS: %d/%d passed, failures=%d" % [checks - failures, checks, failures])
	quit(1 if failures else 0)
