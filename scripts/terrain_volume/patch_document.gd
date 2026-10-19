extends RefCounted
## Isolated version5 study document. Does not modify the legacy save loader.
const Data := preload('res://scripts/terrain_editor/terrain_data.gd')
const Base := preload('res://scripts/terrain_volume/sampled_base.gd')
const PRESET := 'res://assets/terrain/volume_patch/source_rock_v1.res'
const SOURCE_ID := 'tripo-land-v2-patch-01'
const STEP := .25
const LOCAL_LOW := Vector3(-8,-4,-6)
const LOCAL_HIGH := Vector3(8,7,6)
const CONNECTIONS := [Vector3i(1,0,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,1,0),Vector3i(1,0,1),Vector3i(0,1,1),Vector3i.ONE]
var data := Data.new()
var field: RefCounted:
	get: return data.rocks
var lake := {'center': [-.8, 0.], 'level': 2.5, 'enabled': true}
func load_preset() -> bool:
	if not ResourceLoader.exists(PRESET): return false
	var base := Base.new()
	if not base.configure(load(PRESET)): return false
	# Bind saves to the posed/sampled preset, not just its untransformed GLB.
	base.source_sha256 = FileAccess.get_sha256(PRESET)
	data = Data.new()
	data.rocks.base = base
	# A lake is carved into the same editable solid, not drawn over a hidden floor.
	begin_stroke()
	apply_brush(Vector3(-.8, 3.35, 0), 1.25, 'rock_cut')
	end_stroke()
	data._undo.clear()
	data._redo.clear()
	return true
func begin_stroke() -> void:
	data.begin_stroke()
func end_stroke() -> void:
	data.end_stroke()
func apply_brush(at: Vector3, radius: float, tool: String, normal := Vector3.UP) -> int:
	var reach := radius * (1.8 if tool in ['rock_shoulder','rock_cleave'] else 1.) + .5
	if not at.is_finite() or not is_finite(reach): return 0
	if (at-Vector3.ONE*reach).min(LOCAL_LOW) != LOCAL_LOW or (at+Vector3.ONE*reach).max(LOCAL_HIGH) != LOCAL_HIGH:
		return 0
	return data.apply_rock_brush(at, radius, tool, normal)
func undo() -> bool:
	return data.undo()
func redo() -> bool:
	return data.redo()
func serialize() -> Dictionary:
	return {'version': 5, 'source_id': SOURCE_ID, 'source_sha256': field.base.source_sha256,
		'step': STEP, 'rocks': field.records(), 'lake': lake.duplicate(true)}
func deserialize(payload: Dictionary) -> bool:
	if payload.get('version') != 5 or payload.get('source_id') != SOURCE_ID or payload.get('step') != STEP:
		return false
	var candidate = get_script().new()
	if not candidate.load_preset() or payload.get('source_sha256') != candidate.field.base.source_sha256:
		return false
	if not candidate.field.load_records(payload.get('rocks')):
		return false
	for key: Vector3i in candidate.field.samples:
		var p := Vector3(key)*STEP
		if p.min(LOCAL_LOW) != LOCAL_LOW or p.max(LOCAL_HIGH) != LOCAL_HIGH: return false
	var water: Variant = payload.get('lake')
	if not water is Dictionary or not water.get('center') is Array or water.center.size() != 2 or not water.get('enabled') is bool:
		return false
	for number: Variant in [water.get('level'), water.center[0], water.center[1]]:
		if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number)) > 100:
			return false
	if not is_equal_approx(float(water.level)/STEP, roundf(float(water.level)/STEP)): return false
	data = candidate.data
	lake = water.duplicate(true)
	return true
func lake_status() -> Dictionary:
	if not lake.enabled: return {'valid': false, 'reason': 'drained', 'surface': []}
	# Include every lattice edge of the actual fixed tetrahedral subdivision.
	# Axis-only flood fill misses diagonal passages that the rendered skin has.
	var water_y := floori(float(lake.level) / STEP)
	var seed := Vector3i(roundi(float(lake.center[0]) / STEP), water_y, roundi(float(lake.center[1]) / STEP))
	if field.node_value(seed) <= 0:
		# A small island may occupy the anchor while the basin still contains
		# water. Search the authored pond neighborhood, never arbitrary outside air.
		var nearest := INF
		var anchor := seed
		for dz: int in range(-5,6):
			for dx: int in range(-5,6):
				var distance := float(dx*dx+dz*dz)
				var candidate := anchor + Vector3i(dx,0,dz)
				if distance > 25 or distance >= nearest: continue
				if field.node_value(candidate) > 0 and field.base.node_value(candidate) < 0:
					nearest = distance
					seed = candidate
		if nearest == INF:
			return {'valid': false, 'reason': 'filled', 'surface': []}
	var low: Vector3i = field.base.low
	var high: Vector3i = low + field.base.size - Vector3i.ONE
	var seen: Dictionary = {seed: true}
	var queue: Array[Vector3i] = [seed]
	var surface: Array[Vector3i] = []
	var head := 0
	while head < queue.size():
		var key := queue[head]
		head += 1
		if key.x <= low.x or key.z <= low.z or key.y <= low.y or key.x >= high.x or key.z >= high.z:
			return {'valid': false, 'reason': 'breach', 'surface': []}
		if key.y == water_y: surface.append(key)
		for offset: Vector3i in CONNECTIONS:
			for direction: int in [-1,1]:
				var other := key + offset*direction
				if other.y > water_y or seen.has(other): continue
				if field.node_value(other) <= 0: continue
				seen[other] = true
				queue.append(other)
		if queue.size() > 200000:
			return {'valid': false, 'reason': 'capacity', 'surface': []}
	return {'valid': true, 'reason': 'closed', 'surface': surface, 'wet_nodes': queue.size()}
