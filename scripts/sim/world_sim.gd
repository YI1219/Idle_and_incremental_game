extends RefCounted
## Idle kernel: sparse land + springs + pool. Not a Node.
##
## Performance contract:
## - No Node / RigidBody / script per cell. Land is a Dictionary.
## - Economy never runs in _process. Host calls catch_up(now_minutes).
## - Pool fill is closed-form for the whole dt (one add, one min with cap).
## - Offline is the same catch_up, dt capped at 10h. Not 10h of ticks.
## - Nourishment is recomputed only when land, quota, budget, or seep changes.

const LandMathLib := preload("res://scripts/sim/land_math.gd")
const SimConfigLib := preload("res://scripts/sim/sim_config.gd")
const CraftLoopLib := preload("res://scripts/sim/craft_loop.gd")
const ItemStoreLib := preload("res://scripts/sim/item_store.gd")
const ItemMath := preload("res://scripts/sim/item_math.gd")
const ExploreTripLib := preload("res://scripts/sim/explore_trip.gd")

const CELL := 1.0
const PREFAB_X0 := -4
const PREFAB_X1 := 4
const PREFAB_Z0 := -2
const PREFAB_Z1 := 4

var cfg: RefCounted
var policy: String = "soft_dormant"
var cells_in_order: Array[Vector2i] = []
var cell_index: Dictionary = {} ## Vector2i -> order index, rebuilt on mutate
var occupied: Dictionary = {} ## Vector2i -> String
var protection_quota: int = 0
var land_budget: float = 2.4
var springs: Array[Dictionary] = []
var sim_minutes: float = 0.0
var catch_up_calls: int = 0
var apply_steps: int = 0
var show_desaturation: bool = true
var phi_min: float = 0.35
var ledger_cache: Dictionary = {}
var nourished: Dictionary = {} ## Vector2i -> bool
var craft: RefCounted
var items: RefCounted
var knowledge: Dictionary = {}
var trip: RefCounted
var _dirty_ledger: bool = true


func _init(p_cfg: RefCounted = null) -> void:
	cfg = p_cfg if p_cfg else SimConfigLib.new()
	var land: Dictionary = cfg.land()
	policy = String(land.get("policy", "soft_dormant"))
	land_budget = float(land["paid_maintenance_budget_qi_per_minute"])
	show_desaturation = bool(land.get("show_desaturation", true))
	phi_min = float(land.get("dormant_productivity_floor", 0.35))
	trip = ExploreTripLib.new()


func reset_prefab() -> void:
	cells_in_order.clear()
	cell_index.clear()
	occupied.clear()
	protection_quota = 0
	springs.clear()
	sim_minutes = 0.0
	catch_up_calls = 0
	apply_steps = 0
	var sp: Dictionary = cfg.spring()
	springs.append({
		"seep": float(sp["base_seep_qi_per_minute"]),
		"pool": float(sp["initial_pool_qi"]),
		"cap": float(sp["pool_capacity_qi"]),
		"dmax": float(sp["max_draw_qi_per_minute"]),
		"overflow": 0.0,
	})
	for x in range(PREFAB_X0, PREFAB_X1):
		for z in range(PREFAB_Z0, PREFAB_Z1):
			_insert_cell(Vector2i(x, z))
	occupied[Vector2i(0, 0)] = "spring"
	occupied[Vector2i(0, 3)] = "gate"
	knowledge = {"discovered": {}, "completed": {}, "progress": {}}
	trip = ExploreTripLib.new()
	items = ItemStoreLib.new()
	items.configure(cfg)
	items.spawn_starter()
	craft = CraftLoopLib.new()
	craft.setup_starter(cfg)
	craft.occupy(self)
	_mark_ledger_dirty()
	recompute()


func cell_count() -> int:
	return cells_in_order.size()


func has_cell(c: Vector2i) -> bool:
	return cell_index.has(c)


func is_occupied(c: Vector2i) -> bool:
	return occupied.has(c)


func total_seep() -> float:
	var s := 0.0
	for spring in springs:
		s += float(spring["seep"])
	return s


func total_pool() -> float:
	var x := 0.0
	for spring in springs:
		x += float(spring["pool"])
	return x


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))


func cell_center(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * CELL, 0.0, (float(c.y) + 0.5) * CELL)


