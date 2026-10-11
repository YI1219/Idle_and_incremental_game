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
	check(first.grass.is_empty(),"dry lawn uses terrain cover, without flattened loose blade discs")
	check(first.get("grass_clump",[]).is_empty(),"reed-like clumps require pond-bank support")
	check(first.surface_rock.size()>0,"dry surface has individual rocks")
	check(first==deco.placements(d,Vector2i.ZERO),"placement is deterministic")
	for transform:Transform3D in first.surface_rock:
		check(transform.origin.y<1.0,"surface rock origin embeds below ground")
	for cell in d.cells:d.cells[cell].height=1.5
	var raised:Dictionary=deco.placements(d,Vector2i.ZERO)
	check(raised.surface_rock.size()==first.surface_rock.size(),"raise preserves deterministic rock population")
	for i in first.surface_rock.size():
		check(is_equal_approx(raised.surface_rock[i].origin.y-first.surface_rock[i].origin.y,.5),"raise moves supported rocks with terrain")
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
	# A half-metre cliff has no room for a long vine. The old passing
	# population was horizontal lawn sprays, now intentionally removed.
	var low_deco=load("res://scripts/terrain_editor/terrain_decoration.gd").new()
	low_deco.load_assets()
	low_deco._column_layout(low_field,low.seed)
	check(not low_field.surfaces.rim_green.vertices.is_empty(),"minimum-height terrain retains attached moss instead of loose top sprays")
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
