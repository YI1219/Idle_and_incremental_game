extends SceneTree
var failures:=0
func _initialize()->void:call_deferred('run')
func run()->void:
 var path:='res://scripts/terrain_editor/source_stone_crown.gd'
 if not ResourceLoader.exists(path):push_error('Retained-source crown clipping unavailable');quit(1);return
 var models=load('res://scripts/terrain_editor/terrain_models.gd').new()
 for spec:Array in [['q:Rock_Medium_1',.72],['q:Rock_Medium_2',.72],['q:Rock_Medium_1',.86],['q:Rock_Medium_2',.62],['res://assets/nature/refined/cliff_main_v4.glb',.72],['res://assets/nature/refined/cliff_main_v4.glb',.62],['res://assets/nature/refined/cliff_tall_v2.glb',.72],['res://assets/nature/refined/cliff_tall_v2.glb',.86]]:
  var id:String=spec[0]
  var source:Array=models._load(id,'cliff_rock')
  var merged:Dictionary=models._merge(source)
  var built:Dictionary=load(path).build(merged.mesh,.68,spec[1])
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
  for v:Vector3 in vertices:
   if v.y>.000001 or v.y<-.680001:failures+=1;print("bounds ",v)
  print('SOURCE CROWN: ',id,' faces=',vertices.size()/3,' cap=',cap,' invalid_edges/bounds=',failures)
 quit(1 if failures else 0)