func catch_up(now_minutes: float, offline: bool = false) -> void:
	catch_up_calls += 1
	var dt: float = now_minutes - sim_minutes
	if dt <= 0.0:
		sim_minutes = now_minutes
		return
	if offline:
		dt = minf(dt, cfg.offline_cap_minutes())
	if craft:
		craft.advance(self, dt)
	else:
		_apply_pool(dt)
	apply_steps += 1
	sim_minutes = now_minutes


func phi_at(c: Vector2i) -> float:
	recompute()
	var covered: float = 1.0 if bool(nourished.get(c, false)) else 0.0
	return LandMathLib.efficiency(covered, phi_min, 1.0)


func inflow_rate() -> float:
	recompute()
	return float(ledger_cache.get("inflow", 0.0))


func pool_cap() -> float:
	if springs.is_empty():
		return 0.0
	return float(springs[0]["cap"])


func draw_cap() -> float:
	if springs.is_empty():
		return 0.0
	return float(springs[0]["dmax"])


func add_pool(delta: float) -> void:
	if springs.is_empty():
		return
	var spring: Dictionary = springs[0]
	var cap: float = float(spring["cap"])
	var x: float = float(spring["pool"]) + delta
	if x > cap:
		spring["overflow"] = float(spring["overflow"]) + (x - cap)
		spring["pool"] = cap
	else:
		spring["pool"] = maxf(0.0, x)


func runtime_forecast() -> Dictionary:
	var snap: Dictionary = _state_snap()
	var result: Dictionary = {"minutes": INF, "reason": "pool"}
	if craft:
		result = craft.forecast_minutes(self)
	else:
		result = {"minutes": minutes_until_pool_full(), "reason": "pool"}
	_restore_state(snap)
	return result


func minutes_until_pool_full() -> float:
	recompute()
	var inflow: float = float(ledger_cache["inflow"])
	if inflow <= 1e-12:
		return INF
	var room := 0.0
	for spring in springs:
		room += float(spring["cap"]) - float(spring["pool"])
	if room <= 1e-12:
		return 0.0
	return room / inflow


func try_place(c: Vector2i) -> String:
	if has_cell(c):
		return "already_land"
	if cell_count() >= int(cfg.land()["hard_area_cap"]):
		return "area_cap"
	if cell_count() > 0 and not _is_edge_adjacent(c):
		return "not_adjacent"
	if policy == "strict_capacity" and not _strict_allows(cell_count() + 1):
		return "seep_cap"
	_insert_cell(c)
	_mark_ledger_dirty()
	recompute()
	return "ok"


func try_delete(c: Vector2i) -> String:
	if not has_cell(c):
		return "no_land"
	if is_occupied(c):
		return "occupied"
	_remove_cell(c)
	_mark_ledger_dirty()
	recompute()
	return "ok"


func set_land_budget(value: float) -> void:
	land_budget = maxf(0.0, value)
	_mark_ledger_dirty()
	recompute()


func add_protection(quota: int) -> void:
	protection_quota = maxi(0, protection_quota + quota)
	_mark_ledger_dirty()
	recompute()


func recompute() -> void:
	if not _dirty_ledger:
		return
	var land: Dictionary = cfg.land()
	ledger_cache = LandMathLib.ledger(
		cell_count(),
		protection_quota,
		total_seep(),
		int(land["base_free_cells"]),
		float(land["tax_qi_per_cell_minute"]),
		land_budget
	)
	_assign_nourishment()
	_dirty_ledger = false


func to_dict() -> Dictionary:
	var packed: Array = []
	for c in cells_in_order:
		packed.append([c.x, c.y])
	var occ: Dictionary = {}
	for key in occupied.keys():
		var c: Vector2i = key
		occ["%d,%d" % [c.x, c.y]] = occupied[key]
	var spring_rows: Array = []
	for spring in springs:
		spring_rows.append(spring.duplicate())
	return {
		"policy": policy,
		"cells": packed,
		"occupied": occ,
		"protection_quota": protection_quota,
		"land_budget": land_budget,
		"springs": spring_rows,
		"sim_minutes": sim_minutes,
		"craft": craft.to_dict() if craft else {},
		"items": items.to_dict() if items else {},
		"knowledge": knowledge.duplicate(true),
		"trip": trip.to_dict() if trip else {},
	}


