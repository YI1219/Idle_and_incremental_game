extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String):
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func _initialize():call_deferred("run")
func run():
	if not ResourceLoader.exists("res://scripts/build/layout.gd"):
		check(false,"Sandbox entity layout is implemented")
		quit(1)
		return
	var layout=load("res://scripts/build/layout.gd").new()
	var land: Dictionary={}
	for x in range(-10,11):
		for z in range(-10,11):land[Vector2i(x,z)]=true
	layout.configure(land,{Vector2i(5,5):true},{Vector2i(6,6):true})
	check(layout.place("tree",Vector2i(3,3))=="ok","Place supported tree")
	var id: int=layout.last_id
	check(layout.place("rock",Vector2i(3,3))=="overlap","Reject occupied footprint")
	check(layout.place("rock",Vector2i(5,5))=="water","Reject water")
	check(layout.place("rock",Vector2i(30,30))=="no_land","Reject void")
	check(layout.place("rock",Vector2i(6,6))=="reserved","Keep fixed facilities")
	check(layout.place("bush",Vector2i(0,1))=="entrance","Keep house approach clear")
	check(layout.place("rock",Vector2i(-9,-9),Vector2i(-9,-9))=="player","Do not place on player")
	check(layout.move(id,Vector2i(5,5))=="water","Reject invalid move")
	check(layout.at(Vector2i(3,3))==id,"Failed move retains original")
	check(layout.move(id,Vector2i(4,3))=="ok","Valid move commits")
	check(layout.at(Vector2i(3,3))==-1 and layout.at(Vector2i(4,3))==id,"Move releases old occupancy")
	check(layout.remove(0)=="protected","Unique house cannot be deleted")
	var data: Dictionary=layout.to_dict()
	var other=load("res://scripts/build/layout.gd").new()
	other.configure(land,{Vector2i(5,5):true},{Vector2i(6,6):true})
	check(other.restore(JSON.parse_string(JSON.stringify(data)))=="ok","JSON roundtrip")
	check(other.at(Vector2i(4,3))==id,"IDs and positions restored")
	var bad: Dictionary=data.duplicate(true)
	bad.objects.append(bad.objects[-1].duplicate(true))
	check(other.restore(bad)!="ok","Duplicate IDs rejected")
	check(other.at(Vector2i(4,3))==id,"Invalid restore is atomic")
	check(layout.remove(id)=="ok" and layout.at(Vector2i(4,3))==-1,"Remove releases occupied cells")
	print("SANDBOX LAYOUT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
