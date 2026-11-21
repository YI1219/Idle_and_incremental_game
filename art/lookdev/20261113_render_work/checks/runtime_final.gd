extends "res://tools/art/capture_lookdev.gd"
class QualityClock:
 extends "res://scripts/gameplay/systems/time_solar_system.gd"
 func apply_to_scene(scene: Node3D, _immediate_sky: bool=true) -> void:
  super.apply_to_scene(scene,true)
class FixedQuality:
 extends "res://scripts/terrain_editor/preview_quality.gd"
 func advance(_delta: float, _frame_limit: int=0) -> void: pass
var variant: String="after"
var size_name: String="2k"
func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--variant="): variant=arg.trim_prefix("--variant=")
  if arg.begins_with("--size="): size_name=arg.trim_prefix("--size=")
  if arg.begins_with("--out="): output=arg.trim_prefix("--out=")
 viewport=SubViewport.new();viewport.size=Vector2i(2560,1440) if size_name=="2k" else Vector2i(3840,2160)
 viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor)
 if variant=="before":editor.gameplay.time_system=QualityClock.new()
 editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED
 editor.preview_quality=FixedQuality.new();editor.preview_quality.configure(viewport)
 editor.preview_quality._scale=.5 if size_name=="scaled4k" else 1.0;editor.preview_quality._apply()
 editor.hud.hide();editor.gameplay.time_system.set_progress(.29,editor);_frame(Vector2(-2,-1),32,16,30)
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var warm: int=Time.get_ticks_usec()
 while Time.get_ticks_usec()-warm<3000000: await process_frame
 var frames: Array[float]=[];var previous: int=Time.get_ticks_usec();var start: int=previous
 while Time.get_ticks_usec()-start<8000000:
  await process_frame
  var now: int=Time.get_ticks_usec();frames.append((now-previous)/1000.0);previous=now
 var elapsed: float=(Time.get_ticks_usec()-start)/1000000.0;frames.sort()
 var report: Dictionary={"variant":variant,"size":size_name,"frames":frames.size(),"fps":frames.size()/elapsed,"p95_ms":frames[int(frames.size()*.95)],"p99_ms":frames[int(frames.size()*.99)],"resolution":[viewport.size.x,viewport.size.y],"texture_size":[viewport.get_texture().get_size().x,viewport.get_texture().get_size().y],"scale":viewport.scaling_3d_scale,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"simulated_seconds":editor.water_view.simulated_seconds,"snapshots":editor.water_view.get("snapshot_build_count"),"sky_mode":editor.get_node("WorldEnvironment").environment.sky.process_mode,"method":"3s warm +8s normal production editor/water/time render loop; fixed SubViewport 3D pixels; balanced current visual settings; limiter/vsync off; no screenshot I/O"}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
 editor.free();viewport.queue_free();quit()
