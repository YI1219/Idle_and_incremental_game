extends "res://tools/art/capture_lookdev.gd"
class FixedQuality:
 extends "res://scripts/terrain_editor/preview_quality.gd"
 func advance(_delta: float, _limit: int=0) -> void:pass
var candidate: String="base"
func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--variant="):candidate=arg.trim_prefix("--variant=")
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
 viewport=SubViewport.new();viewport.size=Vector2i(3840,2160);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED
 editor.preview_quality=FixedQuality.new();editor.preview_quality.configure(viewport);editor.preview_quality._scale=1.0;editor.preview_quality._apply()
 editor.hud.hide();editor.gameplay.time_system.set_progress(.29,editor);_frame(Vector2(-2,-1),32,16,30)
 if candidate in ["bg","combined"]:
  var split: Node3D=load("res://art/lookdev/20261113_background_foliage/checks/background_prototype.gd").new();editor.add_child(split);split.configure(editor)
 var foliage: RefCounted
 if candidate in ["early_alpha","exact_index","combined"]:
  foliage=load("res://art/lookdev/20261113_background_foliage/checks/foliage_candidate.gd").new();print("FOLIAGE ",foliage.apply(editor,"combined" if candidate=="combined" else candidate))
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var warm: int=Time.get_ticks_usec()
 while Time.get_ticks_usec()-warm<3000000:await process_frame
 var frames: Array[float]=[];var last: int=Time.get_ticks_usec();var start: int=last
 while Time.get_ticks_usec()-start<6000000:
  await process_frame
  var now: int=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
 var elapsed: float=(Time.get_ticks_usec()-start)/1000000.0;frames.sort()
 var report: Dictionary={"candidate":candidate,"fps":frames.size()/elapsed,"p95_ms":frames[int(frames.size()*.95)],"p99_ms":frames[int(frames.size()*.99)],"resolution":[viewport.size.x,viewport.size.y],"texture_size":[viewport.get_texture().get_size().x,viewport.get_texture().get_size().y],"scale":viewport.scaling_3d_scale,"method":"normal live editor/water/daylight;3warm6sample;native4K balanced current settings,no cap/vsync/imageIO"}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
 if foliage!=null:foliage.restore()
 editor.free();viewport.free();quit()
