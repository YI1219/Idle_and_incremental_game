extends SceneTree
## Records the behaviour of the part-one production simulation
## (scripts/gameplay/base/base_sim.gd) as reference data for the runtime port.
## Pure data, so it runs headless:
##   godot --headless --path . --script tools/export/export_production_trace.gd -- --out=runtime/data/reference
##
## Each scenario lists the calls made on the simulation in order, with the
## simulated time of each call, and snapshots of to_dict() at fixed times.
## Replay rule for a port: start at t = 0; for each event in the scenario's
## "timeline", advance time to the event's t (in ticks of at most
## "step_seconds"), then make the call or take the snapshot. Read-only queries
## (stock lookups, expedition_ready() polls) are not listed as calls.
const Sim = preload("res://scripts/gameplay/base/base_sim.gd")
const SIM_PATH: String = "res://scripts/gameplay/base/base_sim.gd"
const CATALOG_PATH: String = "res://scripts/gameplay/base/base_catalog.gd"
const STEP: float = 0.25

var sim: RefCounted
var now: float = 0.0
var calls: Array = []
var snapshots: Array = []
## [kind, index, raw args or label]: the order calls and snapshots happened in.
var timeline: Array = []
var batches: Dictionary = {}

func _initialize() -> void:
	var out: String = "runtime/data/reference"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var directory: String = out if out.is_absolute_path() else ProjectSettings.globalize_path("res://" + out)
	DirAccess.make_dir_recursive_absolute(directory)
	var scenarios: Array = []
	var first: Dictionary = _first_outing()
	scenarios.append(first.scenario)
	scenarios.append(_long_ticks(first.timeline))
	scenarios.append(_hunger_only())
	scenarios.append(_conduit_ring())
	scenarios.append(_mouse_only())
	var data: Dictionary = {
		"source": {
			"base_sim_sha256": FileAccess.get_sha256(SIM_PATH),
			"base_catalog_sha256": FileAccess.get_sha256(CATALOG_PATH),
			"godot": Engine.get_version_info().string,
		},
		"catalog": _catalog(),
		"scenarios": scenarios,
	}
	var path: String = directory.path_join("production_trace.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + path)
		quit(1)
		return
	file.store_string(JSON.stringify(data, " ", true, true) + "\n")
	file.close()
	for scenario: Dictionary in scenarios:
		print("TRACE %s calls=%d snapshots=%d end_t=%.2f" % [scenario.name, (scenario.calls as Array).size(), (scenario.snapshots as Array).size(), float((scenario.snapshots as Array).back().t)])
	print("TRACE written ", path)
	quit(0)

# ---- recording -------------------------------------------------------------

func _begin() -> void:
	sim = Sim.new()
	now = 0.0
	calls = []
	snapshots = []
	timeline = []
	batches = {}

func _call(method: String, args: Array = []) -> Variant:
	var result: Variant = sim.callv(method, args)
	timeline.append(["call", calls.size(), args])
	calls.append({"t": now, "method": method, "args": _plain(args), "result": _plain(result)})
	return result

func _snapshot(label: String = "") -> void:
	if not is_equal_approx(float(sim.seconds), now):
		push_error("SCRIPT clock drift: sim %.6f, driver %.6f" % [float(sim.seconds), now])
	var derived: Dictionary = {
		"efficiency": sim.efficiency(),
		"work_speed": sim.work_speed(),
		"prosperity": sim.prosperity(),
		"combat_power": sim.combat_power(),
		"expedition_ready": _plain(sim.expedition_ready()),
	}
	if not batches.is_empty():
		derived["batches_finished"] = batches.duplicate()
	var entry: Dictionary = {"t": now, "state": _plain(sim.to_dict()), "derived": derived}
	if label != "":
		entry["label"] = label
	timeline.append(["snapshot", snapshots.size(), label])
	snapshots.append(entry)

## One short tick of STEP seconds; counts finished batches of the watched fields.
func _step() -> void:
	var was_active: Dictionary = {}
	for key: String in batches:
		was_active[key] = bool(sim.facilities[int(key)].active)
	sim.tick(STEP)
	now += STEP
	for key: String in batches:
		# Only a finished batch turns an unstaffed field from active to idle here
		# (set_recipe is never called during these runs).
		if bool(was_active[key]) and not bool(sim.facilities[int(key)].active):
			batches[key] = int(batches[key]) + 1

func _scenario(name: String, step_seconds: float, driver: String, description: String, ids: Dictionary) -> Dictionary:
	var events: Array = []
	for event: Array in timeline:
		var source: Array = calls if event[0] == "call" else snapshots
		events.append({"kind": event[0], "index": event[1], "t": source[event[1]].t})
	return {
		"name": name, "step_seconds": step_seconds, "driver": driver, "description": description,
		"ids": ids, "calls": calls, "snapshots": snapshots, "timeline": events,
	}

static func _plain(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2I, TYPE_VECTOR2:
			return [value.x, value.y]
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value:
				out[str(key)] = _plain(value[key])
			return out
		TYPE_ARRAY:
			var out: Array = []
			for item: Variant in value:
				out.append(_plain(item))
			return out
	return value

func _catalog() -> Dictionary:
	var constants: Dictionary = (load(CATALOG_PATH) as Script).get_script_constant_map()
	var out: Dictionary = {}
	for key: String in constants:
		out[key] = _plain(constants[key])
	var sim_constants: Dictionary = (load(SIM_PATH) as Script).get_script_constant_map()
	out["SIM_STEP"] = sim_constants["STEP"]
	out["SIM_SIDES"] = _plain(sim_constants["SIDES"])
	return out

# ---- scenarios -------------------------------------------------------------

## The base of tests/base_supply_loop_test.gd::_first_outing(), driven to the kit.
func _first_outing() -> Dictionary:
	_begin()
	var spring: int = _call("place", ["spirit_spring", Vector2i(0, 0)])
	var well: int = _call("place", ["stone_well", Vector2i(0, 4)])
	var grain_field: int = _call("place", ["spirit_field", Vector2i(3, 1)])
	var herb_field: int = _call("place", ["spirit_field", Vector2i(5, 1)])
	var bed: int = _call("place", ["ore_bed", Vector2i(7, 1)])
	var furnace: int = _call("place", ["alchemy_furnace", Vector2i(9, 1)])
	var forge: int = _call("place", ["forge_hearth", Vector2i(11, 1)])
	var hearth: int = _call("place", ["hearth", Vector2i(3, 4)])
	var gate: int = _call("place", ["realm_gate", Vector2i(14, 4)])
	var trunk: Array = []
	for x: int in range(1, 12):
		trunk.append(Vector2i(x, 0))
	_call("lay_conduit", [trunk])
	_call("set_recipe", [grain_field, "grain"])
	_call("set_recipe", [herb_field, "herb"])
	_call("set_recipe", [bed, "ore"])
	_call("set_recipe", [furnace, "pill_heal"])
	_call("set_recipe", [forge, "blade"])
	for target: int in [grain_field, herb_field, bed]:
		_call("command", [{"type": "haul", "good": "water", "from": well, "to": target, "repeat": true}])
		_call("command", [{"type": "harvest", "at": target, "repeat": true}])
	_snapshot()
	var asked: Dictionary = {"ration": 0, "pill_heal": 0, "blade": 0}
	var n: int = 0
	while true:
		_step()
		n += 1
		# The player's part, as in the test but checked every step instead of every second.
		if asked.ration < 3 and float(sim.stock.get("grain", 0.0)) >= 2.0 * float(3 - asked.ration):
			_call("command", [{"type": "haul", "good": "water", "from": well, "to": hearth}])
			_call("set_recipe", [hearth, "ration"])
			_call("command", [{"type": "haul", "good": "water", "from": well, "to": hearth}])
			_call("command", [{"type": "craft", "at": hearth, "recipe": "ration", "count": 3}])
			asked.ration = 3
		if asked.pill_heal < 2 and float(sim.stock.get("herb", 0.0)) >= 6.0:
			_call("command", [{"type": "craft", "at": furnace, "recipe": "pill_heal", "count": 2}])
			asked.pill_heal = 2
		if asked.blade < 1 and float(sim.stock.get("ore", 0.0)) >= 4.0:
			_call("command", [{"type": "craft", "at": forge, "recipe": "blade", "count": 1}])
			asked.blade = 1
		if bool(sim.expedition_ready().ready):
			_snapshot("kit_ready")
			if not bool(_call("depart")):
				push_error("SCRIPT depart() failed with the kit ready")
			_snapshot("after_depart")
			break
		if n % 120 == 0:
			_snapshot()
		if now >= 3600.0:
			push_error("SCRIPT first_outing: kit not ready after an hour, missing %s" % [sim.expedition_ready().missing])
			break
	var ids: Dictionary = {"spirit_spring": spring, "stone_well": well, "grain_field": grain_field, "herb_field": herb_field, "ore_bed": bed, "alchemy_furnace": furnace, "forge_hearth": forge, "hearth": hearth, "realm_gate": gate}
	var scenario: Dictionary = _scenario("first_outing", STEP, "tick(0.25) repeatedly; calls are made after the tick that reaches their t, snapshots after the calls at the same t",
		"The test's first-outing base and orders; the player queues each craft as soon as its inputs are in the store (checked every 0.25 s). Ends when the kit is ready and depart() succeeds.", ids)
	return {"scenario": scenario, "timeline": timeline.duplicate()}

## The same calls at the same times, but time advanced in single long ticks.
func _long_ticks(source_timeline: Array) -> Dictionary:
	var source_calls: Array = calls
	var source_snapshots: Array = snapshots
	var ids: Dictionary = {}
	_begin()
	for event: Array in source_timeline:
		var t: float = float((source_calls if event[0] == "call" else source_snapshots)[event[1]].t)
		if t > now:
			sim.tick(t - now)
			now = t
		if event[0] == "call":
			_call(String(source_calls[event[1]].method), event[2])
		else:
			_snapshot(String(event[2]))
	return _scenario("first_outing_long_ticks", 30.0, "one tick(gap) from each call or snapshot time to the next; gaps are at most 30 s",
		"Identical calls to first_outing at identical times; time between events passes in one long tick.", ids)

## No food and no well: efficiency falls to the floor and work never stops.
func _hunger_only() -> Dictionary:
	_begin()
	var spring: int = _call("place", ["spirit_spring", Vector2i(0, 0)])
	var urn: int = _call("place", ["qi_urn", Vector2i(6, 0)])
	_call("command", [{"type": "haul", "good": "qi", "from": spring, "to": urn, "repeat": true}])
	_call("command", [{"type": "cultivate", "at": spring, "seconds": 20.0, "repeat": true}])
	_snapshot()
	for n: int in range(1, 4801):
		_step()
		if n % 240 == 0:
			_snapshot()
	return _scenario("hunger_only", STEP, "tick(0.25) repeatedly; snapshots every 60 s",
		"A spring and a qi urn, no food and no well; repeating haul and cultivate orders for 20 minutes.", {"spirit_spring": spring, "qi_urn": urn})

## A field inside a closed ring of conduit and a field outside it, on one network.
func _conduit_ring() -> Dictionary:
	_begin()
	var spring: int = _call("place", ["spirit_spring", Vector2i(1, 4)])
	var inside: int = _call("place", ["spirit_field", Vector2i(4, 4)])
	var outside: int = _call("place", ["spirit_field", Vector2i(9, 4)])
	var well: int = _call("place", ["stone_well", Vector2i(6, 8)])
	# Ring (3,3)-(5,5) around the inside field, then a run from its east side to the outside field.
	var cells: Array = []
	for x: int in range(3, 6):
		cells.append(Vector2i(x, 3))
		cells.append(Vector2i(x, 5))
	cells.append(Vector2i(3, 4))
	cells.append(Vector2i(5, 4))
	cells.append(Vector2i(2, 4))
	for x: int in range(6, 9):
		cells.append(Vector2i(x, 4))
	_call("lay_conduit", [cells])
	_call("set_recipe", [inside, "grain"])
	_call("set_recipe", [outside, "grain"])
	for target: int in [inside, outside]:
		_call("command", [{"type": "haul", "good": "water", "from": well, "to": target, "repeat": true}])
		_call("command", [{"type": "harvest", "at": target, "repeat": true}])
	batches = {str(inside): 0, str(outside): 0}
	_snapshot()
	for n: int in range(1, 2401):
		_step()
		if n % 120 == 0:
			_snapshot()
	return _scenario("conduit_ring", STEP, "tick(0.25) repeatedly; snapshots every 30 s; derived.batches_finished counts each field's finished batches (exporter-side count, not sim state)",
		"Spring, well, a grain field inside a closed conduit ring and one outside it on the same network; the cultivator hauls water and harvests both.", {"spirit_spring": spring, "inside_field": inside, "outside_field": outside, "stone_well": well})

## No orders; the mouse clicks the facilities in turn every 0.5 s.
func _mouse_only() -> Dictionary:
	_begin()
	var spring: int = _call("place", ["spirit_spring", Vector2i(0, 0)])
	var well: int = _call("place", ["stone_well", Vector2i(0, 2)])
	var field: int = _call("place", ["spirit_field", Vector2i(3, 0)])
	var hearth: int = _call("place", ["hearth", Vector2i(3, 2)])
	_call("set_recipe", [field, "grain"])
	_call("set_recipe", [hearth, "ration"])
	var cycle: Array = [spring, well, field, hearth]
	var next: int = 0
	_snapshot()
	for n: int in range(1, 1201):
		_step()
		if n % 2 == 0:
			_call("click", [cycle[next]])
			next = (next + 1) % cycle.size()
		if n % 120 == 0:
			_snapshot()
	return _scenario("mouse_only", STEP, "tick(0.25) repeatedly; one click every 0.5 s cycling spring, well, field, hearth; snapshots every 30 s after that time's click",
		"No orders at all. The mouse alone gathers qi and water, pours them into a grain field and a (staffed, so idle) hearth, and harvests.", {"spirit_spring": spring, "stone_well": well, "spirit_field": field, "hearth": hearth})
