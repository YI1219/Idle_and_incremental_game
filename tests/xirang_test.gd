extends SceneTree

const XirangLib := preload("res://scripts/sim/xirang.gd")
const WorldSimScript := preload("res://scripts/sim/world_sim.gd")
const IslandGeometry := preload("res://scripts/world/island_geometry.gd")

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	_ledger()
	_world()
	print("XIRANG CHECKS: %d/%d passed, failures=%d" % [checks - failures, checks, failures])
	quit(1 if failures else 0)


func _ledger() -> void:
	var store := XirangLib.new()
	store.configure({})
	check(is_equal_approx(store.points, 96.0), "default starting 息壤")
	store.advance(10.0)
	check(is_equal_approx(store.points, 108.0), "idle accumulates closed-form")
	store.advance(10.0, true)
	check(is_equal_approx(store.points, 120.0), "offline uses the offline rate")
	check(is_equal_approx(store.volume_per_cell(), 4.0), "one cell is area times thickness")
	check(is_equal_approx(store.quote_add(10), 1.0), "base cost is one point per cell")
	check(store.quote_add(120) > store.quote_add(80), "soft cap raises cost past the threshold")
	check(is_equal_approx(store.quote_remove(), 0.5), "refund ratio is a tunable constant")
	check(store.try_spend(120.0), "spend succeeds while points last")
	check(is_equal_approx(store.points, 0.0), "spend stops at zero")
	check(not store.try_spend(0.1), "cannot spend past empty")
	store.credit(store.quote_remove())
	check(is_equal_approx(store.points, 0.5), "removing land refunds the configured share")
	var piece := XirangLib.piece_defaults()
	piece.cells = [Vector2i(0, 0), Vector2i(1, 0)]
	piece.rarity = 2.0
	var gained := store.decompose_piece(piece)
	check(is_equal_approx(gained, 4.0), "terrain pieces decompose into points")
	check(store.place_piece(piece) == "not_implemented", "placement remains an extension point")


func _world() -> void:
	var world := WorldSimScript.new()
	world.reset_prefab()
	var before: float = world.xirang.points
	world.catch_up(5.0)
	check(world.xirang.points > before, "world catch-up feeds 息壤")
	var after := IslandGeometry.component_size_after_add(world.cells_in_order, Vector2i(20, 20))
	check(after == 1, "far cell quotes as a new island")
	check(world.try_place(Vector2i(20, 20)) == "ok", "kernel allows a disconnected island")