func from_dict(data: Dictionary) -> void:
	policy = String(data.get("policy", "soft_dormant"))
	cells_in_order.clear()
	cell_index.clear()
	for row in data.get("cells", []):
		_insert_cell(Vector2i(int(row[0]), int(row[1])))
	occupied.clear()
	var occ: Dictionary = data.get("occupied", {})
	for key in occ.keys():
		var parts: PackedStringArray = String(key).split(",")
		occupied[Vector2i(int(parts[0]), int(parts[1]))] = occ[key]
	protection_quota = int(data.get("protection_quota", 0))
	land_budget = float(data.get("land_budget", land_budget))
	springs.clear()
	for row in data.get("springs", []):
		springs.append((row as Dictionary).duplicate())
	sim_minutes = float(data.get("sim_minutes", 0.0))
	if craft == null:
		craft = CraftLoopLib.new()
		craft.setup_starter(cfg)
	if data.has("craft") and not (data["craft"] as Dictionary).is_empty():
		craft.from_dict(data["craft"])
	if items == null:
		items = ItemStoreLib.new()
		items.configure(cfg)
	if data.has("items") and not (data["items"] as Dictionary).is_empty():
		items.from_dict(data["items"])
	if data.has("knowledge"):
		knowledge = (data["knowledge"] as Dictionary).duplicate(true)
	if trip == null:
		trip = ExploreTripLib.new()
	if data.has("trip") and not (data["trip"] as Dictionary).is_empty():
		trip.from_dict(data["trip"])
	craft.occupy(self)
	_mark_ledger_dirty()
	recompute()


func topic_completed(key: String) -> bool:
	return bool((knowledge.get("completed", {}) as Dictionary).get(key, false))


func research_progress(key: String) -> float:
	return float((knowledge.get("progress", {}) as Dictionary).get(key, 0.0))


func research_work_for(rarity: int) -> float:
	var res: Dictionary = cfg.research()
	return ItemMath.research_work(rarity, float(res["required_work_base"]), float(res["required_work_rarity_multiplier"]))


func try_assign_research(item_id: String = "") -> String:
	if item_id == "":
		item_id = items.first_in("world")
		if item_id == "":
			item_id = items.first_in("overhead")
		if item_id == "":
			item_id = items.first_in("bag")
	if item_id == "":
		return "no_sample"
	if not items.get_item(item_id).get("portable", true):
		return "not_portable"
	var key: String = items.topic_of(item_id)
	var moved: String = items.move(item_id, "research")
	if moved != "ok":
		return moved
	craft.research["reserved_id"] = item_id
	craft.research["work"] = research_progress(key)
	var item: Dictionary = items.get_item(item_id)
	craft.research["required"] = research_work_for(int(item.get("rarity", 0)))
	(knowledge.get("discovered", {}) as Dictionary)[String(item.get("def_id", ""))] = true
	return "already_done" if topic_completed(key) else "ok"


func try_collect(item_id: String = "") -> String:
	if item_id == "":
		item_id = String(craft.research.get("reserved_id", ""))
		if item_id == "":
			item_id = items.first_in("world")
	if item_id == "":
		return "no_sample"
	if items.collection_id != "" and items.collection_id != item_id:
		return "collection_full"
	if String(craft.research.get("reserved_id", "")) == item_id:
		_save_research_progress()
		craft.research["reserved_id"] = ""
		craft.research["status"] = "idle"
	return items.move(item_id, "collection")


func try_pack_overhead() -> PackedStringArray:
	return items.pack_all_overhead()


func try_overhead_sample() -> String:
	if items.overhead.size() >= items.overhead_k:
		return "overhead_full"
	return items.assign_overhead(items.spawn(_float_core_fields()))


func expedition_return() -> String:
	return try_overhead_sample()


func expedition_fail() -> PackedStringArray:
	return items.wipe_carried()


func complete_research(item_id: String) -> bool:
	var item: Dictionary = items.get_item(item_id)
	if item.is_empty():
		return false
	var before: int = items.count_all()
	var rarity: int = int(item.get("rarity", 0))
	var stack: int = int(item.get("stack", 1))
	var key: String = items.topic_of(item_id)
	var first: bool = not topic_completed(key)
	(knowledge["progress"] as Dictionary)[key] = research_work_for(rarity)
	(knowledge["completed"] as Dictionary)[key] = true
	(knowledge["discovered"] as Dictionary)[String(item.get("def_id", ""))] = true
	if first:
		_apply_item_reward(String(item.get("reward", "")))
	items.move(item_id, "world")
	craft.research["reserved_id"] = ""
	craft.research["work"] = 0.0
	craft.research["status"] = "done"
	var after_item: Dictionary = items.get_item(item_id)
	return items.count_all() == before and int(after_item.get("stack", 0)) == stack and int(after_item.get("rarity", -1)) == rarity


