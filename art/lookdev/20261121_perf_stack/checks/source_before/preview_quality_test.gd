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
	for i in 150: policy.advance(.025)
	check(view.scaling_3d_scale <= .501 and view.scaling_3d_scale >= .499,"sustained slow 4K rendering adapts down to a 1080p scene budget")
	check(view.size == Vector2i(3840,2160),"adaptive 3D quality preserves 4K interface resolution")
	policy.set_native(true)
	for i in 150: policy.advance(.025)

	check(view.msaa_3d==Viewport.MSAA_4X,"native mode restores the original antialiasing quality")
	check(view.scaling_3d_scale==1.0,"native mode restores full requested 3D pixels")
	policy.set_native(false)
	for i in 40: policy.advance(.12)
	check(view.scaling_3d_scale <= .501,"very slow high-resolution frames still trigger adaptation")
	view.size=Vector2i(1280,720);policy.refresh()
	check(view.scaling_3d_scale==1.0,"ordinary window keeps native sharpness")
	view.size=Vector2i(2560,1440);policy.refresh()
	check(view.scaling_3d_scale==1.0 and view.msaa_3d==Viewport.MSAA_2X,"native-size balanced editing reduces multisample work without reducing pixels")
	policy.set_native(true)
	check(view.msaa_3d==Viewport.MSAA_4X and view.scaling_3d_scale==1.0,"native override restores full multisampling at 2K")
	policy.set_native(false)
	view.size=Vector2i(7680,4320);policy.refresh()
	check(view.scaling_3d_scale<.35,"larger high-DPI windows do not multiply the 3D budget without bound")
	view.free();print("PREVIEW QUALITY ",checks," checks, ",failures," failures");quit(1 if failures else 0)
