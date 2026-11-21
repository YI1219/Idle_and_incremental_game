extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
var checks:int=0
var failures:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run()->void:
	var data:=Data.new()
	for x:int in range(4):data.cells[Vector2i(x,0)]={"height":float(x)*.5+1.5,"water":-1,"water_volume":0.0}
	var before:Dictionary=data.serialize()
	data.begin_stroke()
	var changed:int=data.apply_brush(Vector2(1.5,.5),3.8,"level",true,2.0,3,2.0)
	data.end_stroke()
	var aligned:bool=true
	for r:Dictionary in data.cells.values():aligned=aligned and r.height==2.0
	check(changed==3 and aligned,"one level stroke aligns both higher and lower neighbours to the sampled height")
	check(data.undo() and data.serialize()==before,"one undo restores the full aligned stroke")
	check(data.redo() and data.cells[Vector2i(3,0)].height==2.0,"redo restores the alignment target")
	var wet:=Data.new()
	wet.cells[Vector2i.ZERO]={"height":0.0,"water":2,"water_volume":1.0}
	var solver:RefCounted=load("res://scripts/terrain_editor/water_flow.gd").new()
	solver.configure(wet)
	wet.begin_stroke();wet.apply_brush(Vector2(.5,.5),.49,"level",true,.5,3,.5);wet.end_stroke()
	solver.sync(wet)
	check(absf(solver.total_volume()-1.0)<1e-9,"alignment moves the bed without creating or deleting water")
	solver.step(.2);solver.write_to_data(wet)
	var retained:float=solver.total_volume()
	wet.undo();solver.sync(wet)
	check(absf(solver.total_volume()-retained)<1e-9,"undo alignment preserves current water instead of refilling history")
	var editor:Node3D=load("res://scenes/terrain_editor.tscn").instantiate();root.add_child(editor)
	editor.set_process(false);editor.camera.set_process(false)
	check(editor.snap,"terrain editing starts on grid for repeatable adjacent strokes")
	editor.tool="level";editor.radius=.49
	var screen:Vector2=editor.camera.unproject_position(Vector3(9.5,editor.data.cells[Vector2i(9,-3)].height,-2.5))
	var saved:Dictionary=editor.data.serialize()
	check(editor.begin_paint(screen),"level can begin by sampling unchanged ground before a drag")
	check(editor.data.serialize()==saved,"sampling level leaves real ground unchanged")
	editor.cancel_input();check(editor.data.serialize()==saved,"cancel discards the level blueprint")
	editor.free();print("TERRAIN LEVEL ",checks," checks, ",failures," failures");quit(1 if failures else 0)
