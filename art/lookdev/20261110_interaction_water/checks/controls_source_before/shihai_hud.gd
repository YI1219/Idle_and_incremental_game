class_name ShihaiHUD
extends Control
## Song-Dynasty Scroll Colophon & Tiny-Glade-Style Frameless Seal UI (宋画题跋 · 无框留白风).
## Zero dark plastic boxes: uses classical Kaiti/Songti calligraphy, mineral cinnabar seals,
## adaptive day-ink / night-ivory palette, dynamic breathing de-HUD, and a bottom 6-seal sculpting dock.

const State = preload("res://scripts/gameplay/data/realm_progression.gd")
const TimeSys = preload("res://scripts/gameplay/systems/time_solar_system.gd")
const FishingSys = preload("res://scripts/gameplay/systems/fishing_meditation_system.gd")

const COLOPHON_RECT := Rect2(14.0, 12.0, 236.0, 58.0)
const SEAL_RECT := Rect2(20.0, 20.0, 34.0, 34.0)
const WAKE_HOLD_SECONDS: float = 2.8

const SCULPT_TOOLS: Array[Dictionary] = [
	{"id": "expand",   "name": "辟土", "hint": "开辟新陆"},
	{"id": "contract", "name": "敛岸", "hint": "敛缩旧岸（全额返还配额）"},
	{"id": "raise",    "name": "崇山", "hint": "抬升台地"},
	{"id": "lower",    "name": "夷谷", "hint": "削平低谷"},
	{"id": "water",    "name": "引泉", "hint": "引注灵泉"},
	{"id": "dry",      "name": "涸泽", "hint": "退水成陆"},
]
const BRUSH_RADII: Array[float] = [1.0, 2.2, 3.8]
const WATER_PRESETS: Array[Dictionary] = [
	{"level": 1, "name": "浅涧"},
	{"level": 3, "name": "下池"},
	{"level": 5, "name": "中潭"},
	{"level": 7, "name": "上池"},
]

var director: Node3D

var _kaiti_font: Font
var _songti_font: Font
var _mist_tex: GradientTexture2D

# Dynamic breathing state (0.0 = pure canvas, 1.0 = awakened inscription)
var _wake_timer: float = 2.4
var _wake_alpha: float = 1.0
var _dock_alpha: float = 0.0
var _hover_pos: Vector2 = Vector2(-999.0, -999.0)
var _pulse_time: float = 0.0
var _night_blend: float = 0.0

# Whisper (frameless poetic toast)
var _whisper_text: String = ""
var _whisper_timer: float = 0.0
var _whisper_max: float = 2.4

# Sculpt dock interactive hit areas (rebuilt per layout/draw)
var _dock_bounds: Rect2 = Rect2()
var _tool_hit_rects: Array[Rect2] = []
var _size_hit_rects: Array[Rect2] = []
var _undo_hit_rect: Rect2 = Rect2()
var _scroll_btn_rect: Rect2 = Rect2()
var _water_hit_rects: Array[Rect2] = []
var _Hovered_tool_idx: int = -1

# Folded Xuan-paper leaves (only shown when explicitly opened)
var _scroll_leaf_open: bool = false
var _scroll_leaf_rect: Rect2 = Rect2()
var _leaf_actions: Array[Dictionary] = []

var _log_panel: Control # Kept minimal & frameless Xuan-paper leaf when opened via key/seal
var _log_open: bool = false
var _log_rect: Rect2 = Rect2()

# Cached snapshot for _draw()
var _realm_title: String = "炼气一层 · 初窥识海"
var _realm_short: String = "炼气一层"
var _time_title: String = "春分 · 卯时"
var _mood_title: String = "天青烟岚"
var _qi_ratio: float = 0.5
var _qi_val: float = 160.0
var _qi_cap: float = 300.0
var _dao_ratio: float = 0.0
var _can_break: bool = false
var _cur_cells: int = 623
var _max_cells: int = 687
var _stance: String = "avatar"
var _wallpaper: bool = false
var _time_paused: bool = false

func _ready() -> void:
	name = "ShihaiHUD"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_load_classical_fonts()
	_build_mist_texture()

	# Compatibility node reference for director.gd
	_log_panel = Control.new()
	_log_panel.visible = false
	_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log_panel)

func _exit_tree() -> void:
	_kaiti_font = null
	_songti_font = null
	_mist_tex = null

func _build_mist_texture() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.34, 0.68, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.72),
		Color(1.0, 1.0, 1.0, 0.20),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_mist_tex = GradientTexture2D.new()
	_mist_tex.width = 128
	_mist_tex.height = 64
	_mist_tex.fill = GradientTexture2D.FILL_RADIAL
	_mist_tex.fill_from = Vector2(0.5, 0.5)
	_mist_tex.fill_to = Vector2(1.0, 0.5)
	_mist_tex.gradient = grad

