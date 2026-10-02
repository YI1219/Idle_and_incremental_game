extends SceneTree
## Heightfield v1: volume, cracks, holes, water spill, flatten cost, determinism.

const Heightfield := preload("res://scripts/world/heightfield.gd")
const HeightfieldMesh := preload("res://scripts/world/heightfield_mesh.gd")
const LakeShore := preload("res://scripts/world/lake_shore.gd")
const IslandGeometry := preload("res://scripts/world/island_geometry.gd")
const XirangLib := preload("res://scripts/sim/xirang.gd")

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	_volume()
	_cracks()
	_dig_through()
	_water()
	_flatten()
	_determinism()
	_winding()
	_organic_mask()
	_starter_pebble()
	_shaft()
	print("HEIGHTFIELD CHECKS: %d/%d passed, failures=%d" % [checks - failures, checks, failures])
	quit(1 if failures else 0)


func _rect_field(w: int, h: int, seed: int = 7) -> Heightfield:
	var cells: Dictionary = {}
	for x in w:
		for z in h:
			cells[Vector2i(x, z)] = true
	return Heightfield.from_play_cells(cells, 0.5, -4.0, seed, 1)


func _volume() -> void:
	var field := _rect_field(4, 3)
	var expected := 4.0 * 3.0 * 4.0
	check(is_equal_approx(field.total_volume(), expected), "flat island volume is area times thickness")
	var before := field.total_volume()
	field.set_height(4, 3, field.height_at(4, 3) + 1.0)
	field._clamp_all_land()
	var delta := field.total_volume() - before
	# One interior-ish vertex is shared by up to 4 cells: each contributes area/4.
	check(delta > 0.2 and delta < 1.1, "raising one vertex adds a known prism slice")
	var xirang := XirangLib.new()
	xirang.configure({})
	check(is_equal_approx(xirang.quote_volume(4.0, 10), 1.0), "volume quote matches cell cost at 4 m3")
	check(is_equal_approx(xirang.quote_remove_volume(4.0), 0.5), "volume refund uses the 0.5 ratio")
	var preview: Dictionary = field.preview_brush("raise", Vector3(2.0, 0.0, 1.5), 1.2, 0.8, true)
	var applied: Dictionary = field.apply_brush("raise", Vector3(2.0, 0.0, 1.5), 1.2, 0.8, true)
	check(is_equal_approx(float(preview["delta_volume"]), float(applied["delta_volume"])), "preview volume matches commit")


func _cracks() -> void:
	var field := _rect_field(10, 8, 11)
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	var border: Array = HeightfieldMesh.border_vertices(field, a, b)
	var left: Array = border[0]
	var right: Array = border[1]
	check(left.size() == right.size() and left.size() > 2, "adjacent chunks share a border column")
	var equal := true
	for i in left.size():
		if not (left[i] as Vector3).is_equal_approx(right[i]):
			equal = false
	check(equal, "shared border vertices are identical after world-space jitter")
	var top_a := HeightfieldMesh.build_chunk(field, a, "top")
	var top_b := HeightfieldMesh.build_chunk(field, b, "top")
	check(int(top_a["triangles"]) > 0 and int(top_b["triangles"]) > 0, "chunk tops emit triangles")


func _dig_through() -> void:
	var field := _rect_field(6, 6, 3)
	var mid := Vector3(3.0, 0.0, 3.0)
	for _i in 8:
		field.apply_brush("lower", mid, 1.1, 1.2, true)
	var hole := field.world_to_cell(mid)
	check(not field.is_land(hole.x, hole.y), "digging to the bottom clears the mask")
	var payload := HeightfieldMesh.build_chunk(field, Vector2i(0, 0), "full")
	check(int(payload["triangles"]) > 20, "a holed island still has a mesh")
	var hole_odd := HeightfieldMesh.odd_edge_ratio(payload)
	check(hole_odd < 0.02, "dig-through hole keeps a closed wall/bottom (odd=%.4f)" % hole_odd)
	check(HeightfieldMesh.lowest_y(payload) < -3.5, "closed underside still hangs at y_bottom")


