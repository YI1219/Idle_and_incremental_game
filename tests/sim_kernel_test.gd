extends SceneTree
## Kernel identities from design_v0_2. No scene tree production nodes.

const LandMathLib := preload("res://scripts/sim/land_math.gd")
const SimConfigLib := preload("res://scripts/sim/sim_config.gd")
const WorldSimScript := preload("res://scripts/sim/world_sim.gd")

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _init() -> void:
	_land_table()
	_land_exhaustive()
	_efficiency()
	_energy()
	_world_prefab_and_events()
	_save_roundtrip()
	_closed_form_perf()
	print("SIM KERNEL: %d/%d passed, failures=%d" % [checks - failures, checks, failures])
	quit(1 if failures else 0)


func _land_table() -> void:
	var rows := [
		[64, 0, 0, 0, 0.0, 10.0],
		[80, 0, 16, 0, 1.6, 8.4],
		[96, 0, 24, 8, 2.4, 7.6],
		[96, 16, 16, 0, 1.6, 8.4],
		[96, 32, 0, 0, 0.0, 10.0],
		[128, 0, 24, 40, 2.4, 7.6],
	]
	for row in rows:
		var r: Dictionary = LandMathLib.ledger(int(row[0]), int(row[1]))
		check(int(r["paid"]) == int(row[2]) and int(r["dormant"]) == int(row[3]), "ledger paid/dormant A=%s Q=%s" % [row[0], row[1]])
		check(is_equal_approx(float(r["maintenance"]), float(row[4])), "ledger tax A=%s" % row[0])
		check(is_equal_approx(float(r["inflow"]), float(row[5])), "ledger inflow A=%s" % row[0])


func _land_exhaustive() -> void:
	for area in range(129):
		for protection in [0, 16, 32, 160]:
			for seep in [0.0, 0.05, 1.0, 10.0]:
				var r: Dictionary = LandMathLib.ledger(area, protection, seep)
				check(int(r["free"]) + int(r["paid"]) + int(r["dormant"]) == area, "area conservation A=%d" % area)
				check(float(r["inflow"]) >= -1e-9, "inflow nonnegative")
				check(float(r["maintenance"]) <= seep + 1e-9, "tax <= seep")
	var zero_tax: Dictionary = LandMathLib.ledger(128, 0, 0.0, 64, 0.0, 2.4)
	check(int(zero_tax["dormant"]) == 0 and is_zero_approx(float(zero_tax["maintenance"])), "tau=0 pays all uncovered")
	check(is_zero_approx(float(LandMathLib.ledger(0, 0, 0.0)["inflow"])), "zero area zero source")
	check(int(LandMathLib.ledger(96, 0, 0.0)["dormant"]) == 32, "no seep leaves uncovered dormant")
	check(is_equal_approx(float(LandMathLib.ledger(64, 1000)["inflow"]), 10.0), "protection does not create seep")
	var bad: Dictionary = LandMathLib.ledger(-1)
	check(bad.is_empty(), "negative area rejected")


func _efficiency() -> void:
	check(is_equal_approx(LandMathLib.efficiency(0.0), 0.35), "full dormant floor")
	check(is_equal_approx(LandMathLib.efficiency(0.5), 0.675), "half coverage")
	check(is_equal_approx(LandMathLib.efficiency(1.0), 1.0), "full coverage")
	check(is_equal_approx(LandMathLib.efficiency(0.0, 0.35, 0.0), 1.0), "insensitive facility")
	check(is_equal_approx(LandMathLib.efficiency(0.0, 1.0, 1.0), 1.0), "floor 1 ignores dormant")


func _energy() -> void:
	var cfg := SimConfigLib.new()
	var c: Dictionary = cfg.raw["condensation"]
	var raw: float = float(c["stone_energy_qi"]) / float(c["conversion_efficiency"]) * float(c["base_stones_per_minute"])
	check(is_equal_approx(raw, 2.0), "condensation raw 2.0")
	check(is_equal_approx(raw + float(c["active_overhead_qi_per_minute"]), 2.1), "condensation + overhead")
	var nu: float = float(c["base_stones_per_minute"]) * 1.4
	var boosted: float = float(c["stone_energy_qi"]) / float(c["conversion_efficiency"]) * nu
	check(is_equal_approx(nu, 0.252) and is_equal_approx(boosted, 2.8), "work bonus is not free energy")
	var rates := PackedFloat64Array([10.0, 5.0])
	var inflows := LandMathLib.split_inflows(rates, 2.4)
	check(is_equal_approx(inflows[0] + inflows[1], 12.6), "split land cost across springs")
	var dt := 1.0 / 60.0
	var actual: float = minf(12.0, 0.0 / dt + 7.6)
	check(is_equal_approx(actual, 7.6), "empty pool supply bound")