func _load_classical_fonts() -> void:
	var home: String = OS.get_environment("HOME")
	var kaiti_candidates: Array[String] = [
		home.path_join("Library/Fonts/方正楷体简体.ttf"),
		"/Library/Fonts/方正楷体简体.ttf",
		"/System/Library/Fonts/Supplemental/Songti.ttc",
		"/System/Library/Fonts/Hiragino Sans GB.ttc",
		"/System/Library/Fonts/STHeiti Medium.ttc",
		"C:/Windows/Fonts/simkai.ttf",
		"C:/Windows/Fonts/msyh.ttc",
	]
	var songti_candidates: Array[String] = [
		"/System/Library/Fonts/Supplemental/Songti.ttc",
		home.path_join("Library/Fonts/方正楷体简体.ttf"),
		"/System/Library/Fonts/Hiragino Sans GB.ttc",
		"/System/Library/Fonts/STHeiti Medium.ttc",
		"C:/Windows/Fonts/simsun.ttc",
		"C:/Windows/Fonts/msyh.ttc",
	]
	_kaiti_font = _try_load_font_list(kaiti_candidates)
	_songti_font = _try_load_font_list(songti_candidates)

static func _try_load_font_list(paths: Array[String]) -> Font:
	for p: String in paths:
		if p != "" and FileAccess.file_exists(p):
			var ff := FontFile.new()
			if ff.load_dynamic_font(p) == OK:
				return ff
	return ThemeDB.fallback_font

func notify_activity(hold_seconds: float = WAKE_HOLD_SECONDS) -> void:
	if not _wallpaper:
		_wake_timer = maxf(_wake_timer, hold_seconds)

func is_sculpt_dock_open() -> bool:
	return _stance == "sculpt" and not _wallpaper

func show_toast(msg: String, duration: float = 2.5) -> void:
	if msg == "":
		return
	_whisper_text = msg
	_whisper_max = clampf(duration, 1.4, 3.6)
	_whisper_timer = _whisper_max
	notify_activity(duration)
	queue_redraw()

func set_wallpaper_visuals(enabled: bool) -> void:
	_wallpaper = enabled
	if enabled:
		_scroll_leaf_open = false
		_log_open = false
		_log_panel.visible = false
		_wake_timer = 0.0
		_wake_alpha = 0.0
		_dock_alpha = 0.0
		_whisper_text = "画境净屏 · 按 F11 归返"
		_whisper_max = 1.9
		_whisper_timer = 1.9
	else:
		notify_activity(3.0)
		_wake_alpha = 1.0
	queue_redraw()

func refresh_log() -> void:
	_log_open = _log_panel.visible
	queue_redraw()

func toggle_log_leaf() -> void:
	_log_open = not _log_open
	_log_panel.visible = _log_open
	if _log_open:
		_scroll_leaf_open = false
		notify_activity(5.0)
	queue_redraw()

func is_over_ui(screen: Vector2) -> bool:
	if not visible or _wallpaper:
		return false
	if COLOPHON_RECT.has_point(screen):
		return true
	if is_sculpt_dock_open():
		if _dock_bounds.has_point(screen):
			return true
		var ed: Node3D = director.get("editor") as Node3D if director != null else null
		if ed != null and String(ed.get("tool")) == "water":
			for wr: Rect2 in _water_hit_rects:
				if wr.has_point(screen):
					return true
		if _scroll_leaf_open and _scroll_leaf_rect.has_point(screen):
			return true
	if _log_open and _log_rect.has_point(screen):
		return true
	return false

func _gui_input(event: InputEvent) -> void:
	if _wallpaper:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_hover_pos = mm.position
		if COLOPHON_RECT.has_point(_hover_pos) or (is_sculpt_dock_open() and _dock_bounds.has_point(_hover_pos)):
			notify_activity(1.8)
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _handle_left_click(mb.position):
				accept_event()

func _handle_left_click(pos: Vector2) -> bool:
	if director == null:
		return false
	var ed: Node3D = director.get("editor") as Node3D

	# 1. Open Xuan-paper scroll leaf actions
	if _scroll_leaf_open:
		if _scroll_leaf_rect.has_point(pos):
			for act: Dictionary in _leaf_actions:
				var r: Rect2 = act["rect"] as Rect2
				if r.has_point(pos):
					_execute_leaf_action(String(act["id"]))
					return true
			return true
		else:
			_scroll_leaf_open = false
			queue_redraw()

	# 2. Logbook Xuan-paper leaf
	if _log_open:
		if _log_rect.has_point(pos):
			_log_open = false
			_log_panel.visible = false
			queue_redraw()
			return true
		else:
			_log_open = false
			_log_panel.visible = false
			queue_redraw()

	# 3. Top-left Song-scroll Colophon & Cinnabar Seal
	if COLOPHON_RECT.has_point(pos):
		notify_activity(3.5)
		if SEAL_RECT.grow(6.0).has_point(pos):
			if _can_break:
				director.call("attempt_breakthrough")
			else:
				director.call("toggle_stance")
			return true
		# Clicking time calligraphy steps shichen cleanly
		director.call("step_shichen")
		return true

	# 4. Bottom Sculpting Seal Dock (when in sculpt stance)
	if is_sculpt_dock_open() and ed != null:
		if String(ed.get("tool")) == "water":
			for wi: int in _water_hit_rects.size():
				if _water_hit_rects[wi].has_point(pos):
					ed.set("water_level", int(WATER_PRESETS[wi]["level"]))
					show_toast("水阶 · %s" % String(WATER_PRESETS[wi]["name"]), 1.6)
					return true
		for ti: int in _tool_hit_rects.size():
			if _tool_hit_rects[ti].has_point(pos):
				var tid: String = String(SCULPT_TOOLS[ti]["id"])
				ed.set("tool", tid)
				show_toast("%s · %s" % [String(SCULPT_TOOLS[ti]["name"]), String(SCULPT_TOOLS[ti]["hint"])], 1.8)
				queue_redraw()
				return true
		for si: int in _size_hit_rects.size():
			if _size_hit_rects[si].has_point(pos):
				ed.set("radius", BRUSH_RADII[si])
				queue_redraw()
				return true
		if _undo_hit_rect.has_point(pos):
			ed.call("cancel_input")
			var tdata: RefCounted = ed.get("data") as RefCounted
			if tdata != null and bool(tdata.call("undo")):
				show_toast("回溯一笔", 1.4)
			return true
		if _scroll_btn_rect.has_point(pos):
			_scroll_leaf_open = not _scroll_leaf_open
			queue_redraw()
			return true
		if _dock_bounds.has_point(pos):
			return true

	return false

