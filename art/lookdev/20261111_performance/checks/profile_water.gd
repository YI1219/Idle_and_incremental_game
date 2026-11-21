extends SceneTree
const Water=preload("res://scripts/terrain_editor/water_renderer.gd")
class Profiled:
	extends Water.FlowField
	var costs: Dictionary={}
	func _cap(surface,loops:Array,height:float,tint:Color,extra_rows:PackedFloat32Array=PackedFloat32Array(),force_sweep:bool=false)->void:
		var start:int=Time.get_ticks_usec();super._cap(surface,loops,height,tint,extra_rows,force_sweep);costs.cap=float(costs.get("cap",0.0))+(Time.get_ticks_usec()-start)/1000.0
	func _falls(loop:PackedVector2Array,water_y:float)->void:
		var start:int=Time.get_ticks_usec();super._falls(loop,water_y);costs.falls=float(costs.get("falls",0.0))+(Time.get_ticks_usec()-start)/1000.0
	func _flow_edges(loop:PackedVector2Array,water_y:float)->Array:
		var start:int=Time.get_ticks_usec();var v:Array=super._flow_edges(loop,water_y);costs.edges=float(costs.get("edges",0.0))+(Time.get_ticks_usec()-start)/1000.0;return v
	func _smooth_normals(surface)->void:
		var start:int=Time.get_ticks_usec();super._smooth_normals(surface);costs.normals=float(costs.get("normals",0.0))+(Time.get_ticks_usec()-start)/1000.0
func _initialize()->void:
	var data:RefCounted=load("res://scripts/terrain_editor/terrain_data.gd").new();data.make_preset(1)
	var flow:RefCounted=load("res://scripts/terrain_editor/water_flow.gd").new();flow.configure(data)
	var cache:Array[Dictionary]=[]
	for n:int in 95:flow.step(.1)
	for i:int in 4:
		flow.step(.1)
		var field:RefCounted=Profiled.new();field.shape_cache=cache
		var start:int=Time.get_ticks_usec();field.build_live(data,flow);cache=field.shape_cache
		print("PROFILE ",i," total ",(Time.get_ticks_usec()-start)/1000.0," ",field.costs," basins ",flow.basins.size()," capverts ",field.surfaces.water.vertices.size())
	quit()
