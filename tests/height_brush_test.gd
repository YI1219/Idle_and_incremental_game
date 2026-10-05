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
	check(str(ProjectSettings.get_setting("application/run/main_scene"))=="res://scenes/play.tscn","Godot Play uses the floating-island scene")
	check(not ResourceLoader.exists("res://scenes/courtyard_study.tscn"),"No separate study level remains")
	var game=load("res://scenes/play.tscn").instantiate()
	root.add_child(game)
	for i in 8:await process_frame
	var builder=get_first_node_in_group("sandbox_builder")
	var terrain=builder.island.terrain
	check(terrain.STEP>=.15 and terrain.STEP<=.4,"Terrace step stays inside 0.15–0.4 m")
	check(terrain.MAX_LEVEL==3,"Four terrace levels are 0 through 3")
	var levels: Dictionary={}
	for cell in terrain.water_cells:levels[terrain.level_of(cell)]=true
	check(levels.has(0) and levels.has(3),"Upper and lower water sit on different terraces")
	check(terrain.has_step_fall() and terrain.has_edge_fall(),"Short connecting fall and long edge fall both exist")
	check(terrain.FALL_DROP>terrain.STEP*2.0,"Edge fall is longer than the two-step basin drop")
	check(terrain.get_node("Waterfall").mesh.get_faces().size()>24,"Waterfalls are a merged mesh")
	var home: Vector2i=builder.layout.find(0).cell
	check(terrain.level_of(home)>=2,"Cottage sits on the upper terrace")
	var kinds: Dictionary={}
	var nature:=0
	for row in builder.layout.objects:
		if row.kind=="house":continue
		nature+=1
		kinds[row.kind]=true
		check(not terrain.water_cells.has(row.cell),"Nature prop stands on dry land")
	check(nature>=8,"At least eight removable nature props")
	for kind in ["tree","rock","bush","grass"]:check(kinds.has(kind),"Nature includes "+kind)
	var sample: int=builder.layout.at(Vector2i(-6,-5))
	check(builder.commit_remove(sample)=="ok","A tree can be removed on its own")
	var dry:=Vector2i(6,2)
	check(terrain.level_of(dry)==0,"Lower sample starts at the base terrace")
	check(builder.edit_height(dry,1)=="ok","Raise brush lifts one terrace")
	check(terrain.level_of(dry)==1 and is_equal_approx(terrain.surface_y(dry),terrain.STEP),"Raised cell height is authoritative")
	check(_top_matches(terrain,dry),"Raised mesh follows the cell height")
	check(builder.edit_height(dry,-1)=="ok","Sink brush lowers one terrace")
	check(terrain.level_of(dry)==0,"Sunk cell returns to the base")
	check(builder.edit_height(dry,-1)=="height_floor","Sink stops at the lowest terrace")
	for i in 3:check(builder.edit_height(dry,1)=="ok","Can climb toward the cap")
	check(builder.edit_height(dry,1)=="height_cap","Raise stops at four levels")
	check(builder.edit_height(Vector2i(3,1),1)=="bridge","Bridge deck stays at the foot terrace")
	builder.edit_height(dry,-1)
	builder.edit_height(dry,-1)
	builder.edit_height(dry,-1)
	builder.set_active(true)
	check(builder.snap_line,"Snap guide is on by default")
	builder.choose("land")
	builder.preview_at(Vector2i(-6,-1))
	check(builder._snap_guide.visible,"Expand tool shows a snap line before the stroke")
	builder.begin_stroke(Vector2i(-7,-1))
	builder.continue_stroke(Vector2i(-10,-3))
	builder.end_stroke()
	for x in range(-10,-6):check(builder.island.sim.has_cell(Vector2i(x,-1)),"Snap keeps an expansion on one line")
	check(not builder.island.sim.has_cell(Vector2i(-10,-3)) and not builder.island.sim.has_cell(Vector2i(-9,-2)),"Snap does not paint off the guide line")
	builder.toggle_snap()
	check(not builder.snap_line and not builder._snap_guide.visible,"Snap can be turned off")
	builder.choose("land")
	builder.begin_stroke(Vector2i(-7,0))
	builder.continue_stroke(Vector2i(-9,2))
	builder.end_stroke()
	check(builder.island.sim.has_cell(Vector2i(-9,2)) and builder.island.sim.has_cell(Vector2i(-8,0)),"Free stroke can leave the straight line")
	builder.toggle_snap()
	builder.choose("raise_land")
	var raised:=Vector2i(6,2)
	var before: int=terrain.level_of(raised)
	builder.begin_stroke(raised)
	builder.continue_stroke(Vector2i(6,3))
	builder.end_stroke()
	check(before==0 and terrain.level_of(raised)==1 and terrain.level_of(Vector2i(6,3))==1,"Raise stroke follows the snap column")
	check(terrain.level_of(Vector2i(5,2))==0,"Raise snap does not climb a neighboring column")
	var saved: Dictionary=builder.snapshot()
	var water_levels: Dictionary={}
	for cell in terrain.water_cells:water_levels[cell]=terrain.level_of(cell)
	var height_before: Dictionary=terrain.heights.duplicate()
	var objects_before: Array=[]
	for row in builder.layout.objects:objects_before.append([row.kind,row.cell,terrain.level_of(row.cell)])
	builder.edit_height(Vector2i(-6,-6),-1)
	check(builder.restore_snapshot(saved)=="ok","Height layout reloads")
	check(terrain.water_cells.size()==water_levels.size(),"Reloaded water keeps both basins")
	for cell in water_levels:check(terrain.water_cells.has(cell) and terrain.level_of(cell)==int(water_levels[cell]),"Water cell and level survived reload "+str(cell))
	for cell in height_before:check(int(terrain.heights.get(cell,0))==int(height_before[cell]),"Terrace height survived reload "+str(cell))
	check(builder.layout.objects.size()==objects_before.size(),"Reloaded props keep their count")
	for spec in objects_before:
		var found:=false
		for row in builder.layout.objects:
			if row.kind==spec[0] and row.cell==spec[1] and terrain.level_of(row.cell)==spec[2]:found=true
		check(found,"Reloaded prop keeps cell and height "+str(spec))
	check(terrain.has_step_fall() and terrain.has_edge_fall(),"Reloaded island still has both drops")
	game.queue_free()
	await process_frame
	print("HEIGHT BRUSH checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func _top_matches(terrain: Node3D,cell: Vector2i) -> bool:
	var faces: PackedVector3Array=terrain.get_node("LandSurface").mesh.get_faces()
	var wanted: float=terrain.surface_y(cell)
	for vertex in faces:
		if vertex.x>=cell.x-.01 and vertex.x<=cell.x+1.01 and vertex.z>=cell.y-.01 and vertex.z<=cell.y+1.01:
			if absf(vertex.y-wanted)<.001:return true
	return false
