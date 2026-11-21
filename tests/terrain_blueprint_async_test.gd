extends SceneTree
var checks:int=0
var failures:int=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:
  failures+=1
  push_error(message)
func _initialize()->void:call_deferred('run')
func wait_for_build(editor:Node3D,prepared:bool=false,advance:bool=true)->void:
 var started:int=Time.get_ticks_msec()
 while Time.get_ticks_msec()-started<8000:
  editor.renderer.flush_dirty(6)
  if advance:editor.renderer._process(.016)
  if prepared:
   if not editor.renderer._prepared_blueprint_stamp.is_empty():return
  elif not editor.renderer.has_pending_updates() and editor.renderer._worker_task==-1:return
  await process_frame
 check(false,'asynchronous build settles within timeout')
func raise_cell(editor:Node3D,cell:Vector2i)->void:
 editor.data.begin_stroke()
 editor.data.apply_brush(Vector2(cell)+Vector2.ONE*.5,.49,'raise',true,1.5,3)
 editor.data.end_stroke()
func run()->void:
 var editor:Node3D=load('res://scenes/terrain_editor.tscn').instantiate()
 root.add_child(editor)
 await process_frame
 editor.set_process(false)
 editor.renderer.set_process(false)
 editor.camera.set_process(false)
 editor.tool='raise';editor.radius=.49;editor.snap=true
 var a:=Vector2i(9,-3)
 var b:=Vector2i(8,-3)
 var original:Dictionary=editor.data.serialize()
 var height:float=editor.data.cells[a].height
 var screen:Vector2=editor.camera.unproject_position(Vector3(a.x+.5,height,a.y+.5))
 editor.begin_paint(screen)
 await wait_for_build(editor,true)
 check(editor.data.serialize()==original,'precomputation does not mutate held terrain')
 check(editor.renderer._published_data.cells[a].height==height,'precomputation leaves visible revision intact')
 editor.commit_blueprint()
 check(editor.renderer._worker_task==-1,'prepared release reuses its completed build')
 await wait_for_build(editor)
 check(editor.renderer._published_data.cells[a].height==height+.5,'prepared release publishes planned terrain')
 editor.renderer._process(1.0)
 editor.renderer.threaded_builds=false
 raise_cell(editor,a)
 editor.renderer.flush_dirty(1<<20)
 editor.renderer.threaded_builds=true
 check(editor.renderer.morph_progress<1.0,'fixture holds first transition open')
 var before_b:float=editor.data.cells[b].height
 raise_cell(editor,b)
 var started:int=Time.get_ticks_msec()
 while not editor.renderer._staging_active and Time.get_ticks_msec()-started<8000:
  editor.renderer.flush_dirty(6)
  await process_frame
 check(editor.renderer._staging_active,'second revision waits in staging during first animation')
 check(editor.renderer.contours.source.cells[b].height==before_b,'staging does not replace visible contour authority')
 editor.data.undo()
 check(editor.data.cells[b].height==before_b,'undo removes the staged edit from authoritative data')
 editor.renderer._process(1.0)
 var stale_published:bool=false
 started=Time.get_ticks_msec()
 while Time.get_ticks_msec()-started<8000:
  editor.renderer.flush_dirty(6)
  editor.renderer._process(.016)
  if editor.renderer._published_data.cells[b].height!=before_b:stale_published=true
  if not editor.renderer.has_pending_updates() and editor.renderer._worker_task==-1:break
  await process_frame
 check(not stale_published,'a withdrawn staged revision is never published')
 check(editor.renderer._published_data.cells[b].height==editor.data.cells[b].height,'latest authoritative revision wins')
 editor.renderer._process(1.0)
 var before_cancel:Dictionary=editor.data.serialize()
 height=editor.data.cells[a].height
 screen=editor.camera.unproject_position(Vector3(a.x+.5,height,a.y+.5))
 editor.begin_paint(screen)
 editor.renderer.flush_dirty(6)
 editor.cancel_input()
 await wait_for_build(editor)
 check(editor.data.serialize()==before_cancel,'cancel during worker precomputation preserves terrain')
 check(editor.renderer._prepared_blueprint_stamp.is_empty(),'cancel leaves no stale prepared blueprint')
 var committed:=Vector2i(9,-4)
 height=editor.data.cells[committed].height
 screen=editor.camera.unproject_position(Vector3(committed.x+.5,height,committed.y+.5))
 check(editor.begin_paint(screen),'new stroke can begin after cancel')
 editor.commit_blueprint()
 editor.renderer.flush_dirty(6)
 var committed_state:Dictionary=editor.data.serialize()
 height=editor.data.cells[a].height
 screen=editor.camera.unproject_position(Vector3(a.x+.5,height,a.y+.5))
 editor.begin_paint(screen)
 editor.cancel_input()
 await wait_for_build(editor)
 check(editor.data.serialize()==committed_state,'canceling next draft retains the previous committed edit')
 check(editor.renderer._published_data.cells[committed].height==editor.data.cells[committed].height,'previous commit still publishes after next draft cancellation')
 check(editor.renderer._blueprint_source==null and editor.renderer._committed_blueprint_source==null,'completed and canceled drafts release their references')
 editor.free()
 print('TERRAIN BLUEPRINT ASYNC: %d checks, %d failures'%[checks,failures])
 quit(1 if failures else 0)
