extends RefCounted
## 2 fields → 1 potion bench. Event-stepped, no per-plant nodes.
## WORK draws qi from the spring pool; GROWTH does not.

const LoopMath := preload("res://scripts/sim/loop_math.gd")

var fields: Array[Dictionary] = []
var bench: Dictionary = {}
var event_steps: int = 0
var last_block_reason: String = ""
var bench_enabled: bool = true
var research: Dictionary = {}


func setup_starter(cfg: RefCounted) -> void:
	var farm: Dictionary = cfg.farming()
	var stock: Dictionary = cfg.stock()
	fields = [
		_new_field(Vector2i(-2, 1), farm),
		_new_field(Vector2i(-1, 1), farm),
	]
	bench = {
		"cell": Vector2i(1, 1),
		"on": false,
		"in_batch": false,
		"work": 0.0,
		"potions": 0,
		"status": "idle",
		"work_required": float(stock["potion_work_minutes_per_batch_at_base_rate"]),
		"herbs_per_batch": int(stock["potion_herbs_per_batch"]),
		"qi": float(stock["potion_active_qi_per_minute"]),
		"buffer": int(stock["potion_output_buffer"]),
		"low": float(stock["example_potion_low"]),
		"high": float(stock["example_potion_high"]),
		"speed0": 1.0,
	}
	event_steps = 0
	last_block_reason = ""
	var res: Dictionary = cfg.research()
	research = {
		"cell": Vector2i(2, 1),
		"reserved_id": "",
		"work": 0.0,
		"status": "idle",
		"speed0": float(res["base_work_per_minute"]),
		"qi": float(res["active_qi_per_minute"]),
		"base_work": float(res["required_work_base"]),
		"rarity_mult": float(res["required_work_rarity_multiplier"]),
		"required": 0.0,
	}


func occupy(host: RefCounted) -> void:
	for field in fields:
		host.occupied[field["cell"]] = "field"
	host.occupied[bench["cell"]] = "bench"
	host.occupied[research["cell"]] = "research"


func total_herbs() -> int:
	var n := 0
	for field in fields:
		n += int(field["herbs"])
	return n


func potions() -> int:
	return int(bench["potions"])


func projected_potions() -> int:
	return int(bench["potions"]) + (1 if bench["in_batch"] else 0)


func advance(host: RefCounted, dt: float) -> int:
	var left: float = dt
	var steps := 0
	while left > 1e-9 and steps < 100000:
		_start_ready(host)
		var ev: Dictionary = _next_event(host)
		var step: float = minf(left, float(ev["t"]))
		if step <= 1e-12:
			if String(ev["kind"]) == "blocked":
				last_block_reason = String(ev.get("reason", "blocked"))
				break
			if not _resolve(host, ev):
				last_block_reason = String(ev.get("reason", "blocked"))
				break
			steps += 1
			continue
		_integrate(host, step)
		left -= step
		if String(ev["kind"]) != "end" and step + 1e-12 >= float(ev["t"]):
			_resolve(host, ev)
			steps += 1
		else:
			break
	event_steps += steps
	if left <= 1e-9:
		_start_ready(host)
	return steps


func forecast_minutes(host: RefCounted) -> Dictionary:
	var saved: Dictionary = to_dict()
	var pool: float = host.total_pool()
	var overflow: float = float(host.springs[0]["overflow"])
	var t := 0.0
	var steps := 0
	while t < 600.0 and steps < 50000:
		_start_ready(host)
		var snap: Dictionary = _snapshot(host)
		if not bool(snap["producing"]):
			from_dict(saved)
			host.springs[0]["pool"] = pool
			host.springs[0]["overflow"] = overflow
			return {"minutes": t, "reason": String(snap["block_reason"])}
		var ev: Dictionary = _next_event(host)
		if String(ev["kind"]) == "blocked":
			from_dict(saved)
			host.springs[0]["pool"] = pool
			host.springs[0]["overflow"] = overflow
			return {"minutes": t, "reason": String(ev.get("reason", "blocked"))}
		var step: float = float(ev["t"])
		if step >= INF or step > 600.0 - t:
			from_dict(saved)
			host.springs[0]["pool"] = pool
			host.springs[0]["overflow"] = overflow
			return {"minutes": INF, "reason": "steady"}
		_integrate(host, step)
		t += step
		_resolve(host, ev)
		steps += 1
	from_dict(saved)
	host.springs[0]["pool"] = pool
	host.springs[0]["overflow"] = overflow
	return {"minutes": t, "reason": "horizon"}