func _water() -> void:
	var field := _rect_field(8, 8, 5)
	# Closed pit: lower the interior, leave a rim.
	for z in range(2, 6):
		for x in range(2, 6):
			field.apply_brush("lower", Vector3(float(x) + 0.25, 0.0, float(z) + 0.25), 0.55, 0.9, true)
	var water: Dictionary = field.compute_water()
	check((water.get("lakes", []) as Array).size() >= 1, "a closed pit holds a lake")
	var lake: Dictionary = (water.get("lakes", []) as Array)[0]
	var level := float(lake.get("level", 0.0))
	var floor_h := field.sample_height(Vector3(4.0, 0.0, 4.0))
	check(level >= floor_h + 0.02, "water surface sits at least 2 cm above the pit floor")
	var rings: Array = HeightfieldMesh.lake_rings(field, lake.get("cells", []))
	check(not rings.is_empty(), "lake exposes a waterline ring")
	var baked: Dictionary = LakeShore.bake(rings)
	var shore_p: Vector2 = rings[0][0]
	var shore_d := LakeShore.sample(baked, shore_p)
	check(shore_d < 0.2, "shore field is near zero on the waterline (%.3f)" % shore_d)
	var centroid := Vector2.ZERO
	for p in rings[0]:
		centroid += p
	centroid /= float(maxi(rings[0].size(), 1))
	check(LakeShore.sample(baked, centroid) > shore_d + 0.12, "shore field grows toward the lake interior")
	var sheet: Dictionary = HeightfieldMesh.build_water(field, lake)
	var ring_r := 0.0
	var mesh_r := 0.0
	for p in rings[0]:
		ring_r = maxf(ring_r, p.distance_to(centroid))
	for v in sheet.get("vertices", PackedVector3Array()):
		mesh_r = maxf(mesh_r, Vector2(v.x, v.z).distance_to(centroid))
	check(mesh_r > ring_r + 0.2, "water sheet overlaps the bank past the waterline")
	# Notch the east rim all the way to the coast so the lake drains.
	var max_x := field.origin.x + float(field.cells_x()) * field.spacing
	var x := 5.5
	while x <= max_x + 0.2:
		field.apply_brush("lower", Vector3(x, 0.0, 4.0), 0.75, 1.2, true)
		x += 0.45
	var drained: Dictionary = field.compute_water()
	var still := 0
	for lake2 in drained.get("lakes", []):
		still += (lake2.get("cells", []) as Array).size()
	check(still < (lake.get("cells", []) as Array).size(), "a rim notch lowers or empties the pond")
	check((drained.get("waterfalls", []) as Array).size() >= 1, "a draining notch reports a waterfall site")


func _flatten() -> void:
	var field := _rect_field(6, 6, 9)
	field.apply_brush("raise", Vector3(3.0, 0.0, 3.0), 2.0, 1.4, true)
	var cells: Array = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]
	var preview: Dictionary = field.duplicate_field().flatten_footprint(cells)
	var done: Dictionary = field.flatten_footprint(cells)
	check(is_equal_approx(float(preview["delta_volume"]), float(done["delta_volume"])), "flatten preview matches commit")
	check(is_equal_approx(float(done["target"]), field.snap_height(float(done["target"]))), "flatten target is terrace-snapped")
	var xirang := XirangLib.new()
	xirang.configure({})
	var cost := xirang.quote_volume(maxf(float(done["delta_volume"]), 0.0), 36)
	var refund := xirang.quote_remove_volume(maxf(-float(done["delta_volume"]), 0.0))
	check(cost >= 0.0 and refund >= 0.0, "flatten quotes spend or refund by signed volume")


