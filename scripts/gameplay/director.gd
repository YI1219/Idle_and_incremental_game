class_name GameplayDirector
extends Node3D
## Stage 2 Gameplay Coordinator attached to TerrainEditor.
## Orchestrates Avatar <-> Divine Sense stances, Wallpaper mode, Time/Solar cycle,
## Cultivator locomotion & autonomous AI, Fishing/Meditation, and Land Quota progression.

const State = preload("res://scripts/gameplay/data/realm_progression.gd")
const TimeSys = preload("res://scripts/gameplay/systems/time_solar_system.gd")
const GrassMap = preload("res://scripts/gameplay/systems/grass_compression_map.gd")
const Actor = preload("res://scripts/gameplay/entities/cultivator_actor.gd")
const FishingSys = preload("res://scripts/gameplay/systems/fishing_meditation_system.gd")
const HudUI = preload("res://scripts/gameplay/ui/shihai_hud.gd")
const STICK_DEADZONE: float = 0.18

var editor: Node3D
var state := State.new()
var time_system := TimeSys.new()
var grass_map := GrassMap.new()
var actor: Actor
var fishing: FishingSys
var shihai_hud: HudUI

var stance: String = "avatar" # "avatar" | "sculpt"
var wallpaper_mode: bool = false
var _initialized: bool = false

func setup(editor_node: Node3D) -> void:
	editor = editor_node
	name = "GameplayDirector"

	state.sync_baseline(editor.data.cells.size())
	editor.data.cell_quota = state.max_land_cells()
	grass_map.bind_to_renderer(editor.renderer)

	# Stage-one lookdev has no humanoid or avatar props in the live scene.
	# Time, camera and F11 remain available without creating an actor.

	fishing = FishingSys.new()
	add_child(fishing)
	fishing.status_hint.connect(_on_status_hint)

	state.realm_breakthrough.connect(_on_realm_breakthrough)
	state.catch_logged.connect(func(_item: String, _q: String) -> void:
		if shihai_hud != null and shihai_hud._log_panel.visible:
			shihai_hud.refresh_log()
	)

	shihai_hud = HudUI.new()
	shihai_hud.director = self
	if editor.hud != null:
		editor.hud.add_child(shihai_hud)
		if editor.hud.has_method("bind_shihai_hud"):
			editor.hud.call("bind_shihai_hud", shihai_hud)

	reanchor_entities_to_terrain()
	set_stance("sculpt", true)
	time_system.apply_to_scene(editor)
	_initialized = true
	shihai_hud.tick_ui(0.0, state, time_system, fishing, editor.data.cells.size(), stance, wallpaper_mode)

func surface_at(xz: Vector2) -> Dictionary:
	if editor == null:
		return {}
	if editor.renderer != null and editor.renderer.contours != null:
		var s: Dictionary = editor.renderer.contours.surface_at(xz)
		if not s.is_empty():
			return s
	var c := Vector2i(xz.floor())
	if editor.data != null and editor.data.cells.has(c):
		var rec: Dictionary = editor.data.cells[c]
		var w: int = int(rec.get("water", -1))
		var h: float = float(w) * 0.5 if w >= 0 else float(rec.get("height", 1.5))
		return {"height": h, "water": w}
	return {}

func find_nearest_dry_spot(preferred: Vector2, max_radius: float = 14.0) -> Vector2:
	var s0: Dictionary = surface_at(preferred)
	if _spot_has_dry_margin(preferred, s0):
		return preferred
	var step: float = 0.75
	var rings: int = ceili(max_radius / step)
	for r: int in range(1, rings + 1):
		var rad: float = float(r) * step
		for i: int in 20:
			var ang: float = TAU * float(i) / 20.0
			var cand: Vector2 = preferred + Vector2(cos(ang), sin(ang)) * rad
			if _spot_has_dry_margin(cand, surface_at(cand)):
				return cand
	return preferred