func _world_prefab_and_events() -> void:
	var world := WorldSimScript.new()
	world.reset_prefab()
	check(world.cell_count() == 48, "prefab 48 cells")
	check(int(world.ledger_cache["free"]) == 48, "prefab inside free quota")
	check(is_equal_approx(float(world.ledger_cache["inflow"]), 10.0), "prefab all seep enters pool")
	check(world.is_occupied(Vector2i(0, 0)), "spring occupies a cell")
	check(world.try_delete(Vector2i(0, 0)) == "occupied", "cannot delete spring cell")
	check(world.is_occupied(Vector2i(0, 3)), "gate occupies a cell")
	check(world.try_delete(Vector2i(0, 3)) == "occupied", "cannot delete gate cell")
	check(world.try_place(Vector2i(20, 20)) == "not_adjacent", "no island jumping")
	check(world.try_place(Vector2i(4, 0)) == "ok", "place on rim")
	check(world.cell_count() == 49, "placed one")
	world.policy = "strict_capacity"
	world.reset_prefab()
	world.springs[0]["seep"] = 0.05
	world._mark_ledger_dirty()
	world.recompute()
	var filled_free := true
	for i in 16:
		if world.try_place(Vector2i(4 + i, 0)) != "ok":
			filled_free = false
			break
	check(filled_free, "strict mode still paves inside free quota")
	check(world.try_place(Vector2i(20, 0)) == "seep_cap", "strict mode refuses when tax would exceed seep")
	world.policy = "soft_dormant"
	world.reset_prefab()
	for i in 80:
		world.try_place(Vector2i(4 + i, 0))
	check(world.cell_count() == 128, "soft mode can reach hard cap")
	check(world.try_place(Vector2i(4 + 80, 0)) == "area_cap", "hard area cap")
	check(int(world.ledger_cache["paid"]) == 24, "budget 2.4 pays 24 cells")
	check(int(world.ledger_cache["dormant"]) == 40, "rest dormant at 128")
	world.add_protection(16)
	check(int(world.ledger_cache["dormant"]) == 24, "quota reduces dormant")
	world.catch_up(10.0)
	check(world.apply_steps == 1, "ten minutes is one closed-form apply")
	check(world.total_pool() > 50.0, "pool rose")
	world.catch_up(600.0)
	check(is_equal_approx(world.total_pool(), float(world.springs[0]["cap"])), "pool stops at cap")
	check(world.minutes_until_pool_full() == 0.0, "full reports zero remaining")


func _save_roundtrip() -> void:
	var world := WorldSimScript.new()
	world.reset_prefab()
	world.try_place(Vector2i(4, 0))
	world.add_protection(16)
	world.catch_up(3.0)
	var blob: Dictionary = world.to_dict()
	var other := WorldSimScript.new()
	other.from_dict(blob)
	check(other.cell_count() == world.cell_count(), "save cell count")
	check(other.protection_quota == 16, "save quota")
	check(is_equal_approx(other.total_pool(), world.total_pool()), "save pool")


func _closed_form_perf() -> void:
	var t0 := Time.get_ticks_usec()
	for i in 10000:
		LandMathLib.ledger(96, 16, 10.0, 64, 0.1, 2.4)
	var ledger_us := Time.get_ticks_usec() - t0
	check(ledger_us < 250000, "10000 ledgers under 250ms (was %d us)" % ledger_us)
	var world := WorldSimScript.new()
	world.reset_prefab()
	for i in 80:
		world.try_place(Vector2i(4 + i, 0))
	world.apply_steps = 0
	var t1 := Time.get_ticks_usec()
	world.catch_up(600.0, true)
	var idle_us := Time.get_ticks_usec() - t1
	check(world.apply_steps == 1, "10h offline is one apply, not 36000 ticks")
	check(idle_us < 8000, "10h catch_up under 8ms (was %d us)" % idle_us)
