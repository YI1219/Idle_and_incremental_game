extends "res://tools/art/capture_lookdev.gd"
class FixedQuality:
 extends "res://scripts/terrain_editor/preview_quality.gd"
 func advance(_delta: float, _limit: int=0) -> void:pass
var candidate: String="base"
var size_name: String="4k"
func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--size="):size_name=arg.trim_prefix("--size=")
  if arg.begins_with("--variant="):candidate=arg.trim_prefix("--variant=")
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
 root.title="性能验证 · 自动关闭";root.size=Vector2i(1280,720);root.always_on_top=true;root.grab_focus()
 viewport=SubViewport.new();viewport.size=Vector2i(2560,1440) if size_name=="2k" else Vector2i(3840,2160);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var display:=TextureRect.new();display.texture=viewport.get_texture();display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(display)
 editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED
 editor.preview_quality=FixedQuality.new();editor.preview_quality.configure(viewport);editor.preview_quality._scale=.5 if size_name=="scaled4k" else 1.0;editor.preview_quality._apply()
 editor.hud.hide();editor.gameplay.time_system.set_progress(.29,editor);_frame(Vector2(-2,-1),32,16,30)
 editor.background_view.enabled=candidate=="bg";editor.background_view.sync()
 if candidate=="base":
  var shader: Shader=editor.background_view._original_material.shader
  shader.code=_expand_includes(FileAccess.get_file_as_string("res://art/lookdev/20261113_background_foliage/checks/source_before/sky.gdshader"),"res://shaders/terrain_editor")
 var foliage: RefCounted
 if candidate in ["early_alpha","exact_index","combined"]:
  foliage=load("res://art/lookdev/20261113_background_foliage/checks/foliage_candidate.gd").new();print("FOLIAGE ",foliage.apply(editor,"combined" if candidate=="combined" else candidate))
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var warm: int=Time.get_ticks_usec()
 while Time.get_ticks_usec()-warm<3000000:await process_frame
 var drawn_start: int=Engine.get_frames_drawn()
 var frames: Array[float]=[];var last: int=Time.get_ticks_usec();var start: int=last
 while Time.get_ticks_usec()-start<8000000:
  await process_frame
  var now: int=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
 var elapsed: float=(Time.get_ticks_usec()-start)/1000000.0;frames.sort()
 var report: Dictionary={"rendered_frames":Engine.get_frames_drawn()-drawn_start,"idle_frames":frames.size(),"root_visible":root.visible,"root_mode":root.mode,"draw_calls":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"candidate":candidate,"size":size_name,"fps":(Engine.get_frames_drawn()-drawn_start)/elapsed,"idle_fps":frames.size()/elapsed,"p95_ms":frames[int(frames.size()*.95)],"p99_ms":frames[int(frames.size()*.99)],"resolution":[viewport.size.x,viewport.size.y],"texture_size":[viewport.get_texture().get_size().x,viewport.get_texture().get_size().y],"scale":viewport.scaling_3d_scale,"background_active":editor.background_view.is_active(),"background_size":str(editor.background_view.view.size) if editor.background_view.view!=null else "none","method":"normal live editor/water/daylight;3warm8sample;actual-pixel balanced current settings,no cap/vsync/imageIO"}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
 if foliage!=null:foliage.restore()
 editor.free();viewport.free();quit()
