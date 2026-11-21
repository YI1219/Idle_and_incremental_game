extends SceneTree
var checks:int=0
var failures:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run()->void:
	var editor:Node3D=load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	editor.set_process(false);editor.camera.set_process(false)
	editor.data.cells.clear()
	for z:int in range(-2,3):
		for x:int in range(-2,3):editor.data.cells[Vector2i(x,z)]={"height":4.0,"water":-1}
	for z:int in range(3,6):
		for x:int in range(-2,3):editor.data.cells[Vector2i(x,z)]={"height":1.5,"water":-1}
	editor.renderer.rebuild_all()
	editor.water_view.reset(editor.data)
	editor.camera._center=Vector2(0,1);editor.camera._height=21;editor.camera._pitch=35;editor.camera.advance(0)
	editor.tool="expand";editor.radius=1.1;editor.snap=true
	var top:=Vector3(.5,4,.5)
	var screen:Vector2=editor.camera.unproject_position(top)
	var hit:Dictionary=editor._pointer(screen)
	check(not hit.is_empty() and absf(hit.position.y-4.0)<.01,"expansion points at upper ground instead of default build plane")
	check(Vector2(hit.position.x,hit.position.z).distance_to(Vector2(.5,.5))<.1,"brush ground projection has no lower-plane XY offset")
	editor.tool="contract"
	var face_screen:Vector2=editor.camera.unproject_position(Vector3(.5,2.7,3.0))
	var face_hit:Dictionary=editor._pointer(face_screen)
	check(not face_hit.is_empty() and absf(face_hit.position.y-4.0)<.01,"side of upper terrace selects its highest crown above the lower receiver")
	editor.tool="expand"
	# Hover the upper terrace, then move just beyond its west edge.
	screen=editor.camera.unproject_position(Vector3(-2.5,4,.5))
	check(editor.begin_paint(screen),"adjacent upper edge starts a continuous expansion blueprint")
	if editor.blueprint_data!=null:
		var additions:int=0
		var heights_ok:bool=true
		for cell:Vector2i in editor.blueprint_data.cells:
			if editor.data.cells.has(cell):continue
			additions+=1;heights_ok=heights_ok and editor.blueprint_data.cells[cell].height==4.0
		check(additions>0 and heights_ok,"new land stays level with the touched upper terrace")
		editor.cancel_input()
	else:check(false,"upper expansion has additions")
	# Plane-locked removal must not erase the lower terrace under the ring.
	editor.tool="contract";editor.radius=3.8
	screen=editor.camera.unproject_position(Vector3(.5,4,1.5))
	check(editor.begin_paint(screen),"upper contraction starts")
	if editor.blueprint_data!=null:
		var lower_kept:bool=true
		for cell:Vector2i in editor.data.cells:
			if editor.data.cells[cell].height==1.5:lower_kept=lower_kept and editor.blueprint_data.cells.has(cell)
		check(lower_kept,"upper contraction preserves lower-tier ground")
		editor.cancel_input()
	else:check(false,"upper contraction has a blueprint")
	editor.tool="expand";editor.radius=1.0
	var far:Vector2=editor.camera.unproject_position(Vector3(-12,4,.5))
	check(not editor.begin_paint(far),"expansion does not create a detached lower pad far from the selected bank")
	# Refill a removed interior patch at the exact same projected pointer.
	editor.tool="contract";editor.radius=1.1
	screen=editor.camera.unproject_position(top)
	editor.begin_paint(screen);editor.commit_blueprint();editor.renderer.rebuild_all()
	editor.tool="expand";editor.build_height=4.0
	check(editor.begin_paint(screen),"same pointer can refill a removed upper patch")
	if editor.blueprint_data!=null:
		check(editor.blueprint_data.cells.has(Vector2i.ZERO),"refill stays under the original pointer rather than sliding to a wall anchor")
		var size_before:int=editor.blueprint_data.cells.size()
		editor.continue_paint(screen)
		check(editor.blueprint_data.cells.size()==size_before,"stationary refill does not walk away into extra land")
		editor.cancel_input()
	var before:Dictionary=editor.data.serialize()
	editor.tool="raise";editor.radius=1.0
	screen=editor.camera.unproject_position(Vector3(-.5,4,-.5))
	editor.begin_paint(screen)
	editor.radius=3.8
	check(editor.blueprint_data==null and not editor.painting and editor.data.serialize()==before,"changing brush size cancels an incompatible held draft")
	editor.free()
	print("TERRAIN SURFACE ANCHOR: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
