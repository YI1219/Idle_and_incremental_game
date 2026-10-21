class_name TerrainData
extends RefCounted
## Authoritative sparse terrain. Water stores one of eight absolute elevations.
const Blob := preload("res://scripts/world/blob47.gd")
const CHUNK_SIZE := 8
const MAX_CELLS := 65536
const HISTORY_LIMIT := 64
var cells: Dictionary[Vector2i, Dictionary] = {}
var seed: int = 7301
const RockSculpt=preload("res://scripts/terrain_editor/rock_sculpt.gd")
var rocks:=RockSculpt.new()
var sculpt_base_enabled:=false
var sculpt_base_profile:String='local'
var _rock_before:Dictionary={}
var dirty_chunks: Dictionary = {}
var revision := 0
var _visited: Dictionary = {}
var _before: Dictionary = {}
var _active := false
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []

static func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x)/CHUNK_SIZE), floori(float(cell.y)/CHUNK_SIZE))

func invalidate(cell: Vector2i,land_change:bool=true) -> void:
	if land_change:rocks.base=null
	for z in range(-1,2):
		for x in range(-1,2):
			dirty_chunks[chunk_of(cell + Vector2i(x,z))] = true
	revision += 1

func begin_stroke() -> void:
	if _active: end_stroke()
	_active = true
	_visited.clear()
	_before.clear()
	_rock_before.clear()

func apply_brush(center: Vector2, radius: float, tool: String, snap: bool, height: float, water: int) -> int:
	if not center.is_finite() or not is_finite(radius) or not is_finite(height): return 0
	if tool not in ["raise","lower","expand","contract","water","dry"]: return 0
	if tool == "water" and (water < 0 or water > 7): return 0
	if not _active: begin_stroke()
	if snap: center = center.floor() + Vector2(0.5,0.5)
	radius = clampf(radius, 0.1, 16.0)
	height = clampf(roundf(height*2.0)*0.5,-4.0,12.0)
	if sculpt_base_enabled and tool in ["expand","raise","lower"]:
		var lo:=center-Vector2.ONE*(radius+1.0) if tool=="expand" else Vector2(INF,INF)
		var hi:=center+Vector2.ONE*(radius+1.0) if tool=="expand" else Vector2(-INF,-INF)
		if not preload("res://scripts/terrain_editor/rock_terrain_base.gd").fits(cells,lo,hi,-.5 if tool=="lower" else 0.0,.5 if tool=="raise" else 0.0,height if tool=="expand" else NAN):return 0
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

func ensure_sculpt_base()->bool:
	if not sculpt_base_enabled:return true
	if rocks.base==null:
		var candidate=preload("res://scripts/terrain_editor/rock_terrain_base.gd").new()
		if not candidate.configure(cells,sculpt_base_profile):return false
		rocks.base=candidate
		rocks._height_bounds_dirty=true
	return true
func set_sculpt_base(enabled:bool)->bool:
	end_stroke()
	if enabled==sculpt_base_enabled:return true
	# Conversion is an authoring mode choice, never an implicit brush action.
	# Existing separate trial volumes must be saved/reset before conversion.
	if not rocks.samples.is_empty():return false
	if enabled and not preload("res://scripts/terrain_editor/rock_terrain_base.gd").fits(cells):return false
	sculpt_base_enabled=enabled;rocks.base=null
	ensure_sculpt_base()
	for cell:Vector2i in cells:invalidate(cell,false)
	revision+=1
	return true

func apply_rock_brush(center:Vector3,radius:float,tool:String,normal:=Vector3.UP)->int:
	if not _active:begin_stroke()
	if not ensure_sculpt_base():return 0
	var before:Dictionary=rocks.brush(center,radius,tool,normal)
	for key:Vector3i in before:
		if not _rock_before.has(key):_rock_before[key]=before[key]
	_invalidate_rocks(before.keys())
	return before.size()

func _invalidate_rocks(keys:Array)->void:
	var changed:Dictionary={}
	for key:Vector3i in keys:
		var p:=Vector3(key)*RockSculpt.STEP
		changed[Vector2i(floori(p.x),floori(p.z))]=true
	for cell:Vector2i in changed:invalidate(cell,false)

func end_stroke() -> void:
	if not _active:return
	if not _before.is_empty() or not _rock_before.is_empty():
		var after:Dictionary={};var rock_after:Dictionary={}
		for cell in _before:
			var value:Variant=cells.get(cell)
			after[cell]=value.duplicate() if value!=null else null
		for key:Vector3i in _rock_before:rock_after[key]=rocks.samples.get(key)
		_undo.append({"before":_before.duplicate(true),"after":after,"rock_before":_rock_before.duplicate(),"rock_after":rock_after,"sculpt_base":sculpt_base_enabled})
		if _undo.size()>HISTORY_LIMIT:_undo.pop_front()
		_redo.clear()
	_active=false;_before.clear();_visited.clear();_rock_before.clear()

func _restore(values:Dictionary,rock_values:Dictionary={},rock_mode:bool=false) -> bool:
	# Sparse rock overrides belong to the base against which they were made.
	# Preserve an incompatible entry for replay after switching back.
	if not rock_values.is_empty() and rock_mode!=sculpt_base_enabled:return false
	if sculpt_base_enabled and not values.is_empty():
		var candidate:=cells.duplicate()
		for cell:Vector2i in values:
			if values[cell]==null:candidate.erase(cell)
			else:candidate[cell]=values[cell]
		if not preload("res://scripts/terrain_editor/rock_terrain_base.gd").fits(candidate):return false
	for cell:Vector2i in values:
		if values[cell]==null:cells.erase(cell)
		else:cells[cell]=values[cell].duplicate()
		invalidate(cell)
	rocks.restore(rock_values)
	_invalidate_rocks(rock_values.keys())
	return true

