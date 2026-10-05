extends SceneTree
# Catches lost edits, repeated stroke application, wrong neighbor joining and unsafe load.
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func stroke(d, tool: String, center := Vector2(0.5, 0.5), height := 0.0, water := 0, radius := 0.49, snap := true) -> void:
	d.begin_stroke()
	d.apply_brush(center, radius, tool, snap, height, water)
	d.end_stroke()
func _initialize() -> void:
	var path := "res://scripts/terrain_editor/terrain_data.gd"
	if not ResourceLoader.exists(path):
		check(false, "TerrainData implementation is missing")
		quit(1)
		return
	var script = load(path)
	var d = script.new()
	stroke(d, "expand")
	check(d.cells.size() == 1 and d.cells[Vector2i.ZERO].height == 0.0, "expand creates selected-height land")
	d.begin_stroke()
	d.apply_brush(Vector2(0.5, 0.5), 0.49, "raise", true, 0.0, 0)
	d.apply_brush(Vector2(0.5, 0.5), 0.49, "raise", true, 0.0, 0)
	d.end_stroke()
	check(d.cells[Vector2i.ZERO].height == 0.5, "stroke cannot raise a cell twice")
	stroke(d, "lower")
	check(d.cells[Vector2i.ZERO].height == 0.0, "lower reverses a single raise")
	stroke(d, "water", Vector2(0.5,0.5), 0.0, 2)
	check(d.cells[Vector2i.ZERO].water == 2, "water paints an existing lower floor")
	stroke(d, "contract")
	check(d.cells.is_empty(), "contract removes land and water")
	check(d.undo() and d.cells[Vector2i.ZERO].water == 2, "undo restores contracted water")
	check(d.redo() and d.cells.is_empty(), "redo contracts again")
	stroke(d, "expand", Vector2(0.5,0.5), 12.0)
	stroke(d, "raise")
	check(d.cells[Vector2i.ZERO].height == 12.0, "raise clamps upper bound")
	stroke(d, "contract")
	stroke(d, "expand", Vector2(0.5,0.5), -4.0)
	stroke(d, "lower")
	check(d.cells[Vector2i.ZERO].height == -4.0, "lower clamps bottom bound")
	for level in 8:
		var w = script.new()
		stroke(w, "expand", Vector2(0.5,0.5), level*0.5-0.5)
		stroke(w, "water", Vector2(0.5,0.5), 0.0, level)
		var copy = script.new()
		check(copy.deserialize(JSON.parse_string(JSON.stringify(w.serialize()))), "JSON layout roundtrip succeeds")
		check(copy.cells[Vector2i.ZERO].water == level, "water elevation %d persists" % level)
		stroke(w, "raise")
		check(w.cells[Vector2i.ZERO].water == -1, "raising floor to water removes it")
	var a = script.new()
	var b = script.new()
	stroke(a,"expand",Vector2(1.01,0.5),0,0,0.6,true)
	stroke(b,"expand",Vector2(1.01,0.5),0,0,0.6,false)
	check(a.cells.size()==1 and b.cells.size()==2, "snap toggle changes brush coverage at boundary")
	d.dirty_chunks.clear()
	stroke(d,"expand",Vector2(-0.5,-0.5))
	check(d.dirty_chunks.has(Vector2i(-1,-1)) and d.dirty_chunks.has(Vector2i.ZERO) and d.dirty_chunks.has(Vector2i(-1,0)) and d.dirty_chunks.has(Vector2i(0,-1)), "negative chunk corner invalidates four chunks")
	var offsets := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1)]
	var shapes := {}
	for mask in 256:
		var m = script.new()
		m.cells[Vector2i.ZERO] = {"height":-0.5,"water":0}
		for bit in 8:
			if mask & (1 << bit): m.cells[offsets[bit]] = {"height":-0.5,"water":0}
		var normalized: int = m.water_mask(Vector2i.ZERO)
		shapes[normalized] = true
		check((normalized & 16)==0 or (normalized & 3)==3,"diagonal NE requires both adjacent sides")
	check(shapes.size()==47, "all input configurations support exactly 47 states")
	var m = script.new()
	m.cells[Vector2i.ZERO]={"height":-0.5,"water":0}
	m.cells[Vector2i.RIGHT]={"height":-0.5,"water":1}
	check(m.water_mask(Vector2i.ZERO)==0,"different water elevations do not join")
	var before: Dictionary=d.serialize()
	check(not d.deserialize({"version":1,"seed":2,"cells":[{"x":0,"z":0,"height":INF,"water":-1}]}),"nonfinite heights are rejected")
	check(d.serialize()==before,"invalid load leaves current layout unchanged")
	check(not d.deserialize({"version":1,"seed":2,"cells":[{"x":1025,"z":0,"height":0,"water":-1}]}),"unbounded coordinates rejected")
	check(not d.deserialize({"version":1,"seed":2,"cells":[{"x":0,"z":0,"height":0,"water":8}]}),"ninth water level rejected")
	var huge: Array=[]
	huge.resize(65537)
	check(not d.deserialize({"version":1,"seed":2,"cells":huge}),"oversized load rejected")
	for kind in 3:
		m.make_preset(kind)
		check(m.cells.size()>50,"preset %d contains editable land" % kind)
	print("TERRAIN EDITOR DATA: %d/%d passed" % [checks-failures, checks])
	quit(1 if failures else 0)
