extends SceneTree
## Actual runtime scene and gameplay camera. No alternate render materials.
const OUT := "res://art/review/terrain_fidelity/2026-10-06/target_match/"
var viewport:SubViewport
var editor:Node3D
var captures:Array=[]
func _initialize()->void:call_deferred("run")
func capture(tag:String)->void:
 for i in 36:await process_frame
 await RenderingServer.frame_post_draw
 var error:=viewport.get_texture().get_image().save_png(OUT+tag+".png")
 captures.append({"file":tag+".png","error":error,"position":str(editor.camera.position),"rotation":str(editor.camera.rotation_degrees),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
func rotate(relative:Vector2)->void:
 var press:=InputEventMouseButton.new()
 press.button_index=MOUSE_BUTTON_RIGHT;press.pressed=true
 editor.camera._unhandled_input(press)
 var motion:=InputEventMouseMotion.new()
 motion.relative=relative
 editor.camera._unhandled_input(motion)
 press.pressed=false
 editor.camera._input(press)
 editor.camera.advance(2.0)
func run()->void:
 viewport=SubViewport.new()
 viewport.size=Vector2i(1671,941)
 viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 editor=load("res://scenes/terrain_editor.tscn").instantiate()
 viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 var tag:="final" if OS.get_cmdline_user_args().is_empty() else OS.get_cmdline_user_args()[0]
 await capture(tag)
 if tag=="final":
  rotate(Vector2(160,0))
  await capture("orbit_left")
  rotate(Vector2(-320,0))
  await capture("orbit_right")
  rotate(Vector2(-400,70))
  await capture("orbit_back")
  rotate(Vector2(560,-70))
  editor.camera.recenter(Vector2(-8,-3));editor.camera.wheel(-3);editor.camera.advance(2.0)
  await capture("garden_close")
  editor.camera.recenter(Vector2(8,3));editor.camera.advance(2.0)
  await capture("water_close")
  editor.camera.recenter(Vector2(0,-1));editor.camera.wheel(7);editor.camera.advance(2.0)
  await capture("zoom_out")
  editor.camera.wheel(-4);editor.camera.advance(2.0)
  editor.hud.show()
  await capture("gameplay_ui")
 var file:=FileAccess.open(OUT+tag+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1671,941],"captures":captures},"\t"))
 print("TARGET RUNTIME CAPTURES: ",JSON.stringify(captures))
 quit()
