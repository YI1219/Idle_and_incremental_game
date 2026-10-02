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
	var outline := PackedVector2Array()
	var mid := Vector2.ZERO
	if island and island.terrain:
		for row in island.terrain.island_cache.values():
			outline = row.get("outline", PackedVector2Array())
			var c: Vector3 = row.get("centroid", Vector3.ZERO)
			mid = Vector2(c.x, c.z)
			break
	var rim2 := Vector2(-2.4, 5.2)
	var best := -INF
	for p in outline:
		var score := p.y - p.x * 0.15
		if score > best:
			best = score
			rim2 = p
	if mid == Vector2.ZERO:
		mid = Vector2(0.4, -0.5)
	var out2 := rim2 - mid
	if out2.length_squared() < 1e-4:
		out2 = Vector2(0.0, 1.0)
	out2 = out2.normalized()
	var rim := Vector3(rim2.x, 0.02, rim2.y)
	var from := rim + Vector3(out2.x, 0.0, out2.y) * 2.65 + Vector3(0.0, 0.78, 0.0)
	var look := rim + Vector3(0.0, -0.06, 0.0) - Vector3(out2.x, 0.0, out2.y) * 0.28
	rig.global_transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	var camera := rig.get_node_or_null("Camera3D") as Camera3D
	if camera:
		camera.fov = 30
	for i in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/review/island_style/2026-10-02/grass_edge.png")
	quit()
