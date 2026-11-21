extends RefCounted
## Unit-area finite-volume water. Terrain records are read until explicitly persisted.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const MAX_SUBSTEP: float = 0.025
const FLOW_COEFFICIENT: float = 0.45
const POOL_SURFACE_TOLERANCE: float = 0.025

var depths: Dictionary[Vector2i, float] = {}
var heights: Dictionary[Vector2i, float] = {}
var discharged_volume: float = 0.0
var basins: Array[Dictionary] = []
var last_transfers: Array[Dictionary] = []
var _data: Data
var _beds: Dictionary[Vector2i, float] = {}
var _authored: Dictionary[Vector2i, Dictionary] = {}
var _ordered_cells: Array[Vector2i] = []
# Stable geometry version is independent of solver volume persistence.
var terrain_version: int = 0
var last_step_cells: int = 0
var _sleeping: bool = false
var _hydraulically_still: bool = false
var _persist_dirty: Dictionary[Vector2i, bool] = {}
var _cell_index: Dictionary[Vector2i, int] = {}
var _bed_values: PackedFloat64Array = PackedFloat64Array()
var _height_values: PackedFloat64Array = PackedFloat64Array()
var _neighbors: PackedInt32Array = PackedInt32Array()
var _incoming: PackedFloat64Array = PackedFloat64Array()
var _remaining: PackedFloat64Array = PackedFloat64Array()
var _marked: PackedByteArray = PackedByteArray()
var _affected: PackedInt32Array = PackedInt32Array()
var _previous_wet: PackedInt32Array = PackedInt32Array()
var _fractions: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var _targets: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _target_heights: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var _directions: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])

func configure(data: Data) -> void:
	_data = data
	terrain_version += 1
	_sleeping = false
	_persist_dirty.clear()
	depths.clear()
	heights.clear()
	_beds.clear()
	_authored.clear()
	basins.clear()
	last_transfers.clear()
	discharged_volume = 0.0
	_ordered_cells.assign(data.cells.keys())
	_ordered_cells.sort_custom(_cell_before)
	for cell: Vector2i in _ordered_cells:
		var record: Dictionary = data.cells[cell]
		_beds[cell] = float(record.height)
		_authored[cell] = _authoring_state(record)
		_set_depth(cell, _initial_volume(record, _beds[cell]))
		_persist_dirty[cell] = true
	_prepare_topology()
	_rebuild_basins()

func sync(data: Data) -> void:
	if data != _data:
		configure(data)
		return
	var changed_water: Dictionary = {}
	var edited: bool = false
	for cell: Vector2i in _ordered_cells:
		if not data.cells.has(cell):
			edited = true
			discharged_volume += depths.get(cell, 0.0)
			depths.erase(cell)
			_beds.erase(cell)
			_authored.erase(cell)
			_persist_dirty.erase(cell)
	_ordered_cells.assign(data.cells.keys())
	_ordered_cells.sort_custom(_cell_before)
	for cell: Vector2i in _ordered_cells:
		var record: Dictionary = data.cells[cell]
		var next_bed: float = float(record.height)
		var authored: Dictionary = _authoring_state(record)
		if record.has("water_volume") and (not (record.water_volume is float or record.water_volume is int) or not is_finite(float(record.water_volume)) or float(record.water_volume) < 0.0):
			_persist_dirty[cell] = true
		var is_new: bool = not _beds.has(cell)
		var reset_water: bool = is_new
		edited = edited or is_new
		if not is_new:
			var previous: Dictionary = _authored[cell]
			if next_bed != _beds[cell] or authored != previous:
				_persist_dirty[cell] = true
			edited = edited or next_bed != _beds[cell] or authored != previous
			# The legacy land brush clears its nominal flag when a raised bed
			# crosses that plane. An unchanged explicit volume preserves live water.
			var same_volume: bool = authored.has_volume == previous.has_volume and authored.volume == previous.volume
			var bed_cleared_flag: bool = next_bed != _beds[cell] and same_volume and previous.water >= 0 and authored.water < 0
			reset_water = authored != previous and not bed_cleared_flag
		_beds[cell] = next_bed
		_authored[cell] = authored
		if is_new:
			_persist_dirty[cell] = true
		if reset_water:
			_set_depth(cell, _initial_volume(record, next_bed))
			changed_water[cell] = true
	if not edited:
		return
	terrain_version += 1
	_sleeping = false
	_prepare_topology()
	_level_existing_basins(changed_water)
	_rebuild_basins()
	last_transfers.clear()

