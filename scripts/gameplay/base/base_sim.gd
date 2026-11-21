extends RefCounted
## Part-one base simulation: the supply pipeline for the first exploration
## outing. Pure data, no nodes, so it runs the same in a test, in the scene and
## while the game hangs as a wallpaper. See base_catalog.gd for the numbers.
##
## Three things move goods:
## - the cultivator, commanded like an RTS unit through a queue of orders;
## - the mouse, an independent worker: one unit of work per click;
## - conduits, which carry qi from springs to whatever they touch.
## Hunger and thirst never stop or kill the cultivator; they only slow work.
const Catalog = preload("res://scripts/gameplay/base/base_catalog.gd")
const STEP: float = 0.25
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

## Storehouse and the cultivator's pack, as one pool.
var stock: Dictionary = {}
## id -> {kind, cell, held, recipe, active, progress, ready, click_wait, formation}
var facilities: Dictionary = {}
var conduits: Dictionary = {}
var cultivator: Dictionary = {
	"at": Vector2.ZERO, "food": 1.0, "drink": 1.0, "fasting_left": 0.0, "nourished_left": 0.0,
	"cultivation": 0.0, "orders": [], "steps": [], "order": {}, "pack": {},
}
var seconds: float = 0.0
## The last order that had to be dropped, and what it lacked.
var last_block: Dictionary = {}
var _next_id: int = 1
var _networks: Array = []
var _networks_dirty: bool = true

# ---- building ------------------------------------------------------------

func place(kind: String, cell: Vector2i) -> int:
	assert(Catalog.FACILITIES.has(kind), "unknown facility " + kind)
	for other: Dictionary in facilities.values():
		if other.cell == cell:
			return -1
	if conduits.has(cell):
		return -1
	var id: int = _next_id
	_next_id += 1
	facilities[id] = {"kind": kind, "cell": cell, "held": {}, "recipe": "", "active": false, "progress": 0.0, "ready": {}, "click_wait": 0.0, "formation": false}
	_networks_dirty = true
	return id

func remove(id: int) -> void:
	if not facilities.has(id):
		return
	var facility: Dictionary = facilities[id]
	for good: String in facility.held:
		_add(stock, good, float(facility.held[good]))
	for good: String in facility.ready:
		_add(stock, good, float(facility.ready[good]))
	facilities.erase(id)
	_networks_dirty = true

func lay_conduit(cells: Array) -> int:
	var laid: int = 0
	for cell: Vector2i in cells:
		if conduits.has(cell) or _facility_at(cell) != -1:
			continue
		conduits[cell] = true
		laid += 1
	_networks_dirty = true
	return laid

func lift_conduit(cells: Array) -> void:
	for cell: Vector2i in cells:
		conduits.erase(cell)
	_networks_dirty = true

## Choose what a field, bed, hearth, furnace or forge makes. A standing choice,
## like a production order: it keeps going while inputs arrive.
func set_recipe(id: int, recipe: String) -> bool:
	if not facilities.has(id):
		return false
	var facility: Dictionary = facilities[id]
	var allowed: Array = Catalog.FACILITIES[facility.kind].get("recipes", [])
	if recipe != "" and not allowed.has(recipe):
		return false
	if facility.recipe == recipe:
		return true
	facility.recipe = recipe
	facility.active = false
	facility.progress = 0.0
	return true

# ---- the cultivator ------------------------------------------------------

## Orders (all take "repeat": true to go back to the end of the queue):
##   {"type": "haul", "good": G, "from": id, "to": id}   from = -1 takes from the storehouse
##   {"type": "harvest", "at": id}
##   {"type": "craft", "at": id, "recipe": R, "count": n}  fetches missing water or qi itself
##   {"type": "cultivate", "at": id, "seconds": s}
##   {"type": "take_pill"}                                swallows one fasting pill
func command(order: Dictionary) -> void:
	(cultivator.orders as Array).append(order.duplicate(true))

func clear_orders() -> void:
	(cultivator.orders as Array).clear()
	(cultivator.steps as Array).clear()
	cultivator.order = {}
	_unpack()

