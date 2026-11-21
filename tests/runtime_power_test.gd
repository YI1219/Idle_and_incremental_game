extends SceneTree
class World:
	extends Node3D
	var gameplay: RefCounted
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if not ResourceLoader.exists("res://scripts/terrain_editor/runtime_power.gd"):
		check(false,"runtime has a visible-wallpaper and hidden-window work budget");quit(1);return
	var power: Node=load("res://scripts/terrain_editor/runtime_power.gd").new()
	root.add_child(power)
	Engine.max_fps=0
	power.configure(null)
	power.refresh(false,false)
	check(Engine.max_fps==60,"editing avoids rendering beyond 60fps")
	power.refresh(true,false)
	check(Engine.max_fps==30,"stationary visible wallpaper runs at 30fps")
	power.note_interaction();power.refresh(true,false)
	check(Engine.max_fps==60,"wallpaper camera input immediately restores 60fps")
	power._process(3.0);power.refresh(true,false)
	check(Engine.max_fps==30,"wallpaper returns to its lower budget after interaction")
	power.refresh(true,true)
	check(Engine.max_fps==5,"minimized window avoids continuous high-rate work")
	power.refresh(false,false)
	check(Engine.max_fps==60,"restoring the window restores interaction budget")
	power.free()
	check(Engine.max_fps==0,"scene exit restores the previous application limit")
	var world:=World.new();root.add_child(world)
	power=load("res://scripts/terrain_editor/runtime_power.gd").new();world.add_child(power);power.configure(world)
	check(world.can_process(),"headless world stays active without a native window")
	power.refresh(true,true)
	check(not world.can_process(),"hidden world suspends scene updates")
	check(power.can_process(),"power monitor keeps processing so the world can resume")
	power.refresh(true,false)
	check(world.can_process(),"restoring a window resumes its previous scene processing")
	world.free()
	var viewport:=SubViewport.new();root.add_child(viewport);viewport.size=Vector2i(3840,2160)
	var quality: RefCounted=load("res://scripts/terrain_editor/preview_quality.gd").new();quality.configure(viewport)
	for i: int in 150: quality.advance(1.0/30.0,30)
	check(viewport.scaling_3d_scale>.66,"intentional wallpaper frame pacing must not lower 3D resolution")
	for i: int in 150: quality.advance(.05,30)
	check(viewport.scaling_3d_scale<=.501,"actually slow wallpaper frames can still reduce the existing 3D budget")
	for i: int in 1800: quality.advance(1.0/30.0,30)
	check(viewport.scaling_3d_scale>.66,"stable capped wallpaper gradually recovers from a transient low resolution")
	for i: int in 6: quality.advance(.2,5)
	quality.advance(1.0/60.0,60)
	check(viewport.scaling_3d_scale>.66,"hidden-window samples cannot contaminate restored interactive quality")
	quality.set_native(true)
	for i: int in 150: quality.advance(.05,30)
	check(viewport.scaling_3d_scale==1.0,"native quality remains authoritative while limited")
	viewport.free();print("RUNTIME POWER ",checks," checks, ",failures," failures");quit(1 if failures else 0)