func _spot_has_dry_margin(xz: Vector2, center_surf: Dictionary) -> bool:
	if center_surf.is_empty() or int(center_surf.get("water", -1)) >= 0:
		return false
	for off: Vector2 in [Vector2(0.45, 0.0), Vector2(-0.45, 0.0), Vector2(0.0, 0.45), Vector2(0.0, -0.45)]:
		var ns: Dictionary = surface_at(xz + off)
		if ns.is_empty() or int(ns.get("water", -1)) >= 0:
			return false
	return true

func reanchor_entities_to_terrain() -> void:
	if actor == null:
		return
	var cush_xz: Vector2 = find_nearest_dry_spot(Vector2(8.9, -3.1), 16.0)
	actor.cushion_xz = cush_xz
	if actor.cushion_node != null:
		var cs: Dictionary = surface_at(cush_xz)
		actor.cushion_node.visible = not cs.is_empty() and int(cs.get("water", -1)) < 0
		if actor.cushion_node.visible:
			actor.cushion_node.position = Vector3(cush_xz.x, float(cs.get("height", 1.5)), cush_xz.y)

	var spawn_xz: Vector2 = find_nearest_dry_spot(Vector2(1.45, 6.20), 16.0)
	var asurf: Dictionary = surface_at(spawn_xz)
	var ay: float = float(asurf.get("height", 1.5)) if not asurf.is_empty() else 1.5
	actor.position = Vector3(spawn_xz.x, ay, spawn_xz.y)
	actor.cancel_navigation()
	actor.set_activity("idle", Vector2(3.6, 2.2))
	if fishing != null:
		fishing.stop_all(actor)

func on_preset_changed() -> void:
	state.sync_baseline(editor.data.cells.size())
	editor.data.cell_quota = state.max_land_cells()
	reanchor_entities_to_terrain()
	time_system.apply_to_scene(editor)

func on_style_preset_selected(index: int) -> void:
	var anchors: Array[float] = [0.29, 0.52, 0.76, 0.02]
	var mapped: float = anchors[clampi(index, 0, anchors.size() - 1)]
	time_system.set_progress(mapped, editor)

func on_brush_tool_selected(_tool_name: String) -> void:
	if not _initialized:
		return
	if stance != "sculpt":
		set_stance("sculpt", true)

func set_stance(next_stance: String, silent: bool = false) -> void:
	stance = "sculpt" if next_stance == "sculpt" else "avatar"
	if editor != null:
		editor.cancel_input()
		if editor.camera != null:
			editor.camera.keyboard_pan_enabled = (stance == "sculpt")
		if stance == "avatar":
			editor.brush.visible = false
		if editor.hud != null and editor.hud.has_method("set_sculpt_panel_visible"):
			editor.hud.call("set_sculpt_panel_visible", stance == "sculpt" and not wallpaper_mode)
	if actor != null:
		actor.force_autonomous = (stance == "sculpt" or wallpaper_mode)
	if shihai_hud != null:
		shihai_hud._stance = stance
		if stance != "sculpt":
			shihai_hud._scroll_leaf_open = false
		shihai_hud.notify_activity(3.2)
		if not silent:
			if stance == "sculpt":
				shihai_hud.show_toast("神识造景 · 点选印匣塑造山水", 2.6)
			else:
				shihai_hud.show_toast("化身漫游 · 踏露寻幽", 2.2)
		var cell_n: int = editor.data.cells.size() if (editor != null and editor.data != null) else 0
		shihai_hud.tick_ui(0.0, state, time_system, fishing, cell_n, stance, wallpaper_mode)

func toggle_stance() -> void:
	if wallpaper_mode:
		set_wallpaper_mode(false)
	set_stance("sculpt" if stance == "avatar" else "avatar")

func set_wallpaper_mode(enabled: bool) -> void:
	wallpaper_mode = enabled
	if editor != null:
		editor.cancel_input()
		editor.brush.visible = false
		if editor.camera != null:
			editor.camera.keyboard_pan_enabled = enabled or (stance == "sculpt")
		if editor.hud != null and editor.hud.has_method("set_sculpt_panel_visible"):
			editor.hud.call("set_sculpt_panel_visible", not enabled and stance == "sculpt")
	if actor != null:
		actor.force_autonomous = enabled or (stance == "sculpt")
	if shihai_hud != null:
		shihai_hud.set_wallpaper_visuals(enabled)