func efficiency() -> float:
	var fed: float = 1.0
	var watered: float = 1.0
	if float(cultivator.fasting_left) <= 0.0:
		fed = clampf(float(cultivator.food) / 0.5, 0.0, 1.0)
		watered = clampf(float(cultivator.drink) / 0.5, 0.0, 1.0)
	return Catalog.MIN_EFFICIENCY + (1.0 - Catalog.MIN_EFFICIENCY) * 0.5 * (fed + watered)

func work_speed() -> float:
	var decor: float = 0.0
	for facility: Dictionary in facilities.values():
		decor += float(Catalog.FACILITIES[facility.kind].get("decor", 0.0))
	return efficiency() * (1.0 + minf(decor, Catalog.DECOR_CAP))

# ---- the mouse -----------------------------------------------------------

## One unit of work on whatever was clicked. Returns what happened:
## {"did": "harvest" | "gather" | "pour" | "", "good": G, "amount": n}
func click(id: int) -> Dictionary:
	if not facilities.has(id):
		return {"did": ""}
	var facility: Dictionary = facilities[id]
	if float(facility.click_wait) > 0.0:
		return {"did": ""}
	var info: Dictionary = Catalog.FACILITIES[facility.kind]
	var result: Dictionary = {"did": ""}
	if not (facility.ready as Dictionary).is_empty():
		var total: float = 0.0
		var what: String = ""
		for good: String in facility.ready:
			_add(stock, good, float(facility.ready[good]))
			total += float(facility.ready[good])
			what = good
		facility.ready = {}
		result = {"did": "harvest", "good": what, "amount": total}
	elif info.has("source"):
		for good: String in info.source:
			if float(facility.held.get(good, 0.0)) >= 1.0:
				_add(facility.held, good, -1.0)
				_add(stock, good, 1.0)
				result = {"did": "gather", "good": good, "amount": 1.0}
				break
	elif String(facility.recipe) != "":
		# Pour whichever input the next batch is shortest of.
		var needs: Dictionary = Catalog.RECIPES[facility.recipe].needs
		var pick: String = ""
		var least: float = INF
		for good: String in needs:
			var held: float = float(facility.held.get(good, 0.0))
			if float(needs[good]) * Catalog.BUFFER_BATCHES - held < 1.0 or float(stock.get(good, 0.0)) < 1.0:
				continue
			if held / float(needs[good]) < least:
				least = held / float(needs[good])
				pick = good
		if pick != "":
			_add(stock, pick, -1.0)
			_add(facility.held, pick, 1.0)
			result = {"did": "pour", "good": pick, "amount": 1.0}
	if String(result.did) != "":
		facility.click_wait = Catalog.CLICK_COOLDOWN
	return result

# ---- the outing and the worth of the base --------------------------------

func expedition_ready() -> Dictionary:
	var missing: Dictionary = {}
	for good: String in Catalog.EXPEDITION_KIT:
		var short: float = float(Catalog.EXPEDITION_KIT[good]) - float(stock.get(good, 0.0))
		if short > 0.0001:
			missing[good] = short
	return {"ready": missing.is_empty(), "missing": missing}

## Packs the kit and leaves. True when the outing could start.
func depart() -> bool:
	if not bool(expedition_ready().ready):
		return false
	for good: String in Catalog.EXPEDITION_KIT:
		_add(stock, good, -float(Catalog.EXPEDITION_KIT[good]))
	return true

func prosperity() -> int:
	var total: int = 0
	for facility: Dictionary in facilities.values():
		total += int(Catalog.FACILITIES[facility.kind].get("prosperity", 0))
	return total

## Prosperity of the Sea of Consciousness turns into fighting strength.
func combat_power() -> float:
	return 10.0 + 2.0 * float(cultivator.cultivation) + 0.5 * float(prosperity())

# ---- time ----------------------------------------------------------------

func tick(delta: float) -> void:
	var left: float = maxf(0.0, delta)
	while left > 0.000001:
		var slice: float = minf(STEP, left)
		left -= slice
		_step(slice)

