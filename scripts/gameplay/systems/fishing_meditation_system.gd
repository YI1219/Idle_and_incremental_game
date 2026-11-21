class_name FishingMeditationSystem
extends Node3D
## Handles pond-bank fishing (manual timing + semi-idle 太公忘机钓), water-ink ripples,
## meditation Dao Insight flow, and Realm Breakthrough wave visuals.

const Actor = preload("res://scripts/gameplay/entities/cultivator_actor.gd")
const State = preload("res://scripts/gameplay/data/realm_progression.gd")

signal fish_bite_started
signal fish_bite_ended
signal fishing_result(item_name: String, quality: String, qi_gain: float, insight_gain: float)
signal status_hint(message: String)

const PERFECT_LO: float = 0.38
const PERFECT_HI: float = 0.82

const CATCH_POOL_PERFECT: Array[String] = [
	"太虚水脉残章", "碧玉龙鲤", "云母星鳅", "温玉古佩"
]
const CATCH_POOL_GOOD: Array[String] = [
	"青玉灵鲤", "玄水锦鲤", "烟波银鲈"
]
const CATCH_POOL_AUTO: Array[String] = [
	"识海银鲫", "青玉灵鲤", "灵泉青虾"
]

var phase: String = "none" # "none" | "casting" | "waiting" | "biting" | "cooldown"
var stand_xz: Vector2 = Vector2.ZERO
var bobber_xz: Vector2 = Vector2.ZERO
var water_y: float = 1.5
var bite_progress: float = 0.0
var meditating: bool = false

var _phase_timer: float = 0.0
var _phase_duration: float = 1.0
var _ripple_time: float = 0.0
var _breakthrough_wave_t: float = -1.0
var _breakthrough_origin: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()

var _line_mesh_inst: MeshInstance3D
var _line_im: ImmediateMesh
var _bobber_node: MeshInstance3D
var _wave_mesh_inst: MeshInstance3D
var _wave_im: ImmediateMesh

func _ready() -> void:
	_rng.seed = 730199
	_line_im = ImmediateMesh.new()
	_line_mesh_inst = MeshInstance3D.new()
	_line_mesh_inst.name = "FishingSilkAndRipples"
	_line_mesh_inst.mesh = _line_im
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.vertex_color_use_as_albedo = true
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_mesh_inst.material_override = line_mat
	add_child(_line_mesh_inst)

	var bob_mesh := SphereMesh.new()
	bob_mesh.radius = 0.065
	bob_mesh.height = 0.16
	bob_mesh.radial_segments = 8
	bob_mesh.rings = 4
	var bob_mat := StandardMaterial3D.new()
	bob_mat.albedo_color = Color(0.76, 0.92, 0.82)
	bob_mat.emission_enabled = true
	bob_mat.emission = Color(0.42, 0.78, 0.66)
	bob_mat.emission_energy_multiplier = 0.45
	bob_mat.roughness = 0.6
	_bobber_node = MeshInstance3D.new()
	_bobber_node.name = "JadeBobber"
	_bobber_node.mesh = bob_mesh
	_bobber_node.material_override = bob_mat
	_bobber_node.visible = false
	add_child(_bobber_node)

	_wave_im = ImmediateMesh.new()
	_wave_mesh_inst = MeshInstance3D.new()
	_wave_mesh_inst.name = "BreakthroughWave"
	_wave_mesh_inst.mesh = _wave_im
	var wave_mat := StandardMaterial3D.new()
	wave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wave_mat.vertex_color_use_as_albedo = true
	wave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wave_mesh_inst.material_override = wave_mat
	add_child(_wave_mesh_inst)

func is_fishing() -> bool:
	return phase != "none"

func is_biting() -> bool:
	return phase == "biting"

func is_in_perfect_window() -> bool:
	return phase == "biting" and bite_progress >= PERFECT_LO and bite_progress <= PERFECT_HI

func start_fishing(actor: Actor, bank_pos: Vector2, water_target: Vector2, target_water_y: float) -> void:
	meditating = false
	stand_xz = bank_pos
	bobber_xz = water_target
	water_y = target_water_y
	phase = "casting"
	_phase_timer = 0.0
	_phase_duration = 0.42
	bite_progress = 0.0
	if actor != null:
		actor.set_activity("fishing", bobber_xz)
	_bobber_node.visible = true
	status_hint.emit("临水垂纶 · 静置忘机自得，轻点水面可催鱼提品")

