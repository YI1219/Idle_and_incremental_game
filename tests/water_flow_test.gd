extends SceneTree
## Conservative finite-volume water behavior, exercised without scene rendering.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
var failures: int = 0
var checks: int = 0
var solver_script: GDScript

class CountedWater:
	extends "res://scripts/terrain_editor/water_flow.gd"
	var durations: Array[float] = []

	func _advance(duration: float, transfers: Dictionary) -> bool:
		durations.append(duration)
		return super._advance(duration, transfers)

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("ok: ", message)
	else:
		failures += 1
		push_error(message)

func close(actual: float, expected: float, tolerance: float = 0.000000001) -> bool:
	return is_finite(actual) and absf(actual - expected) <= tolerance

func closed_pair(left: Dictionary, right: Dictionary) -> Data:
	var data: Data = Data.new()
	for y: int in range(-1, 2):
		for x: int in range(-1, 3):
			data.cells[Vector2i(x, y)] = {"height": 10.0, "water": -1}
	data.cells[Vector2i.ZERO] = left.duplicate()
	data.cells[Vector2i.RIGHT] = right.duplicate()
	return data

func make_solver(data: Data) -> RefCounted:
	var solver: RefCounted = solver_script.new()
	solver.configure(data)
	return solver

func advance(solver: RefCounted, count: int, delta: float = 0.1) -> void:
	for tick: int in range(count):
		solver.step(delta)

func test_authored_initialization() -> void:
	var data: Data = closed_pair({"height": -0.5, "water": 3}, {"height": 0.0, "water": -1})
	var before: Dictionary = data.cells.duplicate(true)
	var solver: RefCounted = make_solver(data)
	check(close(solver.depths[Vector2i.ZERO], 2.0), "legacy water plane minus bed defines initial volume")
	check(close(solver.heights[Vector2i.ZERO], 1.5), "legacy integer flag becomes an absolute initial surface")
	check(not solver.depths.has(Vector2i.RIGHT), "authored dry cells start empty")
	check(close(solver.total_volume(), 2.0), "initial total is the sum of cell volumes")
	check(close(solver.discharged_volume, 0.0), "configuration resets discharged volume")
	solver.step(0.1)
	check(data.cells == before, "configure and step leave authoritative terrain records untouched")
	data.cells[Vector2i.ZERO].water_volume = 0.123456789
	data.cells[Vector2i.RIGHT].water_volume = 0.25
	solver.configure(data)
	check(close(solver.depths[Vector2i.ZERO], 0.123456789), "optional continuous volume overrides the legacy plane")
	check(close(solver.depths[Vector2i.RIGHT], 0.25), "optional volume preserves water received by authored-dry terrain")
	check(close(solver.total_volume(), 0.373456789), "continuous initialization does not snap to half metres")
	check(solver.basins.size() == 2, "different initial water surfaces remain distinct basins")

func test_closed_pool_leveling() -> void:
	var data: Data = closed_pair({"height": 0.0, "water": 2}, {"height": 0.0, "water": 0, "water_volume": 0.2})
	var solver: RefCounted = make_solver(data)
	solver.step(0.1)
	var donor: float = solver.depths[Vector2i.ZERO]
	var receiver: float = solver.depths[Vector2i.RIGHT]
	check(donor < 1.0 and donor > 0.0, "bounded transfer decreases the donor volume")
	check(receiver > 0.2 and receiver < 0.6, "the same transfer increases the receiver without instant large-pool merging")
	check(close(1.0 - donor, receiver - 0.2), "the donor loses exactly the volume received downstream")
	check(close(solver.total_volume(), 1.2), "one closed-domain tick conserves total water")
	check(solver.last_transfers.size() == 1, "one flowing internal edge publishes one transfer")
	if solver.last_transfers.size() == 1:
		var transfer: Dictionary = solver.last_transfers[0]
		check(transfer.from == Vector2i.ZERO and transfer.to == Vector2i.RIGHT, "transfer endpoints point from donor to receiver")
		check(transfer.rate > 0.0 and close(transfer.rate * 0.1, 1.0 - donor), "reported rate integrates to the actual transferred volume")
		check(transfer.source_height > transfer.target_height, "flow metadata retains upstream and downstream surfaces")
	advance(solver, 800)
	check(close(solver.total_volume(), 1.2), "long closed-domain evolution preserves total water")
	check(close(solver.depths[Vector2i.ZERO], 0.6) and close(solver.depths[Vector2i.RIGHT], 0.6), "unequal connected pools reach their volume-derived common level")
	check(solver.heights[Vector2i.ZERO] == solver.heights[Vector2i.RIGHT], "leveled pool cells expose exactly the same surface height")
	check(solver.basins.size() == 1 and close(solver.basins[0].volume, 1.2), "leveled cells expose one basin with its conserved volume")
	check(close(solver.discharged_volume, 0.0), "high surrounding beds keep the closed-domain discharge at zero")

