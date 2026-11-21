extends SceneTree
## Headless verification for Stage 2 M1+M2 gameplay systems.

const Director = preload("res://scripts/gameplay/director.gd")

var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("ok: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed := load("res://scenes/terrain_editor.tscn") as PackedScene
	check(packed != null, "terrain_editor.tscn loads")
	var editor: Node3D = packed.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	editor.set_process(false)
	editor.camera.set_process(false)

	var gp: Director = editor.gameplay
	check(gp != null, "GameplayDirector initialized on TerrainEditor")
	check(gp.stance == "avatar", "default startup stance is avatar")
	check(not editor.hud.panel.visible, "sculpt workshop panel hidden in default avatar stance")
	check(editor.hud.is_over_panel(Vector2(30, 30)), "top jade bar covers (30,30) UI guard")

	var start_surf: Dictionary = gp.surface_at(Vector2(gp.actor.position.x, gp.actor.position.z))
	check(not start_surf.is_empty() and int(start_surf.get("water", -1)) < 0, "cultivator spawns on dry land")
	var cush_surf: Dictionary = gp.surface_at(gp.actor.cushion_xz)
	check(not cush_surf.is_empty() and int(cush_surf.get("water", -1)) < 0 and gp.actor.cushion_node.visible, "meditation cushion placed on dry terrace")

	# 1. Direct locomotion, Wind Dash & Grass Compression
	var p0 := Vector2(gp.actor.position.x, gp.actor.position.z)
	for i: int in 18:
		gp.actor.step_actor(1.0 / 30.0, Vector2(-1.0, 0.0), gp.surface_at, gp.grass_map, Callable())
	var p1 := Vector2(gp.actor.position.x, gp.actor.position.z)
	check(p1.distance_to(p0) > 0.4, "manual movement vector moves cultivator across island")
	check(gp.grass_map.sample_at(p1) > 0.08, "walking stamps grass compression trail")

	var dashed: bool = gp.actor.trigger_dash(Vector2(0.0, -1.0))
	check(dashed and gp.actor.activity == "dash", "wind dash triggers cleanly")
	for i: int in 10:
		gp.actor.step_actor(0.03, Vector2.ZERO, gp.surface_at, gp.grass_map, Callable())
	check(gp.actor.activity == "idle", "wind dash returns to idle after burst")

	# 2. BG3-style point-and-click walk & manual interrupt
	var walk_goal: Vector2 = gp.find_nearest_dry_spot(p0 + Vector2(1.5, -1.0), 6.0)
	check(gp.command_avatar_at_world_xz(walk_goal), "clicking dry ground issues walk command")
	for i: int in 45:
		gp.actor.step_actor(1.0 / 30.0, Vector2.ZERO, gp.surface_at, gp.grass_map, Callable())
	check(Vector2(gp.actor.position.x, gp.actor.position.z).distance_to(walk_goal) < 0.85, "cultivator reaches clicked ground target")

	# 3. Time/Solar cycle & Song-dynasty matte invariants + Wallpaper mode
	for step_i: int in 12:
		gp.step_shichen()
		var grass_mat := editor.renderer.materials["grass"] as ShaderMaterial
		var relief: float = float(grass_mat.get_shader_parameter("cover_relief"))
		var fine: float = float(grass_mat.get_shader_parameter("ground_fine_strength"))
		var sun := editor.get_node("SunLight") as DirectionalLight3D
		if step_i in [0, 3, 6, 9]:
			check(is_equal_approx(relief, 0.0) and is_equal_approx(fine, 0.05), "matte velvet lawn parameters preserved at step %d" % step_i)
			check(sun.rotation_degrees.y >= 28.0 and sun.rotation_degrees.y <= 42.0, "sun azimuth stays anchored without spinning at step %d" % step_i)
	check(gp.time_system.day_count >= 2, "full 12-shichen cycle advances day and solar term")

	gp.toggle_wallpaper_mode()
	check(gp.wallpaper_mode and is_zero_approx(gp.shihai_hud._wake_alpha) and gp.actor.force_autonomous, "F11 wallpaper mode hides HUD and enables autonomous life")
	gp.toggle_wallpaper_mode()
	check(not gp.wallpaper_mode and gp.shihai_hud._wake_alpha > 0.5, "exiting wallpaper mode wakes Song-scroll colophon")

	# Dynamic breathing de-HUD: fades to 0 when resting without actions, wakes on activity
	for i: int in 45:
		gp.shihai_hud.tick_ui(0.12, gp.state, gp.time_system, gp.fishing, editor.data.cells.size(), gp.stance, gp.wallpaper_mode)
	check(is_zero_approx(gp.shihai_hud._wake_alpha), "dynamic breathing de-HUD fades cleanly to pure canvas when idle")
	gp.shihai_hud.notify_activity()
	gp.shihai_hud.tick_ui(0.2, gp.state, gp.time_system, gp.fishing, editor.data.cells.size(), gp.stance, gp.wallpaper_mode)
	check(gp.shihai_hud._wake_alpha > 0.5, "player interaction wakes frameless colophon")

	# 4. Pond-bank Fishing: click-to-accelerate + manual boost + hands-free 太公忘机钓
	var pond_click := Vector2(7.0, 3.0)
	check(gp.command_avatar_at_world_xz(pond_click), "clicking pond water commands shoreline fishing")
	for i: int in 180:
		gp.tick(1.0 / 30.0)
		if gp.fishing.is_fishing():
			break
	check(gp.fishing.is_fishing() and gp.actor.activity == "fishing", "cultivator walks to bank and casts bamboo rod")

	# Advance into waiting phase and verify manual click accelerates fish gathering without failing
	for i: int in 20:
		gp.tick(0.03)
	check(gp.fishing.phase == "waiting" and gp.fishing.try_manual_reel(gp.state, 1.0) == "accelerated", "manual tap while waiting gently accelerates fish gathering")

	# Advance to biting sweet spot and perform manual boost reel
	var guard: int = 0
	while not gp.fishing.is_in_perfect_window() and guard < 400:
		gp.tick(0.03)
		guard += 1
	check(gp.fishing.is_in_perfect_window(), "fishing enters golden water-ripple window")
	var insight_before: float = gp.state.dao_insight
	var reel_quality: String = gp.fishing.try_manual_reel(gp.state, gp.time_system.fishing_bonus())
	check(reel_quality == "perfect" and gp.state.dao_insight > insight_before + 25.0 and gp.state.perfect_catches == 1, "manual reel in ripple peak awards Perfect Catch & Dao Insight")

	# Let next cast run hands-free to verify continuous 太公忘机钓 auto-catch
	var catches_before_auto: int = gp.state.total_fish_caught
	for i: int in 360:
		gp.tick(0.03)
		if gp.state.total_fish_caught > catches_before_auto:
			break
	check(gp.state.total_fish_caught > catches_before_auto, "idle fishing automatically completes 太公忘机钓 catch without failing")
	gp.fishing.stop_all(gp.actor)

	# 5. Meditation & Realm Breakthrough
	gp.toggle_meditation()
	check(gp.fishing.meditating and gp.actor.activity == "meditate", "meditation posture activated")
	for i: int in 300:
		gp.tick(0.1)
	check(gp.state.can_breakthrough(), "meditation accumulates enough Dao Insight for Realm 1 breakthrough")
	var old_quota: int = gp.state.max_land_cells()
	check(gp.attempt_breakthrough() and gp.state.realm_index == 1 and gp.state.max_land_cells() == old_quota + 90, "breakthrough advances to 炼气圆满 and expands land quota by +90")
	gp.fishing.stop_all(gp.actor)

	# 6. Progressive Land Quota Cap & 100% Contraction Refund
	gp.set_stance("sculpt", true)
	check(gp.stance == "sculpt" and gp.shihai_hud.is_sculpt_dock_open() and not editor.hud.panel.visible, "Tab stance switch opens frameless bottom seal dock and keeps legacy debug slab hidden")
	gp.state.spirit_qi = 300.0
	# Artificially tighten baseline so we hit exact quota cap within one brush stroke
	gp.state.baseline_cells = editor.data.cells.size() - gp.state.INITIAL_FREE_MARGIN - 90 + 5
	var allowed_max: int = gp.state.max_land_cells()
	var qi_before_expand: float = gp.state.spirit_qi
	editor.data.begin_stroke()
	check(gp.prepare_brush_step("expand"), "expand permitted when 5 quota slots remain")
	var c_before: int = editor.data.cells.size()
	editor.data.apply_brush(Vector2(21.5, 0.5), 4.5, "expand", false, 1.5, 3)
	gp.after_brush_step(c_before, 0, "expand")
	editor.data.end_stroke()
	check(editor.data.cells.size() == allowed_max, "expand brush stops cleanly at exact divine sense land quota (%d == %d)" % [editor.data.cells.size(), allowed_max])
	check(gp.state.spirit_qi < qi_before_expand, "expanding island consumes Spirit Qi")
	check(not gp.prepare_brush_step("expand"), "further expansion blocked when quota is full")

	# Contract land and verify 100% quota freedom + Qi refund
	var qi_before_contract: float = gp.state.spirit_qi
	editor.data.begin_stroke()
	var c_full: int = editor.data.cells.size()
	editor.data.apply_brush(Vector2(21.5, 0.5), 4.6, "contract", false, 1.5, 3)
	gp.after_brush_step(c_full, 0, "contract")
	editor.data.end_stroke()
	check(editor.data.cells.size() < allowed_max and gp.prepare_brush_step("expand"), "contracting land immediately frees 100% of removed quota for reshaping")
	check(gp.state.spirit_qi > qi_before_contract, "contracting land refunds Spirit Qi")

	# 7. Unified Save / Load round-trip
	var save_file: String = "user://terrain_editor/m1_m2_test_save.json"
	gp.time_system.set_progress(0.76, editor)
	var saved_realm: int = gp.state.realm_index
	var saved_fish: int = gp.state.total_fish_caught
	check(editor.save_layout(save_file) == OK, "unified layout + gameplay save succeeds")
	gp.state.realm_index = 0
	gp.state.total_fish_caught = 0
	gp.time_system.set_progress(0.10, editor)
	check(editor.load_layout(save_file) == OK, "unified layout + gameplay load succeeds")
	check(gp.state.realm_index == saved_realm and gp.state.total_fish_caught == saved_fish and is_equal_approx(gp.time_system.day_progress, 0.76), "gameplay realm, catches and shichen restored from save")
	DirAccess.remove_absolute(save_file)

	editor.free()
	print("GAMEPLAY M1+M2 TESTS: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
