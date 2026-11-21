extends SceneTree
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Before = preload("res://art/lookdev/20261113_water_scaling/checks/source_before/water_flow.gd")
const After = preload("res://scripts/terrain_editor/water_flow.gd")
const OldWater = preload("res://art/lookdev/20261113_water_scaling/checks/water_renderer_reference.gd")
const NewWater = preload("res://scripts/terrain_editor/water_renderer.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures.append(label)
  if failures.size() <= 8: push_error(label)
func run() -> void:
 for case: int in 12:
  var a: RefCounted = Data.new()
  a.seed = [7301,2104,4242,913][case % 4]
  if case < 4: a.make_preset([0,0,1,2][case])
  else:
   var rng: RandomNumberGenerator = RandomNumberGenerator.new(); rng.seed = 12345 + case
   for z: int in range(-4,5):
    for x: int in range(-4,5):
     a.cells[Vector2i(x,z)] = {"height":rng.randf_range(-2.0,3.0),"water":-1,"water_volume":rng.randf_range(0.0,2.0) if rng.randf() < .4 else 0.0}
  var b: RefCounted = a.copy()
  var old: RefCounted = Before.new(); old.configure(a)
  var fresh: RefCounted = After.new(); fresh.configure(b)
  var cache: Array[Dictionary] = []
  var base: Dictionary = NewWater._build_image_base(b)
  for step: int in 30:
   if step in [7,13,19]:
    for data: RefCounted in [a,b]:
     if step == 7: data.cells[Vector2i.ZERO] = {"height":1.75,"water":-1,"water_volume":.125}
     if step == 13: data.cells.erase(Vector2i.RIGHT)
     if step == 19: data.cells[Vector2i(-1,0)] = {"height":-1.5,"water":3}
    old.sync(a); fresh.sync(b); base = NewWater._build_image_base(b)
   var delta: float = [.1,.025,.2,.001][step % 4]
   old.step(delta); fresh.step(delta)
   var label: String = "case %d step %d " % [case,step]
   for key: String in ["depths","heights","basins","last_transfers","discharged_volume"]:
    check(old.get(key) == fresh.get(key),label + key)
   check(old.total_volume() == fresh.total_volume(),label + "ordered mass sum")
   if step % 3 == 0:
    var of: RefCounted = OldWater.FlowField.new(); of.build_live(a,old)
    var nf: RefCounted = NewWater.FlowField.new(); nf.shape_cache=cache; nf.build_live(b,fresh); cache=nf.shape_cache
    for kind: String in ["water","waterfall","bank"]:
     for attr: String in ["vertices","normals","colors","uv","uv2"]:
      check(var_to_bytes(of.surfaces[kind].get(attr)) == var_to_bytes(nf.surfaces[kind].get(attr)),label+kind+attr)
    check(of.fall_veils == nf.fall_veils and of.splash_points == nf.splash_points,label+"fall metadata")
    var oi: Dictionary=OldWater._build_images(a,of)
    var ni: Dictionary=NewWater._build_images(b,nf,base)
    check(oi.live.get_data()==ni.live.get_data() and oi.shore.get_data()==ni.shore.get_data() and oi.rect==ni.rect,label+"field bytes")
   old.write_to_data(a); fresh.write_to_data(b)
   check(a.cells == b.cells,label+"persisted cells")
 FileAccess.open("res://art/lookdev/20261113_water_scaling/checks/equivalence.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
 print("EQUIVALENCE ",checks," checks, ",failures.size()," failures")
 quit(1 if not failures.is_empty() else 0)