func stop_all(actor: Actor = null) -> void:
	if phase == "biting":
		fish_bite_ended.emit()
	phase = "none"
	meditating = false
	bite_progress = 0.0
	if _bobber_node != null:
		_bobber_node.visible = false
	if _line_im != null:
		_line_im.clear_surfaces()
	if actor != null and actor.activity in ["fishing", "meditate"]:
		actor.set_activity("idle")

func start_meditation(actor: Actor) -> void:
	if phase != "none":
		stop_all(null)
	meditating = true
	if actor != null:
		actor.set_activity("meditate")
	status_hint.emit("盘膝吐纳 · 静凝识海道韵")

func trigger_breakthrough_wave(origin: Vector3) -> void:
	_breakthrough_origin = origin
	_breakthrough_wave_t = 0.0

func try_manual_reel(state: State, fishing_mult: float = 1.0) -> String:
	if phase == "none":
		return "not_fishing"
	if phase == "casting" or phase == "cooldown":
		return "casting"
	if phase == "waiting":
		# Manual interaction gently ripples the lure to accelerate bite arrival without ever failing!
		_phase_timer = minf(_phase_duration, _phase_timer + 1.45)
		_ripple_time += 0.35
		return "accelerated"
	# During biting: immediate catch + elevated rare/insight probability!
	var quality: String = "perfect" if is_in_perfect_window() else "good"
	if quality == "good" and _rng.randf() < 0.45:
		quality = "perfect"
	_complete_catch(state, quality, fishing_mult)
	return quality

func _complete_catch(state: State, quality: String, fishing_mult: float) -> void:
	fish_bite_ended.emit()
	var item_name: String = "青玉灵鲤"
	var qi_gain: float = 10.0
	var insight_gain: float = 18.0
	var roll: float = _rng.randf()
	if quality == "perfect":
		item_name = CATCH_POOL_PERFECT[_rng.randi() % CATCH_POOL_PERFECT.size()]
		qi_gain = 18.0 * fishing_mult
		insight_gain = 34.0 * fishing_mult
		status_hint.emit("一竿得道 · 钓获「%s」" % item_name)
	elif quality == "good":
		var pool_g: Array[String] = CATCH_POOL_PERFECT if roll < 0.35 else CATCH_POOL_GOOD
		item_name = pool_g[_rng.randi() % pool_g.size()]
		qi_gain = 13.0 * fishing_mult
		insight_gain = 23.0 * fishing_mult
		status_hint.emit("轻提竹纶 · 钓获「%s」" % item_name)
	else:
		# Idle auto-catch (太公忘机钓): still has a 16% chance at rare treasures!
		var pool_a: Array[String] = CATCH_POOL_PERFECT if roll < 0.16 else (CATCH_POOL_GOOD if roll < 0.58 else CATCH_POOL_AUTO)
		item_name = pool_a[_rng.randi() % pool_a.size()]
		qi_gain = 8.5 * fishing_mult
		insight_gain = 14.5 * fishing_mult
		status_hint.emit("忘机自得 · 「%s」入篓" % item_name)

	if state != null:
		state.record_catch(item_name, quality, qi_gain, insight_gain)
	fishing_result.emit(item_name, quality, qi_gain, insight_gain)
	phase = "cooldown"
	_phase_timer = 0.0
	_phase_duration = 1.15
	bite_progress = 0.0

func tick(delta: float, actor: Actor, state: State, meditation_mult: float, fishing_mult: float, surface_query: Callable) -> void:
	if delta <= 0.0:
		return
	_ripple_time += delta

	# Keep water surface elevation synced if user edited water nearby.
	if phase != "none":
		var ws: Dictionary = surface_query.call(bobber_xz)
		if ws.is_empty() or int(ws.get("water", -1)) < 0:
			stop_all(actor)
		else:
			water_y = float(int(ws.get("water", 3))) * 0.5

	if meditating and actor != null:
		if actor.activity != "meditate":
			meditating = false
		elif state != null:
			var near_cushion_bonus: float = 1.25 if Vector2(actor.position.x, actor.position.z).distance_to(actor.cushion_xz) <= 1.5 else 1.0
			state.meditation_seconds += delta
			state.add_qi(1.8 * meditation_mult * near_cushion_bonus * delta)
			state.add_insight(3.4 * meditation_mult * near_cushion_bonus * delta)

	if phase != "none":
		_phase_timer += delta
		match phase:
			"casting":
				if _phase_timer >= _phase_duration:
					phase = "waiting"
					_phase_timer = 0.0
					_phase_duration = _rng.randf_range(3.2, 5.8)
			"waiting":
				if _phase_timer >= _phase_duration:
					phase = "biting"
					_phase_timer = 0.0
					_phase_duration = 1.65
					bite_progress = 0.0
					fish_bite_started.emit()
			"biting":
				bite_progress = clampf(_phase_timer / maxf(0.1, _phase_duration), 0.0, 1.0)
				if _phase_timer >= _phase_duration:
					# Wallpaper / Semi-idle friendly: auto-completes as 太公忘机钓!
					_complete_catch(state, "auto", fishing_mult)
			"cooldown":
				if _phase_timer >= _phase_duration:
					phase = "casting"
					_phase_timer = 0.0
					_phase_duration = 0.38
		_draw_fishing_visuals(actor)

	_draw_breakthrough_wave(delta)

