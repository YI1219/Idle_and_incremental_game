extends "res://art/lookdev/20261113_render_work/checks/probe.gd"
class FixedQuality:
 extends "res://scripts/terrain_editor/preview_quality.gd"
 func advance(_delta: float, _frame_limit: int=0) -> void: pass
var candidate_name: String="base"
var size_name: String="4k"
# Collect/expand shaders without freezing animation or modifying palette values.
func _freeze_material(material: Material) -> void:
 if material==null or frozen_materials.has(material.get_instance_id()):return
 frozen_materials[material.get_instance_id()]=true
 if material.next_pass!=null:_freeze_material(material.next_pass)
 if not material is ShaderMaterial or material.shader==null:return
 var shader: Shader=material.shader
 if not frozen_shaders.has(shader.get_instance_id()):
  var base: String=shader.resource_path.get_base_dir()
  if base.is_empty():base="res://shaders/terrain_editor"
  shader.code=_expand_includes(shader.code,base)
  frozen_shaders[shader.get_instance_id()]=shader
func run() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--variant="):candidate_name=arg.trim_prefix("--variant=")
  if arg.begins_with("--size="):size_name=arg.trim_prefix("--size=")
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
 viewport=SubViewport.new();viewport.size=Vector2i(2560,1440) if size_name=="2k" else Vector2i(3840,2160);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load("res://scenes/terrain_editor.tscn").instantiate();viewport.add_child(editor);editor.runtime_power.process_mode=Node.PROCESS_MODE_DISABLED
 editor.preview_quality=FixedQuality.new();editor.preview_quality.configure(viewport);editor.preview_quality._scale=1.0;editor.preview_quality._apply()
 editor.hud.hide();editor.gameplay.time_system.set_progress(.29,editor);_frame(Vector2(-2,-1),32,16,30)
 _freeze_node(editor);variant(candidate_name)
 if candidate_name=="sky_incremental":editor.get_node("WorldEnvironment").environment.sky.process_mode=Sky.PROCESS_MODE_INCREMENTAL
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var warm: int=Time.get_ticks_usec()
 while Time.get_ticks_usec()-warm<4000000:await process_frame
 var times: Array[float]=[];var last: int=Time.get_ticks_usec();var start: int=last
 while Time.get_ticks_usec()-start<6000000:
  await process_frame
  var now: int=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
 var seconds: float=(Time.get_ticks_usec()-start)/1000000.0;times.sort()
 var report: Dictionary={"variant":candidate_name,"size":size_name,"frames":times.size(),"fps":times.size()/seconds,"p95_ms":times[int(times.size()*.95)],"p99_ms":times[int(times.size()*.99)],"resolution":[viewport.size.x,viewport.size.y],"texture_size":[viewport.get_texture().get_size().x,viewport.get_texture().get_size().y],"scale":viewport.scaling_3d_scale,"sky_mode":editor.get_node("WorldEnvironment").environment.sky.process_mode,"method":"4s warm6s sample;normal editor/water/time;live shaders;fixed currentbalanced pixels;no cap/vsync/screenshotIO"}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report))
 editor.free();viewport.queue_free();quit()
