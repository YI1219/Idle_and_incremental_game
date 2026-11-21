extends SceneTree
var checks:int=0
var failures:int=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var editor:Node3D=load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.set_process(false)
	editor.renderer.threaded_builds=false
	var cell:=Vector2i(9,-3)
	var old:Node3D=editor.renderer.chunks[editor.data.chunk_of(cell)]
	editor.data.begin_stroke()
	editor.data.apply_brush(Vector2(cell)+Vector2.ONE*.5,.49,"contract",true,1.5,3)
	editor.data.end_stroke()
	editor.renderer.flush_dirty(1<<20)
	check(editor.renderer.morph_progress<1.0,"removal starts an animation")
	var retiring:Variant=editor.renderer.get("_retiring_chunks")
	check(retiring is Array and not retiring.is_empty(),"old geometry survives publication for fade-out")
	check(is_instance_valid(old) and old.visible,"retiring geometry remains visible at animation start")
	editor.renderer._process(.2)
	check(is_instance_valid(old) and old.visible,"retiring geometry remains during the descent")
	editor.renderer._process(1.0)
	check(not is_instance_valid(old) or not old.visible,"retired geometry is hidden after fade completion")
	editor.data.begin_stroke()
	editor.data.apply_brush(Vector2(cell)+Vector2.ONE*.5,.49,"expand",true,1.5,3)
	editor.data.end_stroke()
	editor.renderer.flush_dirty(1<<20)
	check(editor.renderer.morph_progress<1.0,"addition starts an animation")
	check(editor.renderer.shown_top(cell)<1.5,"added land begins below its final height")
	editor.renderer._process(1.0)
	check(is_equal_approx(editor.renderer.shown_top(cell),1.5),"added land finishes at the authored height")
	editor.free()
	print("TERRAIN TRANSITION: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
