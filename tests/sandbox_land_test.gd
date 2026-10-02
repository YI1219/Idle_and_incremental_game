extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String):
	checks+=1
	if not ok:
		failures+=1
		push_error(label)
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1280,720)
	var game=load("res://scenes/play.tscn").instantiate()
	root.add_child(game)
	for i in 8:await process_frame
	var builder=get_first_node_in_group("sandbox_builder")
	builder.set_active(true)
	var sim=builder.island.sim
	check(not builder.Layout.CATALOG.has("grove") and not builder.panel.buttons.has("grove"),"No bundled nature tool")
	for row in builder.layout.objects:check(row.kind!="grove","Starter nature is independent")
	check(sim.cell_count()==builder.island.terrain.land_cells.size(),"All rendered ground is represented in build data")
	check(sim.cell_count()<int(sim.cfg.land().hard_area_cap),"Initial yard leaves expansion capacity")
	# North/east/south/west, away from cottage and placed objects.
	for cell in [Vector2i(0,-6),Vector2i(6,0),Vector2i(-2,3),Vector2i(-6,-2)]:
		check(builder.edit_land(cell,true)=="ok","Can erase exterior ground "+str(cell))
		check(not builder.island.terrain.land_cells.has(cell),"Erased ground is visually removed "+str(cell))
		builder.island.rebuild_instances()
		check(not builder.island.terrain.land_cells.has(cell),"Refresh cannot resurrect ground "+str(cell))
		check(builder.edit_land(cell,false)=="ok","Can refill ground "+str(cell))
	for cell in [Vector2i(0,-7),Vector2i(7,-2),Vector2i(-2,4),Vector2i(-7,-2)]:
		check(builder.edit_land(cell,false)=="ok","Can expand each outer edge "+str(cell))
		check(sim.has_cell(cell) and builder.island.terrain.land_cells.has(cell),"Placement data and mesh agree")
	check(builder.edit_land(Vector2i(3,1),true)!="ok","Fixed bridge retains its supporting cells")
	check(builder.edit_land(Vector2i(0,-2),true)!="ok","House support protected")
	# Persist a removed former background cell, rather than regenerating it on load.
	builder.edit_land(Vector2i(-6,-2),true)
	var saved: Dictionary=builder.snapshot()
	check(saved.version==2,"New format marks authoritative whole-yard land")
	builder.edit_land(Vector2i(-6,-2),false)
	check(builder.restore_snapshot(saved)=="ok","New layout restores")
	check(not builder.island.terrain.land_cells.has(Vector2i(-6,-2)),"Removed background stays absent after restore")
	# Dragging paints a connected run even when pointer events skip cells.
	builder.choose("land")
	builder.begin_stroke(Vector2i(-7,-1))
	builder.continue_stroke(Vector2i(-10,-1))
	builder.end_stroke()
	for x in range(-10,-6):check(sim.has_cell(Vector2i(x,-1)),"Continuous stroke fills skipped cells")
	builder.choose("erase_land")
	builder.begin_stroke(Vector2i(-10,-1))
	builder.continue_stroke(Vector2i(-7,-1))
	builder.end_stroke()
	for x in range(-10,-6):check(not sim.has_cell(Vector2i(x,-1)),"Continuous erase removes painted run")
	builder.choose("land")
	builder.begin_stroke(Vector2i(-7,0))
	builder.cancel()
	builder.continue_stroke(Vector2i(-8,0))
	check(not sim.has_cell(Vector2i(-8,0)),"Cancel stops painting")
	# Recreate the prior release's v1 envelope, with 48 logical cells plus hidden support.
	var legacy_land: Array=[]
	for x in range(-4,4):
		for z in range(-2,4):legacy_land.append([x,z])
	var legacy={"version":1,"land":legacy_land,"layout":{"version":1,"objects":[{"id":0,"kind":"house","cell":[0,-2]},{"id":1,"kind":"grove","cell":[-6,-6]}]}}
	check(builder.restore_snapshot(JSON.parse_string(JSON.stringify(legacy)))=="ok","Legacy layout imports without losing surrounding ground")
	check(sim.cell_count()==130,"Legacy support converted into real cells")
	check(builder.layout.objects.size()==5,"Legacy bundle becomes four independently editable props")
	for row in builder.layout.objects:check(row.kind!="grove","Imported bundle is split")
	# Exercise the actual event route, including releasing/crossing the UI.
	builder.choose("land")
	await pointer_button(Vector2i(-7,0),true)
	await pointer_move(Vector2i(-9,0))
	await pointer_button(Vector2i(-9,0),false)
	check(sim.has_cell(Vector2i(-7,0)) and sim.has_cell(Vector2i(-8,0)) and sim.has_cell(Vector2i(-9,0)),"Mouse drag paints outer land")
	await pointer_move(Vector2i(-10,0))
	check(not sim.has_cell(Vector2i(-10,0)),"Mouse release ends stroke")
	await pointer_button(Vector2i(-7,2),true)
	var over_ui:=InputEventMouseMotion.new()
	over_ui.position=builder.panel.surface.get_global_rect().get_center()
	root.push_input(over_ui)
	await process_frame
	await pointer_move(Vector2i(-8,2))
	await pointer_button(Vector2i(-8,2),false)
	check(not sim.has_cell(Vector2i(-8,2)),"Crossing UI cancels stroke without painting behind panel")
	var before: String=JSON.stringify(builder.snapshot())
	var bad: Dictionary=legacy.duplicate(true)
	bad.layout.objects[1].cell=[9000,9000]
	check(builder.restore_snapshot(bad)!="ok" and JSON.stringify(builder.snapshot())==before,"Failed legacy conversion is atomic")
	game.queue_free()
	await process_frame
	print("SANDBOX LAND checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func pointer_button(cell: Vector2i,pressed: bool):
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.position=root.get_camera_3d().unproject_position(Vector3(cell.x+.5,0,cell.y+.5))
	root.push_input(event)
	await process_frame
func pointer_move(cell: Vector2i):
	var event:=InputEventMouseMotion.new()
	event.position=root.get_camera_3d().unproject_position(Vector3(cell.x+.5,0,cell.y+.5))
	root.push_input(event)
	await process_frame
