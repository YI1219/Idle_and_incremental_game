class_name CultivatorActor
extends Node3D
## Playable & semi-autonomous xianxia cultivator in the Sea of Consciousness.
## Supports WASD/Stick movement, Wind Dash (踏风步), BG3-style click-to-move/interact,
## and autonomous idle life (strolling, fishing, meditating on the rush cushion).

signal arrived_for_action(action: String, target_xz: Vector2, aux_xz: Vector2)
signal activity_changed(new_activity: String)
signal manual_interrupted

const SurfaceBuilder = preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface
const GrassMap = preload("res://scripts/gameplay/systems/grass_compression_map.gd")

const WALK_SPEED: float = 4.5
const DASH_SPEED: float = 10.8
const DASH_DURATION: float = 0.22
const DASH_COOLDOWN: float = 0.68
const MAX_STEP_HEIGHT: float = 2.2
const AUTO_IDLE_DELAY: float = 9.5

var activity: String = "idle"
var facing_yaw: float = 0.0
var cushion_xz: Vector2 = Vector2(-5.0, -4.2)
var cushion_node: Node3D
var force_autonomous: bool = false

var _visual_root: Node3D
var _body_mesh: MeshInstance3D
var _sitting_mesh: MeshInstance3D
var _rod_node: Node3D
var _aura_ring: MeshInstance3D
var _vertex_mat: ShaderMaterial

var _nav_active: bool = false
var _nav_target: Vector2 = Vector2.ZERO
var _nav_waypoints: Array[Vector2] = []
var _nav_path_computed: bool = false
var _nav_arrival_radius: float = 0.35
var _nav_action: String = ""
var _nav_aux_xz: Vector2 = Vector2.ZERO

var _dash_timer: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _anim_phase: float = 0.0
var _footstep_accum: float = 0.0
var _idle_since_manual: float = 0.0
var _ai_timer: float = 3.5
var _ai_stage: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 20261104
	_vertex_mat = ShaderMaterial.new()
	_vertex_mat.shader = preload("res://shaders/terrain_editor/decor_vertex_color.gdshader")
	_vertex_mat.set_shader_parameter("linear_vertex_color", true)
	preload("res://scripts/terrain_editor/material_detail.gd").bind(_vertex_mat)

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	_body_mesh = _build_standing_cultivator()
	_visual_root.add_child(_body_mesh)

	_sitting_mesh = _build_sitting_cultivator()
	_sitting_mesh.visible = false
	_visual_root.add_child(_sitting_mesh)

	_rod_node = _build_bamboo_rod()
	_rod_node.visible = false
	_visual_root.add_child(_rod_node)

	_aura_ring = _build_aura_ring()
	_aura_ring.visible = false
	add_child(_aura_ring)

func create_cushion_prop(parent: Node3D) -> Node3D:
	if cushion_node != null and is_instance_valid(cushion_node):
		return cushion_node
	cushion_node = _build_rush_cushion()
	parent.add_child(cushion_node)
	return cushion_node

func rod_tip_global() -> Vector3:
	if _rod_node != null and _rod_node.visible:
		return _rod_node.to_global(Vector3(0.0, 1.42, 1.92))
	return global_position + Vector3(0.0, 1.35, 0.0)

func set_activity(next_activity: String, look_toward_xz: Variant = null) -> void:
	if look_toward_xz is Vector2:
		var delta_xz: Vector2 = (look_toward_xz as Vector2) - Vector2(position.x, position.z)
		if delta_xz.length_squared() > 0.001:
			facing_yaw = atan2(delta_xz.x, delta_xz.y)
			_visual_root.rotation.y = facing_yaw
	if activity == next_activity:
		_sync_posture()
		return
	activity = next_activity
	_sync_posture()
	activity_changed.emit(activity)

func _sync_posture() -> void:
	var sitting: bool = (activity == "meditate")
	if _body_mesh != null:
		_body_mesh.visible = not sitting
	if _sitting_mesh != null:
		_sitting_mesh.visible = sitting
	if _rod_node != null:
		_rod_node.visible = (activity == "fishing")
	if _aura_ring != null:
		_aura_ring.visible = sitting or (_dash_timer > 0.0)

func command_walk_to(target_xz: Vector2, action_on_arrive: String = "", aux_xz: Vector2 = Vector2.ZERO, arrival_radius: float = 0.42, is_manual: bool = true) -> void:
	if is_manual:
		_idle_since_manual = 0.0
	if activity in ["fishing", "meditate"]:
		manual_interrupted.emit()
	_nav_active = true
	_nav_target = target_xz
	_nav_waypoints.clear()
	_nav_path_computed = false
	_nav_action = action_on_arrive
	_nav_aux_xz = aux_xz
	_nav_arrival_radius = arrival_radius
	if activity != "dash":
		set_activity("walk")

