extends RefCounted
## Pure entity occupancy; the world supplies terrain and fixed facility reservations.
const CATALOG := {
	"house": {"label":"小屋", "size":Vector2i(5,5), "offset":Vector2i(-3,-2)},
	"tree": {"label":"乔木", "size":Vector2i.ONE, "offset":Vector2i.ZERO},
	"rock": {"label":"山石", "size":Vector2i.ONE, "offset":Vector2i.ZERO},
	"bush": {"label":"灌木", "size":Vector2i.ONE, "offset":Vector2i.ZERO},
	"grass": {"label":"草丛", "size":Vector2i.ONE, "offset":Vector2i.ZERO}
}
const NOWHERE := Vector2i(9999,9999)
var objects: Array[Dictionary] = [{"id":0,"kind":"house","cell":Vector2i(0,-2)}]
var land: Dictionary={}
var water: Dictionary={}
var reserved: Dictionary={}
var last_id:=0
func configure(p_land: Dictionary,p_water: Dictionary,p_reserved: Dictionary) -> void:
	land=p_land.duplicate()
	water=p_water.duplicate()
	reserved=p_reserved.duplicate()
func footprint(kind: String,cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i]=[]
	if not CATALOG.has(kind):return out
	var info: Dictionary=CATALOG[kind]
	for x in info.size.x:
		for z in info.size.y:out.append(cell+info.offset+Vector2i(x,z))
	return out
func approach(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i]=[]
	for x in [-1,0]:
		for z in [3,4]:out.append(cell+Vector2i(x,z))
	return out
func find(id: int) -> Dictionary:
	for row in objects:
		if row.id==id:return row
	return {}
func at(cell: Vector2i) -> int:
	for row in objects:
		if cell in footprint(row.kind,row.cell):return row.id
	return -1
func evaluate(kind: String,cell: Vector2i,ignore_id: int=-1,player: Vector2i=NOWHERE) -> String:
	if not CATALOG.has(kind):return "unknown"
	var occupied:=footprint(kind,cell)
	var needed:=occupied.duplicate()
	if kind=="house":needed.append_array(approach(cell))
	for c in needed:
		if not land.has(c):return "no_land"
		if water.has(c):return "water"
		# The preserved demo starts with a logical spring/field under its door apron.
		# Only that exact original house location is grandfathered; new sites are strict.
		if reserved.has(c) and not (kind=="house" and cell==Vector2i(0,-2)):return "reserved"
		if c==player:return "player"
		for row in objects:
			if row.id==ignore_id:continue
			if c in footprint(row.kind,row.cell):return "overlap"
			if row.kind=="house" and c in approach(row.cell):return "entrance"
	return "ok"
func place(kind: String,cell: Vector2i,player: Vector2i=NOWHERE) -> String:
	if kind=="house":return "protected"
	if objects.size()>=128:return "object_cap"
	var result:=evaluate(kind,cell,-1,player)
	if result!="ok":return result
	last_id+=1
	objects.append({"id":last_id,"kind":kind,"cell":cell})
	return "ok"
func move(id: int,cell: Vector2i,player: Vector2i=NOWHERE) -> String:
	var row:=find(id)
	if row.is_empty():return "missing"
	var result:=evaluate(row.kind,cell,id,player)
	if result=="ok":row.cell=cell
	return result
func remove(id: int) -> String:
	if id==0:return "protected"
	var row:=find(id)
	if row.is_empty():return "missing"
	objects.erase(row)
	return "ok"
func to_dict() -> Dictionary:
	var rows: Array=[]
	for row in objects:rows.append({"id":row.id,"kind":row.kind,"cell":[row.cell.x,row.cell.y]})
	return {"version":2,"objects":rows}
static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and absf(float(value))<10000
static func valid_cell(value: Variant) -> bool:
	return value is Array and value.size()==2 and integer(value[0]) and integer(value[1])
func restore(data: Variant) -> String:
	if not data is Dictionary or not integer(data.get("version")) or int(data.version) not in [1,2] or not data.get("objects") is Array:return "bad_save"
	if data.version==1:
		data=_split_legacy_groups(data)
		if data.is_empty():return "bad_save"
	if data.objects.is_empty() or data.objects.size()>128:return "bad_save"
	var candidate:=get_script().new() as RefCounted
	candidate.configure(land,water,reserved)
	candidate.objects.clear()
	var ids: Dictionary={}
	for row in data.objects:
		if not row is Dictionary or not integer(row.get("id")) or not row.get("kind") is String or not valid_cell(row.get("cell")):return "bad_save"
		var id:=int(row.id)
		if id<0 or ids.has(id) or (id==0)!=(row.kind=="house"):return "bad_save"
		var cell:=Vector2i(int(row.cell[0]),int(row.cell[1]))
		if candidate.evaluate(row.kind,cell)!="ok":return "bad_save"
		candidate.objects.append({"id":id,"kind":row.kind,"cell":cell})
		candidate.last_id=maxi(candidate.last_id,id)
		ids[id]=true
	if not ids.has(0):return "bad_save"
	objects=candidate.objects
	last_id=candidate.last_id
	return "ok"

static func _split_legacy_groups(data: Dictionary) -> Dictionary:
	# Migrate in memory. Never overwrite the user's original file during loading.
	var result: Dictionary=data.duplicate(true)
	var next_id:=0
	var used: Dictionary={}
	for row in result.objects:
		if not row is Dictionary or not integer(row.get("id")) or not valid_cell(row.get("cell")):return {}
		if used.has(int(row.id)):return {}
		used[int(row.id)]=true
		next_id=maxi(next_id,int(row.id))
	var rows: Array=[]
	for row in result.objects:
		if row.get("kind")!="grove":
			rows.append(row)
			continue
		var origin:=Vector2i(int(row.cell[0]),int(row.cell[1]))
		for item in [["tree",Vector2i.ZERO],["rock",Vector2i(1,0)],["bush",Vector2i(0,1)],["grass",Vector2i.ONE]]:
			var id: int=int(row.id)
			if item[0]!="tree":
				next_id+=1
				id=next_id
			var cell: Vector2i=origin+item[1]
			rows.append({"id":id,"kind":item[0],"cell":[cell.x,cell.y]})
	result.version=2
	result.objects=rows
	return result
