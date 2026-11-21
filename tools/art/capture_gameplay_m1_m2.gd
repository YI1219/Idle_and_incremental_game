extends SceneTree
## Captures real Godot Forward+ screenshots verifying the Song-scroll frameless UI redesign.

const Director = preload("res://scripts/gameplay/director.gd")
const FishingSys = preload("res://scripts/gameplay/systems/fishing_meditation_system.gd")

var out_dir: String = "/tmp/ui_scroll_captures"

func _initialize() -> void:
	call_deferred("run")

func _set_cam(camera: Camera3D, center: Vector2, height: float, yaw: float, pitch: float) -> void:
	camera._center = center
	camera._center_goal = center
	camera._height = height
	camera.height_goal = height
	camera._yaw = yaw
	camera._yaw_goal = yaw
	camera._pitch = pitch
	camera._pitch_goal = pitch
	camera.advance(0.0)

func _wait_render(frames: int = 16) -> void:
	for i: int in frames:
		RenderingServer.force_draw(false)
		await process_frame
	RenderingServer.force_draw(false)

func _save_shot(filename: String) -> void:
	await _wait_render(18)
	var img: Image = root.get_texture().get_image()
	img.save_png(out_dir.path_join(filename))
	print("saved: ", out_dir.path_join(filename))

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)

	var editor: Node3D = (load("res://scenes/terrain_editor.tscn") as PackedScene).instantiate()
	root.add_child(editor)
	await _wait_render(24)
	editor.set_process(false)
	editor.camera.set_process(false)

	var gp: Director = editor.gameplay

	# Shot 1: Awakened Song-Scroll Colophon (on interaction — frameless Kaiti + Cinnabar Seal, ZERO dark boxes)
	gp.time_system.set_progress(0.29, editor)
	gp.state.dao_insight = 42.0
	for i: int in 14:
		gp.actor.step_actor(0.05, Vector2(0.85, 0.35), gp.surface_at, gp.grass_map, Callable())
	gp.grass_map.flush_now()
	gp.shihai_hud.show_toast("踏露寻幽 · 步生青痕", 2.8)
	gp.shihai_hud._whisper_timer = 1.6
	gp.shihai_hud.tick_ui(0.05, gp.state, gp.time_system, gp.fishing, editor.data.cells.size(), gp.stance, gp.wallpaper_mode)
	_set_cam(editor.camera, Vector2(2.5, -1.5), 18.5, 16.0, 27.0)
	await _save_shot("01_morning_awakened_colophon.png")

	# Shot 2: Resting Breathing De-HUD + Idle Pond Fishing (zero 2D bars, only 3D water ripples!)
	var spot: Dictionary = FishingSys.find_fishing_spot_near(Vector2(9.2, 2.2), gp.surface_at, 6.5, Vector2(10.5, 0.5))
	if not spot.is_empty():
		var st: Vector2 = spot["stand_xz"] as Vector2
		var bob: Vector2 = spot["bobber_xz"] as Vector2
		var ss: Dictionary = gp.surface_at(st)
		gp.actor.position = Vector3(st.x, float(ss.get("height", 1.5)), st.y)
		gp.fishing.start_fishing(gp.actor, st, bob, float(spot["water_y"]))
		gp.fishing.phase = "biting"
		gp.fishing._phase_timer = 0.95
		gp.fishing._phase_duration = 1.65
		gp.fishing.tick(0.05, gp.actor, gp.state, 1.0, 1.0, gp.surface_at)
	# Simulate 4s of calm hands-free idle so HUD breathes down to pure canvas!
	gp.shihai_hud._whisper_timer = 0.0
	gp.shihai_hud._wake_timer = 0.0
	gp.shihai_hud.tick_ui(4.0, gp.state, gp.time_system, gp.fishing, editor.data.cells.size(), gp.stance, gp.wallpaper_mode)
	_set_cam(editor.camera, Vector2(6.8, 1.2), 10.2, 22.0, 28.0)
	await _save_shot("02_fishing_idle_pure_canvas.png")

	# Shot 3: Tab Sculpting Mode — Frameless Bottom 6-Seal Dock (Tiny Glade + Song Seal Box, zero left debug slab!)
	gp.set_stance("sculpt", true)
	editor.tool = "water"
	editor.radius = 2.2
	gp.state.dao_insight = 100.0
	gp.shihai_hud._whisper_timer = 0.0
	gp.shihai_hud.tick_ui(0.0, gp.state, gp.time_system, gp.fishing, editor.data.cells.size(), gp.stance, gp.wallpaper_mode)
	_set_cam(editor.camera, Vector2(0.0, -1.0), 20.5, 16.0, 27.0)
	await _save_shot("03_sculpt_seal_dock_water.png")

	# Shot 4: Sculpting Dock with Xuan-Paper Folded Leaf Open (素笺雅集)
	editor.tool = "raise"
	gp.shihai_hud._scroll_leaf_open = true
	gp.shihai_hud.tick_ui(0.0, gp.state, gp.time_system, gp.fishing, editor.data.cells.size(), gp.stance, gp.wallpaper_mode)
	await _save_shot("04_sculpt_xuan_paper_leaf.png")

	# Shot 5: Starry Night Adaptive Ivory Calligraphy (昼墨夜宣 · 星夜自动切换宣白泥金题识)
	gp.shihai_hud._scroll_leaf_open = false
	gp.set_stance("avatar", true)
	gp.state.dao_insight = 55.0
	gp.time_system.set_progress(0.02, editor)
	gp.shihai_hud.notify_activity(3.5)
	gp.shihai_hud.show_toast("星渚垂纶 · 忘机自得", 2.6)
	gp.shihai_hud._whisper_timer = 1.6
	gp.shihai_hud.tick_ui(0.0, gp.state, gp.time_system, gp.fishing, editor.data.cells.size(), gp.stance, gp.wallpaper_mode)
	_set_cam(editor.camera, Vector2(6.2, -0.8), 15.5, -18.0, 27.0)
	await _save_shot("05_night_adaptive_ivory_colophon.png")

	editor.free()
	quit(0)
