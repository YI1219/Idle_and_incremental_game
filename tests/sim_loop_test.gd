extends SceneTree
## 2-field → potion loop identities. Event-stepped, not per-second ticks.

const WorldSimScript := preload("res://scripts/sim/world_sim.gd")
const LoopMath := preload("res://scripts/sim/loop_math.gd")

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _init() -> void:
	_stock()
	_one_cycle_no_bench()
	_two_fields_feed_bench()
	_buffer_fill_no_bench()
	_offline_event_count()
	print("SIM LOOP: %d/%d passed, failures=%d" % [checks - failures, checks, failures])
	quit(1 if failures else 0)


func _stock() -> void:
	check(LoopMath.stock_on(false, 6, 6, 6, 12), "turn on at low")
	check(not LoopMath.stock_on(true, 12, 12, 6, 12), "turn off at high")
	check(LoopMath.stock_on(true, 8, 8, 6, 12), "hold on inside band")
	check(not LoopMath.stock_on(false, 8, 8, 6, 12), "hold off inside band")
	check(not LoopMath.stock_on(false, 5, 12, 6, 12), "reserved output skips extra job")


func _one_cycle_no_bench() -> void:
	var world: RefCounted = WorldSimScript.new()
	world.reset_prefab()
	world.craft.bench_enabled = false
	world.catch_up(4.2)
	check(world.craft.total_herbs() == 4, "two fields finish one unbuffed cycle in 4.2 min")
	check(int(world.craft.fields[0]["herbs"]) == 2, "each field yields 2 herbs")
	check(world.craft.potions() == 0, "disabled bench makes no potions")


func _two_fields_feed_bench() -> void:
	var world: RefCounted = WorldSimScript.new()
	world.reset_prefab()
	world.catch_up(4.2)
	check(world.craft.total_herbs() + world.craft.projected_potions() * 2 >= 4, "harvested herbs exist or are reserved")
	world.catch_up(4.2 + 2.5)
	check(world.craft.potions() >= 1, "first potion after 2.5 min of bench work")
	world.catch_up(40.0)
	check(world.craft.potions() >= 6, "two fields can keep a bench supplied")
	check(world.craft.potions() <= 12, "stock high cap 12")


func _buffer_fill_no_bench() -> void:
	var world: RefCounted = WorldSimScript.new()
	world.reset_prefab()
	world.craft.bench_enabled = false
	world.catch_up(67.2)
	check(int(world.craft.fields[0]["herbs"]) == 32, "local buffer 32 after 16 cycles")
	check(String(world.craft.fields[0]["status"]) == "output_full" or int(world.craft.fields[0]["herbs"]) == 32, "field stops when buffer full")


func _offline_event_count() -> void:
	var world: RefCounted = WorldSimScript.new()
	world.reset_prefab()
	world.craft.event_steps = 0
	world.catch_up(600.0, true)
	check(world.apply_steps == 1, "10h is still one catch_up")
	check(world.craft.event_steps < 8000, "10h uses events not 36000 ticks (%d)" % world.craft.event_steps)
	check(world.craft.potions() == 12 or world.craft.potions() >= 6, "offline still fills potion reserve")
