extends SceneTree
## Part-one supply pipeline: the rules of scripts/gameplay/base/base_sim.gd.
const Sim = preload("res://scripts/gameplay/base/base_sim.gd")
const Catalog = preload("res://scripts/gameplay/base/base_catalog.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run(sim: RefCounted, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		sim.tick(minf(1.0, left))
		left -= 1.0

func _ring(low: Vector2i, high: Vector2i) -> Array:
	var cells: Array = []
	for x: int in range(low.x, high.x + 1):
		cells.append(Vector2i(x, low.y))
		cells.append(Vector2i(x, high.y))
	for y: int in range(low.y + 1, high.y):
		cells.append(Vector2i(low.x, y))
		cells.append(Vector2i(high.x, y))
	return cells

func _two_inputs() -> void:
	# Every stage mixes two inputs in its own ratio; one alone starts nothing.
	var sim := Sim.new()
	var field: int = sim.place("spirit_field", Vector2i(4, 0))
	check(sim.set_recipe(field, "grain") and not sim.set_recipe(field, "blade"), "a field grows crops and refuses a forge recipe")
	sim.facilities[field].held = {"qi": 6.0}
	_run(sim, 5.0)
	check(not sim.facilities[field].active, "qi alone does not start a crop")
	sim.facilities[field].held = {"qi": 3.0, "water": 1.0}
	_run(sim, 1.0)
	check(sim.facilities[field].active and sim.facilities[field].held.is_empty(), "three qi and one water start one batch of spirit grain")
	_run(sim, 61.0)
	check(is_equal_approx(float(sim.facilities[field].ready.get("grain", 0.0)), 4.0), "a batch ripens into four grain after a minute")
	sim.facilities[field].held = {"qi": 3.0, "water": 1.0}
	_run(sim, 5.0)
	check(not sim.facilities[field].active, "a ripe field waits to be gathered before the next batch")
	var ratios: Dictionary = {}
	for recipe: String in Catalog.RECIPES:
		var needs: Dictionary = Catalog.RECIPES[recipe].needs
		check(needs.size() == 2, recipe + " mixes exactly two inputs")
		var values: Array = needs.values()
		ratios[snappedf(float(values[0]) / float(values[1]), 0.001)] = true
	check(ratios.size() >= 6, "stages use different ratios (%d distinct)" % ratios.size())

func _hands_then_conduit() -> void:
	# By hand the cultivator carries both inputs; a conduit takes the qi over.
	var grain: Array[float] = []
	for piped: bool in [false, true]:
		var sim := Sim.new()
		var spring: int = sim.place("spirit_spring", Vector2i(0, 0))
		var well: int = sim.place("stone_well", Vector2i(0, 6))
		var field: int = sim.place("spirit_field", Vector2i(12, 0))
		sim.set_recipe(field, "grain")
		if piped:
			var run: Array = []
			for x: int in range(1, 12):
				run.append(Vector2i(x, 0))
			check(sim.lay_conduit(run) == 11, "eleven conduit cells laid between spring and field")
		else:
			sim.command({"type": "haul", "good": "qi", "from": spring, "to": field, "repeat": true})
		sim.command({"type": "haul", "good": "water", "from": well, "to": field, "repeat": true})
		sim.command({"type": "harvest", "at": field, "repeat": true})
		_run(sim, 600.0)
		grain.append(float(sim.stock.get("grain", 0.0)))
	check(grain[0] >= 8.0, "hauling both inputs by hand still brings in grain (%.0f in ten minutes)" % grain[0])
	check(grain[1] > grain[0], "a conduit for the qi brings in more grain in the same time (%.0f against %.0f)" % [grain[1], grain[0]])

func _formation() -> void:
	var sim := Sim.new()
	var field: int = sim.place("spirit_field", Vector2i(5, 5))
	var outside: int = sim.place("spirit_field", Vector2i(12, 5))
	var ring: Array = _ring(Vector2i(3, 3), Vector2i(7, 7))
	sim.lay_conduit(ring)
	sim.tick(0.25)
	check(sim.facilities[field].formation and not sim.facilities[outside].formation, "a closed ring of conduit wakes a formation over what it encloses")
	sim.set_recipe(field, "grain")
	sim.set_recipe(outside, "grain")
	sim.facilities[field].held = {"qi": 3.0, "water": 1.0}
	sim.facilities[outside].held = {"qi": 3.0, "water": 1.0}
	_run(sim, 50.0)
	check(not sim.facilities[field].ready.is_empty() and sim.facilities[outside].ready.is_empty(), "the field inside the formation ripens first")
	sim.lift_conduit([Vector2i(3, 5)])
	sim.tick(0.25)
	check(not sim.facilities[field].formation, "breaking the ring puts the formation out")

func _body() -> void:
	var sim := Sim.new()
	check(is_equal_approx(sim.efficiency(), 1.0), "a fed and watered cultivator works at full speed")
	_run(sim, 3600.0)
	check(is_equal_approx(sim.efficiency(), Catalog.MIN_EFFICIENCY), "hunger and thirst only slow work, down to half speed")
	var spring: int = sim.place("spirit_spring", Vector2i(2, 0))
	var urn: int = sim.place("qi_urn", Vector2i(8, 0))
	_run(sim, 30.0)
	sim.command({"type": "haul", "good": "qi", "from": spring, "to": urn})
	_run(sim, 60.0)
	check(float(sim.facilities[urn].held.get("qi", 0.0)) >= 3.9, "a starving cultivator still finishes the order")
	sim.stock["pill_fast"] = 1.0
	sim.command({"type": "take_pill"})
	_run(sim, 5.0)
	check(is_equal_approx(sim.efficiency(), 1.0) and not sim.stock.has("pill_fast"), "a fasting pill restores full speed without food or water")
	_run(sim, Catalog.FASTING_SECONDS + 5.0)
	check(sim.efficiency() < 1.0, "the pill wears off")
	var well: int = sim.place("stone_well", Vector2i(2, 3))
	sim.stock["ration"] = 3.0
	_run(sim, 60.0)
	check(is_equal_approx(float(sim.stock.get("ration", 0.0)), 3.0) and well > 0, "the three rations kept for the outing are not eaten at home")
	sim.stock["ration"] = 5.0
	_run(sim, 60.0)
	check(sim.efficiency() > 0.99 and float(sim.stock.get("ration", 0.0)) < 5.0, "with a well and a spare spirit meal the cultivator eats and drinks unasked")

func _mouse() -> void:
	# The mouse works on its own while the cultivator is busy elsewhere.
	var sim := Sim.new()
	var spring: int = sim.place("spirit_spring", Vector2i(0, 0))
	var well: int = sim.place("stone_well", Vector2i(0, 2))
	var field: int = sim.place("spirit_field", Vector2i(3, 0))
	var seat: int = sim.place("qi_dais", Vector2i(30, 30))
	sim.set_recipe(field, "grain")
	sim.command({"type": "cultivate", "at": seat, "seconds": 600.0})
	_run(sim, 20.0)
	check(String(sim.click(spring).did) == "gather" and String(sim.click(spring).did) == "", "one click gathers one unit and then has to wait")
	for index: int in 4:
		_run(sim, 1.0)
		sim.click(spring)
	_run(sim, 1.0)
	sim.click(well)
	check(float(sim.stock.get("qi", 0.0)) >= 3.0 and float(sim.stock.get("water", 0.0)) >= 1.0, "clicks fill the store with qi and water")
	for index: int in 4:
		_run(sim, 1.0)
		sim.click(field)
	_run(sim, 62.0)
	check(String(sim.click(field).did) == "harvest" and is_equal_approx(float(sim.stock.get("grain", 0.0)), 4.0), "clicks alone plant, feed and gather a field")
	check(String(sim.cultivator.order.get("type", "")) == "cultivate", "the cultivator kept to its own order the whole time")

func _cultivation_and_worth() -> void:
	var gains: Array[float] = []
	for fed_on_spirit_meal: bool in [false, true]:
		var sim := Sim.new()
		var spring: int = sim.place("spirit_spring", Vector2i(1, 0))
		_run(sim, 80.0)
		if fed_on_spirit_meal:
			sim.cultivator.nourished_left = Catalog.NOURISHED_SECONDS
		sim.command({"type": "cultivate", "at": spring, "seconds": 30.0})
		_run(sim, 40.0)
		gains.append(float(sim.cultivator.cultivation))
	check(gains[0] > 0.0 and gains[0] < 30.0 * Catalog.RAW_QI_RATE, "raw qi cultivates, but poorly (%.2f from %.0f qi)" % [gains[0], 30.0 * Catalog.RAW_QI_RATE])
	check(is_equal_approx(gains[1], gains[0] * Catalog.NOURISHED_GAIN), "a spirit meal makes the same sitting worth half again as much")
	var sim := Sim.new()
	var bare: float = sim.combat_power()
	sim.place("spirit_spring", Vector2i(0, 0))
	sim.place("post_lantern", Vector2i(2, 0))
	check(sim.prosperity() == 14 and sim.combat_power() > bare, "what stands on the island counts as prosperity, and prosperity as strength")
	var plain: float = sim.work_speed()
	for index: int in 8:
		sim.place("rockery", Vector2i(4 + index, 0))
	check(sim.work_speed() > plain and sim.work_speed() <= 1.0 + Catalog.DECOR_CAP + 0.0001, "decorations speed work a little, up to a cap")

func _first_outing() -> void:
	# The whole line, from spring to a packed kit, without rebuilding anything.
	var sim := Sim.new()
	var spring: int = sim.place("spirit_spring", Vector2i(0, 0))
	var well: int = sim.place("stone_well", Vector2i(0, 4))
	var grain_field: int = sim.place("spirit_field", Vector2i(3, 1))
	var herb_field: int = sim.place("spirit_field", Vector2i(5, 1))
	var bed: int = sim.place("ore_bed", Vector2i(7, 1))
	var furnace: int = sim.place("alchemy_furnace", Vector2i(9, 1))
	var forge: int = sim.place("forge_hearth", Vector2i(11, 1))
	var hearth: int = sim.place("hearth", Vector2i(3, 4))
	sim.place("realm_gate", Vector2i(14, 4))
	var trunk: Array = []
	for x: int in range(1, 12):
		trunk.append(Vector2i(x, 0))
	sim.lay_conduit(trunk)
	sim.set_recipe(grain_field, "grain")
	sim.set_recipe(herb_field, "herb")
	sim.set_recipe(bed, "ore")
	sim.set_recipe(furnace, "pill_heal")
	sim.set_recipe(forge, "blade")
	for target: int in [grain_field, herb_field, bed]:
		sim.command({"type": "haul", "good": "water", "from": well, "to": target, "repeat": true})
		sim.command({"type": "harvest", "at": target, "repeat": true})
	var built: int = sim.facilities.size()
	var asked: Dictionary = {"ration": 0, "pill_heal": 0, "blade": 0}
	var ready_at: float = -1.0
	for second: int in 1800:
		sim.tick(1.0)
		# The player's part: queue a craft once its inputs are in the store.
		if asked.ration < 3 and float(sim.stock.get("grain", 0.0)) >= 2.0 * float(3 - asked.ration):
			sim.command({"type": "haul", "good": "water", "from": well, "to": hearth})
			sim.set_recipe(hearth, "ration")
			sim.command({"type": "haul", "good": "water", "from": well, "to": hearth})
			sim.command({"type": "craft", "at": hearth, "recipe": "ration", "count": 3})
			asked.ration = 3
		if asked.pill_heal < 2 and float(sim.stock.get("herb", 0.0)) >= 6.0:
			sim.command({"type": "craft", "at": furnace, "recipe": "pill_heal", "count": 2})
			asked.pill_heal = 2
		if asked.blade < 1 and float(sim.stock.get("ore", 0.0)) >= 4.0:
			sim.command({"type": "craft", "at": forge, "recipe": "blade", "count": 1})
			asked.blade = 1
		if bool(sim.expedition_ready().ready):
			ready_at = float(second + 1)
			break
	check(ready_at > 0.0, "the first outing's kit comes together within half an hour (missing %s, last block %s)" % [sim.expedition_ready().missing, sim.last_block])
	check(sim.facilities.size() == built, "later lines consumed earlier products; nothing was rebuilt")
	print("FIRST OUTING ready after %.0f s of play; store %s" % [ready_at, sim.stock])
	# Saving mid-way and loading gives the same world.
	var saved: String = JSON.stringify(sim.to_dict())
	var copy := Sim.new()
	copy.from_dict(JSON.parse_string(saved))
	sim.clear_orders()
	copy.clear_orders()
	_run(sim, 120.0)
	_run(copy, 120.0)
	check(JSON.stringify(sim.to_dict().stock) == JSON.stringify(copy.to_dict().stock) and copy.facilities.size() == built, "a saved and loaded base runs on exactly as the original")
	check(sim.depart() and not bool(sim.expedition_ready().ready), "leaving packs the kit out of the store")
	# Hung as a wallpaper the base keeps running: one long tick equals many short ones.
	var slow := Sim.new()
	var fast := Sim.new()
	for world: RefCounted in [slow, fast]:
		world.place("spirit_spring", Vector2i(0, 0))
		var plot: int = world.place("spirit_field", Vector2i(2, 1))
		world.lay_conduit([Vector2i(1, 0), Vector2i(2, 0)])
		world.set_recipe(plot, "grain")
		world.facilities[plot].held = {"water": 2.0}
	for index: int in 600:
		slow.tick(1.0)
	fast.tick(600.0)
	check(JSON.stringify(slow.to_dict().facilities) == JSON.stringify(fast.to_dict().facilities), "ten minutes in one tick equal ten minutes of one-second ticks")

func _initialize() -> void:
	_two_inputs()
	_hands_then_conduit()
	_formation()
	_body()
	_mouse()
	_cultivation_and_worth()
	_first_outing()
	print("BASE SUPPLY LOOP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
