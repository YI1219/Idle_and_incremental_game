extends SceneTree
## Screenshots from the play camera. Not art acceptance.

const Heightfield := preload("res://scripts/world/heightfield.gd")
const HeightfieldMesh := preload("res://scripts/world/heightfield_mesh.gd")
const OUT := "res://art/review/heightfield/2026-10-02"
const ARTIFACTS := "/opt/cursor/artifacts"
const SAFE := Vector3(2.4, 0.0, 1.8)

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
	img.save_png(ARTIFACTS + "/" + String(path).get_file())
	print("wrote ", path)

func run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(ARTIFACTS)
	var scene: Node = load("res://scenes/play.tscn").instantiate()
	root.add_child(scene)
	await frames(40)
	_lock_courtyard()
	var rig: Node3D = get_first_node_in_group("camera_rig")
	var builder: Node3D = get_first_node_in_group("sandbox_builder")
	var island: Node3D = get_first_node_in_group("island_shell")
	var player: Node3D = get_first_node_in_group("player")
	var terrain: Node3D = island.terrain
	if builder:
		builder.set_active(false)
		builder.prune_unsupported_objects()
		builder.rebuild_objects()
	if player:
		player.visible = true
		player.set_physics_process(false)
	terrain.flush_rebuild()
	_restore_pitch(rig)
	_look(rig, player, Vector3(0.4, 0.0, 0.2), 22.0, 1)
	await shot(OUT + "/overview.png")

	# Low side must show the rock-kit underside.
	_set_house_visible(false)
	_restore_pitch(rig)
	rig.near_pitch_deg = 8.0
	rig.pitch_deg = 12.0
	_look(rig, player, Vector3(6.4, 0.0, -1.6), 14.0, 2)
	await shot(OUT + "/low_side.png")

	# seed7-like 3/4 of the whole island from slightly below.
	rig.near_pitch_deg = -16.0
	rig.pitch_deg = -12.0
	_look(rig, player, Vector3(0.2, 0.0, 0.0), 20.0, 3)
	await shot(OUT + "/seed7_three_quarter.png")
	_restore_pitch(rig)

	_look(rig, player, Vector3(3.8, 0.0, 0.4), 10.0, 1)
	await shot(OUT + "/lake.png")
	_set_house_visible(true)

	var playable: Dictionary = terrain.heightfield_stats()
	_time_stroke(terrain)
	playable = terrain.heightfield_stats()
	_print_stats("playable", playable)

	terrain.land_cells.clear()
	for cell in _blob_cells(Vector2i(0, 0), 12, 10, 3):
		terrain.land_cells[cell] = true
	terrain.rebuild()
	terrain.flush_rebuild()
	await frames(8)
	var large: Dictionary = terrain.heightfield_stats()
	_print_stats("4x island", large)

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
	rig.max_distance = 80.0
	rig.far_pitch_deg = 62.0
	_look(rig, player, Vector3(0.0, 0.0, 0.5), 62.0, 1)
	await shot(OUT + "/multi_island.png")
	quit()


func _set_house_visible(shown: bool) -> void:
	var island: Node3D = get_first_node_in_group("island_shell")
	if island == null:
		return
	for child in island.get_parent().get_children():
		if child is DemoCottage:
			child.visible = shown


func _lock_courtyard() -> void:
	var space_state := root.get_node_or_null("SpaceState")
	if space_state:
		space_state.space_id = "outside"
	var space := get_first_node_in_group("space_controller")
	if space:
		space.set_physics_process(false)
		space.set_process(false)


func _blob_cells(center: Vector2i, rx: int, rz: int, seed: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for z in range(center.y - rz, center.y + rz + 1):
		for x in range(center.x - rx, center.x + rx + 1):
			var nx := float(x - center.x) / float(maxi(rx, 1))
			var nz := float(z - center.y) / float(maxi(rz, 1))
			var nse := Heightfield._hash2(float(x) * 0.37 + float(seed), float(z) * 0.29)
			if pow(absf(nx), 2.1) + pow(absf(nz), 2.1) <= 0.88 + (nse.x - 0.5) * 0.26:
				out.append(Vector2i(x, z))
	return out


func _park_player(player: Node3D) -> void:
	if player == null:
		return
	var y := 0.0
	var island: Node3D = get_first_node_in_group("island_shell")
	if island and island.terrain and island.terrain.has_method("sample_height"):
		var h: float = island.terrain.sample_height(SAFE)
		if is_finite(h):
			y = h
	player.global_position = Vector3(SAFE.x, y, SAFE.z)
	player.visible = true


func _look(rig: Node3D, player: Node3D, subject: Vector3, distance: float, yaw_index: int) -> void:
	_park_player(player)
	rig.set_physics_process(true)
	rig._yaw_index = yaw_index
	rig._distance = distance
	var pan := Vector3(subject.x - SAFE.x, 0.0, subject.z - SAFE.z)
	rig._pan_goal = pan
	rig._smooth_pan = pan
	rig._panning = false
	for i in 8:
		rig._apply(true)


func _restore_pitch(rig: Node3D) -> void:
	rig.near_pitch_deg = 38.0
	rig.pitch_deg = 50.0
	rig.far_pitch_deg = 58.0


func _time_stroke(terrain: Node3D) -> void:
	var main: Node3D = terrain.get_node("Islands").get_child(0)
	if main == null or main.field == null:
		return
	var field = main.field
	field.apply_brush("smooth", Vector3(2.4, 0.0, 1.8), 0.9, 0.12, true)
	field.apply_coast_smooth()
	var span := HeightfieldMesh.chunk_range(field)
	var t0 := Time.get_ticks_usec()
	for z in span.y:
		for x in span.x:
			HeightfieldMesh.build_chunk(field, Vector2i(x, z), "top", main.skip_top)
	main.last_stroke_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	main.rebuild_full(true)


func _sculpt_demo(terrain: Node3D) -> void:
	var main: Node3D = terrain.get_node("Islands").get_child(0)
	if main == null or main.field == null:
		return
	var field = main.field
	# Keep the east lake. Shaft sits north of it. A shallow east lip lets one fall
	# leave without emptying the basin.
	for p in [Vector3(3.5, 0.0, 0.4), Vector3(4.2, 0.0, 0.6), Vector3(3.8, 0.0, -0.2)]:
		field.apply_brush("lower", p, 0.85, 0.28, true)
	field.punch_shaft(Vector3(5.4, 0.0, 2.6), 0.95)
	field.apply_brush("lower", Vector3(6.55, 0.0, 0.15), 0.38, 0.12, true)
	field.apply_coast_smooth()
	var span := HeightfieldMesh.chunk_range(field)
	var t0 := Time.get_ticks_usec()
	for z in span.y:
		for x in span.x:
			HeightfieldMesh.build_chunk(field, Vector2i(x, z), "top", main.skip_top)
	main.last_stroke_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	main.rebuild_full(true)
	print("sculpt lakes=", (main.water_info.get("lakes", []) as Array).size(), " falls=", (main.water_info.get("waterfalls", []) as Array).size())


func _print_stats(label: String, stats: Dictionary) -> void:
	print("PERF %s: islands=%s chunks=%s tris=%s draws=%s stroke_ms=%s rebuild_ms=%s rocks=%s rock_tris=%s tufts=%s" % [
		label, stats.get("islands"), stats.get("chunks"), stats.get("triangles"),
		stats.get("draw_calls"), stats.get("stroke_ms"), stats.get("rebuild_ms"),
		stats.get("rock_instances"), stats.get("rock_tris"), stats.get("tufts"),
	])
