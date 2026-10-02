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
	var island: Node3D = get_first_node_in_group("island_shell")
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
	if builder:
		builder.set_active(false)
	rig.set_physics_process(false)
	var look := Vector3(0.4, -2.2, -0.4)
	var from := Vector3(-17.5, 0.55, 12.8)
	rig.global_transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	var camera := rig.get_node_or_null("Camera3D") as Camera3D
	if camera:
		camera.fov = 40
	await shot("res://art/review/island_style/2026-10-02/underside_low.png")

	var terrain: Node3D = island.terrain
	for x in range(-12, 12):
		for z in range(-11, 11):
			terrain.land_cells[Vector2i(x, z)] = true
	terrain.rebuild()
	if terrain.has_method("flush_rebuild"):
		terrain.flush_rebuild()
	await frames(20)
	if camera:
		camera.fov = 38
	from = Vector3(-26.0, 16.0, 28.0)
	look = Vector3(0.0, -1.2, 0.0)
	rig.global_transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	await shot("res://art/review/island_style/2026-10-02/large_island.png")
	from = Vector3(-24.0, 0.8, 20.0)
	look = Vector3(0.5, -2.6, 0.0)
	rig.global_transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	if camera:
		camera.fov = 38
	await shot("res://art/review/island_style/2026-10-02/large_island_underside.png")

	var offsets := [
		Vector2i(28, 0), Vector2i(-30, 4), Vector2i(6, 28), Vector2i(-8, -30),
		Vector2i(26, 22), Vector2i(-26, -24), Vector2i(30, -20),
	]
	for off in offsets:
		for x in range(off.x, off.x + 5):
			for z in range(off.y, off.y + 4):
				terrain.land_cells[Vector2i(x, z)] = true
	terrain.rebuild()
	await frames(20)
	from = Vector3(-8.0, 42.0, 54.0)
	look = Vector3(2.0, -1.0, 0.0)
	rig.global_transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	if camera:
		camera.fov = 46
	await shot("res://art/review/island_style/2026-10-02/multi_island.png")
	quit()