func toggle_wallpaper_mode() -> void:
	set_wallpaper_mode(not wallpaper_mode)

func toggle_time_pause() -> void:
	time_system.paused = not time_system.paused
	if shihai_hud != null:
		shihai_hud.show_toast("已定格当前画境时辰" if time_system.paused else "已恢复昼夜节气自然流转", 2.5)

func step_shichen() -> void:
	time_system.step_shichen(editor)
	if shihai_hud != null:
		shihai_hud.show_toast("时辰流转至：" + time_system.summary_label(), 2.5)

func toggle_meditation() -> void:
	if actor == null or fishing == null:
		return
	if fishing.meditating:
		fishing.stop_all(actor)
		shihai_hud.show_toast("吐纳收功，神清气爽", 2.4)
	else:
		actor.cancel_navigation()
		fishing.start_meditation(actor)

func trigger_wind_dash() -> void:
	if actor == null:
		return
	if fishing != null and (fishing.is_fishing() or fishing.meditating):
		fishing.stop_all(null)
	actor.trigger_dash(_camera_relative_move_input())

func trigger_contextual_interact() -> void:
	if actor == null or fishing == null:
		return
	if shihai_hud != null:
		shihai_hud.notify_activity()
	if fishing.is_fishing():
		fishing.try_manual_reel(state, time_system.fishing_bonus())
		return
	var actor_xz := Vector2(actor.position.x, actor.position.z)
	if actor_xz.distance_to(actor.cushion_xz) <= 1.65:
		toggle_meditation()
		return
	var spot: Dictionary = FishingSys.find_fishing_spot_near(actor_xz, surface_at, 9.0, actor_xz)
	if not spot.is_empty():
		var stand: Vector2 = spot["stand_xz"] as Vector2
		var bob: Vector2 = spot["bobber_xz"] as Vector2
		if actor_xz.distance_to(stand) <= 0.85:
			fishing.start_fishing(actor, stand, bob, float(spot["water_y"]))
		else:
			actor.command_walk_to(stand, "fish", bob, 0.55, true)
			shihai_hud.show_toast("缓步临水垂纶……", 2.0)
	else:
		toggle_meditation()

func attempt_breakthrough() -> bool:
	if shihai_hud != null:
		shihai_hud.notify_activity()
	if not state.can_breakthrough():
		if shihai_hud != null:
			shihai_hud.show_toast("道韵未满（%.0f / %.0f）· 静钓或入定可凝心境" % [state.dao_insight, state.current_insight_target()], 2.6)
		return false
	var ok: bool = state.try_breakthrough()
	if ok and editor != null:
		editor.data.cell_quota = state.max_land_cells()
	return ok

func _on_realm_breakthrough(_idx: int, title: String) -> void:
	if actor != null and fishing != null:
		fishing.trigger_breakthrough_wave(actor.global_position)
	if shihai_hud != null:
		shihai_hud.show_toast("破境扩识 · 晋入「%s」" % title, 3.4)

func _on_status_hint(message: String) -> void:
	if shihai_hud != null:
		shihai_hud.show_toast(message, 2.6)

func _on_actor_manual_interrupted() -> void:
	if fishing != null:
		fishing.stop_all(null)

func _on_actor_arrived_for_action(action: String, stand_xz: Vector2, aux_xz: Vector2) -> void:
	if fishing == null or actor == null:
		return
	if action == "fish":
		var ws: Dictionary = surface_at(aux_xz)
		if not ws.is_empty() and int(ws.get("water", -1)) >= 0:
			var wy: float = float(int(ws.get("water", 3))) * 0.5
			fishing.start_fishing(actor, stand_xz, aux_xz, wy)
		else:
			actor.set_activity("idle")
	elif action == "meditate":
		actor.set_activity("meditate", aux_xz)
		fishing.start_meditation(actor)