func write_to_data(data: Data, reconcile: bool = true) -> void:
	if data != _data:
		return
	# Explicit callers reconcile arbitrary edits. The renderer can skip this
	# only after checking its pending-sync flag and authoring revision.
	if reconcile:
		sync(data)
	for cell: Vector2i in _persist_dirty:
		if data.cells.has(cell):
			data.cells[cell].water_volume = depths.get(cell, 0.0)
			_authored[cell] = _authoring_state(data.cells[cell])
	_persist_dirty.clear()

func step(delta: float) -> void:
	last_transfers.clear()
	last_step_cells = 0
	if _sleeping or not is_finite(delta) or delta <= 0.0 or depths.is_empty():
		return
	var transfer_totals: Dictionary = {}
	var substeps: int = maxi(1, ceili(delta / MAX_SUBSTEP))
	var duration: float = delta / float(substeps)
	for substep: int in range(substeps):
		if not _advance(duration, transfer_totals):
			_sleeping = _hydraulically_still
			break
	for edge: Vector3i in transfer_totals:
		var transfer: Dictionary = transfer_totals[edge]
		last_transfers.append({
			"from": transfer.from, "to": transfer.to,
			"rate": float(transfer.amount) / delta,
			"source_height": transfer.source_height,
			"target_height": transfer.target_height,
		})

func total_volume() -> float:
	var volume: float = 0.0
	for cell: Vector2i in _wet_cells():
		volume += depths[cell]
	return volume

func _wet_cells() -> Array[Vector2i]:
	# Indices already encode row-major order. Native integer sorting avoids a
	# GDScript comparator call for every comparison on every water substep.
	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize(depths.size())
	var cursor: int = 0
	for cell: Vector2i in depths:
		indices[cursor] = _cell_index[cell]
		cursor += 1
	indices.sort()
	var wet: Array[Vector2i] = []
	wet.resize(indices.size())
	for index: int in indices.size():
		wet[index] = _ordered_cells[indices[index]]
	return wet

func _prepare_topology() -> void:
	_cell_index.clear()
	var count: int = _ordered_cells.size()
	_bed_values.resize(count)
	_neighbors.resize(count * 4)
	for index: int in count:
		var cell: Vector2i = _ordered_cells[index]
		_cell_index[cell] = index
		_bed_values[index] = _beds[cell]
	for index: int in count:
		for direction: int in 4:
			_neighbors[index * 4 + direction] = _cell_index.get(_ordered_cells[index] + DIRECTIONS[direction], -1)
	_height_values = _bed_values.duplicate()
	_incoming.resize(count); _incoming.fill(0.0)
	_remaining.resize(count); _remaining.fill(0.0)
	_marked.resize(count); _marked.fill(0)
	_previous_wet.clear()
	_affected.clear()

func _mark_affected(index: int) -> void:
	if _marked[index] == 0:
		_marked[index] = 1
		_affected.append(index)

