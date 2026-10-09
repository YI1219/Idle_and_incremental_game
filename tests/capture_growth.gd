extends SceneTree
## Edit growth in the runtime scene. The renderer clock is paused and progress
## is set explicitly, so the frames are the morph at 0, .12, .25, .40, .60, 1.
## Usage: godot --path . -s res://tests/capture_growth.gd -- <tag> [out=<review dir>]
var OUT := "res://art/review/terrain_fidelity/2026-10-08/round6/"
var viewport:SubViewport
var editor:Node3D
var captures:Array=[]
const STEPS:=[0.0,.12,.25,.40,.60,1.0]
func _initialize()->void:call_deferred("run")
func capture(name:String,progress:float)->void:
	var renderer=editor.renderer
	renderer.morph_progress=progress
	RenderingServer.global_shader_parameter_set("terrain_morph_progress",progress)
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	var error:=viewport.get_texture().get_image().save_png(OUT+name+".png")
	captures.append({"file":name+".png","error":error,"progress":progress,"eased":renderer.morph_ease(progress)})
func publish()->void:
	while editor.renderer.has_pending_updates():editor.renderer.flush_dirty(64)
func frame(center:Vector2,height:float,yaw:float,pitch:float)->void:
	var camera=editor.camera
	camera._center_goal=center;camera.height_goal=height;camera._yaw_goal=yaw;camera._pitch_goal=pitch
	camera._center=center;camera._height=height;camera._yaw=yaw;camera._pitch=pitch
	camera.advance(0.0)
func run()->void:
	var args:=OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("out="):OUT="res://art/review/terrain_fidelity/"+arg.trim_prefix("out=")+"/"
	var tag:="growth" if args.is_empty() or args[0].begins_with("out=") else args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	viewport=SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	editor=load("res://scenes/terrain_editor.tscn").instantiate()
	viewport.add_child(editor)
	editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
	editor.renderer.set_process(false)
	frame(Vector2(15.5,4.0),13.0,48.0,30.0)
	await capture(tag+"_expand_before",1.0)
	var data=editor.data
	data.begin_stroke();data.apply_brush(Vector2(19.2,4.6),2.8,"expand",false,1.5,3);data.end_stroke()
	publish()
	for i in STEPS.size():await capture(tag+"_expand_%d"%i,STEPS[i])
	data.begin_stroke();data.apply_brush(Vector2(18.6,4.4),2.2,"raise",false,1.5,3);data.end_stroke()
	data.begin_stroke();data.apply_brush(Vector2(18.6,4.4),2.2,"raise",false,1.5,3);data.end_stroke()
	publish()
	for i in STEPS.size():await capture(tag+"_raise_%d"%i,STEPS[i])
	var file:=FileAccess.open(OUT+tag+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"resolution":[1280,720],"morph_seconds":editor.renderer.MORPH_SECONDS,"captures":captures},"\t"))
	print("GROWTH CAPTURES ",captures.size())
	quit()