func _step(dt: float) -> void:
	seconds += dt
	if _networks_dirty:
		_rebuild_networks()
	for facility: Dictionary in facilities.values():
		facility.click_wait = maxf(0.0, float(facility.click_wait) - dt)
		var info: Dictionary = Catalog.FACILITIES[facility.kind]
		if info.has("source"):
			for good: String in info.source:
				facility.held[good] = minf(float(info.holds.get(good, 0.0)), float(facility.held.get(good, 0.0)) + float(info.source[good]) * dt)
	_flow_qi(dt)
	for facility: Dictionary in facilities.values():
		_grow(facility, dt)
	_live(dt)
	_act(dt)

func _grow(facility: Dictionary, dt: float) -> void:
	# Unstaffed work: fields and ore beds run by themselves once fed.
	var recipe_id: String = facility.recipe
	if recipe_id == "" or bool(Catalog.RECIPES[recipe_id].staffed):
		return
	var recipe: Dictionary = Catalog.RECIPES[recipe_id]
	if not bool(facility.active):
		# A ripe batch waits to be gathered before the next one starts.
		if not (facility.ready as Dictionary).is_empty() or not _has_inputs(facility.held, recipe.needs):
			return
		for good: String in recipe.needs:
			_add(facility.held, good, -float(recipe.needs[good]))
		facility.active = true
		facility.progress = 0.0
	facility.progress = float(facility.progress) + dt * (Catalog.FORMATION_SPEED if bool(facility.formation) else 1.0)
	if float(facility.progress) >= float(recipe.seconds):
		facility.active = false
		facility.progress = 0.0
		for good: String in recipe.makes:
			_add(facility.ready, good, float(recipe.makes[good]))

func _live(dt: float) -> void:
	cultivator.nourished_left = maxf(0.0, float(cultivator.nourished_left) - dt)
	if float(cultivator.fasting_left) > 0.0:
		cultivator.fasting_left = maxf(0.0, float(cultivator.fasting_left) - dt)
		return
	cultivator.food = maxf(0.0, float(cultivator.food) - dt / Catalog.FOOD_SECONDS)
	cultivator.drink = maxf(0.0, float(cultivator.drink) - dt / Catalog.DRINK_SECONDS)

# ---- qi through conduits -------------------------------------------------

func _rebuild_networks() -> void:
	_networks_dirty = false
	_networks.clear()
	for facility: Dictionary in facilities.values():
		facility.formation = false
	var seen: Dictionary = {}
	for start: Vector2i in conduits:
		if seen.has(start):
			continue
		var cells: Dictionary = {}
		var edges: int = 0
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			cells[cell] = true
			for side: Vector2i in SIDES:
				var next: Vector2i = cell + side
				if not conduits.has(next):
					continue
				edges += 1
				if not seen.has(next):
					seen[next] = true
					queue.append(next)
		var members: Array[int] = []
		for id: int in facilities:
			for side: Vector2i in SIDES:
				if cells.has((facilities[id].cell as Vector2i) + side):
					members.append(id)
					break
		# Each joint was counted from both ends. A run with as many joints as
		# cells closes on itself somewhere: a ring.
		var ring: bool = edges / 2 >= cells.size()
		if ring:
			for id: int in facilities:
				if _enclosed(facilities[id].cell, cells):
					facilities[id].formation = true
		_networks.append({"cells": cells, "members": members, "ring": ring})

func _enclosed(cell: Vector2i, ring_cells: Dictionary) -> bool:
	if ring_cells.has(cell):
		return false
	var low := Vector2i(999999, 999999)
	var high := Vector2i(-999999, -999999)
	for ring_cell: Vector2i in ring_cells:
		low = low.min(ring_cell)
		high = high.max(ring_cell)
	if cell.x <= low.x or cell.x >= high.x or cell.y <= low.y or cell.y >= high.y:
		return false
	# Walk outward over everything that is not conduit; reaching the box edge means a way out.
	var seen: Dictionary = {cell: true}
	var queue: Array[Vector2i] = [cell]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for side: Vector2i in SIDES:
			var next: Vector2i = at + side
			if ring_cells.has(next) or seen.has(next):
				continue
			if next.x <= low.x or next.x >= high.x or next.y <= low.y or next.y >= high.y:
				return false
			seen[next] = true
			queue.append(next)
	return true