func _advance(duration: float, transfer_totals: Dictionary) -> bool:
	_hydraulically_still = true
	# Float64 and sorted cell/direction order preserve the old integration.
	# Only wet donors and receiving neighbours touch per-step scratch storage.
	for index: int in _previous_wet:
		_height_values[index] = _bed_values[index]
	_previous_wet.clear()
	var wet: Array[Vector2i] = _wet_cells()
	last_step_cells += wet.size()
	for cell: Vector2i in wet:
		var index: int = _cell_index[cell]
		_height_values[index] = heights[cell]
		_previous_wet.append(index)
	var moved: bool = false
	for cell: Vector2i in wet:
		var index: int = _cell_index[cell]
		_mark_affected(index)
		var available: float = depths[cell]
		var source_height: float = _height_values[index]
		var source_bed: float = _bed_values[index]
		var requests: int = 0
		var requested_fraction: float = 0.0
		for direction: int in 4:
			var target: int = _neighbors[index * 4 + direction]
			var target_bed: float = _bed_values[target] if target >= 0 else source_bed
			var target_height: float = _height_values[target] if target >= 0 else target_bed
			var head: float = source_height - maxf(source_bed, maxf(target_bed, target_height))
			if head <= 0.0:
				continue
			# Positive head can underflow to zero flux for tiny deltas. It is
			# not equilibrium and must still run when a normal delta arrives.
			_hydraulically_still = false
			var requested: float = minf(available, FLOW_COEFFICIENT * pow(head, 1.5) * duration)
			if requested <= 0.0:
				continue
			var fraction: float = requested / available
			requested_fraction += fraction
			_fractions[requests] = fraction
			_targets[requests] = target
			_target_heights[requests] = target_height
			_directions[requests] = direction
			requests += 1
		var scale: float = 1.0 / maxf(1.0, requested_fraction)
		var donor_remaining: float = available
		for request: int in requests:
			var amount: float = minf(donor_remaining, available * _fractions[request] * scale)
			if amount <= 0.0:
				continue
			donor_remaining -= amount
			var target: int = _targets[request]
			if target < 0:
				discharged_volume += amount
			else:
				_incoming[target] += amount
				_mark_affected(target)
			var edge: Vector3i = Vector3i(cell.x, cell.y, _directions[request])
			var accumulated: float = float(transfer_totals[edge].amount) if transfer_totals.has(edge) else 0.0
			transfer_totals[edge] = {
				"from": cell, "to": _ordered_cells[target] if target >= 0 else null,
				"amount": accumulated + amount, "source_height": source_height,
				"target_height": _target_heights[request],
			}
			moved = true
		_remaining[index] = donor_remaining
	if moved:
		_affected.sort()
		for index: int in _affected:
			_set_depth(_ordered_cells[index], _remaining[index] + _incoming[index])
	for index: int in _affected:
		_remaining[index] = 0.0
		_incoming[index] = 0.0
		_marked[index] = 0
	_affected.clear()
	if not moved:
		return false
	_level_existing_basins()
	_rebuild_basins()
	return true

func _level_existing_basins(excluded: Dictionary = {}) -> void:
	for basin: Dictionary in basins:
		var eligible: Dictionary = {}
		var raised: Dictionary = {}
		for cell: Vector2i in basin.cells:
			if not _beds.has(cell) or excluded.has(cell):
				continue
			if _beds[cell] >= float(basin.height):
				raised[cell] = true
			else:
				eligible[cell] = true
		# New high beds split a pool before any water is redistributed. Each
		# side retains its own volume, then receives displaced barrier water.
		var components: Array[Dictionary] = _connected_components(eligible)
		var component_of: Dictionary[Vector2i, int] = {}
		for index: int in range(components.size()):
			for cell: Vector2i in components[index]:
				component_of[cell] = index
		for barrier: Dictionary in _connected_components(raised):
			var neighbors: Dictionary = {}
			var displaced: float = 0.0
			for cell: Vector2i in barrier:
				displaced += depths.get(cell, 0.0)
				for offset: Vector2i in DIRECTIONS:
					var neighbor: Vector2i = cell + offset
					if component_of.has(neighbor):
						neighbors[component_of[neighbor]] = true
			if neighbors.is_empty():
				# An isolated raised water cell keeps its water and can spill
				# through actual flux on the next simulation tick.
				continue
			var share: float = displaced / float(neighbors.size())
			var remainder: float = displaced
			var pending: int = neighbors.size()
			for index: int in neighbors:
				var target: Vector2i = components[index].keys()[0]
				var amount: float = remainder if pending == 1 else share
				_set_depth(target, depths.get(target, 0.0) + amount)
				remainder -= amount
				pending -= 1
			for cell: Vector2i in barrier:
				depths.erase(cell)
				heights.erase(cell)
		for component: Dictionary in components:
			_level_pool(component)

