extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration=preload("res://scripts/terrain_editor/terrain_decoration.gd")
var checks:int=0
var failures:int=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func columns(decoration:RefCounted)->Dictionary:
	var result:Dictionary={}
	for column:Dictionary in decoration._columns:
		result[Vector3(column.edge.x,column.pose.origin.y,column.edge.y)]=[column.kind,column.pose]
	return result
func verify_seed(seed_value:int)->void:
	var data:=Data.new()
	data.seed=seed_value
	data.make_preset(0)
	var field:=Contours.new()
	field.refresh(data)
	var decoration:=Decoration.new()
	decoration.load_assets()
	decoration._column_layout(field,data.seed)
	var before:=columns(decoration)
	var at:=Vector2(-12,-9)
	data.begin_stroke()
	data.apply_brush(at,1.6,"contract",false,1.5,3)
	data.end_stroke()
	field.refresh(data)
	var fresh:=Contours.new()
	fresh.refresh(data)
	check(field.surfaces.cliff.vertices==fresh.surfaces.cliff.vertices,"warm geology cache equals a fresh build after editing")
	decoration._column_layout(field,data.seed)
	var after:=columns(decoration)
	var distant:int=0
	var moved:int=0
	for anchor:Vector3 in before:
		if Vector2(anchor.x,anchor.z).distance_to(at)<14.0:continue
		distant+=1
		if not after.has(anchor) or after[anchor]!=before[anchor]:moved+=1
	check(distant>=3,"fixture includes several distant existing cliff blocks")
	check(moved==0,"a local contraction keeps distant existing cliff forms and poses")
	data.undo()
	field.refresh(data)
	decoration._column_layout(field,data.seed)
	check(columns(decoration)==before,"undo restores the original cliff layout")
	field.seeded_geology=true
	field.mass_feature_scale=Vector3(1.1,1.7,1.2)
	field.refresh(data)
	fresh.seeded_geology=true
	fresh.mass_feature_scale=field.mass_feature_scale
	fresh.refresh(data)
	check(field.surfaces.cliff.vertices==fresh.surfaces.cliff.vertices,"changing geology settings invalidates old field cache")

func _initialize()->void:
	for seed_value:int in [7301,2104,4242]:verify_seed(seed_value)
	print("TERRAIN LOCALITY: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