func _flow_qi(dt: float) -> void:
	for network: Dictionary in _networks:
		var springs: Array[Dictionary] = []
		var urns: Array[Dictionary] = []
		var takers: Array[Dictionary] = []
		for id: int in network.members:
			var facility: Dictionary = facilities[id]
			var info: Dictionary = Catalog.FACILITIES[facility.kind]
			if info.get("source", {}).has("qi"):
				springs.append(facility)
			elif bool(info.get("relay", false)):
				urns.append(facility)
			elif _qi_room(facility) > 0.0:
				takers.append(facility)
		var wanted: Array[float] = []
		var total: float = 0.0
		for taker: Dictionary in takers:
			var want: float = minf(_qi_room(taker), Catalog.CONDUIT_RATE * dt)
			wanted.append(want)
			total += want
		if total > 0.0:
			var given: float = _draw(springs, total)
			if given < total:
				given += _draw(urns, total - given)
			for index: int in takers.size():
				_add(takers[index].held, "qi", wanted[index] * given / total)
		# What the springs cannot hand on goes into the urns.
		for urn: Dictionary in urns:
			var room: float = minf(float(Catalog.FACILITIES[urn.kind].holds.qi) - float(urn.held.get("qi", 0.0)), Catalog.CONDUIT_RATE * dt)
			if room > 0.0:
				_add(urn.held, "qi", _draw(springs, room))

func _qi_room(facility: Dictionary) -> float:
	var info: Dictionary = Catalog.FACILITIES[facility.kind]
	if info.get("holds", {}).has("qi"):
		return float(info.holds.qi) - float(facility.held.get("qi", 0.0))
	if String(facility.recipe) == "":
		return 0.0
	var needs: Dictionary = Catalog.RECIPES[facility.recipe].needs
	if not needs.has("qi"):
		return 0.0
	return float(needs.qi) * Catalog.BUFFER_BATCHES - float(facility.held.get("qi", 0.0))

func _draw(sources: Array[Dictionary], amount: float) -> float:
	var have: float = 0.0
	for source: Dictionary in sources:
		have += float(source.held.get("qi", 0.0))
	if have <= 0.0 or amount <= 0.0:
		return 0.0
	var taken: float = minf(have, amount)
	for source: Dictionary in sources:
		_add(source.held, "qi", -taken * float(source.held.get("qi", 0.0)) / have)
	return taken

# ---- the cultivator at work ----------------------------------------------

func _act(dt: float) -> void:
	var budget: float = dt
	var guard: int = 0
	while budget > 0.000001 and guard < 32:
		guard += 1
		if (cultivator.steps as Array).is_empty():
			if not _next_steps():
				return
			if (cultivator.steps as Array).is_empty():
				continue
		var step: Dictionary = cultivator.steps[0]
		var used: float = _run(step, budget)
		budget -= used
		if bool(step.get("done", false)):
			(cultivator.steps as Array).pop_front()
			if (cultivator.steps as Array).is_empty():
				_finish_order()

func _next_steps() -> bool:
	# Care for the body first when supplies exist, then the next order.
	var steps: Array = cultivator.steps
	if float(cultivator.fasting_left) <= 0.0:
		if float(cultivator.food) < 0.35 and (_spare_rations() >= 1.0 or float(stock.get("grain", 0.0)) >= 1.0):
			steps.append({"op": "eat", "left": 3.0})
			cultivator.order = {"type": "eat"}
			return true
		var well: int = _nearest_with("water")
		if float(cultivator.drink) < 0.35 and well != -1:
			steps.append({"op": "go", "to": facilities[well].cell})
			steps.append({"op": "drink", "at": well, "left": 2.0})
			cultivator.order = {"type": "drink"}
			return true
	var orders: Array = cultivator.orders
	if orders.is_empty():
		return false
	var order: Dictionary = orders.pop_front()
	cultivator.order = order
	match String(order.get("type", "")):
		"haul":
			var source: int = int(order.get("from", -1))
			if not facilities.has(int(order.to)) or (source != -1 and not facilities.has(source)):
				return _drop(order, {})
			if source != -1:
				steps.append({"op": "go", "to": facilities[source].cell})
			steps.append({"op": "take", "at": source, "good": order.good, "to": int(order.to), "left": Catalog.LOAD_SECONDS})
			steps.append({"op": "go", "to": facilities[int(order.to)].cell})
			steps.append({"op": "give", "at": int(order.to), "good": order.good, "left": Catalog.LOAD_SECONDS})
		"harvest":
			if not facilities.has(int(order.at)):
				return _drop(order, {})
			steps.append({"op": "go", "to": facilities[int(order.at)].cell})
			steps.append({"op": "harvest", "at": int(order.at), "left": Catalog.LOAD_SECONDS})
		"craft":
			if not facilities.has(int(order.at)) or not set_recipe(int(order.at), String(order.recipe)):
				return _drop(order, {})
			steps.append({"op": "go", "to": facilities[int(order.at)].cell})
			steps.append({"op": "work", "at": int(order.at), "count": int(order.get("count", 1)), "waited": 0.0})
		"cultivate":
			if not facilities.has(int(order.at)) or not bool(Catalog.FACILITIES[facilities[int(order.at)].kind].get("seat", false)):
				return _drop(order, {})
			steps.append({"op": "go", "to": facilities[int(order.at)].cell})
			steps.append({"op": "sit", "at": int(order.at), "left": float(order.get("seconds", 60.0))})
		"take_pill":
			steps.append({"op": "pill", "left": 1.0})
		_:
			return _drop(order, {})
	return true