func status_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for i in fields.size():
		var f: Dictionary = fields[i]
		lines.append("田%d %s  药草 %d/%d" % [i + 1, String(f["status"]), int(f["herbs"]), int(f["herb_cap"])])
	lines.append("工台 %s  药品 %d/%d  %s" % [
		String(bench["status"]),
		int(bench["potions"]),
		int(bench["buffer"]),
		"开" if bench["on"] else "待命",
	])
	lines.append("研究 %s  样本 %s" % [
		String(research.get("status", "idle")),
		String(research.get("reserved_id", "")) if String(research.get("reserved_id", "")) != "" else "无",
	])
	return lines


func to_dict() -> Dictionary:
	return {
		"fields": _dup_array(fields),
		"bench": bench.duplicate(true),
		"event_steps": event_steps,
		"bench_enabled": bench_enabled,
		"research": _dup_research(),
	}


func from_dict(data: Dictionary) -> void:
	fields = []
	for row in data.get("fields", []):
		var f: Dictionary = (row as Dictionary).duplicate(true)
		var cell: Variant = f["cell"]
		if cell is Array:
			f["cell"] = Vector2i(int(cell[0]), int(cell[1]))
		fields.append(f)
	bench = (data.get("bench", {}) as Dictionary).duplicate(true)
	var bcell: Variant = bench.get("cell", Vector2i(1, 1))
	if bcell is Array:
		bench["cell"] = Vector2i(int(bcell[0]), int(bcell[1]))
	event_steps = int(data.get("event_steps", 0))
	bench_enabled = bool(data.get("bench_enabled", true))
	if data.has("research"):
		research = (data["research"] as Dictionary).duplicate(true)
		var rcell: Variant = research.get("cell", Vector2i(2, 1))
		if rcell is Array:
			research["cell"] = Vector2i(int(rcell[0]), int(rcell[1]))


func _new_field(cell: Vector2i, farm: Dictionary) -> Dictionary:
	return {
		"cell": cell,
		"stage": "idle",
		"work": 0.0,
		"seed": 1,
		"herbs": 0,
		"status": "idle",
		"sow_work": float(farm["sow_work_required"]),
		"grow_work": float(farm["growth_work_required"]),
		"harvest_work": float(farm["harvest_work_required"]),
		"sow_speed": float(farm["sow_harvest_work_per_minute"]),
		"grow_speed": float(farm["natural_growth_work_per_minute"]),
		"harvest_speed": float(farm["sow_harvest_work_per_minute"]),
		"sow_qi": float(farm["sow_harvest_qi_per_minute"]),
		"harvest_qi": float(farm["sow_harvest_qi_per_minute"]),
		"herb_yield": int(farm["harvest_herbs"]),
		"seed_return": int(farm["seed_returned_per_cycle"]),
		"herb_cap": int(farm["local_herb_output_capacity"]),
	}


func _start_ready(host: RefCounted) -> void:
	for field in fields:
		if String(field["stage"]) == "idle" and int(field["seed"]) >= 1:
			field["seed"] = int(field["seed"]) - 1
			field["stage"] = "sow"
			field["work"] = 0.0
			field["status"] = "sow"
		elif String(field["stage"]) == "harvest" and float(field["work"]) + 1e-9 >= float(field["harvest_work"]):
			if int(field["herbs"]) + int(field["herb_yield"]) <= int(field["herb_cap"]):
				_complete_harvest(field)
	_update_bench_on()
	if bench_enabled and bench["on"] and not bench["in_batch"] and int(bench["potions"]) < int(bench["buffer"]):
		if projected_potions() < int(bench["high"]) and total_herbs() >= int(bench["herbs_per_batch"]):
			if _take_herbs(int(bench["herbs_per_batch"])):
				bench["in_batch"] = true
				bench["work"] = 0.0
				bench["status"] = "work"
	_start_research(host)


func _start_research(host: RefCounted) -> void:
	if String(research.get("reserved_id", "")) == "":
		research["status"] = "idle"
		return
	if not _sample_present(host):
		research["status"] = "paused"
		return
	if host.topic_completed(host.items.topic_of(String(research["reserved_id"]))):
		research["status"] = "already_done"
		return
	var item: Dictionary = host.items.get_item(String(research["reserved_id"]))
	research["required"] = host.research_work_for(int(item.get("rarity", 0)))
	var saved: float = host.research_progress(host.items.topic_of(String(research["reserved_id"])))
	if float(research["work"]) < saved:
		research["work"] = saved
	research["status"] = "work"


