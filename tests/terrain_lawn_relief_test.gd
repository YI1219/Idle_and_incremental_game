extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
const Detail=preload("res://scripts/terrain_editor/rim_surface_detail.gd")
func _initialize():call_deferred("run")
func run():
 var data:=Data.new();data.make_preset(0);var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco._column_layout(field,data.seed)
 var low:=0.0;var high:=0.0;var errors:=0;var seam:Dictionary={};var samples:=0
 for chunk:Vector2i in field.triangle_chunks:
  var mesh:ArrayMesh=Detail.lawn(field.build(chunk).grass,field.lawn_boundaries,field.water_regions)
  if mesh.get_surface_count()==0:continue
  for p:Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
   var base:float=field.levels[0]
   for h:float in field.levels:
    if absf(p.y-h)<absf(p.y-base):base=h
   var delta:=p.y-base;low=minf(low,delta);high=maxf(high,delta);samples+=1
   if absf(delta)>.0551:errors+=1
   for level:int in field.water_regions:
    if absf(level*.5-base)<.01 and Field.contains(field.water_regions[level],Vector2(p.x,p.z)) and absf(delta)>.001:errors+=1;print("wet error ",p,delta)
   if absf(fposmod(p.x,8))<.0001 or absf(fposmod(p.z,8))<.0001:
    var key:=Vector3(snappedf(p.x,.0001),base,snappedf(p.z,.0001))
    if seam.has(key) and absf(seam[key]-p.y)>.0001:errors+=1;print("seam error ",p,seam[key])
    seam[key]=p.y
 var ok:=low<-.015 and high>.015 and errors==0
 print("LAWN RELIEF: range=",Vector2(low,high)," samples=",samples," seam vertices=",seam.size()," errors=",errors," passed=",ok)
 quit(0 if ok else 1)
