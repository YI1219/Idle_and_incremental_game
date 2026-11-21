extends SceneTree
## Slow day progression spreads radiance work; explicit changes get one full draw.
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 if DisplayServer.get_name()=="headless":quit(2);return
 var editor: Node3D=load("res://scenes/terrain_editor.tscn").instantiate();root.add_child(editor)
 editor.process_mode=Node.PROCESS_MODE_DISABLED
 var clock: RefCounted=editor.gameplay.time_system
 var sky: Sky=editor.get_node("WorldEnvironment").environment.sky
 var source: Shader=sky.sky_material.shader
 var size: int=sky.radiance_size
 clock.set_progress(.0,editor)
 check(sky.process_mode==Sky.PROCESS_MODE_QUALITY,"explicit night change retains full radiance processing for the next draw")
 clock.tick(.1,editor)
 check(sky.process_mode==Sky.PROCESS_MODE_QUALITY,"a same-frame clock tick cannot cancel an explicit full update")
 await process_frame;await process_frame
 clock.tick(.1,editor)
 check(sky.process_mode==Sky.PROCESS_MODE_INCREMENTAL,"ordinary daylight ticks distribute the high quality filter after the first draw")
 var night: Dictionary=clock.current_blended_preset()
 check(sky.sky_material.get_shader_parameter("sky_horizon")==night.sky_horizon,"incremental scheduling preserves authoritative palette values")
 clock.set_progress(.76,editor)
 check(sky.process_mode==Sky.PROCESS_MODE_QUALITY,"a later manual preset immediately requests complete radiance again")
 clock.tick(.1,editor)
 check(sky.process_mode==Sky.PROCESS_MODE_QUALITY,"same-frame elapsed time also respects a subsequent manual preset")
 await process_frame;await process_frame
 clock.tick(.1,editor)
 check(sky.process_mode==Sky.PROCESS_MODE_INCREMENTAL,"routine updates resume after the manual preset is drawn")
 check(sky.sky_material.shader==source and sky.radiance_size==size,"scheduling retains the sky shader and radiance resolution")
 editor.free();print("SKY UPDATE ",checks," checks, ",failures," failures");quit(1 if failures else 0)
