extends SceneTree
## Live water publication, conservation, topology edits and worker ownership.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Renderer = preload("res://scripts/terrain_editor/terrain_renderer.gd")
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")
var checks: int = 0
var failures: int = 0
var water_script: GDScript

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("ok: ", message)
	else:
		failures += 1
		push_error(message)

func close(a: float, b: float) -> bool:
	return is_finite(a) and absf(a - b) < 0.00000001

func closed_pair() -> Data:
	var data: Data = Data.new()
	for z: int in range(-1, 2):
		for x: int in range(-1, 3):
			data.cells[Vector2i(x, z)] = {"height": 10.0, "water": -1}
	data.cells[Vector2i.ZERO] = {"height": 0.0, "water": 2}
	data.cells[Vector2i.RIGHT] = {"height": 0.0, "water": -1}
	return data

func make_pair(data: Data) -> Array[Node3D]:
	var terrain: Node3D = Renderer.new()
	root.add_child(terrain)
	terrain.configure(data)
	var water: Node3D = water_script.new()
	terrain.add_child(water)
	water.configure(data, terrain)
	return [terrain, water]

func test_conservation_and_publication() -> void:
	var data: Data = closed_pair()
	var pair: Array[Node3D] = make_pair(data)
	var terrain: Node3D = pair[0]
	var water: Node3D = pair[1]
	check(close(water.flow.total_volume(), 1.0), "initial publication preserves the authored finite volume")
	check(close(water.simulated_seconds, 0.0), "configuration publishes a pool without an undocumented time advance")
	check(water.get_node("water").mesh != null, "independent water mesh is published")
	check(water.get_node("water").material_override == terrain.materials.water, "water uses the terrain's shared style material")
	check(terrain.materials.water.get_shader_parameter("shore_field") == water.shore_texture, "live shoreline texture binds to the shared water material")
	check(water.live_field_image.get_format() == Image.FORMAT_RGBAF, "grass clipping receives a floating-point live water grid")
	check(water.live_field_image.get_pixel(1, 1).a == 1.0, "live grid distinguishes present terrain from the void")
	water.tick(0.1)
	water.flush()
	check(water.flow.depths.get(Vector2i.RIGHT, 0.0) > 0.0, "authored-dry receiving terrain gains positive live water")
	check(close(water.flow.total_volume(), 1.0), "closed-domain dynamic rendering creates no water")
	check(close(water.simulated_seconds, 0.1), "explicit flush advances exactly the queued simulation duration")
	check(data.cells[Vector2i.RIGHT].get("water_volume", 0.0) > 0.0, "idle publication persists continuous receiving volume")
	var finite_geometry: bool = true
	for surface: RefCounted in water.published_surfaces.values():
		for vertex: Vector3 in surface.vertices:
			finite_geometry = finite_geometry and vertex.is_finite()
	check(finite_geometry, "published pool and waterfall geometry contains only finite coordinates")
	check(not water.has_pending_updates(), "flush leaves no worker or queued simulation behind")
	water.free()
	terrain.free()

func test_legacy_layers() -> void:
	var data: Data = closed_pair()
	var pair: Array[Node3D] = make_pair(data)
	var terrain: Node3D = pair[0]
	var water: Node3D = pair[1]
	var chunk: Node3D = Node3D.new()
	for kind: String in ["water", "waterfall", "bank", "shore", "lake_bed"]:
		var node: MeshInstance3D = MeshInstance3D.new()
		node.name = kind
		chunk.add_child(node)
	terrain.add_child(chunk)
	check(not chunk.get_node("water").visible and not chunk.get_node("waterfall").visible and not chunk.get_node("bank").visible, "new terrain chunks cannot expose legacy dynamic water layers")
	check(chunk.get_node("shore").visible and chunk.get_node("lake_bed").visible, "static shore and bed layers remain available")
	chunk.get_node("water").visible = true
	water.sync()
	check(water.get_node("water").visible, "hiding legacy chunks preserves the live renderer's own water")
	water.flush()
	check(not chunk.get_node("water").visible, "terrain sync hides legacy layers again after publication")
	water.free()
	terrain.free()