func test_basin_inflow_propagation() -> void:
	var data: Data = closed_pair({"height": 0.0, "water": 2}, {"height": 0.0, "water": 2})
	data.cells[Vector2i(2, 0)] = {"height": 0.0, "water": 4}
	for cell: Vector2i in [Vector2i(2, -1), Vector2i(2, 1), Vector2i(3, 0)]:
		data.cells[cell] = {"height": 10.0, "water": -1}
	var solver: RefCounted = make_solver(data)
	solver.step(0.1)
	check(solver.depths[Vector2i.ZERO] > 1.0, "inflow propagates to a remote cell of an existing flat basin")
	check(solver.heights[Vector2i.ZERO] == solver.heights[Vector2i.RIGHT], "inflow raises an existing basin as one level")
	check(solver.depths[Vector2i(2, 0)] < 2.0, "incoming basin water is taken from the upstream pool")
	check(solver.heights[Vector2i(2, 0)] > solver.heights[Vector2i.ZERO] + 0.5, "a substantial waterfall drop remains separate during transfer")
	check(close(solver.total_volume(), 4.0), "basin inflow redistribution conserves the entire closed volume")

func test_open_discharge_and_small_depths() -> void:
	var data: Data = Data.new()
	data.cells[Vector2i.ZERO] = {"height": 0.0, "water": 2}
	var solver: RefCounted = make_solver(data)
	solver.step(0.1)
	check(solver.total_volume() < 1.0 and solver.total_volume() > 0.0, "flow into island void decreases retained water")
	check(solver.discharged_volume > 0.0, "void outflow records discharged water")
	check(close(solver.total_volume() + solver.discharged_volume, 1.0), "retained plus discharged water remains conserved")
	check(solver.last_transfers.size() == 4, "all four exposed edges can discharge conservatively")
	var void_only: bool = true
	for transfer: Dictionary in solver.last_transfers:
		void_only = void_only and transfer.to == null and is_finite(transfer.rate) and transfer.rate > 0.0
	check(void_only, "void transfer metadata uses null destinations and finite positive rates")
	advance(solver, 1000)
	check(close(solver.total_volume() + solver.discharged_volume, 1.0), "long open-domain evolution preserves retained plus discharged volume")
	data.cells[Vector2i.ZERO] = {"height": 10.0, "water": -1, "water_volume": 1.0e-20}
	solver.configure(data)
	solver.step(0.1)
	check(solver.depths.has(Vector2i.ZERO) and solver.depths[Vector2i.ZERO] > 0.0, "tiny positive depths are retained without an arbitrary dry cutoff")
	check(close(solver.total_volume() + solver.discharged_volume, 1.0e-20, 1.0e-30), "tiny-volume evolution also conserves water")
	solver.configure(Data.new())
	check(close(solver.total_volume(), 0.0) and close(solver.discharged_volume, 0.0), "reconfiguration clears the previous simulation and discharge")

func test_dry_and_barriers() -> void:
	var data: Data = closed_pair({"height": 0.0, "water": -1}, {"height": -2.0, "water": -1})
	var solver: RefCounted = make_solver(data)
	advance(solver, 50)
	check(solver.depths.is_empty() and solver.heights.is_empty(), "a dry island never creates water")
	check(solver.basins.is_empty() and solver.last_transfers.is_empty(), "a dry island has no artificial basins or flows")
	data.cells[Vector2i.ZERO] = {"height": 0.0, "water": 2}
	data.cells[Vector2i.RIGHT] = {"height": 1.5, "water": -1}
	solver.configure(data)
	advance(solver, 30)
	check(close(solver.depths[Vector2i.ZERO], 1.0) and not solver.depths.has(Vector2i.RIGHT), "a bed above the water surface blocks flow")
	check(close(solver.total_volume(), 1.0), "blocked water remains in its closed source cell")

