extends SceneTree
## Research does not consume samples. Knowledge survives failed trips.

const WorldSimScript := preload("res://scripts/sim/world_sim.gd")
const ItemMath := preload("res://scripts/sim/item_math.gd")

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _init() -> void:
	_work_values()
	_shapes()
	_research_keeps_sample_and_grants_once()
	_pause_when_sample_leaves()
	_overhead_and_fail_keep_knowledge()
	print("SIM RESEARCH: %d/%d passed, failures=%d" % [checks - failures, checks, failures])
	quit(1 if failures else 0)


func _work_values() -> void:
	check(is_equal_approx(ItemMath.research_work(0), 2.0), "r0 work 2")
	check(is_equal_approx(ItemMath.research_work(1), 3.0), "r1 work 3")
	check(is_equal_approx(ItemMath.research_work(4), 10.125), "r4 work 10.125")
	check(ItemMath.topic_key("protection_quota", "basic") == "protection_quota|basic", "topic key")


func _shapes() -> void:
	var herb: Array = [[0, 0], [0, 1], [1, 1]]
	check(ItemMath.rotate_shape(herb, 4) == ItemMath.rotate_shape(herb, 0), "rotate 4 is identity")
	var square: Array = [[0, 0], [1, 0], [0, 1], [1, 1]]
	check(ItemMath.fits(square, Vector2i(4, 3), 0, {}, 6, 5), "square fits")
	check(not ItemMath.fits(square, Vector2i(5, 4), 0, {}, 6, 5), "square out of bounds")
	var occupied: Dictionary = {}
	occupied[Vector2i(4, 3)] = "x"
	check(not ItemMath.fits(square, Vector2i(4, 3), 0, occupied, 6, 5), "overlap rejected")
	var checker: Dictionary = {}
	for x in 6:
		for y in 5:
			if (x + y) % 2 == 0:
				checker[Vector2i(x, y)] = "x"
	var any := false
	for x in 6:
		for y in 5:
			for r in 4:
				any = any or ItemMath.fits(square, Vector2i(x, y), r, checker, 6, 5)
	check(not any, "area enough is not sufficient")


func _research_keeps_sample_and_grants_once() -> void:
	var world: RefCounted = WorldSimScript.new()
	world.reset_prefab()
	var id: String = world.items.first_in("world")
	var before: int = world.items.count_all()
	check(world.try_assign_research(id) == "ok", "assign village sample")
	check(String(world.items.get_item(id)["location"]) == "research", "sample reserved not destroyed")
	world.catch_up(3.0)
	check(world.topic_completed("protection_quota|basic"), "topic completes in 3 min")
	check(world.items.count_all() == before, "research does not consume")
	check(int(world.items.get_item(id)["stack"]) == 1, "stack unchanged")
	check(world.protection_quota == 16, "first complete grants 16 quota")
	check(String(world.items.get_item(id)["location"]) == "world", "sample released home")
	var second: String = world.expedition_return()
	check(second == "ok", "second copy can come home on head")
	var copy_id: String = world.items.overhead[0]
	world.try_assign_research(copy_id)
	world.catch_up(6.0)
	check(world.protection_quota == 16, "repeat topic does not grant again")
	check(world.items.count_all() == before + 1, "second instance still exists")


func _pause_when_sample_leaves() -> void:
	var world: RefCounted = WorldSimScript.new()
	world.reset_prefab()
	var id: String = world.items.first_in("world")
	world.try_assign_research(id)
	world.catch_up(1.0)
	var mid: float = float(world.craft.research["work"])
	check(mid > 0.0 and mid < 3.0, "partial progress")
	world.try_collect(id)
	check(String(world.craft.research["status"]) == "idle" or String(world.items.get_item(id)["location"]) == "collection", "collected off the bench")
	world.catch_up(5.0)
	check(not world.topic_completed("protection_quota|basic"), "paused research does not finish without sample")
	check(is_equal_approx(world.research_progress("protection_quota|basic"), mid) or world.research_progress("protection_quota|basic") >= mid - 0.05, "progress kept")


func _overhead_and_fail_keep_knowledge() -> void:
	var world: RefCounted = WorldSimScript.new()
	world.reset_prefab()
	var id: String = world.items.first_in("world")
	world.try_assign_research(id)
	world.catch_up(3.0)
	check(world.topic_completed("protection_quota|basic"), "knowledge before trip")
	world.expedition_return()
	world.expedition_return()
	world.expedition_return()
	check(world.expedition_return() == "overhead_full", "k=3 blocks even if bag empty")
	world.expedition_fail()
	check(world.items.overhead.size() == 0, "carried lost")
	check(world.topic_completed("protection_quota|basic"), "knowledge remains after fail")
	check(world.items.get_item(id).get("location", "") == "world", "home sample not in loss set")
	world.try_pack_overhead()
	var packed: String = world.items.try_pack(id)
	check(packed == "ok", "2x2 relic fits in bag")
	check(String(world.items.get_item(id)["location"]) == "bag", "now in bag")
	world.expedition_fail()
	check(world.items.get_item(id).is_empty(), "bag is carried and lost")
	check(world.topic_completed("protection_quota|basic"), "forgetting is not a death cost")