func test_worker_edits_and_queue() -> void:
	var data: Data = closed_pair()
	var pair: Array[Node3D] = make_pair(data)
	var terrain: Node3D = pair[0]
	var water: Node3D = pair[1]
	water.tick(0.1)
	var task: int = water._worker_task
	data.cells.erase(Vector2i.RIGHT)
	data.cells[Vector2i.ZERO].height = 0.2
	water.sync()
	check(water._worker_task == task, "sync never replaces a task that still owns the solver")
	for index: int in range(20):
		water.tick(0.1)
	check(water.queued_seconds <= 0.300000001, "long frame catchup remains bounded")
	water.flush()
	check(not water.published_depths.has(Vector2i.RIGHT), "mid-task cell removal is reconciled before final publication")
	check(close(water.flow.total_volume() + water.flow.discharged_volume, 1.0), "mid-task topology changes preserve retained plus discharged water")
	check(water.last_step_seconds <= 0.1, "every worker's simulation advance remains bounded")
	check(not water.has_pending_updates(), "edited topology flush settles all workers")
	water.tick(0.1)
	var retained_flow: RefCounted = water.flow
	water.free()
	terrain.free()
	check(not retained_flow.last_transfers.is_empty(), "disposal waits until an active solver advance completes")

func test_reset_and_empty() -> void:
	var data: Data = closed_pair()
	var pair: Array[Node3D] = make_pair(data)
	var terrain: Node3D = pair[0]
	var water: Node3D = pair[1]
	water.tick(0.1)
	var dry: Data = Data.new()
	dry.cells[Vector2i.ZERO] = {"height": 0.0, "water": -1}
	water.reset(dry)
	water.flush()
	check(close(water.flow.total_volume(), 0.0), "declared reset replaces the previous water state")
	check(water.published_surfaces.water.vertices.is_empty(), "a dry island publishes no water geometry")
	check(not water.get_node("water").visible, "an empty water mesh hides its independent node")
	var empty: Data = Data.new()
	water.reset(empty)
	water.tick(0.1)
	water.flush()
	check(close(water.flow.total_volume(), 0.0) and water.live_field_image.get_width() == 1, "an empty island has a finite empty grid and no water source")
	check(water.fall_veils.is_empty() and water.splash_points.is_empty(), "dry and empty domains publish no falls or splash metadata")
	water.free()
	terrain.free()

func test_flow_gating() -> void:
	var data: Data = closed_pair()
	data.cells[Vector2i.RIGHT].height = 10.0
	var pair: Array[Node3D] = make_pair(data)
	var terrain: Node3D = pair[0]
	var water: Node3D = pair[1]
	water.tick(0.1)
	water.flush()
	check(water.published_surfaces.waterfall.vertices.is_empty(), "a blocked outlet draws no nominal waterfall")
	data.cells[Vector2i.RIGHT].height = -1.0
	water.sync()
	water.tick(0.1)
	water.flush()
	check(not water.published_surfaces.waterfall.vertices.is_empty(), "positive downhill flux publishes a live waterfall")
	check(not water.fall_veils.is_empty(), "live downhill falls publish mist veil metadata")
	var rates_valid: bool = true
	for veil: Dictionary in water.fall_veils:
		rates_valid = rates_valid and veil.get("rate", 0.0) > 0.0 and veil.get("intensity", 0.0) > 0.0
	check(rates_valid, "live veil metadata carries positive measured outflow and intensity")
	water.free()
	terrain.free()

func test_adjacent_blocked_edge() -> void:
	var data: Data = closed_pair()
	data.cells[Vector2i(0, 1)] = {"height": 0.0, "water": 2}
	data.cells[Vector2i.RIGHT].height = -1.0
	var solver: RefCounted = load("res://scripts/terrain_editor/water_flow.gd").new()
	solver.configure(data)
	solver.step(0.1)
	var field: RefCounted = water_script.FlowField.new()
	field.build_live(data, solver)
	field._basin = field.basin_ids[Vector2i.ZERO]
	var water_y: float = float(solver.heights[Vector2i.ZERO]) + 0.045
	var edges: Array = field._flow_edges(PackedVector2Array([Vector2(1.0, 1.1), Vector2(1.0, 1.4), Vector2(0.9, 1.4)]), water_y)
	check(not edges[0].spill, "a nearby flowing edge cannot turn its blocked neighbour into a waterfall")