func trigger_dash(move_dir_world: Vector2) -> bool:
	if _dash_cd > 0.0 or _dash_timer > 0.0:
		return false
	_idle_since_manual = 0.0
	_nav_active = false
	_nav_waypoints.clear()
	if activity in ["fishing", "meditate"]:
		manual_interrupted.emit()
	var d: Vector2 = move_dir_world.normalized() if move_dir_world.length_squared() > 0.01 else Vector2(sin(facing_yaw), cos(facing_yaw))
	_dash_dir = d
	_dash_timer = DASH_DURATION
	_dash_cd = DASH_COOLDOWN
	facing_yaw = atan2(d.x, d.y)
	set_activity("dash")
	return true

func cancel_navigation() -> void:
	_nav_active = false
	_nav_waypoints.clear()
	_nav_path_computed = false
	_nav_action = ""
	if activity == "walk":
		set_activity("idle")

func step_actor(delta: float, manual_move_world: Vector2, surface_query: Callable, grass_map: GrassMap, ai_fishing_finder: Callable) -> void:
	if delta <= 0.0:
		return
	_anim_phase += delta
	if _dash_cd > 0.0:
		_dash_cd = maxf(0.0, _dash_cd - delta)

	var current_xz := Vector2(position.x, position.z)
	var cur_surface: Dictionary = surface_query.call(current_xz)
	var cur_h: float = float(cur_surface.get("height", position.y))

	# 1. Active wind-dash overrides normal locomotion.
	if _dash_timer > 0.0:
		_dash_timer = maxf(0.0, _dash_timer - delta)
		var moved_xz: Vector2 = _try_advance(current_xz, cur_h, _dash_dir * DASH_SPEED * delta, surface_query)
		_apply_world_pos(moved_xz, surface_query, delta)
		if grass_map != null:
			grass_map.stamp_circle(moved_xz, 1.05, 0.56)
		if _dash_timer <= 0.0:
			set_activity("idle")
		_animate_visuals(delta)
		return

	# 2. Direct manual WASD / Left-stick input immediately overrides auto-walk & idle routines.
	if manual_move_world.length_squared() > 0.004:
		_idle_since_manual = 0.0
		if _nav_active:
			_nav_active = false
			_nav_waypoints.clear()
			_nav_action = ""
		if activity in ["fishing", "meditate"]:
			manual_interrupted.emit()
		set_activity("walk")
		var step_vec: Vector2 = manual_move_world.limit_length(1.0) * WALK_SPEED * delta
		var next_xz: Vector2 = _try_advance(current_xz, cur_h, step_vec, surface_query)
		var actual_dir: Vector2 = next_xz - current_xz
		if actual_dir.length_squared() > 0.00001:
			facing_yaw = lerp_angle(facing_yaw, atan2(actual_dir.x, actual_dir.y), 1.0 - exp(-14.0 * delta))
		else:
			facing_yaw = lerp_angle(facing_yaw, atan2(manual_move_world.x, manual_move_world.y), 1.0 - exp(-14.0 * delta))
		_apply_world_pos(next_xz, surface_query, delta)
		_stamp_footsteps(delta, next_xz, grass_map)
		_animate_visuals(delta)
		return

	# 3. Point-and-click / AI navigation toward target (with BFS pond/cliff avoidance).
	if _nav_active:
		if not _nav_path_computed:
			_nav_path_computed = true
			_nav_waypoints = _build_nav_waypoints(current_xz, _nav_target, surface_query)
		while _nav_waypoints.size() > 1 and current_xz.distance_to(_nav_waypoints[0]) <= 0.48:
			_nav_waypoints.remove_at(0)
		var active_goal: Vector2 = _nav_waypoints[0] if not _nav_waypoints.is_empty() else _nav_target
		var is_final_wp: bool = _nav_waypoints.size() <= 1
		var to_goal: Vector2 = active_goal - current_xz
		var arrive_r: float = _nav_arrival_radius if is_final_wp else 0.48
		if to_goal.length() <= arrive_r:
			if not is_final_wp:
				_nav_waypoints.remove_at(0)
			else:
				_nav_active = false
				_nav_waypoints.clear()
				var done_action: String = _nav_action
				var aux: Vector2 = _nav_aux_xz
				_nav_action = ""
				if done_action == "":
					set_activity("idle")
				else:
					arrived_for_action.emit(done_action, current_xz, aux)
		else:
			set_activity("walk")
			var dir: Vector2 = _steer_direction(current_xz, cur_h, to_goal.normalized(), surface_query)
			var step_len: float = minf(WALK_SPEED * delta, to_goal.length())
			var next_xz: Vector2 = _try_advance(current_xz, cur_h, dir * step_len, surface_query)
			if next_xz.distance_squared_to(current_xz) < 0.000004:
				_nav_active = false
				_nav_waypoints.clear()
				var blocked_action: String = _nav_action
				var blocked_aux: Vector2 = _nav_aux_xz
				_nav_action = ""
				if blocked_action != "" and current_xz.distance_to(_nav_target) < 2.2:
					arrived_for_action.emit(blocked_action, current_xz, blocked_aux)
				else:
					set_activity("idle")
			else:
				facing_yaw = lerp_angle(facing_yaw, atan2(dir.x, dir.y), 1.0 - exp(-12.0 * delta))
				_apply_world_pos(next_xz, surface_query, delta)
				_stamp_footsteps(delta, next_xz, grass_map)
		_animate_visuals(delta)
		return

	# 4. Stationary states (idle, fishing, meditate) + grass impression + semi-autonomous AI.
	if activity == "walk":
		set_activity("idle")
	_apply_world_pos(current_xz, surface_query, delta)
	if grass_map != null:
		if activity == "meditate":
			grass_map.stamp_circle(current_xz, 1.15, 0.55)
		elif activity == "fishing":
			grass_map.stamp_circle(current_xz, 0.85, 0.36)

	_idle_since_manual += delta
	if force_autonomous or (activity == "idle" and _idle_since_manual >= AUTO_IDLE_DELAY):
		_tick_autonomous_life(delta, current_xz, surface_query, ai_fishing_finder)

	_animate_visuals(delta)