func _save_research_progress() -> void:
	var id := String(craft.research.get("reserved_id", ""))
	if id == "":
		return
	(knowledge["progress"] as Dictionary)[items.topic_of(id)] = float(craft.research.get("work", 0.0))


func _apply_item_reward(reward: String) -> void:
	if reward == "protection_16":
		add_protection(16)


func _float_core_fields() -> Dictionary:
	return {
		"def_id": "float_core",
		"topic_id": "protection_quota",
		"variant": "basic",
		"rarity": 1,
		"portable": true,
		"stack": 1,
		"stack_max": 1,
		"shape": [[0, 0], [1, 0], [0, 1], [1, 1]],
		"reward": "protection_16",
		"location": "world",
		"revealed": true,
	}


func _state_snap() -> Dictionary:
	return {
		"craft": craft.to_dict() if craft else {},
		"items": items.to_dict() if items else {},
		"knowledge": knowledge.duplicate(true),
		"quota": protection_quota,
		"pool": springs[0]["pool"] if not springs.is_empty() else 0.0,
		"overflow": springs[0]["overflow"] if not springs.is_empty() else 0.0,
	}


func _restore_state(snap: Dictionary) -> void:
	if craft and snap.has("craft"):
		craft.from_dict(snap["craft"])
	if items and snap.has("items"):
		items.from_dict(snap["items"])
	knowledge = (snap.get("knowledge", {}) as Dictionary).duplicate(true)
	protection_quota = int(snap.get("quota", protection_quota))
	if not springs.is_empty():
		springs[0]["pool"] = snap.get("pool", springs[0]["pool"])
		springs[0]["overflow"] = snap.get("overflow", springs[0]["overflow"])
	_mark_ledger_dirty()
	recompute()


func _apply_pool(dt: float) -> void:
	recompute()
	var tax: float = float(ledger_cache["maintenance"])
	var seep := total_seep()
	for spring in springs:
		var share: float = 0.0 if seep <= 0.0 else float(spring["seep"]) / seep
		var inflow: float = float(spring["seep"]) - tax * share
		var pool: float = float(spring["pool"])
		var cap: float = float(spring["cap"])
		if inflow > 0.0:
			var room: float = cap - pool
			var fill_t: float = INF if inflow <= 0.0 else room / inflow
			if dt >= fill_t:
				spring["overflow"] = float(spring["overflow"]) + inflow * (dt - fill_t)
				spring["pool"] = cap
			else:
				spring["pool"] = pool + inflow * dt
		elif inflow < 0.0:
			spring["pool"] = maxf(0.0, pool + inflow * dt)


func _assign_nourishment() -> void:
	nourished.clear()
	var free: int = int(ledger_cache["free"])
	var paid: int = int(ledger_cache["paid"])
	var covered: int = free + paid
	for i in cells_in_order.size():
		nourished[cells_in_order[i]] = i < covered


func _insert_cell(c: Vector2i) -> void:
	cell_index[c] = cells_in_order.size()
	cells_in_order.append(c)


func _remove_cell(c: Vector2i) -> void:
	var idx: int = int(cell_index[c])
	cells_in_order.remove_at(idx)
	cell_index.erase(c)
	for i in range(idx, cells_in_order.size()):
		cell_index[cells_in_order[i]] = i


func _is_edge_adjacent(c: Vector2i) -> bool:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		if has_cell(c + d):
			return true
	return false


func _strict_allows(new_area: int) -> bool:
	var land: Dictionary = cfg.land()
	var next: Dictionary = LandMathLib.ledger(
		new_area,
		protection_quota,
		total_seep(),
		int(land["base_free_cells"]),
		float(land["tax_qi_per_cell_minute"]),
		land_budget
	)
	var required: float = float(next["uncovered"]) * float(land["tax_qi_per_cell_minute"])
	return required <= total_seep() + 1e-9


func _mark_ledger_dirty() -> void:
	_dirty_ledger = true