func _execute_leaf_action(act_id: String) -> void:
	if director == null:
		return
	var ed: Node3D = director.get("editor") as Node3D
	if ed == null:
		return
	match act_id:
		"style_0": ed.call("select_style_preset", 0); show_toast("天青烟岚 · 晓色", 1.8)
		"style_1": ed.call("select_style_preset", 1); show_toast("晴岚温玉 · 昼景", 1.8)
		"style_2": ed.call("select_style_preset", 2); show_toast("暖玉流霞 · 暮色", 1.8)
		"style_3": ed.call("select_style_preset", 3); show_toast("烟渚星灯 · 夜色", 1.8)
		"preset_0": ed.call("select_preset", 0); show_toast("重辟 · 双台叠瀑", 2.0)
		"preset_1": ed.call("select_preset", 1); show_toast("重辟 · 平湖双屿", 2.0)
		"preset_2": ed.call("select_preset", 2); show_toast("重辟 · 太虚石坪", 2.0)
		"save":
			if int(ed.call("save_layout", "user://terrain_editor/layout.json")) == OK:
				show_toast("识海画卷已钤印存录", 2.2)
		"load":
			if int(ed.call("load_layout", "user://terrain_editor/layout.json")) == OK:
				show_toast("已展阅旧藏画卷", 2.2)
		"log":
			_scroll_leaf_open = false
			toggle_log_leaf()
			return
		"avatar":
			_scroll_leaf_open = false
			director.call("set_stance", "avatar", false)
			return
	_scroll_leaf_open = false
	queue_redraw()

func tick_ui(delta: float, state: State, time_sys: TimeSys, _fishing: FishingSys, current_cells: int, stance: String, wallpaper: bool) -> void:
	_pulse_time += delta
	_wallpaper = wallpaper
	_stance = stance
	_cur_cells = current_cells

	if state != null:
		var was_can_break: bool = _can_break
		_realm_title = state.realm_title()
		var parts: PackedStringArray = _realm_title.split(" · ")
		_realm_short = parts[0] if not parts.is_empty() else _realm_title
		_qi_val = state.spirit_qi
		_qi_cap = maxf(1.0, state.current_qi_cap())
		_qi_ratio = clampf(_qi_val / _qi_cap, 0.0, 1.0)
		_dao_ratio = clampf(state.dao_insight / maxf(1.0, state.current_insight_target()), 0.0, 1.0)
		_can_break = state.can_breakthrough()
		_max_cells = state.max_land_cells()
		if _can_break and not was_can_break:
			notify_activity(4.5)

	if time_sys != null:
		var shichen_head: String = time_sys.shichen_label().split(" · ")[0]
		_time_title = "%s · %s" % [time_sys.solar_term_label(), shichen_head]
		_mood_title = String(time_sys.current_blended_preset().get("mood", "天青烟岚"))
		_time_paused = time_sys.paused
		# Smooth day-ink <-> night-ivory blend around dawn (0.14..0.22) and dusk (0.80..0.88)
		var p: float = time_sys.day_progress
		var target_night: float = 0.0
		if p < 0.14 or p > 0.88:
			target_night = 1.0
		elif p < 0.22:
			target_night = 1.0 - (p - 0.14) / 0.08
		elif p > 0.80:
			target_night = (p - 0.80) / 0.08
		_night_blend = lerpf(_night_blend, target_night, clampf(delta * 4.0, 0.0, 1.0)) if delta > 0.0 else target_night

	var hover_colophon: bool = not _wallpaper and COLOPHON_RECT.has_point(_hover_pos)
	var keep_awake: bool = not _wallpaper and (_stance == "sculpt" or hover_colophon or _log_open or _scroll_leaf_open)
	if keep_awake:
		_wake_timer = maxf(_wake_timer, 0.6)
	elif _wake_timer > 0.0:
		_wake_timer = maxf(0.0, _wake_timer - delta)

	var target_wake: float = 0.0
	if not _wallpaper:
		if keep_awake or _wake_timer > 0.0:
			target_wake = 1.0
	if delta <= 0.0 or delta >= 2.0:
		_wake_alpha = target_wake
	else:
		var rate: float = 7.5 if target_wake > _wake_alpha else 1.8
		_wake_alpha = move_toward(_wake_alpha, target_wake, delta * rate)

	var target_dock: float = 1.0 if (_stance == "sculpt" and not _wallpaper) else 0.0
	if delta <= 0.0 or delta >= 2.0:
		_dock_alpha = target_dock
	else:
		_dock_alpha = move_toward(_dock_alpha, target_dock, delta * 6.5)

	if _whisper_timer > 0.0:
		_whisper_timer = maxf(0.0, _whisper_timer - delta)

	queue_redraw()

