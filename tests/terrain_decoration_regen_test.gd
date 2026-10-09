extends SceneTree
## Lookdev decoration follows terrain edits. The homestead island is edited
## through TerrainData's brush/undo API and published by the real
## TerrainRenderer; after every step each visible decoration instance (rim
## blocks, underside boulders, shore stones, vines, plant modules, every
## chunk) must equal a from-scratch placement computed from the current
## height data alone, so nothing survives from an earlier revision.
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Renderer=preload("res://scripts/terrain_editor/terrain_renderer.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration=preload("res://scripts/terrain_editor/terrain_decoration.gd")
const RIM:=["cliff_column","cliff_column_b","cliff_column_c","cliff_column_d"]
var checks:=0
var failures:=0
var fresh:=Decoration.new()
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func drain(renderer)->void:
	while renderer.has_pending_updates():renderer.flush_dirty(2)
func published(renderer)->Dictionary:
	# chunk -> MultiMesh name -> instance transforms
	var result:Dictionary={}
	for chunk in renderer.chunks:
		var groups:Dictionary={}
		for child in renderer.chunks[chunk].get_children():
			if not child is MultiMeshInstance3D:continue
			var poses:Array=[]
			for i in child.multimesh.instance_count:poses.append(child.multimesh.get_instance_transform(i))
			groups[String(child.name)]=poses
		if not groups.is_empty():result[chunk]=groups
	return result
func recomputed(data)->Dictionary:
	# Independent copy of the cells, new contours, and a layout cache that
	# has never seen an earlier revision.
	var copy:=Data.new()
	copy.seed=data.seed
	for cell in data.cells:copy.cells[cell]=data.cells[cell].duplicate()
	var field:=Contours.new()
	field.refresh(copy)
	fresh.contours=field
	fresh.load_assets()
	# The renderer's run cache is the optimization under test. This copy
	# places from the heights alone, with nothing kept from an earlier edit.
	fresh._run_cache.clear()
	var chunks:Dictionary={}
	for cell:Vector2i in copy.cells:
		for z in range(-1,2):
			for x in range(-1,2):chunks[Data.chunk_of(cell+Vector2i(x,z))]=true
	var result:Dictionary={}
	for chunk in chunks:
		var groups:Dictionary={}
		var placed:Dictionary=fresh.placements(copy,chunk)
		for kind in placed:
			if placed[kind].is_empty() or not fresh.assets.has(kind):continue
			for index in fresh.assets[kind].size():
				var poses:Array=[]
				for pose:Transform3D in placed[kind]:poses.append(pose*fresh.assets[kind][index].pose)
				groups[kind+"_%d"%index]=poses
		if not groups.is_empty():result[chunk]=groups
	return result
func same(a:Dictionary,b:Dictionary)->String:
	for chunk in a.keys()+b.keys():
		if not a.has(chunk) or not b.has(chunk):return "chunk %s present on one side only"%chunk
		for name in a[chunk].keys()+b[chunk].keys():
			if not a[chunk].has(name) or not b[chunk].has(name):return "%s %s present on one side only"%[chunk,name]
			var left:Array=a[chunk][name]
			var right:Array=b[chunk][name]
			if left.size()!=right.size():return "%s %s count %d vs %d"%[chunk,name,left.size(),right.size()]
			for i in left.size():
				if not (left[i] as Transform3D).is_equal_approx(right[i]):return "%s %s instance %d moved: %s vs %s"%[chunk,name,i,left[i],right[i]]
	return ""
func follows(renderer,data,label:String)->void:
	drain(renderer)
	var difference:=same(published(renderer),recomputed(data))
	check(difference=="",label+": published decoration equals a fresh placement from current heights ("+difference+")")
	# Rim blocks stand on the current turf: crown .03-.15 m above the land at
	# their edge, and every block belongs to land that still exists.
	var field=renderer.contours
	var floating:=0
	for column:Dictionary in renderer.decoration._columns:
		var edge:Vector2=column.edge
		var out:=Vector2(column.outward.x,column.outward.z)
		var turf:Dictionary=field.surface_at(edge-out*.3)
		if turf.is_empty() or turf.water>=0:floating+=1;continue
		var rise:float=column.pose.origin.y-float(turf.height)
		if rise<.02 or rise>.16:floating+=1
	check(floating==0,label+": every rim block crown sits just above current turf (%d off)"%floating)
func kinds(state:Dictionary,names:Array)->Array:
	var poses:Array=[]
	for chunk in state:
		for name in names:poses.append_array(state[chunk].get(name+"_0",[]))
	return poses
func near(poses:Array,center:Vector2,radius:float)->int:
	var count:=0
	for pose:Transform3D in poses:
		if Vector2(pose.origin.x,pose.origin.z).distance_to(center)<radius:count+=1
	return count
func run()->void:
	# The headless dummy renderer keeps no MultiMesh buffer, so every instance
	# would read back as identity and the comparisons would pass vacuously.
	var probe:=MultiMesh.new()
	probe.transform_format=MultiMesh.TRANSFORM_3D
	probe.mesh=BoxMesh.new()
	probe.instance_count=1
	probe.set_instance_transform(0,Transform3D(Basis(),Vector3.ONE))
	if probe.get_instance_transform(0).origin!=Vector3.ONE:
		push_error("terrain_decoration_regen_test needs a rendering device (run with a display, not --headless)")
		quit(1)
		return
	var data:=Data.new()
	data.make_preset(0)
	var renderer:=Renderer.new()
	root.add_child(renderer)
	renderer.decoration=Decoration.new()
	renderer.configure(data)
	renderer.rebuild_all()
	follows(renderer,data,"initial island")
	var initial:=published(renderer)
	check(kinds(initial,RIM).size()>=40,"homestead rim is clad by rim blocks (%d)"%kinds(initial,RIM).size())
	check(kinds(initial,["underside_rock","underside_rock_b"]).size()>=8,"underside boulders hang below the shell")
	check(kinds(initial,["shore_rock","shore_boulder","shore_pebble"]).size()>=8,"lake banks carry shore stones")
	# Expand: new land on the lower terrace's dry right edge grows its own
	# rock-native rim, boulders and vines where there was only sky.
	var expand_center:=Vector2(19.2,4.6)
	check(not data.cells.has(Vector2i(20,4)),"expand target starts as open sky")
	check(near(kinds(initial,RIM),Vector2(20.6,4.6),1.0)==0,"no rim block exists beyond the old edge")
	var original_cells:=data.cells.keys()
	data.begin_stroke();data.apply_brush(expand_center,2.8,"expand",false,1.5,3);data.end_stroke()
	follows(renderer,data,"expand")
	var expanded:=published(renderer)
	var on_new_land:=0
	for column:Dictionary in renderer.decoration._columns:
		var inside:Vector2=column.edge-Vector2(column.outward.x,column.outward.z)*.3
		if not Vector2i(inside.floor()) in original_cells:on_new_land+=1
	check(on_new_land>=3,"expanded land carries new rim blocks on its new edge (%d)"%on_new_land)
	check(renderer.decoration.layout_hits>renderer.decoration.layout_misses,"expand rebuilds only changed rim runs (%d hits, %d misses, %.2f ms)"%[renderer.decoration.layout_hits,renderer.decoration.layout_misses,renderer.decoration.layout_ms])
	check(near(kinds(expanded,["underside_rock","underside_rock_b"]),expand_center,4.5)>near(kinds(initial,["underside_rock","underside_rock_b"]),expand_center,4.5),"expanded edge gains its own underside boulders")
	check(near(kinds(expanded,["vine"]),expand_center,4.0)>0,"vines re-seat on the expanded rim")
	# Raise part of the new land twice: the blocks follow the new top.
	data.begin_stroke();data.apply_brush(Vector2(18.6,4.4),2.2,"raise",false,1.5,3);data.end_stroke()
	data.begin_stroke();data.apply_brush(Vector2(18.6,4.4),2.2,"raise",false,1.5,3);data.end_stroke()
	follows(renderer,data,"raise")
	var raised_tops:=0
	for column:Dictionary in renderer.decoration._columns:
		if column.edge.distance_to(Vector2(18.6,4.4))<2.6 and column.pose.origin.y>2.4:raised_tops+=1
	check(raised_tops>0,"rim blocks on raised land stand at the raised height")
	# Save/load of the edited island republishes the same decoration.
	var saved:=data.serialize()
	var before_load:=published(renderer)
	check(data.deserialize(saved),"edited island deserializes")
	renderer.rebuild_all()
	check(same(published(renderer),before_load)=="","loaded island republishes identical decoration")
	follows(renderer,data,"load")
	# Contract a stretch of the upper terrace's clad outer wall: blocks,
	# boulders and vines on the removed cells vanish and the new edge is clad.
	data.make_preset(0)
	renderer.rebuild_all()
	follows(renderer,data,"preset reset")
	var target:Vector2
	for column:Dictionary in renderer.decoration._columns:
		if column.edge.x< -12 and column.edge.y>1 and column.pose.origin.y>3:target=column.edge;break
	check(target!=Vector2.ZERO,"found a clad upper-terrace wall to contract")
	var carve:=target-Vector2(0,.6)
	var kept_cells:=data.cells.keys()
	var on_carved:=func()->int:
		var count:=0
		for column:Dictionary in renderer.decoration._columns:
			var inside:Vector2=column.edge-Vector2(column.outward.x,column.outward.z)*.3
			if Vector2i(inside.floor()) in kept_cells and not Vector2i(inside.floor()) in data.cells:count+=1
		return count
	var doomed:=0
	for column:Dictionary in renderer.decoration._columns:
		var inside:Vector2=column.edge-Vector2(column.outward.x,column.outward.z)*.3
		if (inside.floor()+Vector2(.5,.5)).distance_to(carve)<1.6:doomed+=1
	check(doomed>0,"blocks stand on the cells about to be contracted (%d)"%doomed)
	data.begin_stroke();data.apply_brush(carve,1.6,"contract",false,1.5,3);data.end_stroke()
	follows(renderer,data,"contract")
	check(kept_cells.size()>data.cells.size(),"contract removed cells")
	check(on_carved.call()==0,"no rim block remains on contracted cells")
	check(near(kinds(published(renderer),RIM),carve,3.2)>0,"the contracted edge is re-clad by rim blocks")
	# Undo every edit since the reset: the exact original decoration returns.
	check(data.undo(),"contract undoes")
	follows(renderer,data,"undo contract")
	check(same(published(renderer),initial)=="","undo restores the initial decoration exactly")
	# Redo then undo again stays consistent with the data.
	check(data.redo(),"contract redoes")
	follows(renderer,data,"redo contract")
	data.undo()
	drain(renderer)
	check(same(published(renderer),initial)=="","second undo restores the initial decoration exactly")
	# Expand/raise undo chain on the original island (the reset cleared history).
	data.begin_stroke();data.apply_brush(expand_center,2.8,"expand",false,1.5,3);data.end_stroke()
	data.begin_stroke();data.apply_brush(Vector2(18.6,4.4),2.2,"raise",false,1.5,3);data.end_stroke()
	follows(renderer,data,"expand and raise again")
	data.undo();data.undo()
	follows(renderer,data,"undo expand and raise")
	check(same(published(renderer),initial)=="","undoing expand and raise restores the initial decoration exactly")
	print("RIM BAKE us=%d"%renderer.decoration.model_library.block_bake_us)
	renderer.free()
	print("TERRAIN DECORATION REGEN: %d/%d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