# --- Terrain Brush Quota & Spirit Qi Gate ---

func prepare_brush_step(tool_name: String) -> bool:
	if editor == null:
		return true
	if shihai_hud != null:
		shihai_hud.notify_activity(3.2)
	editor.data.cell_quota = state.max_land_cells()
	if tool_name == "expand":
		var cur_cells: int = editor.data.cells.size()
		if cur_cells >= state.max_land_cells():
			if shihai_hud != null:
				shihai_hud.show_toast("神识疆域已满（%d / %d）· 可敛缩旧岸或破境扩识" % [cur_cells, state.max_land_cells()], 2.6)
			return false
		var cap_with_qi: int = state.affordable_expand_cap(cur_cells)
		if cap_with_qi <= cur_cells:
			if shihai_hud != null:
				shihai_hud.show_toast("灵气暂竭 · 少顷自复", 2.2)
			return false
		editor.data.cell_quota = cap_with_qi
	elif tool_name == "water":
		if state.spirit_qi < State.WATER_QI_COST:
			if shihai_hud != null:
				shihai_hud.show_toast("灵气暂竭 · 少顷自复", 2.2)
			return false
	return true

func count_wet_cells() -> int:
	if editor == null or editor.data == null:
		return 0
	var count: int = 0
	for rec: Dictionary in editor.data.cells.values():
		if int(rec.get("water", -1)) >= 0:
			count += 1
	return count

func after_brush_step(before_cells: int, before_wet: int, tool_name: String) -> void:
	if editor == null:
		return
	var after_cells: int = editor.data.cells.size()
	var after_wet: int = count_wet_cells() if tool_name == "water" else before_wet
	state.reconcile_terrain_delta(before_cells, after_cells, before_wet, after_wet, tool_name)
	editor.data.cell_quota = state.max_land_cells()
	if shihai_hud != null:
		shihai_hud.notify_activity(3.2)
	if actor != null and actor.cushion_node != null:
		var cs: Dictionary = surface_at(actor.cushion_xz)
		actor.cushion_node.visible = not cs.is_empty() and int(cs.get("water", -1)) < 0
		if actor.cushion_node.visible:
			actor.cushion_node.position = Vector3(actor.cushion_xz.x, float(cs.get("height", 3.5)), actor.cushion_xz.y)

# --- Input & Frame Tick ---

func handle_unhandled_input(event: InputEvent) -> bool:
	if _is_wallpaper_key(event):
		toggle_wallpaper_mode()
		return true
	if wallpaper_mode and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_wallpaper_mode(false)
		return true
	if _is_tab_or_joy_y(event):
		toggle_stance()
		return true
	if _is_key_or_joy(event, KEY_B, JOY_BUTTON_START):
		attempt_breakthrough()
		return true
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		if shihai_hud != null:
			shihai_hud.toggle_log_leaf()
			return true

	if stance != "avatar" or wallpaper_mode:
		return false

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if fishing != null and (fishing.is_fishing() or fishing.meditating):
			fishing.stop_all(actor)
			if shihai_hud != null:
				shihai_hud.show_toast("收竿敛息", 1.6)
			return true

	if _is_key_or_joy(event, KEY_SPACE, JOY_BUTTON_B):
		trigger_wind_dash()
		return true
	if _is_key_or_joy(event, KEY_F, JOY_BUTTON_A):
		trigger_contextual_interact()
		return true
	if _is_key_or_joy(event, KEY_M, JOY_BUTTON_X):
		toggle_meditation()
		return true

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not event.alt_pressed:
		var mb := event as InputEventMouseButton
		if editor.hud != null and editor.hud.is_over_panel(mb.position):
			return false
		return handle_avatar_world_click(mb.position)
	return false

