extends "res://tests/water_renderer_test.gd"
## Catch repeated idle work, full-domain stepping and unsafe snapshot reuse.
class CountedWater:
	extends "res://scripts/terrain_editor/water_flow.gd"
	var advances: int = 0
	func _advance(duration: float, transfers: Dictionary) -> bool:
		advances += 1
		return super._advance(duration, transfers)

func test_exact_sleep_and_wake() -> void:
	var data: Data = closed_pair()
	data.cells[Vector2i.RIGHT].water = 2
	var solver: RefCounted = CountedWater.new()
	solver.configure(data)
	solver.step(.1)
	var count: int = solver.advances
	for step: int in 8: solver.step(.1)
	check(solver.advances == count, "an exactly stable pool stops repeating the flux solve")
	check(close(solver.total_volume(), 2.0) and solver.last_transfers.is_empty(), "sleep preserves exact retained mass and empty transfers")
	data.cells[Vector2i.RIGHT].height = -1.0
	solver.sync(data)
	solver.step(.1)
	check(solver.advances > count and solver.depths[Vector2i.RIGHT] > 1.0, "a bed edit wakes the pool and redistributes conserved water")
	check(close(solver.total_volume() + solver.discharged_volume, 2.0), "waking never discards water")

func test_sparse_work() -> void:
	var data: Data = closed_pair()
	for z: int in 64:
		for x: int in 64: data.cells[Vector2i(x + 20, z + 20)] = {"height": 8.0, "water": -1}
	var solver: RefCounted = CountedWater.new()
	solver.configure(data)
	solver.step(.1)
	var visited: Variant = solver.get("last_step_cells")
	check(visited is int and visited <= 8, "unrelated dry expansion does not enter the wet-cell flux worklist")
	check(solver.depths[Vector2i.RIGHT] > 0.0 and close(solver.total_volume(), 1.0), "sparse stepping still wets a receiving cell and conserves mass")

func test_underflow_is_not_equilibrium() -> void:
	var data: Data = closed_pair()
	data.cells[Vector2i.ZERO] = {"height": 0.0, "water": -1, "water_volume": 1e-200}
	var solver: RefCounted = CountedWater.new()
	solver.configure(data)
	solver.step(1e-100)
	solver.step(.1)
	check(solver.depths.get(Vector2i.RIGHT, 0.0) > 0.0, "underflow in a tiny positive timestep must not put a flowing pool to sleep")
	check(absf(solver.total_volume() / 1e-200 - 1.0) < 1e-12, "underflow followed by normal time retains all water")

func test_canonical_persistence() -> void:
	var data: Data = closed_pair()
	data.cells[Vector2i.ZERO].water = -1
	var solver: RefCounted = CountedWater.new()
	solver.configure(data)
	solver.write_to_data(data)
	for invalid: Variant in [-1.0, NAN, "invalid"]:
		data.cells[Vector2i.ZERO].water_volume = invalid
		solver.write_to_data(data)
		check(data.cells[Vector2i.ZERO].water_volume is float and data.cells[Vector2i.ZERO].water_volume == 0.0, "explicit persistence canonicalizes invalid raw zero-volume input")

func settle_tick(water: Node3D, seconds: float) -> void:
	water.tick(seconds)
	while water._worker_task >= 0: water._collect_worker(true)

func test_snapshot_lifetime() -> void:
	var data: Data = closed_pair()
	var pair: Array[Node3D] = make_pair(data)
	var water: Node3D = pair[1]
	var builds: Variant = water.get("snapshot_build_count")
	check(builds is int and builds == 1, "configuration builds one immutable terrain snapshot")
	for step: int in 4: settle_tick(water, .1)
	check(builds != null and water.get("snapshot_build_count") == builds, "ordinary flowing updates reuse the terrain snapshot")
	water.tick(.1)
	data.cells.erase(Vector2i.RIGHT)
	data.cells[Vector2i.ZERO].height = .25
	water.sync()
	while water._worker_task >= 0: water._collect_worker(true)
	check(builds != null and water.get("snapshot_build_count") == int(builds) + 1, "an explicit mid-worker edit replaces the snapshot before publication")
	check(not water.published_depths.has(Vector2i.RIGHT), "a stale worker cannot republish removed terrain")
	check(close(water.published_volume + water.published_discharged_volume, 1.0), "snapshot invalidation retains plus discharges exactly the authored mass")
	var changed: Variant = water.get("snapshot_build_count")
	water.flush()
	check(changed != null and water.get("snapshot_build_count") == changed, "an unchanged explicit flush does not recopy the terrain")
	data.seed += 1
	water.sync(); water.flush()
	check(changed != null and water.get("snapshot_build_count") == int(changed) + 1, "a seed-only edit invalidates worker visual inputs")
	var dry: Data = Data.new()
	dry.cells[Vector2i.ZERO] = {"height": 2.0, "water": -1}
	water.reset(dry)
	check(water.published_volume == 0.0 and water.live_field_image.get_pixel(0, 0).r == 2.0, "reset replaces cached terrain images and finite water state")
	pair[0].free()

func run() -> void:
	water_script = load("res://scripts/terrain_editor/water_renderer.gd")
	test_exact_sleep_and_wake()
	test_sparse_work()
	test_underflow_is_not_equilibrium()
	test_canonical_persistence()
	test_snapshot_lifetime()
	print("WATER SCALING ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