# --- Custom Frameless Song-Scroll Vector & Calligraphy Rendering ---

func _ink_primary(alpha: float) -> Color:
	var c: Color = Color(0.10, 0.15, 0.14).lerp(Color(0.94, 0.91, 0.84), _night_blend)
	c.a = alpha
	return c

func _ink_secondary(alpha: float) -> Color:
	var c: Color = Color(0.19, 0.26, 0.24).lerp(Color(0.79, 0.84, 0.82), _night_blend)
	c.a = alpha
	return c

func _porcelain_fill(alpha: float) -> Color:
	var c: Color = Color(0.96, 0.94, 0.89).lerp(Color(0.10, 0.15, 0.20), _night_blend)
	c.a = alpha
	return c

func _cinnabar(alpha: float) -> Color:
	return Color(0.74, 0.21, 0.16, alpha)

func _draw_silk_mist(rect: Rect2, alpha: float) -> void:
	if _mist_tex == null or alpha <= 0.01:
		return
	var c: Color = Color(0.95, 0.94, 0.90).lerp(Color(0.06, 0.10, 0.16), _night_blend)
	c.a = alpha
	draw_texture_rect(_mist_tex, rect, false, c)

func _draw_smooth_disc(center: Vector2, radius: float, fill_col: Color, segs: int = 36) -> void:
	if fill_col.a <= 0.01 or radius <= 0.2:
		return
	var pts := PackedVector2Array()
	pts.resize(segs)
	for i: int in segs:
		var ang: float = TAU * float(i) / float(segs)
		pts[i] = center + Vector2(cos(ang), sin(ang)) * radius
	draw_colored_polygon(pts, fill_col)
	draw_arc(center, radius, 0.0, TAU, segs, Color(fill_col.r, fill_col.g, fill_col.b, fill_col.a * 0.75), 1.0, true)

