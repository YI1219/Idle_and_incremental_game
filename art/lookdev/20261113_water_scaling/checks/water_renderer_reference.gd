extends Node3D
## One worker owns the solver while running. Public flow is readable only idle.
## The editor calls tick explicitly, so frozen captures cannot advance themselves.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Flow = preload("res://art/lookdev/20261113_water_scaling/checks/source_before/water_flow.gd")
const Contours = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")
const MAX_ADVANCE: float = 0.1
const MAX_QUEUED_SECONDS: float = 0.3
const MIN_VISIBLE_DEPTH: float = 0.002
const SURFACE_LIFT: float = 0.045
const WATER_LAYERS: Array[String] = ["water", "waterfall", "bank"]

var flow: RefCounted = Flow.new()
var grass_recovery: RefCounted = preload("res://scripts/terrain_editor/grass_recovery.gd").new()
var published_surfaces: Dictionary = {}
var published_depths: Dictionary = {}
var published_heights: Dictionary = {}
var published_basins: Array[Dictionary] = []
var published_volume: float = 0.0
var published_discharged_volume: float = 0.0
var splash_points: Array = []
var fall_veils: Array = []
var live_field_image: Image
var live_field_texture: ImageTexture
var live_field_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ONE)
var shore_texture: ImageTexture
var simulated_seconds: float = 0.0
var queued_seconds: float = 0.0
var last_step_seconds: float = 0.0
var last_worker_ms: float = 0.0
var last_publish_ms: float = 0.0
var last_advance_worker_ms: float = 0.0
var last_worker_stages: Dictionary = {}
var last_advance_stages: Dictionary = {}
var last_snapshot_ms: float = 0.0
var last_sync_ms: float = 0.0
var publication_revision: int = 0
var _data: Data
var _terrain: Node3D
var _worker_task: int = -1
var _worker_result: Dictionary = {}
var _sync_pending: bool = false
var _nodes: Dictionary[String, MeshInstance3D] = {}
var _shore_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ONE)
# Last successfully published state; never accept a discarded worker as visible.
var _visual_state: Array = []
var _shape_cache: Array[Dictionary] = []

