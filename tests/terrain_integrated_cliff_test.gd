extends SceneTree
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Field=preload('res://scripts/terrain_editor/contour_terrain.gd')
const Deco=preload('res://scripts/terrain_editor/terrain_decoration.gd')
var failures:=0
func _initialize():call_deferred('run')
func boundary_distance(a:PackedVector2Array,b:PackedVector2Array)->float:
 var worst:=0.0
 for p:Vector2 in a:
  var best:=INF
  for i:int in b.size():best=minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,b[i],b[(i+1)%b.size()])))
  worst=maxf(worst,best)
 return worst
func run():
 var models=load('res://scripts/terrain_editor/terrain_models.gd').new()
 for spec:Array in [[11,'cliff_tall_v2.glb',.72],[37,'cliff_tall_v2.glb',.86],[23,'cliff_main_v4.glb',.72],[41,'cliff_main_v4.glb',.62]]:
  var source:Dictionary=models._merge(models._load('res://assets/nature/refined/'+spec[1],'cliff_rock'))
  var original:Dictionary=load('res://scripts/terrain_editor/source_stone_crown.gd').build(source.mesh,.68,spec[2])
  var current:Dictionary=models._rock_body_models(spec[0])[0]
  var cap_gap:=maxf(boundary_distance(original.cap_polygon,current.cap_polygon),boundary_distance(current.cap_polygon,original.cap_polygon))
  var deeper:float=original.mesh.get_aabb().position.y-current.mesh.get_aabb().position.y
  var ok:bool=cap_gap<.0001 and deeper>.15 and current.get('integrated_foot',false) and absf(current.body_height-.68)<.00001
  var edges:Dictionary={}
  var faces:PackedVector3Array=current.mesh.get_faces()
  for i in range(0,faces.size(),3):
   for j in 3:
    var a:=faces[i+j].snapped(Vector3.ONE*.00001);var b:=faces[i+(j+1)%3].snapped(Vector3.ONE*.00001)
    var key:=str(a,b) if str(a)<str(b) else str(b,a)
    edges[key]=edges.get(key,0)+1
  var invalid_edges:=0
  for uses:int in edges.values():
   if uses!=2:invalid_edges+=1
  ok=ok and invalid_edges==0
  if not ok:failures+=1
  print('INTEGRATED CLIFF ',spec[0],': cap_gap=',cap_gap,' extra_depth=',deeper,' invalid_edges=',invalid_edges,' passed=',ok)
 var data:=Data.new();data.make_preset(0);var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco._column_layout(field,data.seed)
 if not deco._mass.is_empty() or deco._columns.size()<20:failures+=1
 print('INTEGRATED CLIFF SCENE: columns=',deco._columns.size(),' detached_roots=',deco._mass.size(),' failures=',failures)
 quit(1 if failures else 0)