func _build_nav_waypoints(start_xz: Vector2, goal_xz: Vector2, surface_query: Callable) -> Array[Vector2]:
	var s_surf: Dictionary = surface_query.call(start_xz)
	var cur_h: float = float(s_surf.get("height", position.y))
	if _line_walkable(start_xz, goal_xz, cur_h, surface_query):
		return [goal_xz]
	var start_c := Vector2i(start_xz.floor())
	var goal_c := Vector2i(goal_xz.floor())
	var queue: Array[Vector2i] = [start_c]
	var came_from: Dictionary = {start_c: start_c}
	var heights: Dictionary = {start_c: cur_h}
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	var best_cell: Vector2i = start_c
	var best_dist: float = (Vector2(start_c) + Vector2(0.5, 0.5)).distance_squared_to(goal_xz)
	var head: int = 0
	while head < queue.size() and head < 850:
		var c: Vector2i = queue[head]
		head += 1
		if c == goal_c:
			best_cell = c
			break
		var ch: float = float(heights[c])
		for d: Vector2i in dirs:
			var nc: Vector2i = c + d
			if came_from.has(nc) or absi(nc.x) > 40 or absi(nc.y) > 34:
				continue
			var np := Vector2(float(nc.x) + 0.5, float(nc.y) + 0.5)
			if not _is_walkable(np, ch, surface_query):
				continue
			var ns: Dictionary = surface_query.call(np)
			var nh: float = float(ns.get("height", ch))
			came_from[nc] = c
			heights[nc] = nh
			queue.append(nc)
			var d2: float = np.distance_squared_to(goal_xz)
			if d2 < best_dist:
				best_dist = d2
				best_cell = nc
	if best_cell == start_c:
		return [goal_xz]
	var raw_pts: Array[Vector2] = []
	var trace: Vector2i = best_cell
	while trace != start_c:
		raw_pts.push_front(Vector2(float(trace.x) + 0.5, float(trace.y) + 0.5))
		trace = came_from[trace] as Vector2i
	if best_cell == goal_c:
		raw_pts[raw_pts.size() - 1] = goal_xz
	return raw_pts

