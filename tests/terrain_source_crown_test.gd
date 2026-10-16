extends SceneTree
var failures:=0
func _initialize()->void:call_deferred('run')
func run()->void:
 var path:='res://scripts/terrain_editor/source_stone_crown.gd'
 if not ResourceLoader.exists(path):push_error('Retained-source crown clipping unavailable');quit(1);return
 var models=load('res://scripts/terrain_editor/terrain_models.gd').new()
 for spec:Array in [['q:Rock_Medium_1',.72],['q:Rock_Medium_2',.72],['q:Rock_Medium_1',.86],['q:Rock_Medium_2',.62],['res://assets/nature/refined/cliff_main_v4.glb',.72],['res://assets/nature/refined/cliff_main_v4.glb',.62],['res://assets/nature/refined/cliff_tall_v2.glb',.72],['res://assets/nature/refined/cliff_tall_v2.glb',.86],['res://assets/nature/refined/cliff_integrated_main_v1.glb',.72,'cliff_main_v4.glb'],['res://assets/nature/refined/cliff_integrated_main_v1.glb',.62,'cliff_main_v4.glb'],['res://assets/nature/refined/cliff_integrated_tall_v1.glb',.72,'cliff_tall_v2.glb'],['res://assets/nature/refined/cliff_integrated_tall_v1.glb',.86,'cliff_tall_v2.glb']]:
  var id:String=spec[0]
  var source:Array=models._load(id,'cliff_rock')
  var merged:Dictionary=models._merge(source)
  var reference_bounds:=AABB()
  if spec.size()>2:
   var retained:Dictionary=models._merge(models._load('res://assets/nature/refined/'+spec[2],'cliff_rock'))
   reference_bounds=retained.mesh.get_aabb()
  var built:Dictionary=load(path).build(merged.mesh,.68,spec[1],reference_bounds)
  var vertices:PackedVector3Array=built.mesh.get_faces()
  var edges:Dictionary={};var cap:=0
  for i in range(0,vertices.size(),3):
   if absf(vertices[i].y)+absf(vertices[i+1].y)+absf(vertices[i+2].y)<.00001:cap+=1
   for j in 3:
    var a:=vertices[i+j].snapped(Vector3.ONE*.00001);var b:=vertices[i+(j+1)%3].snapped(Vector3.ONE*.00001)
    var key:=str(a,b) if str(a)<str(b) else str(b,a)
    edges[key]=int(edges.get(key,0))+1
  for key:String in edges:
   if edges[key]!=2:failures+=1;print("edge ",key," count=",edges[key])
  if cap<3:failures+=1
  # Bounds use uploaded vertices; get_faces() rounds to 1e-4, which can
  # move a noncanonical extended floor below its exact metadata height.
  for v:Vector3 in built.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
   if v.y>.000001 or v.y<-float(built.geometry_height)-.000001:failures+=1;print("bounds ",v)
  print('SOURCE CROWN: ',id,' faces=',vertices.size()/3,' cap=',cap,' invalid_edges/bounds=',failures)
 quit(1 if failures else 0)
