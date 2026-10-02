extends SceneTree
## Screenshots from the play camera. Not art acceptance.

const Heightfield := preload("res://scripts/world/heightfield.gd")
const HeightfieldMesh := preload("res://scripts/world/heightfield_mesh.gd")
const OUT := "res://art/review/heightfield/2026-10-02"
const ARTIFACTS := "/opt/cursor/artifacts"

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await process_frame

func shot(path: String) -> void:
	await frames(14)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(path)
	var name := String(path).get_file()
	img.save_png(ARTIFACTS + "/" + name)
	print("wrote ", path)

func run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(ARTIFACTS)
	var scene: Node = load("res://scenes/play.tscn").instantiate()
	root.add_child(scene)
	await frames(40)
	var space_state := root.get_node_or_null("SpaceState")
	if space_state:
		space_state.space_id = "outside"
	var rig: Node3D = get_first_node_in_group("camera_rig")
	var builder: Node3D = get_first_node_in_group("sandbox_builder")
	var island: Node3D = get_first_node_in_group("island_shell")
	var player: Node3D = get_first_node_in_group("player")
	var terrain: Node3D = island.terrain
	if builder:
		builder.set_active(false)
	if player:
		player.visible = true
	terrain.flush_rebuild()
	_restore_pitch(rig)
	_play_view(rig, player, Vector3(0.6, 0.0, 3.2), 22.0, 1)
	await shot(OUT + "/overview.png")

	_sculpt_demo(terrain)
	terrain.flush_rebuild()
	await frames(8)

	_play_view(rig, player, Vector3(-4.2, 0.0, 2.4), 9.0, 2)
	await shot(OUT + "/closeup_slope.png")

	_play_view(rig, player, Vector3(1.4, 0.0, -3.6), 10.0, 6)
	await shot(OUT + "/lake.png")

	_play_view(rig, player, Vector3(0.2, 0.0, 4.2), 10.0, 0)
	await shot(OUT + "/hole_waterfall.png")

	if builder:
		builder.set_active(true)
		builder.commit_place("tree", Vector2i(-3, -5))
		builder.set_active(false)
	terrain.flush_rebuild()
	_play_view(rig, player, Vector3(-3.0, 0.0, -4.8), 10.0, 5)
	await shot(OUT + "/placed_building.png")

	_low_side(rig, player, Vector3(5.4, 0.0, 1.0), 15.0, 2)
	await shot(OUT + "/low_side.png")
	_restore_pitch(rig)

	_side_view(rig, player, Vector3(-10.0, -1.2, 8.0), Vector3(0.4, -2.8, 0.4), 40.0)
	await shot(OUT + "/underside.png")
	if player:
		player.visible = true
	rig.set_physics_process(true)
	_restore_pitch(rig)

	var playable: Dictionary = terrain.heightfield_stats()
	_print_stats("playable", playable)

	terrain.land_cells.clear()
	for cell in _blob_cells(Vector2i(0, 0), 12, 10, 3):
		terrain.land_cells[cell] = true
	terrain.rebuild()
	terrain.flush_rebuild()
	await frames(8)
	var large: Dictionary = terrain.heightfield_stats()
	_print_stats("4x island", large)
	_play_view(rig, player, Vector3(0.0, 0.0, 2.0), 28.0, 1)
	await shot(OUT + "/large_island.png")

	var offsets := [
		Vector2i(28, 0), Vector2i(-30, 4), Vector2i(6, 28), Vector2i(-8, -30),
		Vector2i(26, 22), Vector2i(-26, -24), Vector2i(30, -20),
	]
	var seed_i := 11
	for off in offsets:
		for cell in _blob_cells(off, 4, 3, seed_i):
			terrain.land_cells[cell] = true
		seed_i += 5
	terrain.rebuild()
	terrain.flush_rebuild()
	await frames(8)
	var multi: Dictionary = terrain.heightfield_stats()
	_print_stats("4x + 7 satellites", multi)
	_play_view(rig, player, Vector3(0.0, 0.0, 2.0), 32.0, 1)
	await shot(OUT + "/multi_island.png")
	quit()


