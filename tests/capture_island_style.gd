extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await process_frame

func shot(path: String) -> void:
	await frames(16)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(path)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: Node = load("res://scenes/play.tscn").instantiate()
	root.add_child(scene)
	await frames(40)
	var rig: Node3D = get_first_node_in_group("camera_rig")
	var builder: Node3D = get_first_node_in_group("sandbox_builder")
	DirAccess.make_dir_recursive_absolute("res://art/review/island_style/2026-10-02")
	rig._distance = rig.default_distance
	rig.snap_to_target()
	if builder:
		builder.set_active(false)
	await shot("res://art/review/island_style/2026-10-02/overview_play.png")
	rig._distance = rig.min_distance
	rig.snap_to_target()
	await shot("res://art/review/island_style/2026-10-02/closeup_play.png")
	if builder:
		builder.set_active(true)
	rig._distance = rig.default_distance
	rig.snap_to_target()
	await shot("res://art/review/island_style/2026-10-02/overview_build.png")
	rig._distance = rig.min_distance
	rig.snap_to_target()
	await shot("res://art/review/island_style/2026-10-02/closeup_build.png")
	quit()