func test_sync_and_persistence() -> void:
	var data: Data = closed_pair({"height": 0.0, "water": 2}, {"height": 0.0, "water": 0, "water_volume": 0.2})
	var solver: RefCounted = make_solver(data)
	solver.step(0.1)
	var live_donor: float = solver.depths[Vector2i.ZERO]
	var live_receiver: float = solver.depths[Vector2i.RIGHT]
	solver.sync(data)
	check(close(solver.depths[Vector2i.ZERO], live_donor) and close(solver.depths[Vector2i.RIGHT], live_receiver), "unchanged sync preserves live donor and receiver volumes")
	check(solver.last_transfers.size() == 1, "unchanged sync preserves current visual flow metadata")
	solver.write_to_data(data)
	check(close(data.cells[Vector2i.ZERO].water_volume, live_donor), "explicit persistence writes the current continuous donor volume")
	check(solver.last_transfers.size() == 1, "persisting live volumes preserves current visual flow metadata")
	solver.sync(data)
	check(close(solver.depths[Vector2i.ZERO], live_donor), "persisted solver values are baseline updates rather than refill commands")
	data.cells[Vector2i.ZERO].height = 2.0
	data.cells[Vector2i.ZERO].water = -1
	solver.sync(data)
	check(close(solver.depths[Vector2i.ZERO], live_donor), "a bed raise with legacy automatic dry marker retains its displaced water")
	check(close(solver.heights[Vector2i.ZERO], 2.0 + live_donor), "raised-bed water exposes the displaced absolute surface")
	check(close(solver.total_volume(), 1.2), "bed elevation editing creates or deletes no water")
	data.cells[Vector2i.RIGHT].water_volume = 0.125
	solver.sync(data)
	check(close(solver.depths[Vector2i.RIGHT], 0.125), "an explicit changed volume resets only its author-edited cell")
	check(close(solver.depths[Vector2i.ZERO], live_donor), "volume authoring preserves an unrelated live donor")
	data.cells[Vector2i.RIGHT].water_volume = 0.0
	data.cells[Vector2i.RIGHT].water = -1
	solver.sync(data)
	check(not solver.depths.has(Vector2i.RIGHT), "an explicit dry edit removes the affected cell volume")
	data.cells[Vector2i(4, 0)] = {"height": -4.0, "water": -1}
	solver.sync(data)
	check(not solver.depths.has(Vector2i(4, 0)), "newly added dry terrain starts empty below existing water elevations")
	data.cells.erase(Vector2i.ZERO)
	solver.sync(data)
	check(close(solver.total_volume(), 0.0) and close(solver.discharged_volume, live_donor), "deleted terrain discharges exactly its existing water")
	var fresh: Data = closed_pair({"height": 0.0, "water": 1}, {"height": 0.0, "water": -1})
	solver.sync(fresh)
	check(close(solver.total_volume(), 0.5) and close(solver.discharged_volume, 0.0), "syncing a different dataset starts its own independent volume state")

func test_changed_basin_beds() -> void:
	var data: Data = closed_pair({"height": 0.0, "water": 2}, {"height": 0.5, "water": 2})
	var solver: RefCounted = make_solver(data)
	solver.write_to_data(data)
	data.cells[Vector2i.RIGHT].height = 2.0
	data.cells[Vector2i.RIGHT].water = -1
	solver.sync(data)
	check(close(solver.total_volume(), 1.5), "raising a flat-pool bed preserves basin volume")
	check(not solver.depths.has(Vector2i.RIGHT) and close(solver.depths[Vector2i.ZERO], 1.5), "a raised bed leaves the flat basin and displaces its water into lower members")
	data.cells[Vector2i.ZERO].height = -0.5
	solver.sync(data)
	check(close(solver.total_volume(), 1.5) and close(solver.heights[Vector2i.ZERO], 1.0), "lowering a bed lowers surface while preserving existing water")
	data.cells[Vector2i(0, -1)].height = 0.0
	data.cells[Vector2i(0, -2)] = {"height": 10.0, "water": -1}
	solver.sync(data)
	solver.step(0.1)
	check(solver.depths.get(Vector2i(0, -1), 0.0) > 0.0, "newly opened low terrain receives existing water")
	check(close(solver.total_volume(), 1.5), "opening a closed basin redistributes water without adding any")