func _line_walkable(a: Vector2, b: Vector2, start_h: float, surface_query: Callable) -> bool:
	var dist: float = a.distance_to(b)
	var steps: int = maxi(1, ceili(dist / 0.55))
	var ref_h: float = start_h
	for i: int in range(1, steps + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		if not _is_walkable(p, ref_h, surface_query):
			return false
		var s: Dictionary = surface_query.call(p)
		ref_h = float(s.get("height", ref_h))
	return true

func _tick_autonomous_life(delta: float, current_xz: Vector2, surface_query: Callable, ai_fishing_finder: Callable) -> void:
	_ai_timer -= delta
	if _ai_timer > 0.0:
		return
	_ai_stage = (_ai_stage + 1) % 3
	if _ai_stage == 1 and ai_fishing_finder.is_valid():
		var spot: Dictionary = ai_fishing_finder.call(current_xz)
		if not spot.is_empty():
			var stand: Vector2 = spot["stand_xz"] as Vector2
			var bobber: Vector2 = spot["bobber_xz"] as Vector2
			_ai_timer = _rng.randf_range(18.0, 26.0)
			command_walk_to(stand, "fish", bobber, 0.55, false)
			return
	if _ai_stage == 2:
		var c_surf: Dictionary = surface_query.call(cushion_xz)
		if not c_surf.is_empty() and int(c_surf.get("water", -1)) < 0:
			_ai_timer = _rng.randf_range(16.0, 24.0)
			command_walk_to(cushion_xz, "meditate", cushion_xz + Vector2(0.0, 2.0), 0.48, false)
			return
	# Scenic stroll to a random nearby dry meadow point.
	for attempt: int in 10:
		var candidate := current_xz + Vector2(_rng.randf_range(-6.5, 6.5), _rng.randf_range(-5.0, 5.0))
		var s: Dictionary = surface_query.call(candidate)
		if not s.is_empty() and int(s.get("water", -1)) < 0:
			_ai_timer = _rng.randf_range(6.0, 10.0)
			command_walk_to(candidate, "", Vector2.ZERO, 0.45, false)
			return
	_ai_timer = 5.0

func _steer_direction(origin: Vector2, cur_h: float, desired: Vector2, surface_query: Callable) -> Vector2:
	if _is_walkable(origin + desired * 0.75, cur_h, surface_query):
		return desired
	for deg: float in [32.0, -32.0, 64.0, -64.0, 95.0, -95.0]:
		var cand: Vector2 = desired.rotated(deg_to_rad(deg))
		if _is_walkable(origin + cand * 0.75, cur_h, surface_query):
			return cand
	return desired

func _try_advance(origin: Vector2, cur_h: float, delta_xz: Vector2, surface_query: Callable) -> Vector2:
	var target: Vector2 = origin + delta_xz
	if _is_walkable(target, cur_h, surface_query):
		return target
	# Try sliding along X or Z at pond banks / cliff edges.
	var slide_x := Vector2(origin.x + delta_xz.x, origin.y)
	if absf(delta_xz.x) > 0.0001 and _is_walkable(slide_x, cur_h, surface_query):
		return slide_x
	var slide_z := Vector2(origin.x, origin.y + delta_xz.y)
	if absf(delta_xz.y) > 0.0001 and _is_walkable(slide_z, cur_h, surface_query):
		return slide_z
	return origin

func _is_walkable(xz: Vector2, ref_h: float, surface_query: Callable) -> bool:
	var s: Dictionary = surface_query.call(xz)
	if s.is_empty() or int(s.get("water", -1)) >= 0:
		return false
	var h: float = float(s.get("height", ref_h))
	if absf(h - ref_h) > MAX_STEP_HEIGHT:
		return false
	# Keep a small safety margin inside outer cliff rims.
	for offset: Vector2 in [Vector2(0.28, 0.0), Vector2(-0.28, 0.0), Vector2(0.0, 0.28), Vector2(0.0, -0.28)]:
		var ns: Dictionary = surface_query.call(xz + offset)
		if ns.is_empty():
			return false
	return true

func _apply_world_pos(xz: Vector2, surface_query: Callable, delta: float) -> void:
	var s: Dictionary = surface_query.call(xz)
	var target_y: float = float(s.get("height", position.y)) if not s.is_empty() else position.y
	var smooth_y: float = lerpf(position.y, target_y, 1.0 - exp(-16.0 * delta))
	position = Vector3(xz.x, smooth_y, xz.y)

func _stamp_footsteps(delta: float, xz: Vector2, grass_map: GrassMap) -> void:
	if grass_map == null:
		return
	_footstep_accum += delta
	grass_map.stamp_circle(xz, 0.88, 0.45)

func _animate_visuals(_delta: float) -> void:
	_visual_root.rotation.y = facing_yaw
	if activity == "walk":
		_visual_root.position.y = absf(sin(_anim_phase * 7.5)) * 0.035
		_visual_root.rotation.x = 0.045
		_visual_root.rotation.z = sin(_anim_phase * 7.5) * 0.025
	elif activity == "dash":
		_visual_root.position.y = 0.08
		_visual_root.rotation.x = 0.16
		_visual_root.rotation.z = 0.0
	elif activity == "meditate":
		_visual_root.position.y = 0.02 + sin(_anim_phase * 1.8) * 0.018
		_visual_root.rotation.x = 0.0
		_visual_root.rotation.z = 0.0
	elif activity == "fishing":
		_visual_root.position.y = sin(_anim_phase * 1.5) * 0.01
		_visual_root.rotation.x = 0.02
		_visual_root.rotation.z = 0.0
		if _rod_node != null:
			_rod_node.rotation.x = sin(_anim_phase * 1.9) * 0.025
	else:
		_visual_root.position.y = sin(_anim_phase * 2.0) * 0.012
		_visual_root.rotation.x = 0.0
		_visual_root.rotation.z = 0.0

	if _aura_ring != null and _aura_ring.visible:
		_aura_ring.rotation.y = _anim_phase * 0.55
		var pulse: float = 1.0 + sin(_anim_phase * 2.4) * 0.06
		_aura_ring.scale = Vector3(pulse, 1.0, pulse)

# --- Procedural Broad-Plane Song-Dynasty Xianxia Meshes ---

static func _add_tapered_prism(builder: RefCounted, base_center: Vector3, bottom_size: Vector2, top_size: Vector2, height: float, color: Color, sides: int = 6, top_offset: Vector2 = Vector2.ZERO) -> void:
	var bot_ring: Array[Vector3] = []
	var top_ring: Array[Vector3] = []
	for i: int in sides:
		var ang: float = TAU * float(i) / float(sides) + PI / float(sides)
		var ca: float = cos(ang)
		var sa: float = sin(ang)
		bot_ring.append(base_center + Vector3(ca * bottom_size.x * 0.5, 0.0, sa * bottom_size.y * 0.5))
		top_ring.append(base_center + Vector3(top_offset.x + ca * top_size.x * 0.5, height, top_offset.y + sa * top_size.y * 0.5))
	for i: int in sides:
		var ni: int = (i + 1) % sides
		var shade: float = 0.92 + 0.12 * cos(TAU * float(i) / float(sides))
		builder.quad(bot_ring[i], bot_ring[ni], top_ring[ni], top_ring[i], color * shade)
	# Cap top
	var top_c: Vector3 = base_center + Vector3(top_offset.x, height, top_offset.y)
	for i: int in sides:
		var ni: int = (i + 1) % sides
		builder.triangle(top_c, top_ring[ni], top_ring[i], color * 1.06, true)

static func _add_box_part(builder: RefCounted, center: Vector3, size: Vector3, rot_euler: Vector3, color: Color) -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var b := Basis.from_euler(rot_euler)
	var v: Array[Vector3] = [
		center + b * Vector3(-hx,  hy, -hz),
		center + b * Vector3( hx,  hy, -hz),
		center + b * Vector3( hx,  hy,  hz),
		center + b * Vector3(-hx,  hy,  hz),
		center + b * Vector3(-hx, -hy, -hz),
		center + b * Vector3( hx, -hy, -hz),
		center + b * Vector3( hx, -hy,  hz),
		center + b * Vector3(-hx, -hy,  hz),
	]
	builder.quad(v[0], v[1], v[2], v[3], color * 1.06, true)
	builder.quad(v[7], v[6], v[5], v[4], color * 0.78)
	builder.quad(v[3], v[2], v[6], v[7], color * 0.98)
	builder.quad(v[1], v[0], v[4], v[5], color * 0.86)
	builder.quad(v[0], v[3], v[7], v[4], color * 0.90)
	builder.quad(v[2], v[1], v[5], v[6], color * 0.92)

static func _add_smooth_loft(builder: RefCounted, rings: Array, sides: int, c_bot: Color, c_top: Color, cap_top: bool = false) -> void:
	# Smooth-shaded silk-robe loft: rings = [[center: Vector3, radii: Vector2, rot_x: float], ...]
	if rings.size() < 2:
		return
	var v_rings: Array = []
	var n_rings: Array = []
	var cols: Array[Color] = []
	for r_i: int in rings.size():
		var t: float = float(r_i) / float(rings.size() - 1)
		var spec: Array = rings[r_i]
		var c: Vector3 = spec[0]
		var rad: Vector2 = spec[1]
		var rx: float = float(spec[2]) if spec.size() > 2 else 0.0
		var basis_r := Basis.from_euler(Vector3(rx, 0.0, 0.0))
		var pts: Array[Vector3] = []
		var nrms: Array[Vector3] = []
		for s: int in sides:
			var a: float = TAU * float(s) / float(sides)
			var ca := cos(a)
			var sa := sin(a)
			var fold := 1.0 + 0.035 * cos(a * 4.0) * (1.0 - t * 0.7)
			var local := Vector3(ca * rad.x * 0.5 * fold, 0.0, sa * rad.y * 0.5 * fold)
			pts.append(c + basis_r * local)
			var n_local := Vector3(ca / maxf(rad.x, 0.02), 0.18, sa / maxf(rad.y, 0.02)).normalized()
			nrms.append((basis_r * n_local).normalized())
		v_rings.append(pts)
		n_rings.append(nrms)
		cols.append(c_bot.lerp(c_top, t))

	for r_i: int in range(rings.size() - 1):
		var r0: Array = v_rings[r_i]
		var r1: Array = v_rings[r_i + 1]
		var n0: Array = n_rings[r_i]
		var n1: Array = n_rings[r_i + 1]
		var col0: Color = cols[r_i]
		var col1: Color = cols[r_i + 1]
		for s: int in sides:
			var ns: int = (s + 1) % sides
			var p_a: Vector3 = r0[s]; var p_b: Vector3 = r0[ns]; var p_c: Vector3 = r1[ns]; var p_d: Vector3 = r1[s]
			var fn := -(p_b - p_a).cross(p_c - p_a)
			var out_n: Vector3 = n0[s] + n0[ns] + n1[ns] + n1[s]
			var tris: Array = [[p_a, n0[s], col0], [p_b, n0[ns], col0], [p_c, n1[ns], col1], [p_a, n0[s], col0], [p_c, n1[ns], col1], [p_d, n1[s], col1]]
			if fn.dot(out_n) < 0.0:
				tris = [[p_a, n0[s], col0], [p_c, n1[ns], col1], [p_b, n0[ns], col0], [p_a, n0[s], col0], [p_d, n1[s], col1], [p_c, n1[ns], col1]]
			for item: Array in tris:
				builder.vertices.append(item[0])
				builder.normals.append(item[1])
				builder.colors.append(item[2])
				builder.uv.append(Vector2(clampf((item[0] as Vector3).y / 1.8, 0.0, 1.0), 0.05))

	if cap_top:
		var top_pts: Array[Vector3] = v_rings[rings.size() - 1]
		var top_c: Vector3 = rings[rings.size() - 1][0]
		var top_col: Color = cols[rings.size() - 1] * 1.03
		for s: int in sides:
			var ns: int = (s + 1) % sides
			var p_ns: Vector3 = top_pts[ns]
			var p_s: Vector3 = top_pts[s]
			var fn: Vector3 = -(p_ns - top_c).cross(p_s - top_c)
			var v1: Vector3 = p_ns if fn.y >= 0.0 else p_s
			var v2: Vector3 = p_s if fn.y >= 0.0 else p_ns
			var tri_vs: Array[Vector3] = [top_c, v1, v2]
			for vp: Vector3 in tri_vs:
				builder.vertices.append(vp)
				builder.normals.append(Vector3.UP)
				builder.colors.append(top_col)
				builder.uv.append(Vector2(1.0, 0.05))

func _build_standing_cultivator() -> MeshInstance3D:
	var b := SurfaceBuilder.new()
	# Serene Song-painting white-celadon scholar-immortal robe (素衣广袖高士, zero T-pose boxes!)
	var c_robe_low := Color(0.66, 0.71, 0.70)
	var c_robe_hi := Color(0.90, 0.91, 0.87)
	var c_hem := Color(0.045, 0.085, 0.095)
	var c_sash := Color(0.035, 0.070, 0.082)
	var c_skin := Color(0.64, 0.50, 0.40)
	var c_hair := Color(0.020, 0.024, 0.030)
	var c_jade := Color(0.26, 0.54, 0.44)

	# 1. Smooth flowing white silk skirt & crossed-collar upper robe (14-sided smooth loft, pure white hem on grass!)
	_add_smooth_loft(b, [
		[Vector3(0.0, 0.00, -0.02), Vector2(0.52, 0.46)],
		[Vector3(0.0, 0.16, -0.01), Vector2(0.47, 0.41)],
		[Vector3(0.0, 0.50,  0.00), Vector2(0.37, 0.31)],
		[Vector3(0.0, 0.88,  0.00), Vector2(0.27, 0.22)],
	], 14, c_robe_low, c_robe_hi, false)
	# Dark pine-ink waist sash
	_add_smooth_loft(b, [
		[Vector3(0.0, 0.87, 0.00), Vector2(0.285, 0.235)],
		[Vector3(0.0, 0.96, 0.00), Vector2(0.280, 0.230)],
	], 14, c_sash, c_sash * 1.08, false)
	# Slender sloped shoulders
	_add_smooth_loft(b, [
		[Vector3(0.0, 0.95, 0.00), Vector2(0.27, 0.22)],
		[Vector3(0.0, 1.24, 0.00), Vector2(0.35, 0.24)],
		[Vector3(0.0, 1.38, 0.00), Vector2(0.20, 0.17)],
	], 14, c_robe_hi * 0.96, c_robe_hi * 1.04, true)
	# Dark crossed lapel trim & waist jade ribbon
	_add_smooth_loft(b, [
		[Vector3(0.0, 0.46, 0.14), Vector2(0.075, 0.025)],
		[Vector3(0.0, 0.88, 0.115), Vector2(0.065, 0.025)],
	], 8, c_jade * 0.85, c_jade, false)
	_add_smooth_loft(b, [
		[Vector3(0.0, 1.12, 0.112), Vector2(0.08, 0.03)],
		[Vector3(0.0, 1.36, 0.082), Vector2(0.15, 0.04)],
	], 8, c_hem, c_hem * 1.05, false)

	# 2. Gracefully draped wide hanfu sleeves (广袖垂落: flaring gently at elbows like Ref 1!)
	for side_s: float in [-1.0, 1.0]:
		_add_smooth_loft(b, [
			[Vector3(side_s * 0.16, 1.31,  0.00), Vector2(0.14, 0.15),  0.08],
			[Vector3(side_s * 0.27, 1.11,  0.03), Vector2(0.18, 0.23),  0.22],
			[Vector3(side_s * 0.21, 0.93,  0.09), Vector2(0.17, 0.28),  0.28],
			[Vector3(side_s * 0.10, 0.80,  0.11), Vector2(0.12, 0.24),  0.18],
			[Vector3(side_s * 0.07, 0.72,  0.10), Vector2(0.07, 0.15),  0.08],
		], 10, c_robe_hi, c_robe_low * 0.96, true)

	# 3. Smooth neck, oval head, long flowing ink hair drape & jade hairpin crown
	_add_smooth_loft(b, [
		[Vector3(0.0, 1.37, 0.00), Vector2(0.10, 0.10)],
		[Vector3(0.0, 1.45, 0.00), Vector2(0.095, 0.095)],
	], 10, c_skin * 0.90, c_skin, false)
	_add_smooth_loft(b, [
		[Vector3(0.0, 1.44, 0.00), Vector2(0.14, 0.15)],
		[Vector3(0.0, 1.54, 0.00), Vector2(0.185, 0.195)],
		[Vector3(0.0, 1.64, 0.00), Vector2(0.155, 0.165)],
	], 12, c_skin * 0.95, c_skin * 1.02, true)
	# Neat Song-dynasty scholar-immortal bound hair & topknot (束发青玉冠, keeps white back robe pure like Ref 1!)
	_add_smooth_loft(b, [
		[Vector3(0.0, 1.39, -0.055), Vector2(0.11, 0.055)],
		[Vector3(0.0, 1.56, -0.025), Vector2(0.185, 0.145)],
		[Vector3(0.0, 1.66, -0.010), Vector2(0.155, 0.155)],
	], 10, c_hair, c_hair * 1.15, true)
	# Topknot & celadon jade crown (束发青玉冠)
	_add_smooth_loft(b, [
		[Vector3(0.0, 1.65, -0.015), Vector2(0.082, 0.082)],
		[Vector3(0.0, 1.74, -0.020), Vector2(0.060, 0.060)],
	], 10, c_hair * 1.1, c_jade * 0.95, true)

	var inst := MeshInstance3D.new()
	inst.name = "StandingBody"
	inst.mesh = b.mesh()
	inst.material_override = _vertex_mat
	return inst

func _build_sitting_cultivator() -> MeshInstance3D:
	var b := SurfaceBuilder.new()
	var c_robe_low := Color(0.58, 0.63, 0.61)
	var c_robe_hi := Color(0.76, 0.78, 0.74)
	var c_hem := Color(0.045, 0.085, 0.095)
	var c_sash := Color(0.035, 0.070, 0.082)
	var c_skin := Color(0.64, 0.50, 0.40)
	var c_hair := Color(0.020, 0.024, 0.030)
	var c_jade := Color(0.26, 0.54, 0.44)

	# Smooth lotus-meditation posture with wide sleeves draped softly onto lap
	_add_smooth_loft(b, [
		[Vector3(0.0, 0.05, 0.00), Vector2(0.72, 0.60)],
		[Vector3(0.0, 0.22, 0.00), Vector2(0.54, 0.44)],
	], 14, c_hem, c_robe_low, false)
	_add_smooth_loft(b, [
		[Vector3(0.0, 0.21, 0.00), Vector2(0.54, 0.44)],
		[Vector3(0.0, 0.52, 0.00), Vector2(0.28, 0.23)],
	], 14, c_robe_low, c_robe_hi, false)
	_add_smooth_loft(b, [
		[Vector3(0.0, 0.51, 0.00), Vector2(0.29, 0.24)],
		[Vector3(0.0, 0.59, 0.00), Vector2(0.28, 0.23)],
	], 14, c_sash, c_sash * 1.08, false)
	_add_smooth_loft(b, [
		[Vector3(0.0, 0.58, 0.00), Vector2(0.27, 0.22)],
		[Vector3(0.0, 0.84, 0.00), Vector2(0.34, 0.23)],
		[Vector3(0.0, 0.96, 0.00), Vector2(0.19, 0.16)],
	], 14, c_robe_hi * 0.96, c_robe_hi * 1.04, true)
	for side_s: float in [-1.0, 1.0]:
		_add_smooth_loft(b, [
			[Vector3(side_s * 0.15, 0.89, 0.00), Vector2(0.13, 0.14)],
			[Vector3(side_s * 0.20, 0.70, 0.06), Vector2(0.15, 0.19)],
			[Vector3(side_s * 0.09, 0.54, 0.14), Vector2(0.13, 0.18)],
		], 10, c_robe_hi, c_robe_low, true)
	_add_smooth_loft(b, [
		[Vector3(0.0, 0.98, 0.00), Vector2(0.14, 0.15)],
		[Vector3(0.0, 1.09, 0.00), Vector2(0.185, 0.195)],
		[Vector3(0.0, 1.19, 0.00), Vector2(0.155, 0.165)],
	], 12, c_skin * 0.95, c_skin * 1.02, true)
	_add_smooth_loft(b, [
		[Vector3(0.0, 0.58, -0.105), Vector2(0.12, 0.045)],
		[Vector3(0.0, 0.88, -0.090), Vector2(0.17, 0.065)],
		[Vector3(0.0, 1.13, -0.030), Vector2(0.195, 0.14)],
		[Vector3(0.0, 1.21, -0.010), Vector2(0.165, 0.165)],
	], 10, c_hair, c_hair * 1.15, true)
	_add_smooth_loft(b, [
		[Vector3(0.0, 1.20, -0.015), Vector2(0.085, 0.085)],
		[Vector3(0.0, 1.29, -0.020), Vector2(0.065, 0.065)],
	], 10, c_jade * 0.90, c_jade * 1.08, true)

	var inst := MeshInstance3D.new()
	inst.name = "SittingBody"
	inst.mesh = b.mesh()
	inst.material_override = _vertex_mat
	return inst

func _build_bamboo_rod() -> Node3D:
	var holder := Node3D.new()
	holder.name = "BambooRod"
	var b := SurfaceBuilder.new()
	var c_bamboo := Color(0.22, 0.34, 0.17)
	var c_grip := Color(0.12, 0.08, 0.05)
	_add_box_part(b, Vector3(0.16, 0.98, 0.34), Vector3(0.036, 0.036, 0.42), Vector3(-0.32, 0.0, 0.0), c_grip)
	_add_box_part(b, Vector3(0.14, 1.16, 0.92), Vector3(0.024, 0.024, 0.85), Vector3(-0.28, -0.04, 0.0), c_bamboo)
	_add_box_part(b, Vector3(0.07, 1.34, 1.58), Vector3(0.014, 0.014, 0.72), Vector3(-0.20, -0.08, 0.0), c_bamboo * 1.12)
	var inst := MeshInstance3D.new()
	inst.mesh = b.mesh()
	inst.material_override = _vertex_mat
	holder.add_child(inst)
	return holder

func _build_rush_cushion() -> Node3D:
	var holder := Node3D.new()
	holder.name = "MeditationCushion"
	# Weathered grey-taupe garden boulder beside the stone daybed (坐忘青石, Ref 1):
	var built: Array = preload("res://scripts/terrain_editor/terrain_models.gd")._boulder_models(6.4, Vector3(0.68, 0.44, 0.62))
	var inst := MeshInstance3D.new()
	inst.mesh = built[0].mesh
	var rock_mat := ShaderMaterial.new()
	rock_mat.shader = load("res://shaders/terrain_editor/cliff_rock.gdshader")
	preload("res://scripts/terrain_editor/material_detail.gd").bind(rock_mat)
	inst.material_override = rock_mat
	inst.position.y = -0.06
	holder.add_child(inst)
	return holder

func _build_aura_ring() -> MeshInstance3D:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for ring_idx: int in 2:
		var r: float = 0.78 if ring_idx == 0 else 1.08
		var segs: int = 36
		for i: int in segs:
			var a0: float = TAU * float(i) / float(segs)
			var a1: float = TAU * float(i + 1) / float(segs)
			if ring_idx == 1 and i % 2 == 1:
				continue
			im.surface_add_vertex(Vector3(cos(a0) * r, 0.05, sin(a0) * r))
			im.surface_add_vertex(Vector3(cos(a1) * r, 0.05, sin(a1) * r))
	im.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.66, 0.90, 0.80, 0.72)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var inst := MeshInstance3D.new()
	inst.name = "SpiritAuraRing"
	inst.mesh = im
	inst.material_override = mat
	return inst
