extends SceneTree
## Isolated cost of the lighting-round features at the default camera.
## Toggles one feature at a time in the same running scene and view.
## Usage: godot --path . -s res://tests/benchmark_lighting_round.gd -- <tag> [out=<review dir>]
var viewport:SubViewport
var editor:Node3D
func _initialize()->void:call_deferred("run")
func measure(frames:int=12)->Dictionary:
 for i in 6:await RenderingServer.frame_post_draw
 var rid:=viewport.get_viewport_rid()
 var cpu:=PackedFloat64Array()
 var gpu:=PackedFloat64Array()
 for i in frames:
  await RenderingServer.frame_post_draw
  cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
  gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
 cpu.sort();gpu.sort()
 return {"cpu_ms_median":cpu[frames/2],"gpu_ms_median":gpu[frames/2],"gpu_ms_max":gpu[frames-1]}
func run()->void:
 viewport=SubViewport.new()
 viewport.size=Vector2i(1280,720)
 viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(),true)
 editor=load("res://scenes/terrain_editor.tscn").instantiate()
 viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 for i in 30:await process_frame
 var env:Environment
 var sun:DirectionalLight3D
 for child in editor.get_children():
  if child is WorldEnvironment:env=child.environment
  if child is DirectionalLight3D and child.shadow_enabled:sun=child
 var decks:Array=editor.landscape.get_children().filter(func(n):return n is MeshInstance3D)
 var results:={}
 results.all_on=await measure()
 env.glow_enabled=false
 results.glow_off=await measure()
 env.glow_enabled=true
 for deck in decks:deck.visible=false
 results.cloud_decks_off=await measure()
 for deck in decks:deck.visible=true
 env.fog_enabled=false
 results.fog_off=await measure()
 env.fog_enabled=true
 env.ssao_enabled=false
 results.ssao_off=await measure()
 env.ssao_enabled=true
 sun.shadow_enabled=false
 results.sun_shadow_off=await measure()
 sun.shadow_enabled=true
 var mist:Node3D=editor.renderer.get_node_or_null("WaterfallMist")
 if mist!=null:
  mist.visible=false
  results.waterfall_mist_off=await measure()
  mist.visible=true
 results.all_on_again=await measure()
 var args:=OS.get_cmdline_user_args()
 var tag:="after" if args.is_empty() else args[0]
 var dir:="2026-10-08/lighting_round1"
 for arg in args:
  if arg.begins_with("out="):dir=arg.trim_prefix("out=")
 var out:="res://art/review/terrain_fidelity/%s/feature_cost_%s.json"%[dir,tag]
 var file:=FileAccess.open(out,FileAccess.WRITE)
 file.store_string(JSON.stringify({"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1280,720],"results":results},"\t"))
 print("FEATURE COST: ",JSON.stringify(results))
 quit()