func _draw_fishing_visuals(actor: Actor) -> void:
	_line_im.clear_surfaces()
	if actor == null or phase == "none":
		return
	var rod_tip: Vector3 = actor.rod_tip_global()
	var cast_t: float = clampf(_phase_timer / maxf(0.01, _phase_duration), 0.0, 1.0) if phase == "casting" else 1.0
	var bob_dip: float = -0.09 * absf(sin(_ripple_time * 13.0)) if phase == "biting" else sin(_ripple_time * 2.4) * 0.022
	var target_pos := Vector3(bobber_xz.x, water_y + 0.03 + bob_dip, bobber_xz.y)
	var cur_bob: Vector3 = rod_tip.lerp(target_pos, cast_t)
	if phase == "casting":
		cur_bob.y += sin(cast_t * PI) * 0.85
	_bobber_node.global_position = cur_bob

	_line_im.surface_begin(Mesh.PRIMITIVE_LINES)
	# 1. Silk fishing line catenary
	var segs: int = 12
	var line_col := Color(0.88, 0.94, 0.90, 0.72)
	for i: int in segs:
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var p0: Vector3 = rod_tip.lerp(cur_bob, t0) - Vector3(0.0, sin(t0 * PI) * 0.18, 0.0)
		var p1: Vector3 = rod_tip.lerp(cur_bob, t1) - Vector3(0.0, sin(t1 * PI) * 0.18, 0.0)
		_line_im.surface_set_color(line_col)
		_line_im.surface_add_vertex(p0)
		_line_im.surface_set_color(line_col)
		_line_im.surface_add_vertex(p1)

	# 2. Concentric celadon water ripples
	if phase in ["waiting", "biting", "cooldown"]:
		var speed: float = 1.6 if phase == "biting" else 0.65
		var max_r: float = 0.95 if phase == "biting" else 0.62
		for r_idx: int in 2:
			var prog: float = fposmod(_ripple_time * speed + float(r_idx) * 0.5, 1.0)
			var rad: float = 0.10 + prog * max_r
			var alpha: float = (1.0 - prog) * (0.68 if phase == "biting" else 0.36)
			_add_circle_lines(_line_im, Vector3(bobber_xz.x, water_y + 0.025, bobber_xz.y), rad, Color(0.76, 0.95, 0.88, alpha), 28)

	# 3. Bite timing ring directly on water surface (for pure diegetic 3D play!)
	if phase == "biting":
		var outer_r: float = lerpf(0.92, 0.18, bite_progress)
		var sweet: bool = is_in_perfect_window()
		var ring_col: Color = Color(0.98, 0.86, 0.46, 0.92) if sweet else Color(0.68, 0.92, 0.84, 0.78)
		_add_circle_lines(_line_im, Vector3(bobber_xz.x, water_y + 0.04, bobber_xz.y), outer_r, ring_col, 32)
		# Inner sweet-spot reference ring
		_add_circle_lines(_line_im, Vector3(bobber_xz.x, water_y + 0.035, bobber_xz.y), 0.42, Color(0.95, 0.84, 0.52, 0.40), 24)
	_line_im.surface_end()

func _draw_breakthrough_wave(delta: float) -> void:
	if _breakthrough_wave_t < 0.0:
		return
	_breakthrough_wave_t += delta
	_wave_im.clear_surfaces()
	if _breakthrough_wave_t >= 1.5:
		_breakthrough_wave_t = -1.0
		return
	var prog: float = _breakthrough_wave_t / 1.5
	var eased: float = 1.0 - pow(1.0 - prog, 3.0)
	var r1: float = 0.6 + eased * 18.0
	var r2: float = maxf(0.3, r1 - 1.8)
	var alpha: float = (1.0 - prog) * 0.85
	_wave_im.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_circle_lines(_wave_im, _breakthrough_origin + Vector3(0.0, 0.18, 0.0), r1, Color(0.98, 0.88, 0.54, alpha), 48)
	_add_circle_lines(_wave_im, _breakthrough_origin + Vector3(0.0, 0.14, 0.0), r2, Color(0.64, 0.92, 0.82, alpha * 0.75), 48)
	_wave_im.surface_end()