func _drop(order: Dictionary, missing: Dictionary) -> bool:
	last_block = {"order": order, "missing": missing, "at_seconds": seconds}
	cultivator.order = {}
	(cultivator.steps as Array).clear()
	_unpack()
	return not (cultivator.orders as Array).is_empty()

func _finish_order() -> void:
	var order: Dictionary = cultivator.order
	cultivator.order = {}
	if bool(order.get("repeat", false)):
		(cultivator.orders as Array).append(order)

func _unpack() -> void:
	for good: String in cultivator.pack:
		_add(stock, good, float(cultivator.pack[good]))
	cultivator.pack = {}

## Runs one step for up to `budget` seconds and returns the time it used.
func _run(step: Dictionary, budget: float) -> float:
	var op: String = step.op
	if op == "go":
		var target := Vector2(step.to)
		var at: Vector2 = cultivator.at
		var distance: float = at.distance_to(target)
		var reach: float = Catalog.WALK_SPEED * efficiency() * budget
		if reach >= distance:
			cultivator.at = target
			step.done = true
			return budget * (distance / reach) if reach > 0.0 else 0.0
		cultivator.at = at.move_toward(target, reach)
		return budget
	if op == "work":
		return _work(step, budget)
	if op == "sit":
		var seat: Dictionary = facilities.get(int(step.at), {})
		if seat.is_empty():
			step.done = true
			return 0.0
		var span: float = minf(budget, float(step.left))
		var drawn: float = minf(Catalog.RAW_QI_RATE * span, float(seat.held.get("qi", 0.0)))
		_add(seat.held, "qi", -drawn)
		cultivator.cultivation = float(cultivator.cultivation) + drawn * Catalog.RAW_QI_YIELD * efficiency() * (Catalog.NOURISHED_GAIN if float(cultivator.nourished_left) > 0.0 else 1.0)
		step.left = float(step.left) - span
		step.done = float(step.left) <= 0.000001
		return span
	# Timed hand work: quicker when fed and watered.
	var speed: float = work_speed()
	var need: float = float(step.left) / speed
	if need > budget:
		step.left = float(step.left) - budget * speed
		return budget
	step.done = true
	_finish_hand_work(step)
	return need