class FlowField:
	extends "res://scripts/terrain_editor/contour_terrain.gd"
	var live_depths: Dictionary = {}
	var live_heights: Dictionary = {}
	var basin_ids: Dictionary = {}
	var outgoing: Dictionary = {}
	var _basin: int = -1
	var shape_cache: Array[Dictionary] = []

	func build_live(snapshot: Data, solver: RefCounted) -> void:
		source = snapshot
		live_depths = solver.depths.duplicate()
		live_heights = solver.heights.duplicate()
		for kind: String in ["water", "waterfall", "bank"]:
			surfaces[kind] = Legacy.Surface.new()
		for basin: Dictionary in solver.basins:
			for cell: Vector2i in basin.cells:
				basin_ids[cell] = int(basin.id)
		_build_outgoing(solver.last_transfers)
		var next_cache: Array[Dictionary] = []
		for basin: Dictionary in solver.basins:
			var visible: Dictionary = {}
			for cell: Vector2i in basin.cells:
				if live_depths.get(cell, 0.0) >= MIN_VISIBLE_DEPTH:
					visible[cell] = true
			if visible.is_empty():
				continue
			_basin = int(basin.id)
			var shape: Dictionary = {}
			for cached: Dictionary in shape_cache:
				if cached.cells == visible:
					shape = cached
					break
			if shape.is_empty():
				var loops: Array = _outlines(visible)
				var subdivided: Array[PackedVector2Array] = []
				for loop: PackedVector2Array in loops:
					subdivided.append(_subdivide_outline(loop))
				var cap: RefCounted = Legacy.Surface.new()
				_cap(cap, loops, 0.0, Color.WHITE)
				shape = {"cells": visible, "loops": loops, "subdivided": subdivided, "cap": cap}
			next_cache.append(shape)
			var loops: Array = shape.loops
			water_regions[_basin] = loops
			var water_y: float = float(basin.height) + SURFACE_LIFT
			# Only height and its UV component vary until visible membership changes.
			var cap: RefCounted = shape.cap
			var vertices: PackedVector3Array = cap.vertices.duplicate()
			var uv: PackedVector2Array = cap.uv.duplicate()
			for index: int in vertices.size():
				vertices[index].y = water_y
				uv[index].y = water_y
			surfaces.water.vertices.append_array(vertices)
			surfaces.water.normals.append_array(cap.normals)
			surfaces.water.colors.append_array(cap.colors)
			surfaces.water.uv.append_array(uv)
			for loop: PackedVector2Array in shape.subdivided:
				_falls(loop, water_y)
		shape_cache = next_cache
		for kind: String in ["waterfall", "bank"]:
			_smooth_normals(surfaces[kind])
		for veil: Dictionary in fall_veils:
			var measured: Dictionary = _nearest_outflow(Vector2(veil.lip.x, veil.lip.z), veil.out)
			veil.rate = measured.get("rate", 0.0)
			veil.intensity = clampf(float(veil.rate) / 0.45, 0.0, 1.0)
		for splash: Dictionary in splash_points:
			var measured: Dictionary = _nearest_outflow(Vector2(splash.center.x, splash.center.z), splash.out)
			splash.rate = measured.get("rate", 0.0)
			splash.intensity = clampf(float(splash.rate) / 0.45, 0.0, 1.0)

	func _smooth_normals(surface) -> void:
		# Preserve the original accumulation order and rounding, but normalize
		# each shared position once rather than once per duplicated vertex.
		var vertices: PackedVector3Array = surface.vertices
		var keys: PackedVector3Array = PackedVector3Array()
		keys.resize(vertices.size())
		var sums: Dictionary[Vector3, Vector3] = {}
		for index: int in range(0, vertices.size(), 3):
			var a: Vector3 = vertices[index]
			var weighted: Vector3 = -(vertices[index + 1] - a).cross(vertices[index + 2] - a)
			for corner: int in range(index, index + 3):
				var key: Vector3 = (vertices[corner] * 10000.0).round()
				keys[corner] = key
				sums[key] = sums.get(key, Vector3.ZERO) + weighted
		for key: Vector3 in sums:
			sums[key] = sums[key].normalized()
		var normals: PackedVector3Array = PackedVector3Array()
		normals.resize(vertices.size())
		for index: int in keys.size():
			normals[index] = sums[keys[index]]
		surface.normals = normals

	func surface_at(point: Vector2) -> Dictionary:
		var cell: Vector2i = Vector2i(point.floor())
		if not source.cells.has(cell):
			return {}
		var bed: float = float(source.cells[cell].height)
		if live_depths.get(cell, 0.0) > 0.0:
			return {"height": live_heights[cell] + SURFACE_LIFT, "water": basin_ids.get(cell, -1)}
		return {"height": bed, "water": -1}

	func _build_outgoing(transfers: Array) -> void:
		var void_rates: Dictionary = {}
		for transfer: Dictionary in transfers:
			var rate: float = float(transfer.rate)
			if rate <= 0.0 or not is_finite(rate):
				continue
			var cell: Vector2i = transfer.from
			if transfer.to == null:
				void_rates[cell] = void_rates.get(cell, 0.0) + rate
			else:
				_add_outflow(cell, transfer.to, rate)
		# Missing-neighbour requests have equal heads in WaterFlow. Its public
		# null destination omits direction, so distribute their sum equally.
		for cell: Vector2i in void_rates:
			var missing: Array[Vector2i] = []
			for direction: Vector2i in Flow.DIRECTIONS:
				if not source.cells.has(cell + direction):
					missing.append(cell + direction)
			for target: Vector2i in missing:
				_add_outflow(cell, target, float(void_rates[cell]) / float(missing.size()))

	func _add_outflow(cell: Vector2i, target: Vector2i, rate: float) -> void:
		var direction: Vector2 = Vector2(target - cell)
		var entry: Dictionary = {
			"from": cell, "to": target, "out": direction,
			"center": Vector2(cell) + Vector2.ONE * 0.5 + direction * 0.5,
			"rate": rate,
		}
		if not outgoing.has(cell):
			outgoing[cell] = []
		outgoing[cell].append(entry)

	func _nearest_outflow(point: Vector2, out: Vector2, basin: int = -1) -> Dictionary:
		var best: Dictionary = {}
		var distance: float = 4.0
		var center: Vector2i = Vector2i(point.floor())
		for z: int in range(-2, 3):
			for x: int in range(-2, 3):
				var cell: Vector2i = center + Vector2i(x, z)
				if basin >= 0 and basin_ids.get(cell, -1) != basin:
					continue
				for entry: Dictionary in outgoing.get(cell, []):
					if out.dot(entry.out) < 0.35:
						continue
					var tangent: Vector2 = Vector2(-entry.out.y, entry.out.x)
					if basin >= 0 and absf((point - Vector2(entry.center)).dot(tangent)) > 0.50001:
						continue
					var next_distance: float = point.distance_squared_to(entry.center)
					if next_distance < distance:
						distance = next_distance
						best = entry
		return best

	func _subdivide_outline(loop: PackedVector2Array) -> PackedVector2Array:
		# Sample flux within each original cell edge, including beside an outlet
		# blocked by the next cell. The cap keeps the same collinear boundary.
		var result: PackedVector2Array = PackedVector2Array()
		for index: int in range(loop.size()):
			var a: Vector2 = loop[index]
			var b: Vector2 = loop[(index + 1) % loop.size()]
			var count: int = maxi(1, ceili(a.distance_to(b) / 0.4))
			for part: int in range(count):
				result.append(a.lerp(b, float(part) / float(count)))
		return result

	func _flow_edges(loop: PackedVector2Array, water_y: float) -> Array:
		var result: Array = []
		var stop: int = -1
		for index: int in range(loop.size()):
			var a: Vector2 = loop[index]
			var b: Vector2 = loop[(index + 1) % loop.size()]
			var out: Vector2 = Vector2(b.y - a.y, a.x - b.x).normalized()
			var transfer: Dictionary = _nearest_outflow((a + b) * 0.5, out, _basin)
			var sample: Dictionary = {"height": water_y, "water": -1}
			var rate: float = 0.0
			if not transfer.is_empty() and ((a + b) * 0.5).distance_squared_to(transfer.center) < 0.85:
				var target: Vector2i = transfer.to
				sample = surface_at(Vector2(target) + Vector2.ONE * 0.5)
				rate = float(transfer.rate)
			# Flux is measured on cells; smoothed boundaries may pass close to a
			# different side of that cell. A nearby outlet must not coat the pool's
			# own side wall with a detached strip of falling water.
			var outside:Dictionary=surface_at((a+b)*.5+out*.28)
			var supported:bool=outside.get("water",-1)!=_basin and float(outside.get("height",-12.0))<water_y-.1
			var spill: bool = supported and rate > 0.0 and float(sample.get("height", -12.0)) < water_y - 0.1
			if not spill:
				sample = {"height": water_y, "water": -1}
			result.append({"sample": sample, "spill": spill, "rate": rate, "intensity": clampf(rate / 0.45, 0.0, 1.0), "start": 0.0, "width": 0.0, "run": 0, "length": a.distance_to(b)})
			if not spill:
				stop = index
		if stop < 0:
			return result
		var run: Array[int] = []
		var width: float = 0.0
		for step: int in range(1, loop.size() + 1):
			var index: int = (stop + step) % loop.size()
			if result[index].spill:
				result[index].start = width
				width += float(result[index].length)
				run.append(index)
			else:
				for member: int in run:
					result[member].width = width
					result[member].run = index
				run.clear()
				width = 0.0
		return result