static func _add_circle_lines(im: ImmediateMesh, center: Vector3, radius: float, col: Color, segments: int) -> void:
	for i: int in segments:
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		im.surface_set_color(col)
		im.surface_add_vertex(center + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius))
		im.surface_set_color(col)
		im.surface_add_vertex(center + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius))

# --- Spatial Shoreline Spot Solver ---

static func find_fishing_spot_near(query_xz: Vector2, surface_query: Callable, search_radius: float = 6.5, actor_xz: Vector2 = Vector2.INF) -> Dictionary:
	# Find nearest water surface point around query_xz.
	var best_water := Vector2.INF
	var best_water_dist: float = INF
	var best_water_level: int = -1
	var step: float = 0.65
	var steps: int = ceili(search_radius / step)
	for dz: int in range(-steps, steps + 1):
		for dx: int in range(-steps, steps + 1):
			var cand := query_xz + Vector2(float(dx) * step, float(dz) * step)
			var d2: float = query_xz.distance_squared_to(cand)
			if d2 > search_radius * search_radius or d2 >= best_water_dist:
				continue
			var s: Dictionary = surface_query.call(cand)
			if not s.is_empty() and int(s.get("water", -1)) >= 0:
				best_water_dist = d2
				best_water = cand
				best_water_level = int(s.get("water", 3))
	if not best_water.is_finite():
		return {}

	# Cast 32 radial rays out to 9.5m so clicking the center of a wide pond still finds its shoreline.
	var best_stand := Vector2.INF
	var best_shore_water := best_water
	var best_score: float = INF
	for angle_i: int in 32:
		var ang: float = TAU * float(angle_i) / 32.0
		var dir := Vector2(cos(ang), sin(ang))
		var last_wet: Vector2 = best_water
		for step_i: int in range(1, 20):
			var dist: float = float(step_i) * 0.5
			var stand_cand: Vector2 = best_water + dir * dist
			var ss: Dictionary = surface_query.call(stand_cand)
			if ss.is_empty():
				break
			var w_lvl: int = int(ss.get("water", -1))
			if w_lvl >= 0:
				if w_lvl == best_water_level:
					last_wet = stand_cand
				continue
			var stand_h: float = float(ss.get("height", 1.5))
			var water_h: float = float(best_water_level) * 0.5
			if stand_h < water_h - 0.25 or stand_h > water_h + 0.65:
				continue
			# Verify flat meadow bank margin away from outer void and terrace step cliffs
			var safe: bool = true
			for off: Vector2 in [Vector2(0.52, 0.0), Vector2(-0.52, 0.0), Vector2(0.0, 0.52), Vector2(0.0, -0.52)]:
				var ns: Dictionary = surface_query.call(stand_cand + off)
				if ns.is_empty():
					safe = false
					break
				if int(ns.get("water", -1)) < 0 and absf(float(ns.get("height", stand_h)) - stand_h) > 0.60:
					safe = false
					break
			if not safe:
				continue
			var score: float = stand_cand.distance_to(query_xz)
			if actor_xz.is_finite():
				score += stand_cand.distance_to(actor_xz) * 0.75
			if score < best_score:
				best_score = score
				best_stand = stand_cand
				best_shore_water = last_wet
			break
	if not best_stand.is_finite():
		return {}

	# Place bobber 1.3..2.1m off the shoreline into the same pond level.
	var into_water: Vector2 = (best_shore_water - best_stand).normalized()
	if into_water.length_squared() < 0.001:
		into_water = (best_water - best_stand).normalized()
	var final_bobber: Vector2 = best_shore_water
	for push: float in [1.9, 1.45, 1.0, 0.65]:
		var probe: Vector2 = best_stand + into_water * push
		var ps: Dictionary = surface_query.call(probe)
		if not ps.is_empty() and int(ps.get("water", -1)) == best_water_level:
			final_bobber = probe
			break

	return {
		"stand_xz": best_stand,
		"bobber_xz": final_bobber,
		"water_y": float(best_water_level) * 0.5,
	}