func _rebuild_basins() -> void:
	heights.clear()
	for cell: Vector2i in depths:
		heights[cell] = _beds[cell] + depths[cell]
	basins.clear()
	var visited: Dictionary = {}
	for start: Vector2i in _wet_cells():
		if not depths.has(start) or visited.has(start):
			continue
		var members: Dictionary = {start: true}
		var queue: Array[Vector2i] = [start]
		var low: float = heights[start]
		var high: float = low
		var cursor: int = 0
		visited[start] = true
		while cursor < queue.size():
			var cell: Vector2i = queue[cursor]
			cursor += 1
			for offset: Vector2i in DIRECTIONS:
				var neighbor: Vector2i = cell + offset
				if not heights.has(neighbor) or visited.has(neighbor):
					continue
				var next_low: float = minf(low, heights[neighbor])
				var next_high: float = maxf(high, heights[neighbor])
				if next_high - next_low > POOL_SURFACE_TOLERANCE:
					continue
				low = next_low
				high = next_high
				visited[neighbor] = true
				members[neighbor] = true
				queue.append(neighbor)
		var basin: Dictionary = _level_pool(members)
		if basin.is_empty():
			continue
		# Leveling can dry a shallow bridge. Public basins must reflect the
		# remaining wet connectivity, including when no later flux occurs.
		var components: Array[Dictionary] = [basin.cells]
		if basin.cells.size() < members.size():
			components = _connected_components(basin.cells)
		for component: Dictionary in components:
			var volume: float = 0.0
			for cell: Vector2i in component:
				volume += depths[cell]
			basins.append({"id": basins.size(), "cells": component, "height": basin.height, "volume": volume})

func _connected_components(members: Dictionary) -> Array[Dictionary]:
	var pending: Dictionary = members.duplicate()
	var components: Array[Dictionary] = []
	while not pending.is_empty():
		var start: Vector2i = pending.keys()[0]
		var component: Dictionary = {start: true}
		var queue: Array[Vector2i] = [start]
		var cursor: int = 0
		pending.erase(start)
		while cursor < queue.size():
			var cell: Vector2i = queue[cursor]
			cursor += 1
			for offset: Vector2i in DIRECTIONS:
				var neighbor: Vector2i = cell + offset
				if pending.has(neighbor):
					pending.erase(neighbor)
					component[neighbor] = true
					queue.append(neighbor)
		components.append(component)
	return components

func _level_pool(members: Dictionary) -> Dictionary:
	var ordered: Array[Vector2i] = []
	ordered.assign(members.keys())
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _beds[a] < _beds[b] if _beds[a] != _beds[b] else _cell_before(a, b))
	var volume: float = 0.0
	for cell: Vector2i in ordered:
		volume += depths.get(cell, 0.0)
	if volume <= 0.0:
		for cell: Vector2i in ordered:
			depths.erase(cell)
			heights.erase(cell)
		return {}
	# Solve in offsets from the lowest bed. Tiny positive volumes survive even
	# when adding their depth to an absolute bed would round back to that bed.
	var bottom: float = _beds[ordered[0]]
	var relative_bed_sum: float = 0.0
	var active: int = 0
	var level_offset: float = 0.0
	for cell: Vector2i in ordered:
		var relative_bed: float = _beds[cell] - bottom
		if active > 0 and level_offset <= relative_bed:
			break
		relative_bed_sum += relative_bed
		active += 1
		level_offset = (volume + relative_bed_sum) / float(active)
	var level: float = bottom + level_offset
	var wet: Dictionary = {}
	var assigned: float = 0.0
	for cell: Vector2i in ordered:
		var depth: float = maxf(0.0, level_offset - (_beds[cell] - bottom))
		_set_depth(cell, depth)
		if depth > 0.0:
			wet[cell] = true
			heights[cell] = level
			assigned += depth
		else:
			heights.erase(cell)
	# Keep arithmetic roundoff in the deepest member rather than deleting water.
	var deepest: Vector2i = ordered[0]
	var remainder: float = volume - assigned
	if remainder != 0.0:
		_set_depth(deepest, depths.get(deepest, 0.0) + remainder)
		if depths.has(deepest):
			wet[deepest] = true
			heights[deepest] = level
	return {"cells": wet, "height": level, "volume": volume}

func _set_depth(cell: Vector2i, volume: float) -> void:
	if depths.get(cell, 0.0) != volume:
		_persist_dirty[cell] = true
	if volume > 0.0:
		depths[cell] = volume
	else:
		depths.erase(cell)

func _initial_volume(record: Dictionary, bed: float) -> float:
	if record.has("water_volume"):
		return _valid_volume(record.water_volume)
	var water: int = int(record.get("water", -1))
	return maxf(0.0, float(water) * 0.5 - bed) if water >= 0 else 0.0

func _authoring_state(record: Dictionary) -> Dictionary:
	return {
		"water": int(record.get("water", -1)),
		"has_volume": record.has("water_volume"),
		"volume": _valid_volume(record.get("water_volume", 0.0)),
	}

func _valid_volume(value: Variant) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return maxf(0.0, float(value))
	return 0.0

func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)
