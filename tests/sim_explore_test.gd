extends SceneTree
## Two-path trip: token must be carried, notes survive fail, mist is the only fail.

const WorldSimScript := preload("res://scripts/sim/world_sim.gd")
const TripScript := preload("res://scripts/sim/explore_trip.gd")

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _init() -> void:
	_map_fork()
	_observe_is_knowledge_not_item()
	_pickup_needs_overhead_room()
	_withdraw_keeps_carried()
	_fail_drops_carried_keeps_note_and_home()
	print("SIM EXPLORE: %d/%d passed, failures=%d" % [checks - failures, checks, failures])
	quit(1 if failures else 0)


func _map_fork() -> void:
	var trip: RefCounted = TripScript.new()
	check(trip.cell_count() == 14, "fourteen walk cells")
	check(trip.branch_of(TripScript.LOOT_CELL) == "left", "loot on left")
	check(trip.branch_of(TripScript.NOTE_CELL) == "right", "note on right")
	check(trip.branch_of(TripScript.DANGER_CELL) == "left", "mist deeper on left")
	check(trip.has_cell(Vector2i(-2, 5)), "safe cell before mist")
	check(not trip.has_cell(Vector2i(0, 6)), "no third stem into the fog")


func _observe_is_knowledge_not_item() -> void:
	var world: RefCounted = WorldSimScript.new()
	world.reset_prefab()
	var before: int = world.items.count_all()
	world.trip.begin()
	check(world.trip.touch(world, TripScript.NOTE_CELL) == "observe", "right path observes")
	check(world.trip.note_in_journal(world), "sign enters the journal")
	check(world.items.count_all() == before, "observation does not mint an item")
	check(world.items.overhead.size() == 0, "note is not carried")


func _pickup_needs_overhead_room() -> void:
	var world: RefCounted = WorldSimScript.new()
	world.reset_prefab()
	world.trip.begin()
	check(world.trip.touch(world, TripScript.LOOT_CELL) == "pickup", "left path grants a sample")
	check(world.items.overhead.size() == 1, "sample sits on the head")
	check(world.trip.touch(world, TripScript.LOOT_CELL) == "gone", "same stone is not duplicated")
	world.expedition_return()
	world.expedition_return()
	check(world.items.overhead.size() == 3, "head is full")
	world.trip.loot_present = true
	check(world.trip.touch(world, TripScript.LOOT_CELL) == "overhead_full", "full head refuses pickup")
	check(world.trip.loot_present, "stone stays on the ground")


func _withdraw_keeps_carried() -> void:
	var world: RefCounted = WorldSimScript.new()
	world.reset_prefab()
	var home: String = world.items.first_in("world")
	world.trip.begin()
	world.trip.touch(world, TripScript.LOOT_CELL)
	check(world.trip.withdraw() == "withdrawn", "entrance is a real withdraw")
	check(world.items.overhead.size() == 1, "token still on the head")
	check(not world.items.get_item(home).is_empty(), "village sample untouched")
	check(world.trip.outcome == "withdrawn", "trip records the choice")


func _fail_drops_carried_keeps_note_and_home() -> void:
	var world: RefCounted = WorldSimScript.new()
	world.reset_prefab()
	var home: String = world.items.first_in("world")
	world.try_assign_research(home)
	world.catch_up(3.0)
	check(world.topic_completed("protection_quota|basic"), "home research finished")
	world.trip.begin()
	world.trip.touch(world, TripScript.NOTE_CELL)
	world.trip.touch(world, TripScript.LOOT_CELL)
	check(world.items.overhead.size() == 1, "carried a stone into the mist")
	check(world.trip.touch(world, TripScript.DANGER_CELL) == "fail", "mist sends you home")
	check(world.trip.consume_fail(), "view can veil once")
	check(not world.trip.consume_fail(), "fail is not retriggered")
	check(world.items.overhead.size() == 0, "carried stone is gone")
	check(world.trip.note_in_journal(world), "the sign stays in the journal")
	check(world.topic_completed("protection_quota|basic"), "finished research stays")
	check(world.items.get_item(home).get("location", "") != "", "home sample was not in the loss set")
	check(world.trip.outcome == "failed", "fail is distinct from withdraw")