func handle_avatar_world_click(screen_pos: Vector2) -> bool:
	if shihai_hud != null:
		shihai_hud.notify_activity()
	if fishing != null and fishing.is_biting():
		fishing.try_manual_reel(state, time_system.fishing_bonus())
		return true
	if editor == null or editor.camera == null or editor.renderer == null:
		return false
	var origin: Vector3 = editor.camera.project_ray_origin(screen_pos)
	var dir: Vector3 = editor.camera.project_ray_normal(screen_pos)
	var hit: Dictionary = editor.renderer.pick(origin, dir)
	var click_xz := Vector2.INF
	if not hit.is_empty():
		var hp: Vector3 = hit["position"] as Vector3
		click_xz = Vector2(hp.x, hp.z)
	elif absf(dir.y) > 0.001:
		var t: float = (1.5 - origin.y) / dir.y
		if t > 0.0:
			var p3: Vector3 = origin + dir * t
			click_xz = Vector2(p3.x, p3.z)
	if not click_xz.is_finite():
		return false
	return command_avatar_at_world_xz(click_xz)

func command_avatar_at_world_xz(click_xz: Vector2) -> bool:
	if actor == null:
		return false
	if shihai_hud != null:
		shihai_hud.notify_activity()
	# If already fishing and player clicks the same pond / bobber area -> accelerate or boost catch!
	if fishing != null and fishing.is_fishing() and click_xz.distance_to(fishing.bobber_xz) <= 4.0:
		fishing.try_manual_reel(state, time_system.fishing_bonus())
		return true

	# 1. Clicked near rush meditation cushion?
	if click_xz.distance_to(actor.cushion_xz) <= 1.25:
		var actor_xz := Vector2(actor.position.x, actor.position.z)
		if actor_xz.distance_to(actor.cushion_xz) <= 0.65:
			fishing.start_meditation(actor)
		else:
			actor.command_walk_to(actor.cushion_xz, "meditate", actor.cushion_xz + Vector2(0.0, 2.0), 0.50, true)
			if shihai_hud != null:
				shihai_hud.show_toast("行至蒲团……", 1.8)
		return true

	# 2. Clicked water or immediate shoreline? Walk over & cast fishing rod!
	var clicked_surf: Dictionary = surface_at(click_xz)
	var near_water: bool = not clicked_surf.is_empty() and int(clicked_surf.get("water", -1)) >= 0
	if not near_water:
		for off: Vector2 in [Vector2(0.9, 0.0), Vector2(-0.9, 0.0), Vector2(0.0, 0.9), Vector2(0.0, -0.9)]:
			var ns: Dictionary = surface_at(click_xz + off)
			if not ns.is_empty() and int(ns.get("water", -1)) >= 0:
				near_water = true
				break
	if near_water:
		var actor_xz := Vector2(actor.position.x, actor.position.z)
		var spot: Dictionary = FishingSys.find_fishing_spot_near(click_xz, surface_at, 6.5, actor_xz)
		if not spot.is_empty():
			var stand: Vector2 = spot["stand_xz"] as Vector2
			var bob: Vector2 = spot["bobber_xz"] as Vector2
			if actor_xz.distance_to(stand) <= 0.75:
				fishing.start_fishing(actor, stand, bob, float(spot["water_y"]))
			else:
				actor.command_walk_to(stand, "fish", bob, 0.55, true)
				if shihai_hud != null:
					shihai_hud.show_toast("行至水畔垂纶……", 1.8)
			return true

	# 3. Clicked dry ground -> BG3-style point-and-click walk!
	if not clicked_surf.is_empty() and int(clicked_surf.get("water", -1)) < 0:
		actor.command_walk_to(click_xz, "", Vector2.ZERO, 0.38, true)
		return true
	return false

