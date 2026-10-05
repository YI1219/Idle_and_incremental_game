extends SceneTree
const OUT:="res://art/review/terrain_fidelity/2026-10-05/"
func _initialize()->void:call_deferred("run")
func run()->void:
 var editor=load("res://scenes/terrain_editor.tscn").instantiate()
 root.add_child(editor);editor.hud.hide();editor.brush.hide();editor.set_process(false)
 editor.camera.wheel(-5.0);editor.camera.recenter(Vector2(7.2,-1.8))
 while editor.renderer.has_pending_updates():
  editor.renderer.flush_dirty(2);await process_frame
 for i in 60:await process_frame
 var start:=Time.get_ticks_usec();var records:Array=[]
 for step in 5:
  if step>0:
   for i in 15:await process_frame
  await RenderingServer.frame_post_draw
  var name:="flow_time_%d.png"%step
  var error:=root.get_texture().get_image().save_png(OUT+name)
  if error!=OK:push_error("Temporal capture failed");quit(1);return
  records.append({"file":name,"frames_after_start":step*15,"wall_seconds":(Time.get_ticks_usec()-start)/1000000.0})
 var output:=FileAccess.open(OUT+"flow_temporal.json",FileAccess.WRITE)
 output.store_string(JSON.stringify({"source":"actual Metal Forward+ render, fixed60Hz timestep, five still frames across60drawn frames","frames":records,"limits":"Single fixed camera/default layout; not all temporal behavior or frame pacing"},"\t"))
 print("FLOW TEMPORAL: ",JSON.stringify(records));quit()