func _research_running(host: RefCounted) -> bool:
	if String(research.get("reserved_id", "")) == "":
		return false
	if not _sample_present(host):
		return false
	if host.topic_completed(host.items.topic_of(String(research["reserved_id"]))):
		return false
	return true


func _sample_present(host: RefCounted) -> bool:
	var id := String(research.get("reserved_id", ""))
	if id == "":
		return false
	var item: Dictionary = host.items.get_item(id)
	return not item.is_empty() and String(item.get("location", "")) == "research"


func _dup_research() -> Dictionary:
	var d: Dictionary = research.duplicate(true)
	var c: Vector2i = d["cell"]
	d["cell"] = [c.x, c.y]
	return d


func _update_bench_on() -> void:
	bench["on"] = LoopMath.stock_on(
		bool(bench["on"]),
		float(bench["potions"]),
		float(projected_potions()),
		float(bench["low"]),
		float(bench["high"])
	)
	if int(bench["potions"]) >= int(bench["buffer"]) and not bench["in_batch"]:
		bench["on"] = false
		bench["status"] = "output_full"
	elif not bench["on"] and not bench["in_batch"]:
		if int(bench["potions"]) >= int(bench["high"]):
			bench["status"] = "stock_done"
		elif total_herbs() < int(bench["herbs_per_batch"]):
			bench["status"] = "no_input"
		else:
			bench["status"] = "idle"


func _next_event(host: RefCounted) -> Dictionary:
	var snap: Dictionary = _snapshot(host)
	var best_t: float = INF
	var best := {"kind": "blocked", "t": INF, "reason": String(snap["block_reason"])}
	if float(snap["t_field"]) < best_t:
		best_t = float(snap["t_field"])
		best = {"kind": "field", "t": best_t, "index": int(snap["field_index"])}
	if float(snap["t_bench"]) < best_t:
		best_t = float(snap["t_bench"])
		best = {"kind": "bench", "t": best_t}
	if float(snap["t_research"]) < best_t:
		best_t = float(snap["t_research"])
		best = {"kind": "research", "t": best_t}
	if float(snap["t_pool"]) < best_t:
		best_t = float(snap["t_pool"])
		best = {"kind": "pool", "t": best_t, "reason": String(snap["pool_reason"])}
	if best_t >= INF:
		return {"kind": "blocked", "t": INF, "reason": String(snap["block_reason"])}
	best["t"] = best_t
	return best


func _snapshot(host: RefCounted) -> Dictionary:
	var phi_fields: PackedFloat32Array = PackedFloat32Array()
	var want_qi := 0.0
	phi_fields.resize(fields.size())
	for i in fields.size():
		var f: Dictionary = fields[i]
		var phi: float = host.phi_at(f["cell"])
		phi_fields[i] = phi
		var stage := String(f["stage"])
		if stage == "sow":
			want_qi += float(f["sow_qi"])
		elif stage == "harvest" and int(f["herbs"]) + int(f["herb_yield"]) <= int(f["herb_cap"]):
			want_qi += float(f["harvest_qi"])
	var phi_bench: float = host.phi_at(bench["cell"])
	if bench["in_batch"]:
		want_qi += float(bench["qi"])
	if _research_running(host):
		want_qi += float(research["qi"])
	var I: float = host.inflow_rate()
	var X: float = host.total_pool()
	var cap: float = host.pool_cap()
	var dmax: float = host.draw_cap()
	var u := 1.0
	if want_qi > 1e-12:
		if X <= 1e-12:
			u = clampf(minf(dmax, I) / want_qi, 0.0, 1.0)
		elif want_qi > dmax:
			u = dmax / want_qi
	var P: float = want_qi * u
	var speeds: PackedFloat32Array = PackedFloat32Array()
	speeds.resize(fields.size())
	var t_field := INF
	var field_index := 0
	var any_work := false
	for i in fields.size():
		var f: Dictionary = fields[i]
		var phi: float = phi_fields[i]
		var stage := String(f["stage"])
		var speed := 0.0
		var remain := 0.0
		if stage == "sow":
			speed = float(f["sow_speed"]) * phi * u
			remain = float(f["sow_work"]) - float(f["work"])
			any_work = true
		elif stage == "grow":
			speed = float(f["grow_speed"]) * phi
			remain = float(f["grow_work"]) - float(f["work"])
			any_work = true
		elif stage == "harvest" and int(f["herbs"]) + int(f["herb_yield"]) <= int(f["herb_cap"]):
			speed = float(f["harvest_speed"]) * phi * u
			remain = float(f["harvest_work"]) - float(f["work"])
			any_work = true
		speeds[i] = speed
		var tf: float = LoopMath.stage_time(remain, speed)
		if tf < t_field:
			t_field = tf
			field_index = i
	var bench_speed := 0.0
	var t_bench := INF
	if bench["in_batch"]:
		bench_speed = float(bench["speed0"]) * phi_bench * u
		t_bench = LoopMath.stage_time(float(bench["work_required"]) - float(bench["work"]), bench_speed)
		any_work = true
	var research_speed := 0.0
	var t_research := INF
	if _research_running(host):
		var phi_r: float = host.phi_at(research["cell"])
		research_speed = float(research["speed0"]) * phi_r * u
		t_research = LoopMath.stage_time(float(research["required"]) - float(research["work"]), research_speed)
		any_work = true
		research["status"] = "work"
	var t_pool := INF
	var pool_reason := ""
	if P > I + 1e-12 and X > 1e-12:
		t_pool = X / (P - I)
		pool_reason = "empty"
	elif I > P + 1e-12 and X + 1e-12 < cap:
		t_pool = (cap - X) / (I - P)
		pool_reason = "full"
	var block := "idle"
	if not any_work:
		if int(bench["potions"]) >= int(bench["high"]):
			block = "stock_done"
		elif u <= 1e-12 and want_qi > 1e-12:
			block = "no_energy"
		elif total_herbs() >= int(fields[0]["herb_cap"]) * fields.size():
			block = "herb_full"
		else:
			block = "idle"
	return {
		"u": u,
		"P": P,
		"I": I,
		"speeds": speeds,
		"bench_speed": bench_speed,
		"t_field": t_field,
		"field_index": field_index,
		"t_bench": t_bench,
		"t_research": t_research,
		"research_speed": research_speed,
		"t_pool": t_pool,
		"pool_reason": pool_reason,
		"block_reason": block,
		"producing": any_work,
	}