func test_outlet_surface_support() -> void:
	var data: Data=Data.new()
	data.make_preset(0)
	var solver:RefCounted=load("res://scripts/terrain_editor/water_flow.gd").new()
	solver.configure(data)
	solver.step(.1)
	var field:RefCounted=water_script.FlowField.new()
	field.build_live(data,solver)
	var unsupported:int=0
	for basin:Dictionary in solver.basins:
		field._basin=int(basin.id)
		for loop:PackedVector2Array in field.water_regions.get(int(basin.id),[]):
			var subdivided:PackedVector2Array=field._subdivide_outline(loop)
			var edges:Array=field._flow_edges(subdivided,float(basin.height)+.045)
			for i:int in edges.size():
				if not edges[i].spill:continue
				var a:Vector2=subdivided[i]
				var b:Vector2=subdivided[(i+1)%subdivided.size()]
				var out:=Vector2(b.y-a.y,a.x-b.x).normalized()
				var outside:Dictionary=field.surface_at((a+b)*.5+out*.28)
				if outside.get("water",-1)==int(basin.id):unsupported+=1
	check(unsupported==0,"nearby outflow cannot attach a detached waterfall to its own basin side")

func test_normal_preset(seed_value: int = 7301, preset: int = 0) -> void:
	var data: Data = Data.new()
	data.seed = seed_value
	data.make_preset(preset)
	var pair: Array[Node3D] = make_pair(data)
	var terrain: Node3D = pair[0]
	var water: Node3D = pair[1]
	var initial: float = water.flow.total_volume()
	water.tick(0.1)
	water.flush()
	check(close(water.flow.total_volume() + water.flow.discharged_volume, initial), "normal preset retains the authored mass balance")
	check(water.published_surfaces.water.vertices.is_empty() == (initial == 0.0), "normal preset water geometry matches its physical wet state")
	print("water timing seed=", seed_value, " preset=", preset, " cells=", data.cells.size(), " advance=", water.last_advance_worker_ms, "ms publish=", water.last_publish_ms, "ms snapshot=", water.last_snapshot_ms, "ms sync=", water.last_sync_ms, "ms stages=", water.last_advance_stages)
	water.free()
	terrain.free()

func test_frozen_and_tiny() -> void:
	var data: Data = closed_pair()
	data.cells[Vector2i.ZERO] = {"height": 0.0, "water": -1, "water_volume": 0.000000001}
	data.cells[Vector2i.RIGHT].height = 10.0
	var pair: Array[Node3D] = make_pair(data)
	var terrain: Node3D = pair[0]
	var water: Node3D = pair[1]
	var revision: int = water.publication_revision
	await create_timer(0.12).timeout
	check(close(water.simulated_seconds, 0.0) and water.publication_revision == revision, "scene processing without explicit ticks leaves frozen water unchanged")
	water.tick(0.1)
	water.flush()
	check(water.published_volume > 0.0 and absf(water.published_volume - 0.000000001) < 0.000000000000001, "sub-visible water remains in the physical volume")
	check(water.published_surfaces.water.vertices.is_empty(), "sub-visible water can omit geometry without deleting mass")
	water.free()
	terrain.free()

func test_detached_disposal() -> void:
	var data: Data = Data.new()
	data.make_preset(0)
	var terrain: Node3D = Renderer.new()
	root.add_child(terrain)
	terrain.configure(data)
	var water: Node3D = water_script.new()
	water.configure(data, terrain)
	var retained_flow: RefCounted = water.flow
	water.tick(0.1)
	water.free()
	check(not retained_flow.last_transfers.is_empty(), "a configured detached renderer also joins its worker on disposal")
	terrain.free()

func run() -> void:
	check(ResourceLoader.exists("res://scripts/terrain_editor/water_renderer.gd"), "independent water renderer exists")
	if failures > 0:
		quit(1)
		return
	water_script = load("res://scripts/terrain_editor/water_renderer.gd")
	test_conservation_and_publication()
	test_legacy_layers()
	test_worker_edits_and_queue()
	test_reset_and_empty()
	test_flow_gating()
	test_adjacent_blocked_edge()
	test_outlet_surface_support()
	test_normal_preset()
	test_normal_preset(2104, 0)
	test_normal_preset(4242, 1)
	test_normal_preset(913, 2)
	test_detached_disposal()
	await test_frozen_and_tiny()
	print("water_renderer_test: ", checks - failures, "/", checks, " passed")
	quit(1 if failures else 0)