func test_finite_steps_and_determinism() -> void:
	var data: Data = closed_pair({"height": 0.0, "water": 2}, {"height": 0.0, "water": -1})
	var solver: RefCounted = make_solver(data)
	for invalid: float in [0.0, -0.1, NAN, INF]:
		solver.step(invalid)
	check(close(solver.total_volume(), 1.0) and close(solver.depths[Vector2i.ZERO], 1.0), "zero negative and nonfinite deltas leave the simulation finite and unchanged")
	solver.step(5.0)
	var finite: bool = true
	for cell: Vector2i in solver.depths:
		finite = finite and is_finite(solver.depths[cell]) and solver.depths[cell] > 0.0 and is_finite(solver.heights[cell])
	check(finite and close(solver.total_volume(), 1.0), "large frame gaps use bounded substeps with finite conservative outputs")
	var split_solver: RefCounted = make_solver(data)
	advance(split_solver, 50)
	check(close(split_solver.depths[Vector2i.ZERO], solver.depths[Vector2i.ZERO]), "bounded integration matches the same duration split across normal ticks")
	var reversed_data: Data = Data.new()
	var keys: Array = data.cells.keys()
	keys.reverse()
	for cell: Vector2i in keys:
		reversed_data.cells[cell] = data.cells[cell].duplicate()
	var reversed_solver: RefCounted = make_solver(reversed_data)
	reversed_solver.step(5.0)
	check(reversed_solver.depths == solver.depths, "cell insertion order does not change deterministic water results")
	data.cells[Vector2i.ZERO].water_volume = NAN
	data.cells[Vector2i.RIGHT].water_volume = -3.0
	solver.configure(data)
	check(close(solver.total_volume(), 0.0), "invalid optional depths cannot introduce nonfinite or negative water")

func test_multiple_outlets_and_basin_drying() -> void:
	var data: Data = Data.new()
	data.cells[Vector2i.ZERO] = {"height": 0.0, "water": 2, "water_volume": 1000000.0}
	var solver: RefCounted = make_solver(data)
	solver.step(0.1)
	check(close(solver.total_volume(), 0.0) and close(solver.discharged_volume, 1000000.0), "simultaneous outlets share a bounded donor budget without negative water")
	var reported_discharge: float = 0.0
	for transfer: Dictionary in solver.last_transfers:
		reported_discharge += float(transfer.rate) * 0.1
	check(close(reported_discharge, 1000000.0), "scaled outlet metadata integrates to exactly the exhausted donor budget")
	data = closed_pair({"height": 0.0, "water": 2}, {"height": 0.5, "water": 2})
	data.cells.erase(Vector2i.LEFT)
	solver.configure(data)
	advance(solver, 1000)
	check(not solver.depths.has(Vector2i.RIGHT) and solver.depths.get(Vector2i.ZERO, 0.0) > 0.0, "a falling basin dries its higher bed while retaining lower water")
	check(close(solver.total_volume() + solver.discharged_volume, 1.5), "dry-member removal during discharge preserves retained plus discharged water")

func test_topology_split_and_authored_flag() -> void:
	var data: Data = closed_pair({"height": 0.0, "water": 2}, {"height": 0.0, "water": 2})
	data.cells[Vector2i(2, 0)] = {"height": 0.0, "water": 2}
	var solver: RefCounted = make_solver(data)
	data.cells.erase(Vector2i.RIGHT)
	data.cells[Vector2i(2, 0)].height = -1.0
	solver.sync(data)
	check(close(solver.depths[Vector2i.ZERO], 1.0) and close(solver.depths[Vector2i(2, 0)], 1.0), "topology deletion splits old basins before changed beds can move water across the gap")
	check(close(solver.discharged_volume, 1.0) and close(solver.total_volume(), 2.0), "basin splitting discharges only water on deleted terrain")
	data.cells[Vector2i.ZERO].water = 1
	solver.sync(data)
	check(close(solver.depths[Vector2i.ZERO], 0.5) and close(solver.depths[Vector2i(2, 0)], 1.0), "a changed legacy plane authors only that cell when no volume override exists")
	data.cells[Vector2i(4, 0)] = {"height": -1.0, "water": 1}
	solver.sync(data)
	check(close(solver.depths[Vector2i(4, 0)], 1.5), "added authored-wet terrain initializes from its own bed and plane")

func closed_triple() -> Data:
	var data: Data = closed_pair({"height": 0.0, "water": 2}, {"height": 0.0, "water": 2})
	data.cells[Vector2i(2, 0)] = {"height": 0.0, "water": 2}
	for cell: Vector2i in [Vector2i(2, -1), Vector2i(2, 1), Vector2i(3, 0)]:
		data.cells[cell] = {"height": 10.0, "water": -1}
	return data