func _finish_hand_work(step: Dictionary) -> void:
	match String(step.op):
		"take":
			var good: String = step.good
			var target: Dictionary = facilities.get(int(step.to), {})
			var room: float = _room_for(target, good) if not target.is_empty() else 0.0
			var amount: float = minf(Catalog.CARRY, room)
			if int(step.at) == -1:
				amount = minf(amount, float(stock.get(good, 0.0)))
				_add(stock, good, -amount)
			else:
				var source: Dictionary = facilities.get(int(step.at), {})
				amount = minf(amount, float(source.get("held", {}).get(good, 0.0))) if not source.is_empty() else 0.0
				if amount > 0.0:
					_add(source.held, good, -amount)
			if amount > 0.0:
				_add(cultivator.pack, good, amount)
		"give":
			var good: String = step.good
			var target: Dictionary = facilities.get(int(step.at), {})
			var carried: float = float(cultivator.pack.get(good, 0.0))
			if not target.is_empty() and carried > 0.0:
				var placed: float = minf(carried, _room_for(target, good))
				_add(target.held, good, placed)
				_add(cultivator.pack, good, -placed)
			_unpack()
		"harvest":
			var field: Dictionary = facilities.get(int(step.at), {})
			if not field.is_empty():
				for good: String in field.ready:
					_add(stock, good, float(field.ready[good]))
				field.ready = {}
		"eat":
			if _spare_rations() >= 1.0:
				_add(stock, "ration", -1.0)
				cultivator.food = minf(1.0, float(cultivator.food) + 0.6)
				cultivator.nourished_left = Catalog.NOURISHED_SECONDS
			elif float(stock.get("grain", 0.0)) >= 1.0:
				_add(stock, "grain", -1.0)
				cultivator.food = minf(1.0, float(cultivator.food) + 0.25)
		"drink":
			var well: Dictionary = facilities.get(int(step.at), {})
			if not well.is_empty() and float(well.held.get("water", 0.0)) >= 1.0:
				_add(well.held, "water", -1.0)
				cultivator.drink = 1.0
		"pill":
			if float(stock.get("pill_fast", 0.0)) >= 1.0:
				_add(stock, "pill_fast", -1.0)
				cultivator.fasting_left = Catalog.FASTING_SECONDS

func _work(step: Dictionary, budget: float) -> float:
	var facility: Dictionary = facilities.get(int(step.at), {})
	if facility.is_empty() or String(facility.recipe) == "":
		step.done = true
		return 0.0
	var recipe: Dictionary = Catalog.RECIPES[facility.recipe]
	if not bool(facility.active):
		# Qi must already stand in the facility (conduit, haul or click); the
		# other inputs come out of the storehouse with the cultivator.
		var missing: Dictionary = {}
		for good: String in recipe.needs:
			var have: float = float(facility.held.get(good, 0.0)) + (float(stock.get(good, 0.0)) if good != "qi" else 0.0)
			if have < float(recipe.needs[good]) - 0.0001:
				missing[good] = float(recipe.needs[good]) - have
		if not missing.is_empty():
			# Fetch what is short from wherever it stands before giving up.
			for good: String in missing:
				var source: int = _nearest_with(good, int(step.at))
				if source == -1:
					continue
				var steps: Array = cultivator.steps
				steps.push_front({"op": "give", "at": int(step.at), "good": good, "left": Catalog.LOAD_SECONDS})
				steps.push_front({"op": "go", "to": facility.cell})
				steps.push_front({"op": "take", "at": source, "good": good, "to": int(step.at), "left": Catalog.LOAD_SECONDS})
				steps.push_front({"op": "go", "to": facilities[source].cell})
				step.waited = 0.0
				return 0.0
			step.waited = float(step.waited) + budget
			if float(step.waited) >= 5.0:
				step.done = true
				last_block = {"order": cultivator.order, "missing": missing, "at_seconds": seconds}
				cultivator.order = {}
			return budget
		for good: String in recipe.needs:
			var from_held: float = minf(float(facility.held.get(good, 0.0)), float(recipe.needs[good]))
			_add(facility.held, good, -from_held)
			_add(stock, good, -(float(recipe.needs[good]) - from_held))
		facility.active = true
		facility.progress = 0.0
		step.waited = 0.0
	var rate: float = work_speed() * (Catalog.FORMATION_SPEED if bool(facility.formation) else 1.0)
	var need: float = (float(recipe.seconds) - float(facility.progress)) / rate
	if need > budget:
		facility.progress = float(facility.progress) + budget * rate
		return budget
	facility.active = false
	facility.progress = 0.0
	for good: String in recipe.makes:
		_add(stock, good, float(recipe.makes[good]))
	step.count = int(step.count) - 1
	step.done = int(step.count) <= 0
	return need

# ---- small helpers -------------------------------------------------------

