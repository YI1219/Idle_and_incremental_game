extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: Node = load("res://scenes/play.tscn").instantiate()
	root.add_child(scene)
	for i in 20:
		await process_frame
	var player: Node3D = get_first_node_in_group("player")
	var rig: Node3D = get_first_node_in_group("camera_rig")
	player.set_physics_process(false)
	player.global_position = Vector3(3.4, 0.4, 1.6)
	rig.max_distance = 28.0
	rig._distance = 20.0
	rig._yaw_index = 0
	rig.look_height = 0.7
	rig.snap_to_target()
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://art/review/floating_island/2026-10-05")
	var image := root.get_texture().get_image()
	image.save_png("res://art/review/floating_island/2026-10-05/island.png")
	quit()
