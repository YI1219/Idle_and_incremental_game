extends SceneTree
## Screenshots for the heightfield island pass. Not art acceptance.

const Heightfield := preload("res://scripts/world/heightfield.gd")
const HeightfieldMesh := preload("res://scripts/world/heightfield_mesh.gd")
const OUT := "res://art/review/heightfield/2026-10-02"

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await process_frame

var _shot_cam: Camera3D

func shot(path: String) -> void:
	if _shot_cam:
		_shot_cam.make_current()
	await frames(10)
	if _shot_cam:
		_shot_cam.make_current()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("wrote ", path)

func run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene: Node = load("res://scenes/play.tscn").instantiate()
	root.add_child(scene)
	await frames(36)
	var rig: Node3D = get_first_node_in_group("camera_rig")
	var builder: Node3D = get_first_node_in_group("sandbox_builder")
	var island: Node3D = get_first_node_in_group("island_shell")
	var terrain: Node3D = island.terrain
	if builder:
		builder.set_active(false)
	terrain.flush_rebuild()
	rig.set_physics_process(false)
	var play_cam := rig.get_node_or_null("Camera3D") as Camera3D
	if play_cam:
		play_cam.current = false
	var arena: Node = scene.find_child("PracticeArena", true, false)
	if arena:
		arena.visible = false
	var shot_cam := Camera3D.new()
	shot_cam.name = "ShotCam"
	shot_cam.near = 1.2
	shot_cam.far = 240.0
	scene.add_child(shot_cam)
	_shot_cam = shot_cam
	shot_cam.make_current()
	_aim(shot_cam, Vector3(8.5, 14.0, 12.0), Vector3(0.0, -0.4, 0.0), 42)
	await shot(OUT + "/overview.png")

	_sculpt_demo(terrain, island)
	terrain.flush_rebuild()
	await frames(8)
	if scene.get("house"):
		(scene.house as Node3D).visible = false
	var player: Node3D = get_first_node_in_group("player")
	if player:
		player.visible = false

	_aim(shot_cam, Vector3(-6.4, 3.8, 4.8), Vector3(-3.4, 0.6, 1.3), 38)
	await shot(OUT + "/closeup_slope.png")

	_aim(shot_cam, Vector3(3.4, 6.4, -6.2), Vector3(1.2, -0.4, -3.2), 40)
	await shot(OUT + "/lake.png")

	_aim(shot_cam, Vector3(3.2, 1.8, 6.6), Vector3(0.4, -1.8, 2.6), 36)
	await shot(OUT + "/hole_waterfall.png")

	if builder:
		builder.set_active(true)
		builder.commit_place("tree", Vector2i(-2, -5))
		builder.set_active(false)
	terrain.flush_rebuild()
	_aim(shot_cam, Vector3(-2.0, 5.6, -9.5), Vector3(-2.0, 0.2, -5.0), 38)
	await shot(OUT + "/placed_building.png")

	_aim(shot_cam, Vector3(-12.0, -2.8, 10.0), Vector3(0.5, -3.5, 0.8), 42)
	await shot(OUT + "/underside.png")

	var playable: Dictionary = terrain.heightfield_stats()
	_print_stats("playable", playable)

	for x in range(-12, 12):
		for z in range(-11, 11):
			terrain.land_cells[Vector2i(x, z)] = true
	terrain.rebuild()
	terrain.flush_rebuild()
	await frames(6)
	var large: Dictionary = terrain.heightfield_stats()
	_print_stats("4x island", large)
	_aim(shot_cam, Vector3(-22.0, 16.0, 26.0), Vector3(0.0, -1.0, 0.0), 38)
	await shot(OUT + "/large_island.png")

	var offsets := [
		Vector2i(28, 0), Vector2i(-30, 4), Vector2i(6, 28), Vector2i(-8, -30),
		Vector2i(26, 22), Vector2i(-26, -24), Vector2i(30, -20),
	]
	for off in offsets:
		for x in range(off.x, off.x + 5):
			for z in range(off.y, off.y + 4):
				terrain.land_cells[Vector2i(x, z)] = true
	terrain.rebuild()
	terrain.flush_rebuild()
	await frames(6)
	var multi: Dictionary = terrain.heightfield_stats()
	_print_stats("4x + 7 satellites", multi)
	_aim(shot_cam, Vector3(-8.0, 42.0, 54.0), Vector3(2.0, -1.0, 0.0), 46)
	await shot(OUT + "/multi_island.png")
	quit()


func _sculpt_demo(terrain: Node3D, island: Node3D) -> void:
	var main: Node3D = terrain.get_node("Islands").get_child(0)
	if main == null or main.field == null:
		return
	var field = main.field
	# Slope for grass→rock closeup.
	field.apply_brush("raise", Vector3(-3.2, 0.0, 1.2), 2.4, 1.6, true)
	field.apply_brush("raise", Vector3(-3.6, 0.0, 1.6), 1.4, 1.2, true)
	# Extra closed pit near the river for a readable lake.
	for p in [Vector3(1.2, 0.0, -3.4), Vector3(1.6, 0.0, -3.0), Vector3(0.8, 0.0, -3.0)]:
		field.apply_brush("lower", p, 1.3, 1.1, true)
	# Through-hole near the south rim so water can fall into the cloud sea.
	for _i in 6:
		field.apply_brush("lower", Vector3(0.4, 0.0, 2.8), 1.0, 1.4, true)
	var span := HeightfieldMesh.chunk_range(field)
	var t0 := Time.get_ticks_usec()
	for z in span.y:
		for x in span.x:
			HeightfieldMesh.build_chunk(field, Vector2i(x, z), "top", main.skip_top)
	main.last_stroke_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	main.rebuild_full(true)


func _aim(cam: Camera3D, from: Vector3, look: Vector3, fov: float) -> void:
	var forward := look - from
	if forward.length_squared() < 1e-6:
		look += Vector3(0.2, -0.2, 0.2)
		forward = look - from
	if absf(forward.normalized().dot(Vector3.UP)) > 0.92:
		look += Vector3(0.4, 0.0, 0.4)
	cam.fov = fov
	cam.near = 1.2
	cam.far = 240.0
	cam.global_transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	cam.make_current()


func _print_stats(label: String, stats: Dictionary) -> void:
	print("PERF %s: islands=%s chunks=%s tris=%s draws=%s stroke_ms=%s rebuild_ms=%s" % [
		label, stats.get("islands"), stats.get("chunks"), stats.get("triangles"),
		stats.get("draw_calls"), stats.get("stroke_ms"), stats.get("rebuild_ms"),
	])
