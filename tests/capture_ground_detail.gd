extends SceneTree
## Three cameras shared with tests/capture_heightfield.gd, plus a placed-device close-up.
## SHOT_DIR selects the output folder. Visual evidence only.

const OUT_FALLBACK := "res://art/review/heightfield/2026-10-02/tuft_shore_contact/before"
const ARTIFACTS := "/opt/cursor/artifacts"
const SAFE := Vector3(2.4, 0.0, 1.8)

func _initialize() -> void:
	call_deferred("run")


func frames(n: int) -> void:
	for _i in n:
		await process_frame


func shot(dir_path: String, name: String) -> void:
	await frames(10)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := dir_path + "/" + name
	img.save_png(path)
	var art := ARTIFACTS + "/" + dir_path.get_file() + "_" + name
	img.save_png(art)
	print("wrote ", path)


func run() -> void:
	root.size = Vector2i(1280, 720)
	var out := OS.get_environment("SHOT_DIR")
	if out.is_empty():
		out = OUT_FALLBACK
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.make_dir_recursive_absolute(ARTIFACTS)
	var scene: Node = load("res://scenes/play.tscn").instantiate()
	root.add_child(scene)
	await frames(30)
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
	if terrain.has_method("flush_rebuild"):
		terrain.flush_rebuild()
	_restore_pitch(rig)
	# overview — same subject, distance, and yaw as capture_heightfield.gd
	_look(rig, player, Vector3(0.4, 0.0, 0.2), 22.0, 1)
	await shot(out, "overview.png")
	# lake close-up — same camera as capture_heightfield.gd lake.png
	_look(rig, player, Vector3(3.8, 0.0, 0.4), 11.0, 1)
	await shot(out, "lake.png")
	# placed device: potion bench crate at cell (1, 1), low enough to see the base
	rig.near_pitch_deg = 28.0
	rig.pitch_deg = 34.0
	_look(rig, player, Vector3(1.15, 0.0, 1.15), 4.6, 2)
	await shot(out, "device.png")
	_print_stats(terrain)
	quit()


func _lock_courtyard() -> void:
	var space_state := root.get_node_or_null("SpaceState")
	if space_state:
		space_state.space_id = "outside"
	var space := get_first_node_in_group("space_controller")
	if space:
		space.set_physics_process(false)
		space.set_process(false)


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
	for _i in 8:
		rig._apply(true)


func _restore_pitch(rig: Node3D) -> void:
	rig.near_pitch_deg = 38.0
	rig.pitch_deg = 50.0
	rig.far_pitch_deg = 58.0


func _print_stats(terrain: Node3D) -> void:
	if terrain == null or not terrain.has_method("heightfield_stats"):
		return
	var stats: Dictionary = terrain.heightfield_stats()
	print("PERF detail: islands=%s chunks=%s tris=%s draws=%s" % [
		stats.get("islands"), stats.get("chunks"), stats.get("triangles"), stats.get("draw_calls"),
	])
	var islands := terrain.get_node_or_null("Islands")
	if islands == null:
		return
	for child in islands.get_children():
		if child.has_method("stats"):
			var row: Dictionary = child.stats()
			print("PERF island grass_tris=%s grass_tufts=%s grass_draws=%s shore=%s" % [
				row.get("grass_tris", 0), row.get("grass_tufts", 0), row.get("grass_draws", 0), row.get("shore", 0),
			])