func _integrate(host: RefCounted, dt: float) -> void:
	var snap: Dictionary = _snapshot(host)
	host.add_pool((float(snap["I"]) - float(snap["P"])) * dt)
	var speeds: PackedFloat32Array = snap["speeds"]
	for i in fields.size():
		fields[i]["work"] = float(fields[i]["work"]) + float(speeds[i]) * dt
	if bench["in_batch"]:
		bench["work"] = float(bench["work"]) + float(snap["bench_speed"]) * dt
	if _research_running(host):
		research["work"] = float(research["work"]) + float(snap["research_speed"]) * dt


func _resolve(host: RefCounted, ev: Dictionary) -> bool:
	var kind := String(ev["kind"])
	if kind == "field":
		return _complete_field(int(ev["index"]))
	if kind == "bench":
		return _complete_bench()
	if kind == "research":
		return host.complete_research(String(research["reserved_id"]))
	if kind == "pool":
		return true
	return false


func _complete_field(index: int) -> bool:
	var f: Dictionary = fields[index]
	var stage := String(f["stage"])
	if stage == "sow":
		f["stage"] = "grow"
		f["work"] = 0.0
		f["status"] = "grow"
		return true
	if stage == "grow":
		f["stage"] = "harvest"
		f["work"] = 0.0
		f["status"] = "harvest"
		return true
	if stage == "harvest":
		if int(f["herbs"]) + int(f["herb_yield"]) > int(f["herb_cap"]):
			f["status"] = "output_full"
			return false
		_complete_harvest(f)
		return true
	return false


func _complete_harvest(f: Dictionary) -> void:
	f["herbs"] = int(f["herbs"]) + int(f["herb_yield"])
	f["seed"] = int(f["seed"]) + int(f["seed_return"])
	f["stage"] = "idle"
	f["work"] = 0.0
	f["status"] = "idle"


func _complete_bench() -> bool:
	if not bench["in_batch"]:
		return false
	bench["in_batch"] = false
	bench["work"] = 0.0
	bench["potions"] = int(bench["potions"]) + 1
	_update_bench_on()
	return true


func _take_herbs(n: int) -> bool:
	if total_herbs() < n:
		return false
	var left := n
	for field in fields:
		var have: int = int(field["herbs"])
		var take: int = mini(have, left)
		field["herbs"] = have - take
		left -= take
		if left == 0:
			return true
	return false


func _dup_array(rows: Array[Dictionary]) -> Array:
	var out: Array = []
	for row in rows:
		var d: Dictionary = row.duplicate(true)
		var c: Vector2i = d["cell"]
		d["cell"] = [c.x, c.y]
		out.append(d)
	return out