func configure(data: Data, terrain_renderer: Node3D) -> void:
	_disconnect_terrain()
	_terrain = terrain_renderer
	_terrain.child_entered_tree.connect(_on_terrain_child_entered)
	for kind: String in WATER_LAYERS:
		if _nodes.has(kind):
			continue
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = kind
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_nodes[kind] = instance
	reset(data)

func reset(data: Data) -> void:
	_wait_discard()
	_visual_state.clear()
	_shape_cache.clear()
	_data = data
	queued_seconds = 0.0
	simulated_seconds = 0.0
	_sync_pending = false
	grass_recovery.clear()
	flow.configure(data)
	_hide_legacy(_terrain)
	_start_worker(0.0)
	_collect_worker(true)

func _process(delta: float) -> void:
	if grass_recovery.advance(delta):
		_bind_grass_recovery()

func _bind_grass_recovery() -> void:
	if grass_recovery.texture == null:
		return
	var bounds: Rect2 = grass_recovery.rect
	RenderingServer.global_shader_parameter_set("grass_recovery_field", grass_recovery.texture)
	RenderingServer.global_shader_parameter_set("grass_recovery_rect", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
	RenderingServer.global_shader_parameter_set("grass_recovery_active", 1.0)

func tick(delta: float) -> void:
	if _data == null:
		return
	if is_finite(delta) and delta > 0.0:
		queued_seconds = minf(MAX_QUEUED_SECONDS, queued_seconds + delta)
	_collect_worker(false)
	if _worker_task < 0 and queued_seconds >= MAX_ADVANCE - 0.000000001:
		_schedule_advance()

func sync() -> void:
	if _data == null:
		return
	_hide_legacy(_terrain)
	_bind_fields_and_mist()
	_sync_pending = true
	if _worker_task < 0:
		_reconcile()
		_start_worker(0.0)

func flush() -> void:
	if _data == null:
		return
	# Include direct authoring changes even when the caller has not ticked yet.
	_sync_pending = true
	while _worker_task >= 0 or _sync_pending or queued_seconds > 0.000000001:
		_collect_worker(true)
		if _worker_task >= 0:
			continue
		if _sync_pending:
			_reconcile()
			_start_worker(0.0)
		elif queued_seconds > 0.000000001:
			_schedule_advance()
	flow.write_to_data(_data)
	_hide_legacy(_terrain)
	_bind_fields_and_mist()

func has_pending_updates() -> bool:
	return _worker_task >= 0 or _sync_pending or queued_seconds > 0.000000001

func _reconcile() -> void:
	var started: int = Time.get_ticks_usec()
	flow.sync(_data)
	_sync_pending = false
	last_sync_ms = float(Time.get_ticks_usec() - started) / 1000.0

func _schedule_advance() -> void:
	var duration: float = minf(MAX_ADVANCE, queued_seconds)
	queued_seconds = maxf(0.0, queued_seconds - duration)
	_start_worker(duration)

func _start_worker(duration: float) -> void:
	assert(_worker_task < 0, "A water solver can have only one worker owner")
	var started: int = Time.get_ticks_usec()
	var snapshot: Data = Data.new()
	snapshot.seed = _data.seed
	snapshot.cells = _data.cells.duplicate(true)
	last_snapshot_ms = float(Time.get_ticks_usec() - started) / 1000.0
	_worker_task = WorkerThreadPool.add_task(_build_worker.bind(snapshot, duration), false, "Live water")

func _build_worker(snapshot: Data, duration: float) -> void:
	var started: int = Time.get_ticks_usec()
	if duration > 0.0:
		flow.step(duration)
	var solved: int = Time.get_ticks_usec()
	var state: Array = [flow.depths, flow.heights, flow.last_transfers, flow._beds, snapshot.seed]
	if state == _visual_state:
		_worker_result = {"unchanged": true, "duration": duration, "worker_ms": float(solved - started) / 1000.0,
			"stages": {"solver": float(solved - started) / 1000.0, "mesh": 0.0, "images": 0.0}}
		return
	var field: FlowField = FlowField.new()
	field.shape_cache = _shape_cache
	field.build_live(snapshot, flow)
	_shape_cache = field.shape_cache
	var meshes: Dictionary = {}
	for kind: String in WATER_LAYERS:
		meshes[kind] = field.surfaces[kind].mesh()
	var meshed: int = Time.get_ticks_usec()
	var fields: Dictionary = _build_images(snapshot, field)
	var finished: int = Time.get_ticks_usec()
	_worker_result = {
		"state": state.duplicate(true), "meshes": meshes, "surfaces": field.surfaces,
		"depths": field.live_depths, "heights": field.live_heights,
		"basins": flow.basins.duplicate(true), "splashes": field.splash_points,
		"volume": flow.total_volume(), "discharged": flow.discharged_volume,
		"veils": field.fall_veils, "fields": fields, "duration": duration,
		"worker_ms": float(finished - started) / 1000.0,
		"stages": {"solver": float(solved - started) / 1000.0, "mesh": float(meshed - solved) / 1000.0, "images": float(finished - meshed) / 1000.0},
	}

func _collect_worker(wait: bool) -> void:
	if _worker_task < 0:
		return
	if not wait and not WorkerThreadPool.is_task_completed(_worker_task):
		return
	WorkerThreadPool.wait_for_task_completion(_worker_task)
	_worker_task = -1
	var result: Dictionary = _worker_result
	_worker_result = {}
	simulated_seconds += float(result.duration)
	last_step_seconds = float(result.duration)
	last_worker_ms = float(result.worker_ms)
	last_worker_stages = result.stages
	if last_step_seconds > 0.0:
		last_advance_worker_ms = last_worker_ms
		last_advance_stages = last_worker_stages
	if _sync_pending:
		_reconcile()
		_start_worker(0.0)
		return
	if result.get("unchanged", false):
		last_publish_ms = 0.0
		return
	var started: int = Time.get_ticks_usec()
	flow.write_to_data(_data)
	_visual_state = result.state
	_publish(result)
	last_publish_ms = float(Time.get_ticks_usec() - started) / 1000.0

func _publish(result: Dictionary) -> void:
	var started: int = Time.get_ticks_usec()
	published_surfaces = result.surfaces
	published_depths = result.depths
	published_heights = result.heights
	published_basins.assign(result.basins)
	published_volume = float(result.volume)
	published_discharged_volume = float(result.discharged)
	splash_points = result.splashes
	fall_veils = result.veils
	grass_recovery.sync(_data.cells, published_depths, published_heights)
	_bind_grass_recovery()
	live_field_image = result.fields.live
	live_field_rect = result.fields.rect
	_shore_rect = result.fields.rect
	live_field_texture = _update_texture(live_field_texture, live_field_image)
	shore_texture = _update_texture(shore_texture, result.fields.shore)
	for kind: String in WATER_LAYERS:
		_nodes[kind].mesh = result.meshes[kind]
		_nodes[kind].material_override = _terrain.materials[kind]
		_nodes[kind].visible = not published_surfaces[kind].vertices.is_empty()
	_bind_fields_and_mist()
	publication_revision += 1
	last_publish_ms = float(Time.get_ticks_usec() - started) / 1000.0

func _update_texture(texture: ImageTexture, image: Image) -> ImageTexture:
	if texture != null and texture.get_width() == image.get_width() and texture.get_height() == image.get_height():
		texture.update(image)
		return texture
	return ImageTexture.create_from_image(image)

func _bind_fields_and_mist() -> void:
	if not is_instance_valid(_terrain) or shore_texture == null:
		return
	var material: ShaderMaterial = _terrain.materials.water
	material.set_shader_parameter("shore_field", shore_texture)
	material.set_shader_parameter("shore_origin", _shore_rect.position)
	material.set_shader_parameter("shore_extent", _shore_rect.size)
	RenderingServer.global_shader_parameter_set("live_water_field", live_field_texture)
	RenderingServer.global_shader_parameter_set("live_water_rect", Vector4(live_field_rect.position.x, live_field_rect.position.y, live_field_rect.size.x, live_field_rect.size.y))
	RenderingServer.global_shader_parameter_set("live_water_active", 1.0)
	if _terrain.mist != null:
		_terrain.mist.sync(splash_points, fall_veils, _terrain.contours.land_regions)

func _on_terrain_child_entered(child: Node) -> void:
	_hide_legacy(child)

func _hide_legacy(node: Node) -> void:
	if not is_instance_valid(node) or node == self:
		return
	if node is GeometryInstance3D and String(node.name) in WATER_LAYERS:
		(node as GeometryInstance3D).visible = false
	for child: Node in node.get_children():
		_hide_legacy(child)

func _disconnect_terrain() -> void:
	if is_instance_valid(_terrain) and _terrain.child_entered_tree.is_connected(_on_terrain_child_entered):
		_terrain.child_entered_tree.disconnect(_on_terrain_child_entered)

func _wait_discard() -> void:
	if _worker_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_worker_task)
		_worker_task = -1
	_worker_result = {}