func tick(delta: float) -> void:
	if not _initialized or editor == null:
		return
	time_system.tick(delta, editor)
	state.tick_passive(delta, 1.0)

	# Gamepad camera orbit support in both stances
	var orbit_joy: float = _joypad_orbit_axis()
	if absf(orbit_joy) > 0.01 and editor.camera != null:
		editor.camera.orbit_pixels(Vector2(orbit_joy * delta * 210.0, 0.0))

	var manual_world_move := Vector2.ZERO
	if stance == "avatar" and not wallpaper_mode:
		var focus: Control = get_viewport().gui_get_focus_owner()
		if not focus is LineEdit and not focus is TextEdit:
			manual_world_move = _camera_relative_move_input()
			if manual_world_move.length_squared() > 0.01 and shihai_hud != null:
				shihai_hud.notify_activity(2.2)

	if actor != null:
		var ai_finder := func(near_xz: Vector2) -> Dictionary:
			return FishingSys.find_fishing_spot_near(near_xz, surface_at, 16.0)
		actor.step_actor(delta, manual_world_move, surface_at, grass_map, ai_finder)
		if stance == "avatar" and not wallpaper_mode and actor.activity in ["walk", "dash"] and editor.camera != null:
			editor.camera.recenter(Vector2(actor.position.x, actor.position.z))

	if fishing != null:
		fishing.tick(delta, actor, state, time_system.meditation_bonus(), time_system.fishing_bonus(), surface_at)

	grass_map.tick(delta)

	if shihai_hud != null:
		shihai_hud.tick_ui(delta, state, time_system, fishing, editor.data.cells.size(), stance, wallpaper_mode)

func _camera_relative_move_input() -> Vector2:
	var raw := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		raw.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		raw.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		raw.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		raw.x += 1.0
	var pads: Array[int] = Input.get_connected_joypads()
	if not pads.is_empty():
		var stick := Vector2(
			Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_X),
			Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_Y)
		)
		if stick.length() > STICK_DEADZONE:
			raw += stick
	raw = raw.limit_length(1.0)
	if raw.length_squared() < 0.001 or editor == null or editor.camera == null:
		return raw
	var yaw_rad: float = deg_to_rad(float(editor.camera._yaw))
	var right := Vector2(cos(yaw_rad), -sin(yaw_rad))
	var back := Vector2(sin(yaw_rad), cos(yaw_rad))
	return (right * raw.x + back * raw.y).limit_length(1.0)

static func _joypad_orbit_axis() -> float:
	var pads: Array[int] = Input.get_connected_joypads()
	if pads.is_empty():
		return 0.0
	var pad: int = pads[0]
	var ax: float = Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X)
	if absf(ax) < STICK_DEADZONE:
		ax = 0.0
	if Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_SHOULDER):
		ax -= 0.85
	if Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER):
		ax += 0.85
	return clampf(ax, -1.0, 1.0)

static func _is_key_or_joy(event: InputEvent, key: Key, joy_btn: JoyButton) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == key or event.physical_keycode == key
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == joy_btn
	return false

static func _is_tab_or_joy_y(event: InputEvent) -> bool:
	return _is_key_or_joy(event, KEY_TAB, JOY_BUTTON_Y)

static func _is_wallpaper_key(event: InputEvent) -> bool:
	return _is_key_or_joy(event, KEY_F11, JOY_BUTTON_BACK)

func serialize() -> Dictionary:
	return {
		"state": state.serialize(),
		"time": time_system.serialize(),
		"actor_xz": [snappedf(actor.position.x, 0.01), snappedf(actor.position.z, 0.01)] if actor != null else [3.6, -2.2],
	}

func deserialize(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var st_dict: Variant = payload.get("state", {})
	if st_dict is Dictionary:
		state.deserialize(st_dict as Dictionary)
	editor.data.cell_quota = state.max_land_cells()
	var tm_dict: Variant = payload.get("time", {})
	if tm_dict is Dictionary:
		time_system.deserialize(tm_dict as Dictionary, editor)
	reanchor_entities_to_terrain()
	var axz: Variant = payload.get("actor_xz", [])
	if axz is Array and (axz as Array).size() == 2 and actor != null:
		var cand := Vector2(float((axz as Array)[0]), float((axz as Array)[1]))
		var s: Dictionary = surface_at(cand)
		if not s.is_empty() and int(s.get("water", -1)) < 0:
			actor.position = Vector3(cand.x, float(s.get("height", 1.5)), cand.y)
