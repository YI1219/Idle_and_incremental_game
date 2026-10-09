extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	if not ResourceLoader.exists("res://scripts/terrain_editor/terrain_decoration.gd"):
		check(false,"terrain decoration implementation missing")
		quit(1)
		return
	var deco=load("res://scripts/terrain_editor/terrain_decoration.gd").new()
	var d=Data.new()
	for z in 8:
		for x in 8:d.cells[Vector2i(x,z)]={"height":1.0,"water":-1}
	var first:Dictionary=deco.placements(d,Vector2i.ZERO)
	check(first.grass.size()>8,"dry land has generated grass")
	check(first.get("grass_clump",[]).size()>0,"dry land has solid grass clumps")
	check(first.surface_rock.size()>0,"dry surface has individual rocks")
	check(first==deco.placements(d,Vector2i.ZERO),"placement is deterministic")
	# Rim blocks crown the island edge just above the turf, and ground modules
	# over a block sit on its crown (TerrainDecoration._rim_lift) instead of
	# being buried in it, so "ground height" there is the crown height.
	var expected_y:=func(at:Vector3)->float:
		var top:float=deco.rim_top_at(Vector2(at.x,at.z))
		return 1.0 if top==-INF else maxf(1.0,top-.04)
	for transform:Transform3D in first.grass:
		check(is_equal_approx(transform.origin.y,expected_y.call(transform.origin)),"grass follows ground height")
	for pose:Transform3D in first.get("grass_clump",[]):
		var on_crown:=false
		for column:Dictionary in deco._columns:
			if is_equal_approx(pose.origin.y,column.pose.origin.y-.05):on_crown=true
		check(on_crown or is_equal_approx(pose.origin.y,expected_y.call(pose.origin)),"solid grass clumps follow ground height")
	for transform:Transform3D in first.surface_rock:
		check(transform.origin.y<1.0,"surface rock origin embeds below ground")
	for cell in d.cells:d.cells[cell].height=1.5
	var raised:Dictionary=deco.placements(d,Vector2i.ZERO)
	check(raised.grass.size()==first.grass.size(),"raise preserves deterministic population count")
	for i in first.grass.size():
		check(is_equal_approx(raised.grass[i].origin.y-first.grass[i].origin.y,0.5),"raise moves grass with terrain")
	check(raised.get("grass_clump",[]).size()==first.get("grass_clump",[]).size(),"raise retains deterministic clump population")
	for i in first.get("grass_clump",[]).size():
		check(is_equal_approx(raised.grass_clump[i].origin.y-first.grass_clump[i].origin.y,.5),"raise moves solid clumps with terrain")
	for cell in d.cells:d.cells[cell].water=4
	var wet:Dictionary=deco.placements(d,Vector2i.ZERO)
	check(wet.get("grass_clump",[]).is_empty() and wet.grass.is_empty() and wet.tree.is_empty() and wet.bush.is_empty() and wet.surface_rock.is_empty(),"water removes surface vegetation and rocks")
	for cell in d.cells:
		d.cells[cell].water=-1
		d.cells[cell].height=1.0
	d.begin_stroke()
	d.apply_brush(Vector2(0.5,0.5),0.49,"contract",true,0,0)
	d.end_stroke()
	d.undo()
	check(deco.placements(d,Vector2i.ZERO)==first,"undo restores original automatic decoration")
	deco.load_assets()
	check(deco.assets.has("tree") and deco.assets.has("grass") and deco.assets.has("cliff_rock") and deco.assets.has("shore_rock") and deco.assets.has("fence"),"terrain and supporting CC0 model parts loaded")
	var low:=Data.new()
	for z in 8:
		for x in 8:low.cells[Vector2i(x,z)]={"height":-4.0,"water":-1}
	var low_field=load("res://scripts/terrain_editor/contour_terrain.gd").new()
	low_field.refresh(low)
	var floor_y:=INF
	for point:Vector3 in low_field.surfaces.cliff.vertices:floor_y=minf(floor_y,point.y)
	var low_vines:Array=deco.placements(low,Vector2i.ZERO).vine
	check(not low_vines.is_empty(),"minimum-height terrain still supplies hanging foliage")
	var supported:=true
	for pose:Transform3D in low_vines:
		if pose.origin.y<floor_y:supported=false
	check(supported,"hanging foliage roots stay above the actual cliff floor on minimum-height terrain")
	var parent:=Node3D.new()
	root.add_child(parent)
	deco.populate(parent,d,Vector2i.ZERO)
	check(parent.get_child_count()>0 and parent.get_child_count()<=20,"decoration uses grouped MultiMeshes")
	for child in parent.get_children():check(child is MultiMeshInstance3D,"no per-decoration model nodes")
	parent.free()
	print("TERRAIN EDITOR DECORATION: %d/%d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