func _exit_tree() -> void:
	_wait_discard()
	_disconnect_terrain()
	RenderingServer.global_shader_parameter_set("live_water_active", 0.0)
	RenderingServer.global_shader_parameter_set("grass_recovery_active", 0.0)

func _notification(what: int) -> void:
	# Detached nodes do not receive _exit_tree, but can still own a task.
	if what == NOTIFICATION_PREDELETE:
		_wait_discard()
		_disconnect_terrain()
		if _data != null:
			RenderingServer.global_shader_parameter_set("live_water_active", 0.0)
			RenderingServer.global_shader_parameter_set("grass_recovery_active", 0.0)

static func _build_images(snapshot: Data, field: FlowField) -> Dictionary:
	var low: Vector2i = Vector2i.ZERO
	var high: Vector2i = Vector2i.ZERO
	if not snapshot.cells.is_empty():
		low = snapshot.cells.keys()[0]
		high = low
		for cell: Vector2i in snapshot.cells:
			low = low.min(cell)
			high = high.max(cell)
	var size: Vector2i = high - low + Vector2i.ONE
	var live: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBAF)
	var shore: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	live.fill(Color(0.0, 0.0, 0.0, 0.0))
	shore.fill(Color(0.0, 0.0, 0.0, 0.0))
	var distances: Dictionary = {}
	var impacts: Dictionary = {}
	var queue: Array[Vector2i] = []
	var impact_queue: Array[Vector2i] = []
	for cell: Vector2i in field.live_depths:
		distances[cell] = 3.0
		impacts[cell] = 4.0
		for direction: Vector2i in Flow.DIRECTIONS:
			if field.basin_ids.get(cell + direction, -1) != field.basin_ids[cell]:
				distances[cell] = 0.5
		if distances[cell] == 0.5:
			queue.append(cell)
	for source_cell: Vector2i in field.outgoing:
		for transfer: Dictionary in field.outgoing[source_cell]:
			var target: Vector2i = transfer.to
			if field.live_depths.has(target) and float(field.live_heights.get(source_cell, 0.0)) - float(field.live_heights[target]) > 0.1 and impacts[target] > 0.0:
				impacts[target] = 0.0
				impact_queue.append(target)
	_spread_distance(distances, queue, field.basin_ids, 3.0)
	_spread_distance(impacts, impact_queue, field.basin_ids, 4.0)
	for cell: Vector2i in snapshot.cells:
		var pixel: Vector2i = cell - low
		var depth: float = float(field.live_depths.get(cell, 0.0))
		var height: float = float(field.live_heights.get(cell, snapshot.cells[cell].height))
		var rate: float = 0.0
		for transfer: Dictionary in field.outgoing.get(cell, []):
			rate += float(transfer.rate)
		live.set_pixelv(pixel, Color(height, depth, clampf(rate / 0.45, 0.0, 1.0), 1.0))
		if depth > 0.0:
			shore.set_pixelv(pixel, Color(float(distances[cell]) / 3.0, clampf(depth / 4.0, 0.0, 1.0), 1.0 - float(impacts[cell]) / 4.0, 1.0))
	return {"live": live, "shore": shore, "rect": Rect2(Vector2(low), Vector2(size))}

static func _spread_distance(distances: Dictionary, queue: Array[Vector2i], basin_ids: Dictionary, limit: float) -> void:
	var cursor: int = 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		var next: float = float(distances[cell]) + 1.0
		if next >= limit:
			continue
		for direction: Vector2i in Flow.DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if basin_ids.get(neighbor, -1) != basin_ids[cell] or float(distances.get(neighbor, 0.0)) <= next:
				continue
			distances[neighbor] = next
			queue.append(neighbor)