func _blob_cells(center: Vector2i, rx: int, rz: int, seed: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in range(center.y - rz, center.y + rz + 1):
		for x in range(center.x - rx, center.x + rx + 1):
			var nx := float(x - center.x) / float(maxi(rx, 1))
			var nz := float(z - center.y) / float(maxi(rz, 1))
			var nse := Heightfield._hash2(float(x) * 0.37 + float(seed), float(z) * 0.29)
			if pow(absf(nx), 2.1) + pow(absf(nz), 2.1) <= 0.92 + (nse.x - 0.5) * 0.22:
				out.append(Vector2i(x, z))
	return out


func _play_view(rig: Node3D, player: Node3D, at: Vector3, distance: float, yaw_index: int = 1) -> void:
	if player:
		var y := 0.0
		var island: Node3D = get_first_node_in_group("island_shell")
		if island and island.terrain and island.terrain.has_method("sample_height"):
			var h: float = island.terrain.sample_height(at)
			if is_finite(h):
				y = h
		player.global_position = Vector3(at.x, y, at.z)
		player.visible = true
	rig._yaw_index = yaw_index
	rig._distance = distance
	rig._pan_goal = Vector3.ZERO
	rig.snap_to_target()
	for i in 8:
		rig._apply(true)


func _low_side(rig: Node3D, player: Node3D, at: Vector3, distance: float, yaw_index: int) -> void:
	rig.near_pitch_deg = 16.0
	rig.pitch_deg = 18.0
	rig.far_pitch_deg = 20.0
	_play_view(rig, player, at, distance, yaw_index)


func _restore_pitch(rig: Node3D) -> void:
	rig.near_pitch_deg = 38.0
	rig.pitch_deg = 50.0
	rig.far_pitch_deg = 58.0


func _side_view(rig: Node3D, player: Node3D, from: Vector3, look: Vector3, fov: float) -> void:
	rig.set_physics_process(false)
	var cam := rig.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return
	var xform := Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	rig.global_transform = xform
	cam.transform = Transform3D.IDENTITY
	cam.fov = fov
	cam.near = 1.2
	cam.far = 240.0
	cam.make_current()
	if player:
		player.visible = false


func _sculpt_demo(terrain: Node3D) -> void:
	var main: Node3D = terrain.get_node("Islands").get_child(0)
	if main == null or main.field == null:
		return
	var field = main.field
	field.apply_brush("raise", Vector3(-3.2, 0.0, 1.2), 2.4, 1.6, true)
	field.apply_brush("raise", Vector3(-3.6, 0.0, 1.6), 1.4, 1.2, true)
	for p in [Vector3(1.2, 0.0, -3.4), Vector3(1.6, 0.0, -3.0), Vector3(0.8, 0.0, -3.0)]:
		field.apply_brush("lower", p, 1.3, 1.1, true)
	for _i in 6:
		field.apply_brush("lower", Vector3(0.4, 0.0, 2.8), 1.0, 1.4, true)
	field.apply_coast_smooth()
	var span := HeightfieldMesh.chunk_range(field)
	var t0 := Time.get_ticks_usec()
	for z in span.y:
		for x in span.x:
			HeightfieldMesh.build_chunk(field, Vector2i(x, z), "top", main.skip_top)
	main.last_stroke_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	main.rebuild_full(true)


func _print_stats(label: String, stats: Dictionary) -> void:
	print("PERF %s: islands=%s chunks=%s tris=%s draws=%s stroke_ms=%s rebuild_ms=%s" % [
		label, stats.get("islands"), stats.get("chunks"), stats.get("triangles"),
		stats.get("draw_calls"), stats.get("stroke_ms"), stats.get("rebuild_ms"),
	])
