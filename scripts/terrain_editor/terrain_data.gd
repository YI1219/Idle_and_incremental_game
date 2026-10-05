class_name TerrainData
extends RefCounted
## Authoritative sparse terrain. Water stores one of eight absolute elevations.
const Blob := preload("res://scripts/world/blob47.gd")
const CHUNK_SIZE := 8
const MAX_CELLS := 65536
const HISTORY_LIMIT := 64
var cells: Dictionary[Vector2i, Dictionary] = {}
var seed: int = 7301
var dirty_chunks: Dictionary = {}
var revision := 0
var _visited: Dictionary = {}
var _before: Dictionary = {}
var _active := false
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []

static func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x)/CHUNK_SIZE), floori(float(cell.y)/CHUNK_SIZE))

func invalidate(cell: Vector2i) -> void:
	for z in range(-1,2):
		for x in range(-1,2):
			dirty_chunks[chunk_of(cell + Vector2i(x,z))] = true
	revision += 1

func begin_stroke() -> void:
	if _active: end_stroke()
	_active = true
	_visited.clear()
	_before.clear()

func apply_brush(center: Vector2, radius: float, tool: String, snap: bool, height: float, water: int) -> int:
	if not center.is_finite() or not is_finite(radius) or not is_finite(height): return 0
	if tool not in ["raise","lower","expand","contract","water","dry"]: return 0
	if tool == "water" and (water < 0 or water > 7): return 0
	if not _active: begin_stroke()
	if snap: center = center.floor() + Vector2(0.5,0.5)
	radius = clampf(radius, 0.1, 16.0)
	height = clampf(roundf(height*2.0)*0.5,-4.0,12.0)
	var changed := 0
	for z in range(floori(center.y-radius), ceili(center.y+radius)):
		for x in range(floori(center.x-radius), ceili(center.x+radius)):
			var cell := Vector2i(x,z)
			if absi(x)>1024 or absi(z)>1024 or _visited.has(cell): continue
			if (Vector2(cell)+Vector2(0.5,0.5)).distance_squared_to(center)>radius*radius: continue
			_visited[cell] = true
			var old: Variant = cells.get(cell)
			var next: Variant = old.duplicate() if old != null else null
			match tool:
				"expand":
					if old == null and cells.size()<MAX_CELLS: next = {"height":height,"water":-1}
				"contract": next = null
				"raise", "lower":
					if next != null:
						next.height = clampf(next.height + (0.5 if tool=="raise" else -0.5),-4.0,12.0)
						if next.water>=0 and next.height>=next.water*0.5: next.water = -1
				"water":
					if next != null and next.height<water*0.5: next.water = water
				"dry":
					if next != null: next.water = -1
			if old == next: continue
			_before[cell] = old.duplicate() if old != null else null
			if next == null: cells.erase(cell)
			else: cells[cell] = next
			invalidate(cell)
			changed += 1
	return changed

func end_stroke() -> void:
	if not _active: return
	if not _before.is_empty():
		var after := {}
		for cell in _before:
			var value: Variant=cells.get(cell)
			after[cell]=value.duplicate() if value!=null else null
		_undo.append({"before":_before.duplicate(true),"after":after})
		if _undo.size()>HISTORY_LIMIT: _undo.pop_front()
		_redo.clear()
	_active = false
	_before.clear()
	_visited.clear()

func _restore(values: Dictionary) -> void:
	for cell: Vector2i in values:
		if values[cell]==null: cells.erase(cell)
		else: cells[cell]=values[cell].duplicate()
		invalidate(cell)

func undo() -> bool:
	end_stroke()
	if _undo.is_empty(): return false
	var entry: Dictionary = _undo.pop_back()
	_restore(entry.before)
	_redo.append(entry)
	return true

func redo() -> bool:
	end_stroke()
	if _redo.is_empty(): return false
	var entry: Dictionary = _redo.pop_back()
	_restore(entry.after)
	_undo.append(entry)
	return true

func water_mask(cell: Vector2i) -> int:
	if not cells.has(cell) or cells[cell].water<0: return 0
	var mask := 0
	for bit: int in Blob.OFFSETS:
		var other: Vector2i = cell+Blob.OFFSETS[bit]
		if cells.has(other) and cells[other].water==cells[cell].water: mask |= bit
	return Blob.normalize(mask)

func serialize() -> Dictionary:
	var records: Array=[]
	# Stable ordering makes evidence and save comparisons useful.
	var keys := cells.keys()
	keys.sort_custom(func(a: Vector2i,b: Vector2i): return a.y<b.y or (a.y==b.y and a.x<b.x))
	for cell: Vector2i in keys:
		records.append({"x":cell.x,"z":cell.y,"height":cells[cell].height,"water":cells[cell].water})
	return {"version":1,"seed":seed,"cells":records}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func deserialize(payload: Dictionary) -> bool:
	if payload.get("version")!=1 or not _number(payload.get("seed")): return false
	if float(payload.seed)!=floorf(float(payload.seed)) or absf(float(payload.seed))>2147483647: return false
	var records: Variant=payload.get("cells")
	if not records is Array or records.size()>MAX_CELLS: return false
	var candidate: Dictionary[Vector2i,Dictionary]={}
	for record: Variant in records:
		if not record is Dictionary: return false
		for key in ["x","z","height","water"]:
			if not _number(record.get(key)): return false
		if absf(record.x)>1024 or absf(record.z)>1024: return false
		if float(record.x)!=floorf(record.x) or float(record.z)!=floorf(record.z): return false
		if record.height < -4 or record.height > 12 or not is_equal_approx(record.height*2.0,roundf(record.height*2.0)): return false
		if record.water < -1 or record.water>7 or float(record.water)!=floorf(record.water): return false
		if record.water>=0 and record.height>=record.water*0.5: return false
		var cell := Vector2i(int(record.x),int(record.z))
		if candidate.has(cell): return false
		candidate[cell]={"height":float(record.height),"water":int(record.water)}
	end_stroke()
	for cell: Vector2i in cells: invalidate(cell)
	cells = candidate
	seed = int(payload.seed)
	for cell: Vector2i in cells: invalidate(cell)
	_undo.clear()
	_redo.clear()
	return true

func make_preset(kind: int) -> void:
	end_stroke()
	for cell: Vector2i in cells: invalidate(cell)
	cells.clear()
	_undo.clear()
	_redo.clear()
	var width := 21 if kind==1 else 16
	var depth := 8 if kind==1 else 12
	for z in range(-depth,depth+1):
		for x in range(-width,width+1):
			var contour := pow(float(x)/width,2)+pow(float(z)/depth,2)
			if contour > 1.0+0.065*sin(x*0.9+z*0.7): continue
			if kind==2 and Vector2(x+4,z).length()<3.0: continue
			var upper := x < -2
			var height := 3.5 if upper else 1.5
			var water := -1
			var pond_center := Vector2(-8,-2) if upper else Vector2(5,2)
			var p := (Vector2(x,z)-pond_center)/Vector2(4.7,3.4)
			if kind!=2 and p.length()<1.0:
				height-=0.5
				water=7 if upper else 3
			# Outlets connect terraces and lead to the lower island boundary.
			if kind!=2 and z==0 and x>=-8 and x<=5:
				height=3.0 if upper else 1.0
				water=7 if upper else 3
			if kind!=2 and x==7 and z>=2:
				height=1.0
				water=3
			var cell := Vector2i(x,z)
			cells[cell]={"height":height,"water":water}
			invalidate(cell)