func undo() -> bool:
	end_stroke()
	if _undo.is_empty():return false
	var entry:Dictionary=_undo.back()
	if not _restore(entry.before,entry.get("rock_before",{}),entry.get("sculpt_base",false)):return false
	_undo.pop_back();_redo.append(entry)
	return true

func redo() -> bool:
	end_stroke()
	if _redo.is_empty():return false
	var entry:Dictionary=_redo.back()
	if not _restore(entry.after,entry.get("rock_after",{}),entry.get("sculpt_base",false)):return false
	_redo.pop_back();_undo.append(entry)
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
	var payload:Dictionary={"version":1,"seed":seed,"cells":records}
	if not rocks.samples.is_empty() or sculpt_base_enabled:
		payload.version=(4 if sculpt_base_profile=='local' else 3) if sculpt_base_enabled else 2;payload.rocks=rocks.records()
		if sculpt_base_enabled:
			payload.sculpt_base=true
			if sculpt_base_profile!='legacy':payload.sculpt_profile=sculpt_base_profile
	return payload

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func deserialize(payload: Dictionary) -> bool:
	# JSON numbers arrive as floats; Array membership compares their types.
	if (payload.get("version")!=1 and payload.get("version")!=2 and payload.get("version")!=3 and payload.get("version")!=4) or not _number(payload.get("seed")): return false
	var candidate_rocks=preload("res://scripts/terrain_editor/rock_sculpt.gd").new()
	if payload.version>=2 and not candidate_rocks.load_records(payload.get("rocks")):return false
	if payload.version>=3 and (not payload.get("sculpt_base") is bool or payload.get("sculpt_base")!=true):return false
	var candidate_profile:Variant=payload.get('sculpt_profile','legacy') if payload.version>=3 else 'local'
	if not candidate_profile is String or candidate_profile not in ['legacy','local']:return false
	if payload.version==4 and candidate_profile!='local':return false
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
	if payload.version>=3 and not preload("res://scripts/terrain_editor/rock_terrain_base.gd").fits(candidate):return false
	end_stroke()
	for cell: Vector2i in cells: invalidate(cell)
	_invalidate_rocks(rocks.samples.keys())
	rocks=candidate_rocks
	sculpt_base_enabled=payload.version>=3
	sculpt_base_profile=candidate_profile
	_invalidate_rocks(rocks.samples.keys())
	cells = candidate
	seed = int(payload.seed)
	for cell: Vector2i in cells: invalidate(cell)
	_undo.clear()
	_redo.clear()
	return true

func make_preset(kind: int) -> void:
	end_stroke()
	for cell: Vector2i in cells: invalidate(cell)
	_invalidate_rocks(rocks.samples.keys())
	rocks.samples.clear()
	rocks.base=null;sculpt_base_enabled=false;sculpt_base_profile='local'
	cells.clear()
	_undo.clear()
	_redo.clear()
	var width := 21
	for z in range(-14,15):
		for x in range(-width,width+1):
			var at:=Vector2(x+.5,z+.5)
			var upper_shape:=((at-Vector2(-7,-3))/Vector2(14,9)).length()
			var lower_shape:=((at-Vector2(7,3))/Vector2(11,8)).length()
			if kind==1:
				upper_shape=((at-Vector2(-9,-2))/Vector2(12,7)).length()
				lower_shape=((at-Vector2(9,2))/Vector2(12,7)).length()
			var ripple:=.025*sin(at.x*.74+at.y*.81)+.018*sin(at.x*1.3-at.y*.6)
			var terrace_line:=1.5 if kind==1 else 3.0
			var filled:=false
			if kind==0 and minf(upper_shape,lower_shape)>1.0+ripple:
				# The homestead's two lobes share one elongated footprint. A
				# smooth union plus a front bridge closes the old waist notches
				# without moving either terrace, lake, or the connecting fall.
				var bridge:=((at-Vector2(-3.0,5.5))/Vector2(6.5,3.4)).length()
				filled=_smooth_min(_smooth_min(upper_shape,lower_shape,.5),bridge,.5)<=1.0+ripple
				if not filled:continue
			elif minf(upper_shape,lower_shape)>1.0+ripple:continue
			if kind==2 and (at-Vector2(-4,0)).length()<2.8:continue
			var upper:=upper_shape<1.0+ripple and (at.y < -at.x*.6+terrace_line or lower_shape>1.0)
			if filled:upper=upper_shape<lower_shape or (at.y>4.0 and at.x<-1.5)
			var height:=3.5 if upper else 1.5
			var water:=-1
			var pond_center:=(Vector2(-6,0) if kind==1 else Vector2(-3,0)) if upper else Vector2(7,3)
			var pond_shape:=((at-pond_center)/Vector2(5.5 if upper or kind==1 else 6.5,3.3 if upper else 3.6)).length()
			if kind!=2 and pond_shape<1.0 and (not upper or at.y < -at.x*.6+terrace_line-1.25):
				height-=.5
				water=7 if upper else 3
			# Wide outlets become continuous ribbons, then adaptive waterfalls at the drops.
			if kind!=2 and at.x>-6 and at.x<7 and absf(at.y-1.0)<1.05:
				height=3.0 if upper else 1.0
				water=7 if upper else 3
			if kind!=2 and absf(at.x-10.5)<1.6 and at.y>3:
				height=1.0
				water=3
			var cell:=Vector2i(x,z)
			cells[cell]={"height":height,"water":water}
			invalidate(cell)

static func _smooth_min(a:float,b:float,k:float)->float:
	var h:=clampf(.5+.5*(b-a)/k,0.0,1.0)
	return lerpf(b,a,h)-k*h*(1.0-h)
