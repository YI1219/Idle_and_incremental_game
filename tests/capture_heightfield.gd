extends SceneTree
## Screenshots for the heightfield island pass. Not art acceptance.

const Heightfield := preload("res://scripts/world/heightfield.gd")
const OUT := "res://art/review/heightfield/2026-10-02"

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await process_frame

func shot(path: String) -> void:
	await frames(10)
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
	rig._distance = rig.default_distance
	rig.snap_to_target()
	await shot(OUT + "/overview.png")

	_sculpt_demo(terrain, island)
	terrain.flush_rebuild()
	await frames(8)

	rig._distance = rig.min_distance
	rig.snap_to_target()
	await shot(OUT + "/closeup_slope.png")

	rig.set_physics_process(false)
	_look(rig, Vector3(4.6, 4.2, 1.8), Vector3(4.4, -0.2, 0.2), 32)
	await shot(OUT + "/lake.png")

	_look(rig, Vector3(-2.2, 3.4, 7.2), Vector3(0.4, -0.8, 3.2), 34)
	await shot(OUT + "/hole_waterfall.png")

	if builder:
		builder.set_active(true)
		builder.commit_place("tree", Vector2i(-2, -5))
		builder.set_active(false)
	terrain.flush_rebuild()
	_look(rig, Vector3(-2.0, 4.8, -2.4), Vector3(-1.5, 0.2, -4.6), 36)
	await shot(OUT + "/placed_building.png")

	_look(rig, Vector3(-16.0, 0.4, 12.5), Vector3(0.2, -2.4, -0.2), 40)
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
	_look(rig, Vector3(-22.0, 16.0, 26.0), Vector3(0.0, -1.0, 0.0), 38)
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
	_look(rig, Vector3(-8.0, 42.0, 54.0), Vector3(2.0, -1.0, 0.0), 46)
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
	main.rebuild_full(true)


func _look(rig: Node3D, from: Vector3, look: Vector3, fov: float) -> void:
	rig.global_transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	var cam := rig.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.fov = fov
		cam.near = 1.2


func _print_stats(label: String, stats: Dictionary) -> void:
	print("PERF %s: islands=%s chunks=%s tris=%s draws=%s stroke_ms=%s rebuild_ms=%s" % [
		label, stats.get("islands"), stats.get("chunks"), stats.get("triangles"),
		stats.get("draw_calls"), stats.get("stroke_ms"), stats.get("rebuild_ms"),
	])
