extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var editor = load("res://scenes/terrain_editor.tscn").instantiate()
 root.add_child(editor)
 await process_frame
 editor.set_process(false)
 var failures: int=0
 for seed_value: int in [7301,2104]:
  if editor.data.seed!=seed_value:
   editor.data.seed=seed_value
   editor.renderer.rebuild_all()
  var dec=editor.renderer.decoration
  var outer: int=0
  var steps: int=0
  var above_parent: int=0
  var crown_error: float=0.0
  var bad_determinants: int=0
  for col: Dictionary in dec._columns:
   if col.get("is_step",false):steps+=1
   else:outer+=1
   if col.pose.basis.determinant()<=0:bad_determinants+=1
   var source: PackedVector3Array=dec.assets[col.kind][0].mesh.get_faces()
   for v: Vector3 in source:
    var delta: float=(col.pose*v).y-col.pose.origin.y
    if delta>0.00001:above_parent+=1
    if absf(v.y)<0.00001:crown_error=maxf(crown_error,absf(delta))
  print("WORLD_COLUMN seed=",seed_value," outer=",outer," step=",steps," above_own_grass=",above_parent," crown_height_error=",crown_error," bad_pose_determinants=",bad_determinants)
  if above_parent>0 or crown_error>0.00001 or bad_determinants>0:failures+=1
  var count: int=0
  var unmatched: int=0
  var worst_gap: float=INF
  var worst_kind: String=""
  for mass: Dictionary in dec._mass:
   if not mass.get("is_shoulder",false):continue
   var parent_y: float=-INF
   for col: Dictionary in dec._columns:
    if col.cell==mass.cell:parent_y=maxf(parent_y,col.pose.origin.y)
   if parent_y==-INF:
    unmatched+=1
    continue
   if mass.pose.basis.determinant()<=0:failures+=1
   var verts: PackedVector3Array=dec.assets[mass.kind][0].mesh.get_faces()
   var highest: float=-INF
   for v: Vector3 in verts:highest=maxf(highest,(mass.pose*v).y)
   var gap: float=parent_y-highest
   if gap<worst_gap:
    worst_gap=gap
    worst_kind=mass.kind
   if gap<=0:failures+=1
   count+=1
  print("WORLD_ROOT seed=",seed_value," tested=",count," unmatched=",unmatched," minimum_grass_gap=",worst_gap," kind=",worst_kind)
 print("WORLD_ROUND16 failures=",failures)
 editor.free()
 quit(1 if failures else 0)
