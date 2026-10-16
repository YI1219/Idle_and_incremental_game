extends SceneTree
var checks:=0;var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred('run')
func run():
 var viewport=SubViewport.new();viewport.size=Vector2i(1000,720);viewport.own_world_3d=true;root.add_child(viewport)
 var editor=load('res://scenes/terrain_editor.tscn').instantiate();viewport.add_child(editor)
 editor.set_process(false);editor.camera.set_process(false)
 var button=editor.hud.find_child('ConvertRockBase',true,false)
 if button==null:check(false,'Workshop has no explicit reversible base-conversion control');editor.free();viewport.queue_free();quit(1);return
 var payload={'version':1,'seed':7301,'cells':[]}
 for z in range(-3,4):
  for x in range(-4,5):payload.cells.append({'x':x,'z':z,'height':3.5,'water':-1})
 check(editor.data.deserialize(payload),'Fixture replaces the initial layout through normal loading')
 button.pressed.emit()
 check(editor.data.sculpt_base_enabled,'Conversion UI enables one terrain volume')
 while editor.renderer.has_pending_updates():editor.renderer.flush_dirty(64)
 editor.camera.position=Vector3(0,10,10);editor.camera.look_at(Vector3(0,3.5,0))
 var screen:Vector2=editor.camera.unproject_position(Vector3(0,3.5,0))
 var tools=editor.hud.find_child('TerrainTools',true,false);tools.select(7);tools.item_selected.emit(7);editor.radius=1.0
 var before=editor.data.serialize()
 var hit:Dictionary=editor._pointer(screen)
 check(not hit.is_empty() and absf(hit.position.y-3.5)<.01,'Screen pointer hits the actual unified cap')
 check(editor.begin_paint(screen),'Public pointer route starts a sculpt stroke')
 editor.continue_paint(screen);editor.cancel_input()
 check(editor.data.serialize()!=before,'Public pointer route carves existing ground')
 while editor.renderer.has_pending_updates():editor.renderer.flush_dirty(64)
 hit=editor._pointer(screen)
 check(not hit.is_empty() and hit.position.y<3.0,'Pointer follows the carved surface; no old cap covers it')
 check(editor.data.undo() and editor.data.serialize()==before,'Full pointer stroke is undoable')
 editor.renderer.rebuild_all()
 var kinds:Dictionary={}
 for chunk in editor.renderer.chunks.values():
  for child in chunk.get_children():kinds[child.name]=true
 check(kinds.has('sculpted_terrain') and not kinds.has('grass') and not kinds.has('cliff'),'Published geometry has one base skin')
 check(not kinds.has('cliff_column_0') and not kinds.has('rim_outcrop_0'),'Converted volume has no old cliff-model overlay')
 var edges:Dictionary={};var triangles:=0
 for chunk in editor.renderer.chunks.values():
  var skin=chunk.get_node('sculpted_terrain')
  var vertices:PackedVector3Array=skin.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  triangles+=vertices.size()/3
  for i in range(0,vertices.size(),3):
   for j in 3:
    var a:=Vector3i((vertices[i+j]*100000).round());var b:=Vector3i((vertices[i+(j+1)%3]*100000).round());var key:Array=[a,b] if a<b else [b,a]
    edges[key]=edges.get(key,0)+1
 var invalid:=0
 for count:int in edges.values():
  if count!=2:invalid+=1
 check(invalid==0,'Actual published unified skin remains closed at chunk seams')
 print('SCULPT BASE PUBLISHED: triangles=',triangles,' invalid_edges=',invalid)
 editor.free();viewport.queue_free()
 print('SCULPT BASE INPUT: ',checks-failures,'/',checks)
 quit(1 if failures else 0)