func _determinism() -> void:
	var a := _rect_field(5, 5, 21)
	var b := _rect_field(5, 5, 21)
	a.apply_brush("raise", Vector3(2.5, 0.0, 2.5), 1.4, 0.7, false)
	b.apply_brush("raise", Vector3(2.5, 0.0, 2.5), 1.4, 0.7, false)
	var same := a.heights == b.heights and a.mask == b.mask
	check(same, "same seed and stroke reproduce H and M")
	var pa := HeightfieldMesh.build_chunk(a, Vector2i(0, 0), "top")
	var pb := HeightfieldMesh.build_chunk(b, Vector2i(0, 0), "top")
	check(pa["vertices"] == pb["vertices"], "mesh vertices are deterministic")


func _winding() -> void:
	var field := _rect_field(4, 4, 2)
	var top := HeightfieldMesh.build_chunk(field, Vector2i(0, 0), "top")
	var tv: PackedVector3Array = top["vertices"]
	check(tv.size() >= 3, "flat top emits triangles")
	if tv.size() >= 3:
		var n: Vector3 = (tv[1] - tv[0]).cross(tv[2] - tv[0])
		check(n.y < 0.0, "top winding is clockwise from above (Godot front)")
	var full := HeightfieldMesh.build_chunk(field, Vector2i(0, 0), "full")
	var fv: PackedVector3Array = full["vertices"]
	var bottom_ok := false
	for i in range(0, fv.size() - 2, 3):
		if fv[i].y > -3.5:
			continue
		var bn: Vector3 = (fv[i + 1] - fv[i]).cross(fv[i + 2] - fv[i])
		bottom_ok = bn.y > 0.0
		break
	check(bottom_ok, "bottom winding is clockwise from below")


func _organic_mask() -> void:
	var field := _rect_field(8, 6, 4)
	var before := field.land_cell_count()
	field.stamp_rounded_blob()
	field.organicize_coast()
	check(field.land_cell_count() <= before, "organic coast never grows past the play rectangle")
	check(field.land_cell_count() >= 8, "blob stamp keeps a usable island")
	var payloads: Array = []
	var span := HeightfieldMesh.chunk_range(field)
	for z in span.y:
		for x in span.x:
			payloads.append(HeightfieldMesh.build_chunk(field, Vector2i(x, z), "full"))
	var closed := HeightfieldMesh.combine(payloads)
	check(HeightfieldMesh.odd_edge_ratio(closed) < 0.02, "organic rim stays a closed mesh")


func _starter_pebble() -> void:
	var cells: Array[Vector2i] = IslandGeometry.courtyard_yard_cells()
	var land: Dictionary = {}
	var min_c := Vector2i(999, 999)
	var max_c := Vector2i(-999, -999)
	for cell in cells:
		land[cell] = true
		min_c.x = mini(min_c.x, cell.x)
		min_c.y = mini(min_c.y, cell.y)
		max_c.x = maxi(max_c.x, cell.x)
		max_c.y = maxi(max_c.y, cell.y)
	var box := (max_c.x - min_c.x + 1) * (max_c.y - min_c.y + 1)
	check(cells.size() < box - 8, "starter yard is not a filled rectangle")
	for must in [Vector2i(0, -6), Vector2i(6, 0), Vector2i(-2, 3), Vector2i(-6, -2), Vector2i(0, -2), Vector2i(0, 3)]:
		check(land.has(must), "starter pebble keeps required cell %s" % must)
	var fall := HeightfieldMesh.build_waterfall(Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), -6.0, 1.2)
	check(int(fall.get("triangles", 0)) >= 20, "waterfall ribbon emits a curved sheet")


func _shaft() -> void:
	var field := _rect_field(8, 8, 3)
	field.punch_shaft(Vector3(4.0, 0.0, 4.0), 1.0)
	check(not field.sample_land(Vector3(4.0, 0.0, 4.0)), "punch_shaft opens a vertical hole")
	var payload := HeightfieldMesh.build_chunk(field, Vector2i(0, 0), "full")
	check(int(payload.get("triangles", 0)) > 20, "a punched shaft still has a mesh")
	check(HeightfieldMesh.odd_edge_ratio(payload) < 0.08, "shaft walls stay mostly closed (odd=%.4f)" % HeightfieldMesh.odd_edge_ratio(payload))
