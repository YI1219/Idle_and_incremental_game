extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: Node = load("res://scenes/play.tscn").instantiate()
	root.add_child(scene)
	for i in 40:
		await process_frame
	var island: Node3D = get_first_node_in_group("island_shell")
	var builder: Node3D = get_first_node_in_group("sandbox_builder")
	var rig: Node3D = get_first_node_in_group("camera_rig")
	if builder:
		builder.set_active(false)
	if island and island.terrain and island.terrain.has_method("flush_bakes"):
		island.terrain.flush_bakes()
	for i in 8:
		await process_frame
	rig.set_physics_process(false)
	var rim := Vector3(-3.2, 0.0, 5.6)
	var mid := Vector3(0.4, 0.0, -0.6)
	if island and island.terrain:
		var land := island.terrain.get_node_or_null("LandSurface") as MeshInstance3D
		if land and land.mesh:
			var best := -INF
			for v in land.mesh.get_faces():
				if absf(v.y) > 0.04:
					continue
				var score := v.z - v.x * 0.18
				if score > best:
					best = score
					rim = Vector3(v.x, 0.0, v.z)
		if not island.terrain.island_cache.is_empty():
			var c: Vector3 = island.terrain.island_cache.values()[0].get("centroid", mid)
			mid = Vector3(c.x, 0.0, c.z)
	var out := rim - mid
	out.y = 0.0
	if out.length_squared() < 1e-4:
		out = Vector3(0.0, 0.0, 1.0)
	out = out.normalized()
	var from := rim + out * 3.25 + Vector3(0.0, 0.38, 0.0)
	var look := rim + Vector3(0.0, -0.22, 0.0) - out * 0.12
	print("grass_edge rim=", rim, " from=", from, " look=", look)
	rig.global_transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	var camera := rig.get_node_or_null("Camera3D") as Camera3D
	if camera:
		camera.fov = 32
	for i in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/review/island_style/2026-10-02/grass_edge.png")
	quit()
