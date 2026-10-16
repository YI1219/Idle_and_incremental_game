extends SceneTree
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Renderer=preload('res://scripts/terrain_editor/terrain_renderer.gd')
var failures:=0;var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred('run')
func run():
 var d=Data.new();d.apply_rock_brush(Vector3(-.2,2,0),1.3,'rock_add');d.end_stroke()
 var renderer=Renderer.new();root.add_child(renderer);renderer.configure(d);renderer.animate_edits=false
 renderer.rebuild_all()
 var hit:Dictionary=renderer.pick(Vector3(-.2,8,0),Vector3.DOWN)
 check(not hit.is_empty() and hit.position.y>3,'Volume-only layout renders and picks its sculpted surface')
 check(renderer.chunks.size()>=4,'Negative/chunk-corner sculpt geometry publishes across chunks')
 if hit.is_empty():renderer.free();quit(1);return
 check(hit.has('normal') and hit.normal.y>.6,'Picking supplies actual surface normals for direct brushes')
 var edges:Dictionary={};var triangles:=0
 for node in renderer.chunks.values():
  var instance=node.get_node('sculpted_rock')
  var faces:PackedVector3Array=instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  triangles+=faces.size()/3
  for i in range(0,faces.size(),3):
   for j in 3:
    var a=Vector3i((faces[i+j]*100000).round());var b=Vector3i((faces[i+(j+1)%3]*100000).round())
    var key=[a,b] if a<b else [b,a]
    edges[key]=edges.get(key,0)+1
 var invalid_edges:=0
 for uses in edges.values():
  if uses!=2:invalid_edges+=1
 check(invalid_edges==0 and triangles>100,'Actual published chunk surfaces close across chunk seams')
 print('SCULPT PUBLISHED: triangles=',triangles,' invalid_edges=',invalid_edges)
 var old=hit.position.y
 d.apply_rock_brush(Vector3(-.2,3.3,0),.8,'rock_cut');d.end_stroke()
 renderer.flush_dirty(1)
 check(absf(renderer.pick(Vector3(-.2,8,0),Vector3.DOWN).position.y-old)<.001,'Picking stays on the old mesh during partial publication')
 while renderer.has_pending_updates():renderer.flush_dirty(64)
 hit=renderer.pick(Vector3(-.2,8,0),Vector3.DOWN)
 check(not hit.is_empty() and hit.position.y<old-.3,'Cutting updates visible geometry and picking together')
 check(renderer._published_data.rocks.records()==d.rocks.records(),'Published snapshot owns the exact sculpt data')
 var stable=renderer._published_data.rocks.records()
 d.apply_rock_brush(Vector3(0,4,0),1,'rock_add');d.end_stroke()
 check(renderer._published_data.rocks.records()==stable,'Pending source changes cannot mutate the published rock field')
 d.undo();d.undo();renderer.rebuild_all()
 check(absf(renderer.pick(Vector3(-.2,8,0),Vector3.DOWN).position.y-old)<.001,'Undo restores rendered/pickable shape')
 renderer.free()
 print('ROCK SCULPT RUNTIME: ',checks-failures,'/',checks)
 quit(1 if failures else 0)