func _draw_ink_text(font: Font, pos: Vector2, txt: String, font_size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	if col.a <= 0.01 or txt == "":
		return
	var sheen: Color = Color(0.96, 0.95, 0.91).lerp(Color(0.04, 0.07, 0.11), _night_blend)
	sheen.a = col.a * lerpf(0.32, 0.55, _night_blend)
	draw_string(font, pos + Vector2(0.0, 1.0), txt, align, width, font_size, sheen)
	draw_string(font, pos, txt, align, width, font_size, col)

func _draw() -> void:
	var vp: Vector2 = size if size.x > 10.0 else Vector2(1280.0, 720.0)
	_draw_colophon()
	if _dock_alpha > 0.01:
		_draw_sculpt_dock(vp, _dock_alpha)
	if _scroll_leaf_open and _dock_alpha > 0.2:
		_draw_scroll_leaf(vp, _dock_alpha)
	if _log_open and not _wallpaper:
		_draw_log_leaf(vp)
	_draw_whisper(vp)

func _draw_colophon() -> void:
	# Even when resting in avatar mode, if breakthrough is ready, gently pulse the tiny cinnabar seal.
	var seal_rest_alpha: float = 0.0
	if not _wallpaper and _can_break:
		seal_rest_alpha = 0.58 + 0.20 * sin(_pulse_time * 2.4)
	var a: float = maxf(_wake_alpha, 0.0)
	var seal_a: float = maxf(a, seal_rest_alpha)
	if seal_a <= 0.01:
		return

	if a > 0.02:
		# Seamless radial mountain-mist breath so calligraphy stays crisp even when tree foliage passes behind
		_draw_silk_mist(Rect2(-16.0, -8.0, 326.0, 92.0), a * lerpf(0.72, 0.64, _night_blend))

	var center := Vector2(37.0, 37.0)
	# 1. Hairline Concentric Spirit Qi & Dao Insight Brush Rings (open calligraphic gap)
	if a > 0.02:
		var track_col: Color = _ink_secondary(a * 0.22)
		var qi_col: Color = Color(0.20, 0.48, 0.39).lerp(Color(0.48, 0.82, 0.69), _night_blend)
		qi_col.a = a * 0.86
		var dao_col: Color = Color(0.68, 0.46, 0.18).lerp(Color(0.95, 0.80, 0.45), _night_blend)
		dao_col.a = a * 0.90

		var start_a: float = -PI * 0.5
		var span_max: float = TAU * 0.90
		draw_arc(center, 18.5, start_a, start_a + span_max, 36, track_col, 1.3, true)
		if _qi_ratio > 0.01:
			draw_arc(center, 18.5, start_a, start_a + span_max * _qi_ratio, 32, qi_col, 1.55, true)
		draw_arc(center, 23.0, start_a, start_a + span_max, 40, track_col, 1.2, true)
		if _dao_ratio > 0.01:
			draw_arc(center, 23.0, start_a, start_a + span_max * _dao_ratio, 36, dao_col, 1.65, true)

	# 2. Carved Cinnabar Square Seal (宋画朱砂印, 22×22px)
	var seal_box := Rect2(center - Vector2(11.0, 11.0), Vector2(22.0, 22.0))
	var cin: Color = _cinnabar(seal_a * 0.92)
	draw_rect(seal_box, cin, true)
	draw_rect(seal_box.grow(-1.8), Color(0.96, 0.93, 0.87, seal_a * 0.44), false, 1.0)
	var seal_glyph: String = "破" if _can_break else ("造" if _stance == "sculpt" else "识")
	draw_string(_kaiti_font, Vector2(seal_box.position.x, seal_box.position.y + 16.5), seal_glyph, HORIZONTAL_ALIGNMENT_CENTER, seal_box.size.x, 14, Color(0.98, 0.96, 0.91, seal_a))

	if a <= 0.02:
		return

	# 3. Vertical Hairline Colophon Rule + Classical Kaiti Inscription
	var rule_x: float = 69.0
	draw_line(Vector2(rule_x, 20.0), Vector2(rule_x, 54.0), _ink_secondary(a * 0.36), 1.0, true)

	var paused_mark: String = " · 定" if _time_paused else ""
	_draw_ink_text(_kaiti_font, Vector2(80.0, 35.0), _time_title + paused_mark, 19, _ink_primary(a * 0.95))

	var hovered: bool = COLOPHON_RECT.has_point(_hover_pos)
	var sub_line: String = "%s · %s" % [_realm_short, _mood_title]
	var sub_col: Color = _ink_secondary(a * 0.86)
	if _can_break:
		sub_line = "%s · 道韵圆满（点印破境）" % _realm_short
		sub_col = Color(0.66, 0.18, 0.14, a * 0.95).lerp(Color(0.95, 0.79, 0.44, a), _night_blend)
	elif _stance == "sculpt" or hovered:
		sub_line = "%s · 疆域 %d/%d · 灵气 %.0f" % [_realm_short, _cur_cells, _max_cells, _qi_val]
	_draw_ink_text(_kaiti_font, Vector2(81.0, 53.0), sub_line, 13, sub_col)

func _draw_sculpt_dock(vp: Vector2, a: float) -> void:
	var ed: Node3D = director.get("editor") as Node3D if director != null else null
	var active_tool: String = String(ed.get("tool")) if ed != null else "raise"
	var active_radius: float = float(ed.get("radius")) if ed != null else 1.6
	var active_water: int = int(ed.get("water_level")) if ed != null else 3

	var item_step: float = 52.0
	var tools_w: float = float(SCULPT_TOOLS.size()) * item_step
	var sizes_w: float = 102.0
	var extras_w: float = 96.0
	var total_w: float = tools_w + sizes_w + extras_w + 24.0
	var base_x: float = (vp.x - total_w) * 0.5
	var center_y: float = vp.y - 46.0
	_dock_bounds = Rect2(base_x - 12.0, center_y - 28.0, total_w + 24.0, 66.0)

	# Zero wide pill box! Each seal floats independently as a Song-porcelain / Cinnabar token (Tiny Glade style).
	var porcelain: Color = _porcelain_fill(a * 0.88)
	var porcelain_hov: Color = _porcelain_fill(a * 0.95)
	var shadow_disc := Color(0.04, 0.07, 0.09, a * 0.18)

	# 1. Six Sculpting Tool Porcelain / Cinnabar Medallions
	_tool_hit_rects.clear()
	for i: int in SCULPT_TOOLS.size():
		var cx: float = base_x + 26.0 + float(i) * item_step
		var c := Vector2(cx, center_y)
		var hit_r := Rect2(cx - 22.0, center_y - 24.0, 44.0, 52.0)
		_tool_hit_rects.append(hit_r)
		var tid: String = String(SCULPT_TOOLS[i]["id"])
		var tname: String = String(SCULPT_TOOLS[i]["name"])
		var selected: bool = (active_tool == tid)
		var hovered: bool = hit_r.has_point(_hover_pos)
		var rad: float = 19.0 if selected else (17.8 if hovered else 16.8)

		_draw_smooth_disc(c + Vector2(0.0, 1.5), rad, shadow_disc, 32)
		if selected:
			_draw_smooth_disc(c, rad, _cinnabar(a * 0.95), 36)
			draw_arc(c, rad - 2.2, 0.0, TAU, 36, Color(0.97, 0.94, 0.88, a * 0.48), 1.0, true)
			_draw_tool_glyph(tid, c, Color(0.98, 0.96, 0.91, a), 1.65)
			_draw_silk_mist(Rect2(cx - 32.0, center_y + 19.0, 64.0, 22.0), a * 0.72)
			var cap_col: Color = Color(0.66, 0.18, 0.14, a * 0.96).lerp(Color(0.96, 0.84, 0.68, a), _night_blend)
			_draw_ink_text(_kaiti_font, Vector2(cx - 24.0, center_y + 34.0), tname, 13, cap_col, HORIZONTAL_ALIGNMENT_CENTER, 48.0)
		else:
			_draw_smooth_disc(c, rad, porcelain_hov if hovered else porcelain, 36)
			draw_arc(c, rad, 0.0, TAU, 36, _ink_secondary(a * (0.55 if hovered else 0.32)), 1.15, true)
			_draw_tool_glyph(tid, c, _ink_primary(a * (0.94 if hovered else 0.80)), 1.45)
			if hovered:
				_draw_silk_mist(Rect2(cx - 32.0, center_y + 19.0, 64.0, 22.0), a * 0.68)
				_draw_ink_text(_kaiti_font, Vector2(cx - 24.0, center_y + 34.0), tname, 13, _ink_primary(a * 0.92), HORIZONTAL_ALIGNMENT_CENTER, 48.0)

	# Water level Xuan-paper slips (shown ONLY when "water" tool is active)
	_water_hit_rects.clear()
	if active_tool == "water":
		var wx0: float = base_x + 26.0 + 4.0 * item_step - 84.0
		var wy: float = center_y - 42.0
		for wi: int in WATER_PRESETS.size():
			var wr := Rect2(wx0 + float(wi) * 44.0, wy - 11.0, 40.0, 21.0)
			_water_hit_rects.append(wr)
			var lvl: int = int(WATER_PRESETS[wi]["level"])
			var w_sel: bool = (active_water == lvl)
			var w_hov: bool = wr.has_point(_hover_pos)
			var tag := StyleBoxFlat.new()
			tag.bg_color = _cinnabar(a * 0.94) if w_sel else _porcelain_fill(a * (0.92 if w_hov else 0.84))
			tag.border_color = Color(0.97, 0.94, 0.88, a * 0.40) if w_sel else _ink_secondary(a * 0.28)
			tag.set_border_width_all(1)
			tag.set_corner_radius_all(3)
			draw_style_box(tag, wr)
			var w_txt_col: Color = Color(0.98, 0.96, 0.91, a) if w_sel else _ink_primary(a * 0.88)
			draw_string(_kaiti_font, Vector2(wr.position.x, wr.position.y + 15.0), String(WATER_PRESETS[wi]["name"]), HORIZONTAL_ALIGNMENT_CENTER, wr.size.x, 12, w_txt_col)

	# 2. Three Ink-Drop Brush Radius Tokens (细 · 中 · 阔)
	var div1_x: float = base_x + tools_w + 8.0
	_size_hit_rects.clear()
	var dot_radii: Array[float] = [2.6, 4.3, 6.2]
	for si: int in BRUSH_RADII.size():
		var sx: float = div1_x + 20.0 + float(si) * 31.0
		var sc := Vector2(sx, center_y)
		var sr := Rect2(sx - 14.0, center_y - 18.0, 28.0, 36.0)
		_size_hit_rects.append(sr)
		var match_size: bool = absf(active_radius - BRUSH_RADII[si]) < 0.55
		var s_hov: bool = sr.has_point(_hover_pos)
		_draw_smooth_disc(sc + Vector2(0.0, 1.2), 12.6, shadow_disc, 28)
		_draw_smooth_disc(sc, 12.6, porcelain_hov if (s_hov or match_size) else porcelain, 28)
		draw_arc(sc, 12.6, 0.0, TAU, 28, _cinnabar(a * 0.78) if match_size else _ink_secondary(a * 0.30), 1.15, true)
		var dot_col: Color = _cinnabar(a * 0.94) if match_size else _ink_primary(a * (0.88 if s_hov else 0.68))
		_draw_smooth_disc(sc, dot_radii[si], dot_col, 24)

	# 3. Undo & Scroll Leaf Porcelain Tokens
	var div2_x: float = div1_x + sizes_w + 6.0
	var ux: float = div2_x + 24.0
	var uc := Vector2(ux, center_y)
	_undo_hit_rect = Rect2(ux - 18.0, center_y - 20.0, 36.0, 42.0)
	var u_hov: bool = _undo_hit_rect.has_point(_hover_pos)
	_draw_smooth_disc(uc + Vector2(0.0, 1.4), 15.5, shadow_disc, 32)
	_draw_smooth_disc(uc, 15.5, porcelain_hov if u_hov else porcelain, 32)
	draw_arc(uc, 15.5, 0.0, TAU, 32, _ink_secondary(a * (0.52 if u_hov else 0.30)), 1.1, true)
	var u_col: Color = _ink_primary(a * (0.94 if u_hov else 0.78))
	draw_arc(uc, 6.8, -PI * 0.85, PI * 0.55, 20, u_col, 1.45, true)
	var tip := uc + Vector2(cos(-PI * 0.85), sin(-PI * 0.85)) * 6.8
	draw_line(tip, tip + Vector2(4.0, -1.1), u_col, 1.45, true)
	draw_line(tip, tip + Vector2(1.3, 4.0), u_col, 1.45, true)
	if u_hov:
		_draw_silk_mist(Rect2(ux - 28.0, center_y + 19.0, 56.0, 22.0), a * 0.68)
		_draw_ink_text(_kaiti_font, Vector2(ux - 22.0, center_y + 34.0), "回溯", 13, _ink_primary(a * 0.92), HORIZONTAL_ALIGNMENT_CENTER, 44.0)

	var mx: float = ux + 44.0
	var mc := Vector2(mx, center_y)
	_scroll_btn_rect = Rect2(mx - 18.0, center_y - 20.0, 36.0, 42.0)
	var m_hov: bool = _scroll_btn_rect.has_point(_hover_pos)
	_draw_smooth_disc(mc + Vector2(0.0, 1.4), 15.5, shadow_disc, 32)
	if _scroll_leaf_open:
		_draw_smooth_disc(mc, 15.5, _cinnabar(a * 0.94), 32)
		draw_arc(mc, 13.5, 0.0, TAU, 32, Color(0.97, 0.94, 0.88, a * 0.45), 1.0, true)
	else:
		_draw_smooth_disc(mc, 15.5, porcelain_hov if m_hov else porcelain, 32)
		draw_arc(mc, 15.5, 0.0, TAU, 32, _ink_secondary(a * (0.52 if m_hov else 0.30)), 1.1, true)
	var m_col: Color = Color(0.98, 0.96, 0.91, a) if _scroll_leaf_open else _ink_primary(a * (0.94 if m_hov else 0.78))
	for li: int in [-1, 0, 1]:
		var ly: float = mc.y + float(li) * 4.2
		var half_w: float = 6.4 if li != 0 else 4.6
		draw_line(Vector2(mc.x - half_w, ly), Vector2(mc.x + half_w, ly), m_col, 1.45, true)
	if m_hov or _scroll_leaf_open:
		_draw_silk_mist(Rect2(mx - 28.0, center_y + 19.0, 56.0, 22.0), a * 0.68)
		var m_cap_col: Color = Color(0.66, 0.18, 0.14, a * 0.95).lerp(Color(0.96, 0.84, 0.68, a), _night_blend) if _scroll_leaf_open else _ink_primary(a * 0.92)
		_draw_ink_text(_kaiti_font, Vector2(mx - 22.0, center_y + 34.0), "卷轴", 13, m_cap_col, HORIZONTAL_ALIGNMENT_CENTER, 44.0)

func _draw_tool_glyph(tool_id: String, c: Vector2, col: Color, width: float) -> void:
	match tool_id:
		"expand":
			draw_arc(c, 5.5, 0.0, TAU, 20, col, width, true)
			for d: Vector2 in [Vector2(0.0, -1.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0), Vector2(1.0, 0.0)]:
				draw_line(c + d * 7.2, c + d * 10.2, col, width, true)
		"contract":
			draw_arc(c, 8.2, -PI * 0.72, PI * 0.72, 18, col, width, true)
			draw_arc(c + Vector2(3.2, 0.0), 6.2, PI * 0.65, PI * 1.35, 14, col, width, true)
		"raise":
			var p1 := PackedVector2Array([c + Vector2(-9.5, 5.5), c + Vector2(-2.2, -7.2), c + Vector2(4.2, 5.5)])
			var p2 := PackedVector2Array([c + Vector2(-1.0, 5.5), c + Vector2(4.8, -4.2), c + Vector2(9.8, 5.5)])
			draw_polyline(p1, col, width, true)
			draw_polyline(p2, col, width * 0.9, true)
		"lower":
			var pv := PackedVector2Array([c + Vector2(-9.5, -4.0), c + Vector2(-4.0, 5.2), c + Vector2(4.0, 5.2), c + Vector2(9.5, -4.0)])
			draw_polyline(pv, col, width, true)
			draw_line(c + Vector2(-5.5, -1.5), c + Vector2(5.5, -1.5), Color(col.r, col.g, col.b, col.a * 0.55), 1.1, true)
		"water":
			for row_i: int in [-1, 0, 1]:
				var wy: float = c.y + float(row_i) * 4.4
				var pts := PackedVector2Array()
				for s: int in 9:
					var t: float = float(s) / 8.0
					var wx: float = lerpf(-8.2, 8.2, t)
					pts.append(Vector2(c.x + wx, wy + sin(t * TAU + float(row_i)) * 1.45))
				draw_polyline(pts, col, width * 0.92, true)
		"dry":
			draw_line(c + Vector2(-9.0, 4.5), c + Vector2(9.0, 4.5), col, width, true)
			draw_arc(c + Vector2(0.0, 2.2), 5.4, PI, TAU, 18, col, width, true)

func _draw_scroll_leaf(vp: Vector2, a: float) -> void:
	# Compact warm Xuan-paper leaf (素笺小页) hovering delicately above the right side of the dock
	var w: float = 236.0
	var h: float = 166.0
	var lx: float = clampf(_scroll_btn_rect.position.x - w + 42.0, 24.0, vp.x - w - 24.0)
	var ly: float = vp.y - 88.0 - h
	_scroll_leaf_rect = Rect2(lx, ly, w, h)

	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.95, 0.93, 0.88, a * 0.94)
	paper.border_color = Color(0.28, 0.25, 0.20, a * 0.42)
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(3)
	draw_style_box(paper, _scroll_leaf_rect)
	draw_rect(_scroll_leaf_rect.grow(-3.0), Color(0.28, 0.25, 0.20, a * 0.16), false, 1.0)

	var ink := Color(0.16, 0.20, 0.19, a * 0.92)
	var sub := Color(0.38, 0.36, 0.31, a * 0.78)
	_leaf_actions.clear()

	draw_string(_songti_font, Vector2(lx + 14.0, ly + 24.0), "时辰四景", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, sub)
	var styles: Array[Array] = [["style_0", "晓岚"], ["style_1", "晴昼"], ["style_2", "流霞"], ["style_3", "星夜"]]
	for i: int in styles.size():
		var r := Rect2(lx + 14.0 + float(i) * 52.0, ly + 30.0, 46.0, 24.0)
		_leaf_actions.append({"id": styles[i][0], "rect": r})
		var hov: bool = r.has_point(_hover_pos)
		draw_string(_kaiti_font, Vector2(r.position.x, r.position.y + 17.0), String(styles[i][1]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, _cinnabar(a) if hov else ink)

	draw_line(Vector2(lx + 14.0, ly + 62.0), Vector2(lx + w - 14.0, ly + 62.0), Color(0.28, 0.25, 0.20, a * 0.18), 1.0)
	draw_string(_songti_font, Vector2(lx + 14.0, ly + 78.0), "重辟母本", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, sub)
	var presets: Array[Array] = [["preset_0", "双台叠瀑"], ["preset_1", "平湖双屿"], ["preset_2", "太虚石坪"]]
	for i: int in presets.size():
		var r := Rect2(lx + 14.0 + float(i) * 70.0, ly + 84.0, 66.0, 24.0)
		_leaf_actions.append({"id": presets[i][0], "rect": r})
		var hov: bool = r.has_point(_hover_pos)
		draw_string(_kaiti_font, Vector2(r.position.x, r.position.y + 17.0), String(presets[i][1]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, _cinnabar(a) if hov else ink)

	draw_line(Vector2(lx + 14.0, ly + 116.0), Vector2(lx + w - 14.0, ly + 116.0), Color(0.28, 0.25, 0.20, a * 0.18), 1.0)
	var ops: Array[Array] = [["save", "钤印存卷"], ["load", "展阅旧卷"], ["log", "水脉鱼录"], ["avatar", "归返化身"]]
	for i: int in ops.size():
		var r := Rect2(lx + 12.0 + float(i) * 54.0, ly + 126.0, 52.0, 26.0)
		_leaf_actions.append({"id": ops[i][0], "rect": r})
		var hov: bool = r.has_point(_hover_pos)
		draw_string(_kaiti_font, Vector2(r.position.x, r.position.y + 18.0), String(ops[i][1]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, _cinnabar(a) if hov else ink)

func _draw_log_leaf(vp: Vector2) -> void:
	if director == null:
		return
	var state: State = director.get("state") as State
	if state == null:
		return
	var w: float = 250.0
	var rows_n: int = maxi(1, state.discoveries.size())
	var h: float = 96.0 + float(rows_n) * 22.0
	var lx: float = vp.x - w - 26.0
	var ly: float = 22.0
	_log_rect = Rect2(lx, ly, w, h)

	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.95, 0.93, 0.88, 0.94)
	paper.border_color = Color(0.28, 0.25, 0.20, 0.42)
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(3)
	draw_style_box(paper, _log_rect)
	draw_rect(_log_rect.grow(-3.0), Color(0.28, 0.25, 0.20, 0.16), false, 1.0)

	var ink := Color(0.16, 0.20, 0.19, 0.92)
	var sub := Color(0.38, 0.36, 0.31, 0.78)
	draw_string(_kaiti_font, Vector2(lx + 16.0, ly + 28.0), "识海水脉 · 鱼篓录", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	draw_rect(Rect2(lx + w - 34.0, ly + 13.0, 18.0, 18.0), _cinnabar(0.88), true)
	draw_string(_kaiti_font, Vector2(lx + w - 34.0, ly + 26.5), "合", HORIZONTAL_ALIGNMENT_CENTER, 18.0, 11, Color(0.97, 0.95, 0.90))
	draw_string(_songti_font, Vector2(lx + 16.0, ly + 48.0), "垂纶 %d 尾  ·  入定 %.0f 息" % [state.total_fish_caught, state.meditation_seconds], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, sub)
	draw_line(Vector2(lx + 16.0, ly + 56.0), Vector2(lx + w - 16.0, ly + 56.0), Color(0.28, 0.25, 0.20, 0.18), 1.0)

	if state.discoveries.is_empty():
		draw_string(_songti_font, Vector2(lx + 16.0, ly + 80.0), "池波尚静，轻点水面即可忘机垂钓。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, sub)
	else:
		var idx: int = 0
		for k: String in state.discoveries.keys():
			var ry: float = ly + 78.0 + float(idx) * 22.0
			draw_string(_kaiti_font, Vector2(lx + 18.0, ry), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
			draw_string(_songti_font, Vector2(lx + w - 58.0, ry), "× %d" % int(state.discoveries[k]), HORIZONTAL_ALIGNMENT_RIGHT, 40.0, 12, sub)
			idx += 1

func _draw_whisper(vp: Vector2) -> void:
	if _whisper_timer <= 0.01 or _whisper_text == "":
		return
	var fade_in: float = clampf((_whisper_max - _whisper_timer) / 0.18, 0.0, 1.0)
	var fade_out: float = clampf(_whisper_timer / 0.65, 0.0, 1.0)
	var a: float = minf(fade_in, fade_out) * 0.94
	var wy: float = vp.y - (104.0 if is_sculpt_dock_open() else 36.0)
	var mist_w: float = clampf(float(_whisper_text.length()) * 20.0 + 72.0, 180.0, 440.0)
	_draw_silk_mist(Rect2((vp.x - mist_w) * 0.5, wy - 24.0, mist_w, 38.0), a * 0.72)
	_draw_ink_text(_kaiti_font, Vector2(0.0, wy), _whisper_text, 17, _ink_primary(a), HORIZONTAL_ALIGNMENT_CENTER, vp.x)
