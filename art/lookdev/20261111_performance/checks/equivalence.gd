extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Flow=preload("res://scripts/terrain_editor/water_flow.gd")
const Before=preload("res://art/lookdev/20261111_performance/checks/water_renderer_before.gd")
const After=preload("res://scripts/terrain_editor/water_renderer.gd")
var failures: Array[String]=[]
var checks: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func run() -> void:
	for layout: Array in [[7301,0],[2104,0],[4242,1],[913,2]]:
		var data: RefCounted=Data.new();data.seed=layout[0];data.make_preset(layout[1])
		var solver: RefCounted=Flow.new();solver.configure(data)
		var cache: Array[Dictionary]=[]
		for step: int in 20:
			if step==8:
				data.cells.erase(Vector2i.ZERO);data.cells[Vector2i(1,1)]={"height":-1.0,"water":-1}
				solver.sync(data)
			solver.step(.1 if step<15 else 1.0)
			var before: RefCounted=Before.FlowField.new();before.build_live(data,solver)
			var after: RefCounted=After.FlowField.new();after.shape_cache=cache;after.build_live(data,solver);cache=after.shape_cache
			for key: String in ["water","waterfall","bank"]:
				for attr: String in ["vertices","normals","colors","uv","uv2"]:
					check(var_to_bytes(before.surfaces[key].get(attr))==var_to_bytes(after.surfaces[key].get(attr)),str(layout)+" step "+str(step)+" "+key+" "+attr)
			check(before.fall_veils==after.fall_veils and before.splash_points==after.splash_points,"falls metadata "+str(layout)+" "+str(step))
			var a: Dictionary=Before._build_images(data,before)
			var b: Dictionary=After._build_images(data,after)
			check(a.live.get_data()==b.live.get_data() and a.shore.get_data()==b.shore.get_data(),"field pixels "+str(layout)+" "+str(step))
	FileAccess.open("res://art/lookdev/20261111_performance/checks/equivalence.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("EQUIVALENCE ",checks," checks; ",failures.size()," failures");quit(1 if not failures.is_empty() else 0)