func test_drying_bridge_splits_configured_basin() -> void:
	var data: Data = closed_triple()
	data.cells[Vector2i.ZERO].water_volume = 1.0
	data.cells[Vector2i.RIGHT] = {"height": 1.01, "water": -1, "water_volume": 0.01}
	data.cells[Vector2i(2, 0)].water_volume = 1.0
	var solver: RefCounted = make_solver(data)
	check(not solver.depths.has(Vector2i.RIGHT), "volume-derived leveling dries a bridge above the new common surface")
	check(solver.basins.size() == 2, "a bridge dried during configuration produces two physically connected basins")
	var single_members: bool = true
	for basin: Dictionary in solver.basins:
		single_members = single_members and basin.cells.size() == 1 and close(basin.volume, 1.005)
	check(single_members, "each side of a dried bridge exposes its own cells and volume")
	solver.step(0.1)
	check(solver.basins.size() == 2 and close(solver.total_volume(), 2.01), "stationary pools retain correct separation and volume after a bridge dries")

func test_raised_bridge_blocks_cross_partition_redistribution() -> void:
	var data: Data = closed_triple()
	var solver: RefCounted = make_solver(data)
	solver.write_to_data(data)
	data.cells[Vector2i.RIGHT].height = 3.0
	data.cells[Vector2i.RIGHT].water = -1
	data.cells[Vector2i(2, 0)].height = -2.0
	solver.sync(data)
	check(not solver.depths.has(Vector2i.RIGHT), "raising a bridge above the old pool displaces its water and leaves a dry barrier")
	check(close(solver.depths[Vector2i.ZERO], 1.5) and close(solver.depths[Vector2i(2, 0)], 1.5), "raised-bridge water shares between adjacent pools without transferring existing water across the dry barrier")
	check(close(solver.heights[Vector2i.ZERO], 1.5) and close(solver.heights[Vector2i(2, 0)], -0.5), "lowering one separated bed changes only its pool surface")
	check(solver.basins.size() == 2 and close(solver.total_volume(), 3.0), "bed-created partitions expose independent conserved basins")
	advance(solver, 10)
	check(close(solver.depths[Vector2i.ZERO], 1.5) and close(solver.depths[Vector2i(2, 0)], 1.5), "separated closed pools retain their own water after subsequent simulation")

func test_substep_count_has_no_float_dust() -> void:
	var data: Data = closed_pair({"height": 0.0, "water": 2}, {"height": 0.0, "water": -1})
	var solver: CountedWater = CountedWater.new()
	solver.configure(data)
	solver.step(0.1)
	check(solver.durations.size() == 4, "a normal 0.1 second tick executes four substeps without a floating-point dust fifth step")
	var bounded: bool = true
	for duration: float in solver.durations:
		bounded = bounded and duration > 0.0 and duration <= 0.025
	check(bounded, "every scheduled normal-tick substep remains positive and bounded")
	solver.durations.clear()
	solver.step(1.0e-20)
	check(solver.durations.size() == 1 and solver.durations[0] == 1.0e-20, "a genuinely tiny positive delta is advanced in full")

func test_actual_presets_conserve() -> void:
	for preset: int in [0, 1, 2]:
		var data: Data = Data.new()
		data.make_preset(preset)
		var solver: RefCounted = make_solver(data)
		var initial: float = solver.total_volume()
		advance(solver, 20)
		check(close(solver.total_volume() + solver.discharged_volume, initial, 1.0e-8), "actual preset %d conserves retained plus discharged volume" % preset)
		var consistent: bool = true
		for basin: Dictionary in solver.basins:
			var basin_sum: float = 0.0
			for cell: Vector2i in basin.cells:
				basin_sum += solver.depths[cell]
				consistent = consistent and solver.heights[cell] == basin.height and solver.heights[cell] >= float(data.cells[cell].height)
			consistent = consistent and close(basin_sum, basin.volume, 1.0e-8)
		check(consistent, "actual preset %d basin levels and volumes match consumer-facing cell data" % preset)

func run() -> void:
	solver_script = load("res://scripts/terrain_editor/water_flow.gd") as GDScript
	check(solver_script != null, "continuous conservative water solver exists")
	if solver_script != null:
		test_authored_initialization()
		test_closed_pool_leveling()
		test_basin_inflow_propagation()
		test_open_discharge_and_small_depths()
		test_dry_and_barriers()
		test_sync_and_persistence()
		test_changed_basin_beds()
		test_finite_steps_and_determinism()
		test_multiple_outlets_and_basin_drying()
		test_topology_split_and_authored_flag()
		test_drying_bridge_splits_configured_basin()
		test_raised_bridge_blocks_cross_partition_redistribution()
		test_substep_count_has_no_float_dust()
		test_actual_presets_conserve()
	print("WATER FLOW: ", checks, " checks, ", failures, " failures")
	quit(1 if failures > 0 else 0)