func _room_for(facility: Dictionary, good: String) -> float:
	var info: Dictionary = Catalog.FACILITIES[facility.kind]
	if info.get("holds", {}).has(good):
		return float(info.holds[good]) - float(facility.held.get(good, 0.0))
	if String(facility.recipe) == "":
		return 0.0
	var needs: Dictionary = Catalog.RECIPES[facility.recipe].needs
	if not needs.has(good):
		return 0.0
	return maxf(0.0, float(needs[good]) * Catalog.BUFFER_BATCHES - float(facility.held.get(good, 0.0)))

func _spare_rations() -> float:
	# The outing's rations are not eaten at home; hunger only slows work.
	return float(stock.get("ration", 0.0)) - float(Catalog.EXPEDITION_KIT.get("ration", 0.0))

func _has_inputs(held: Dictionary, needs: Dictionary) -> bool:
	for good: String in needs:
		if float(held.get(good, 0.0)) < float(needs[good]) - 0.0001:
			return false
	return true

func _facility_at(cell: Vector2i) -> int:
	for id: int in facilities:
		if facilities[id].cell == cell:
			return id
	return -1

func _nearest_with(good: String, except: int = -1) -> int:
	# Only places that give the good out: springs, wells and urns, not another
	# facility's input buffer.
	var best: int = -1
	var best_d: float = INF
	for id: int in facilities:
		if id == except or float(facilities[id].held.get(good, 0.0)) < 1.0:
			continue
		var info: Dictionary = Catalog.FACILITIES[facilities[id].kind]
		if not info.get("source", {}).has(good) and not bool(info.get("relay", false)):
			continue
		var d: float = (cultivator.at as Vector2).distance_to(Vector2(facilities[id].cell))
		if d < best_d:
			best_d = d
			best = id
	return best

static func _add(pool: Dictionary, good: String, amount: float) -> void:
	var value: float = float(pool.get(good, 0.0)) + amount
	if value <= 0.000001:
		pool.erase(good)
	else:
		pool[good] = value

# ---- saving --------------------------------------------------------------

func to_dict() -> Dictionary:
	var out_facilities: Array = []
	for id: int in facilities:
		var copy: Dictionary = (facilities[id] as Dictionary).duplicate(true)
		copy["id"] = id
		copy["cell"] = [facilities[id].cell.x, facilities[id].cell.y]
		out_facilities.append(copy)
	var out_conduits: Array = []
	for cell: Vector2i in conduits:
		out_conduits.append([cell.x, cell.y])
	var who: Dictionary = cultivator.duplicate(true)
	who["at"] = [cultivator.at.x, cultivator.at.y]
	# Steps hold cell values and are rebuilt from the order on load.
	who["steps"] = []
	if not (cultivator.order as Dictionary).is_empty() and not ["eat", "drink"].has(String(cultivator.order.get("type", ""))):
		(who.orders as Array).push_front((cultivator.order as Dictionary).duplicate(true))
	who["order"] = {}
	return {"version": 1, "seconds": seconds, "stock": stock.duplicate(true), "facilities": out_facilities, "conduits": out_conduits, "cultivator": who, "next_id": _next_id}

func from_dict(data: Dictionary) -> void:
	seconds = float(data.get("seconds", 0.0))
	stock = (data.get("stock", {}) as Dictionary).duplicate(true)
	facilities.clear()
	for entry: Dictionary in data.get("facilities", []):
		var copy: Dictionary = entry.duplicate(true)
		var id: int = int(copy.id)
		copy.erase("id")
		copy["cell"] = Vector2i(int(entry.cell[0]), int(entry.cell[1]))
		facilities[id] = copy
	conduits.clear()
	for cell: Array in data.get("conduits", []):
		conduits[Vector2i(int(cell[0]), int(cell[1]))] = true
	var who: Dictionary = (data.get("cultivator", {}) as Dictionary).duplicate(true)
	if not who.is_empty():
		who["at"] = Vector2(float(who.at[0]), float(who.at[1]))
		who["steps"] = []
		who["order"] = {}
		# Whatever was in the pack mid-trip goes back to the storehouse.
		for good: String in who.get("pack", {}):
			_add(stock, good, float(who.pack[good]))
		who["pack"] = {}
		cultivator = who
	_next_id = int(data.get("next_id", facilities.size() + 1))
	_networks_dirty = true
