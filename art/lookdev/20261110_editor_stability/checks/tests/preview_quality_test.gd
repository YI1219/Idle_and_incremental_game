extends SceneTree
var checks:int=0
var failures:int=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:
	if not ResourceLoader.exists("res://scripts/terrain_editor/preview_quality.gd"):
		check(false,"high-resolution preview has an explicit render budget and native override")
		print("PREVIEW QUALITY ",checks," checks, ",failures," failures");quit(1);return
	var view:=SubViewport.new();root.add_child(view);view.size=Vector2i(3840,2160);view.msaa_3d=Viewport.MSAA_4X
	var policy:RefCounted=load("res://scripts/terrain_editor/preview_quality.gd").new()
	policy.configure(view)
	check(view.size==Vector2i(3840,2160),"4K display and UI remain 4K")
	check(view.scaling_3d_scale<.70 and view.scaling_3d_scale>.6,"interactive 4K scene respects a 2K render budget")
	check(view.msaa_3d==Viewport.MSAA_2X,"high-resolution editing reduces redundant multisampling before upscaling")
	policy.set_native(true)
	check(view.msaa_3d==Viewport.MSAA_4X,"native mode restores the original antialiasing quality")
	check(view.scaling_3d_scale==1.0,"native mode restores full requested 3D pixels")
	policy.set_native(false);view.size=Vector2i(1280,720);policy.refresh()
	check(view.scaling_3d_scale==1.0,"ordinary window keeps native sharpness")
	view.size=Vector2i(7680,4320);policy.refresh()
	check(view.scaling_3d_scale<.35,"larger high-DPI windows do not multiply the 3D budget without bound")
	view.free();print("PREVIEW QUALITY ",checks," checks, ",failures," failures");quit(1 if failures else 0)
