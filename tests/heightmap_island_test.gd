extends SceneTree
## Heightmap shell: brushes, inward fold, sparse embeds. No viewport.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Island = preload("res://scripts/terrain_editor/heightmap_island.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(Island.wall_inset(0.0) == 0.0, "rim inset starts at the footprint")
	check(Island.wall_inset(0.6) > 0.04, "upper wall leans instead of dropping straight")
	check(Island.wall_inset(FOLD()) > Island.wall_inset(0.6), "fold is deeper than the lip")
	var before := Island.wall_inset(FOLD())
	var after := Island.wall_inset(FOLD() + 1.2)
	check(after > before + 0.5, "past the threshold the wall pinches inward")
	check(Island.wall_inset(4.0) > 0.0, "inset never flares outward")
	var data := Data.new()
	data.make_preset(0)
	var island := Island.new()
	island.refresh(data)
	check(island.surfaces.grass.vertices.size() > 30, "heightmap top has a grass surface")
	check(island.surfaces.cliff.vertices.size() > 30, "heightmap builds a cliff shell")
	check(island.keel_inset_mean > 0.2, "preset underside regenerates inside the rim")
	check(not island.embeds.is_empty() and island.embeds.size() < 80, "preset places a sparse embed set")
	check(island.cliff_embed_placements() == island.embeds, "embed placement hook returns the same set")
	var inward := 0
	var outward := 0
	for edge in island._boundary:
		var points: PackedVector2Array = edge.points
		var mid: Vector2 = points[mini(1, points.size() - 1)]
		var outward_dir: Vector2 = edge.outward
		var top: Vector2 = mid
		var keel: Vector2 = island._displace(mid, outward_dir, float(edge.y), maxf(float(edge.y) - Island.KEEL_Y, 0.8))
		var moved := (top - keel).dot(outward_dir)
		if moved > 0.15:
			inward += 1
		if moved < -0.02:
			outward += 1
	check(inward > 8 and outward == 0, "skirt samples fold inward and do not flare")
	var occupied := data.cells.size()
	var empty := _empty_neighbor(data)
	check(empty != Vector2i(99999, 99999), "preset has a cell outside the footprint")
	data.begin_stroke()
	var expanded := data.apply_brush(Vector2(empty) + Vector2(0.5, 0.5), 0.55, "expand", true, 2.0, 0)
	data.end_stroke()
	check(expanded > 0 and data.cells.size() > occupied, "expand grows the footprint")
	island.refresh(data)
	check(island.keel_inset_mean > 0.2, "underside rebuilds after expand")
	var raised_cell: Vector2i = empty
	var raised_before: float = data.cells[raised_cell].height
	data.begin_stroke()
	var raised := data.apply_brush(Vector2(raised_cell) + Vector2(0.5, 0.5), 0.4, "raise", true, 2.0, 0)
	data.end_stroke()
	check(raised > 0 and data.cells[raised_cell].height == raised_before + 0.5, "raise edits height only")
	data.begin_stroke()
	var lowered := data.apply_brush(Vector2(raised_cell) + Vector2(0.5, 0.5), 0.4, "lower", true, 2.0, 0)
	data.end_stroke()
	check(lowered > 0 and is_equal_approx(data.cells[raised_cell].height, raised_before), "lower restores the brushed height")
	data.begin_stroke()
	var shrunk := data.apply_brush(Vector2(raised_cell) + Vector2(0.5, 0.5), 0.4, "contract", true, 2.0, 0)
	data.end_stroke()
	check(shrunk > 0 and not data.cells.has(raised_cell), "shrink removes footprint")
	island.refresh(data)
	check(island.keel_inset_mean > 0.2, "underside rebuilds after shrink")
	check(_has_rock_step(data), "preset keeps a steep step that reads as a rock wall")
	print("HEIGHTMAP ISLAND: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)

func FOLD() -> float:
	return Island.FOLD_DEPTH

func _shown(record: Dictionary) -> float:
	return float(record.water) * 0.5 if int(record.water) >= 0 else float(record.height)

func _has_rock_step(data: Data) -> bool:
	for cell: Vector2i in data.cells:
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not data.cells.has(neighbor):
				continue
			if absf(_shown(data.cells[cell]) - _shown(data.cells[neighbor])) >= Island.ROCK_RISE:
				return true
	return false

func _empty_neighbor(data: Data) -> Vector2i:
	for cell: Vector2i in data.cells:
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not data.cells.has(neighbor):
				return neighbor
	return Vector2i(99999, 99999)
