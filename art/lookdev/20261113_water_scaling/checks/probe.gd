extends SceneTree
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Renderer = preload("res://scripts/terrain_editor/terrain_renderer.gd")
const OldFlow = preload("res://art/lookdev/20261113_water_scaling/checks/source_before/water_flow.gd")
const NewFlow = preload("res://scripts/terrain_editor/water_flow.gd")
const OldWater = preload("res://art/lookdev/20261113_water_scaling/checks/water_renderer_reference.gd")
const NewWater = preload("res://scripts/terrain_editor/water_renderer.gd")
var rows: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func fixture(kind: String, factor: int) -> RefCounted:
 var data: RefCounted = Data.new()
 if kind == "flowing": data.make_preset(0)
 else:
  for z: int in range(-1,2):
   for x: int in range(-1,3): data.cells[Vector2i(x,z)]={"height":10.0,"water":-1}
  data.cells[Vector2i.ZERO]={"height":0.0,"water":2}
  data.cells[Vector2i.RIGHT]={"height":0.0,"water":2}
  for z: int in 16:
   for x: int in 16: data.cells[Vector2i(24+x,24+z)]={"height":8.0,"water":-1}
 var extra: int = data.cells.size() * (factor-1)
 var width: int = maxi(1,ceili(sqrt(float(extra))))
 for i: int in extra:
  data.cells[Vector2i(64+i%width,-16+i/width)]={"height":8.0,"water":-1}
 return data
func run() -> void:
 for kind: String in ["flowing","stable"]:
  for factor: int in [1,4,16]:
   for variant: String in ["before","after","after","before"]:
    var data: RefCounted=fixture(kind,factor)
    var flow: RefCounted=OldFlow.new() if variant=="before" else NewFlow.new()
    flow.configure(data)
    var start: int=Time.get_ticks_usec()
    for step: int in 100: flow.step(.1)
    rows.append({"mode":"solver","kind":kind,"factor":factor,"variant":variant,"cells":data.cells.size(),"wet":flow.depths.size(),"total_ms":(Time.get_ticks_usec()-start)/1000.0,"volume":flow.total_volume(),"discharged":flow.discharged_volume})
    var terrain: Node3D=Renderer.new(); root.add_child(terrain); terrain.configure(Data.new())
    var water: Node3D=OldWater.new() if variant=="before" else NewWater.new()
    terrain.add_child(water); water.configure(data,terrain)
    var snapshot_ms: float=0.0; var worker_ms: float=0.0; var publish_ms: float=0.0
    start=Time.get_ticks_usec()
    for step: int in 40:
     water.tick(.1)
     snapshot_ms+=water.last_snapshot_ms
     while water._worker_task>=0: water._collect_worker(true)
     worker_ms+=water.last_worker_ms; publish_ms+=water.last_publish_ms
    rows.append({"mode":"pipeline","kind":kind,"factor":factor,"variant":variant,"cells":data.cells.size(),"wet":water.published_depths.size(),"total_ms":(Time.get_ticks_usec()-start)/1000.0,"snapshot_ms":snapshot_ms,"worker_mean_ms":worker_ms/40.0,"publish_mean_ms":publish_ms/40.0,"volume":water.published_volume,"discharged":water.published_discharged_volume,"snapshots":water.get("snapshot_build_count")})
    terrain.free()
 FileAccess.open("res://art/lookdev/20261113_water_scaling/checks/probe.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"notes":"headless CPU only; 100 fixed solver ticks or 40 worker/publication ticks after setup; unchanged wet domain with 1x/4x/16x total cells; ABBA; pipeline uses real renderer materials without terrain mesh building"},"\t"))
 print("PROBE ",rows.size()," rows"); quit()
