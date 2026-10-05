extends SceneTree
var checks:=0
var failures:=0
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func chunk_state(node:Node3D)->Dictionary:
	var result:Dictionary={}
	for child in node.get_children():
		if child is MeshInstance3D:result[child.name]=child.mesh.get_faces()
		elif child is MultiMeshInstance3D:
			var transforms:Array[Transform3D]=[]
			for i in child.multimesh.instance_count:transforms.append(child.multimesh.get_instance_transform(i))
			result[child.name]=transforms
	return result
func _initialize()->void: call_deferred("run")
func run()->void:
	if not ResourceLoader.exists("res://scripts/terrain_editor/terrain_renderer.gd"):
		check(false,"chunk renderer implementation missing")
		quit(1)
		return
	var geom=load("res://scripts/terrain_editor/chunk_geometry.gd")
	var renderer=load("res://scripts/terrain_editor/terrain_renderer.gd").new()
	root.add_child(renderer)
	var d=Data.new()
	d.cells[Vector2i.ZERO]={"height":1.0,"water":-1}
	d.cells[Vector2i.RIGHT]={"height":0.0,"water":-1}
	d.invalidate(Vector2i.ZERO)
	var g:Dictionary=geom.build(d,Vector2i.ZERO)
	check(g.grass.get_faces().size()>0,"dry cells generate merged grass")
	var step:=false
	for v in g.cliff.get_faces():
		if is_equal_approx(v.x,1.0) and v.y>=0 and v.y<=1: step=true
	check(step,"height difference exposes shared-side cliff")
	check(g.cliff.get_faces().size()>18,"outer edges generate cliff faces")
	d.cells[Vector2i.ZERO]={"height":-0.5,"water":0}
	g=geom.build(d,Vector2i.ZERO)
	check(g.water.get_faces().size()>0,"isolated water renders")
	check(g.bank.get_faces().size()>0,"isolated water has rounded bank")
	var land_over_water:=false
	for v in g.grass.get_faces():
		if v.x<1 and v.z<1 and v.y>=0: land_over_water=true
	check(not land_over_water,"grass does not cover water cell")
	var offsets=[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1)]
	var polys:Dictionary={}
	for mask in 256:
		var m=Data.new()
		m.cells[Vector2i.ZERO]={"height":-0.5,"water":0}
		for bit in 8:
			if mask&(1<<bit): m.cells[offsets[bit]]={"height":-0.5,"water":0}
		var shape:PackedVector2Array=geom.water_polygon(m.water_mask(Vector2i.ZERO))
		polys[m.water_mask(Vector2i.ZERO)]=str(shape)
		check(Geometry2D.triangulate_polygon(shape).size()>0,"connection state triangulates")
	check(polys.size()==47,"all 47 rendered states exercised")
	var unique:Dictionary={}
	for p in polys.values(): unique[p]=true
	check(unique.size()==47,"47 states have distinct bank contours")
	# Adjacent blob contours must meet exactly, including concave-to-straight banks.
	for configuration in 16:
		var paired=Data.new()
		paired.cells[Vector2i.ZERO]={"height":-0.5,"water":0}
		paired.cells[Vector2i.RIGHT]={"height":-0.5,"water":0}
		var around=[Vector2i(0,-1),Vector2i(1,-1),Vector2i(0,1),Vector2i(1,1)]
		for bit in 4:
			if configuration&(1<<bit):paired.cells[around[bit]]={"height":-0.5,"water":0}
		var left:PackedVector2Array=geom.water_polygon(paired.water_mask(Vector2i.ZERO))
		var right:PackedVector2Array=geom.water_polygon(paired.water_mask(Vector2i.RIGHT))
		var left_edge:PackedFloat32Array=[]
		var right_edge:PackedFloat32Array=[]
		for point in left:
			if is_equal_approx(point.x,1.0):left_edge.append(point.y)
		for point in right:
			if is_equal_approx(point.x,0.0):right_edge.append(point.y)
		left_edge.sort()
		right_edge.sort()
		check(is_equal_approx(left_edge[0],right_edge[0]),"joined north bank endpoints match for configuration %d"%configuration)
		check(is_equal_approx(left_edge[-1],right_edge[-1]),"joined south bank endpoints match for configuration %d"%configuration)
	d.cells[Vector2i.ZERO]={"height":1.0,"water":3}
	d.cells[Vector2i.RIGHT]={"height":0.0,"water":1}
	g=geom.build(d,Vector2i.ZERO)
	check(g.waterfall.get_faces().size()>0,"high water spills toward lower water")
	# Every allowed water elevation must have supported banks above a deep floor.
	for level in 8:
		var deep=Data.new()
		for z in range(-1,2):
			for x in range(-1,2):deep.cells[Vector2i(x,z)]={"height":-4.0,"water":-1}
		deep.cells[Vector2i.ZERO].water=level
		var deep_geometry:Dictionary=geom.build(deep,Vector2i.ZERO)
		for side_index in 4:
			var connected:=false
			for vertex in deep_geometry.cliff.get_faces():
				var on_edge:bool=(is_equal_approx(vertex.z,0) if side_index==0 else is_equal_approx(vertex.x,1) if side_index==1 else is_equal_approx(vertex.z,1) if side_index==2 else is_equal_approx(vertex.x,0))
				if on_edge and is_equal_approx(vertex.y,level*0.5+0.018):connected=true
			check(connected,"deep water bank has a supporting wall for level %d side %d"%[level,side_index])
	renderer.decoration=load("res://scripts/terrain_editor/terrain_decoration.gd").new()
	renderer.configure(d)
	renderer.rebuild_all()
	var hit:Dictionary=renderer.pick(Vector3(0.5,10,0.5),Vector3.DOWN)
	check(not hit.is_empty() and absf(hit.position.y-1.5)<0.01,"pick uses water height")
	var corner_hit:Dictionary=renderer.pick(Vector3(-0.1,0.5,0.88),Vector3(1,0,1))
	check(not corner_hit.is_empty(),"picking cannot skip a short diagonal crossing of an occupied cell")
	check(renderer.pick(Vector3(6,10,6),Vector3.DOWN).is_empty(),"pick misses absent cells")
	var side:Dictionary=renderer.pick(Vector3(-3,0.5,0.5),Vector3.RIGHT)
	check(not side.is_empty() and side.cell==Vector2i.ZERO,"pick hits vertical island side")
	d.dirty_chunks.clear()
	d.invalidate(Vector2i(3,3))
	check(renderer.flush_dirty(1)==1 and d.dirty_chunks.is_empty(),"interior edit only rebuilds one chunk")
	check(renderer.flush_dirty()==0,"idle renderer does not rebuild")
	d.invalidate(Vector2i(7,7))
	check(d.dirty_chunks.size()==4,"chunk corner includes three neighbor chunks")
	var original_chunk:Dictionary=chunk_state(renderer.chunks[Vector2i.ZERO])
	d.begin_stroke()
	d.apply_brush(Vector2(0.5,0.5),0.49,"contract",true,0,0)
	d.end_stroke()
	d.undo()
	while not d.dirty_chunks.is_empty():renderer.flush_dirty(1)
	check(chunk_state(renderer.chunks[Vector2i.ZERO])==original_chunk,"queued edit/undo restores actual chunk meshes and MultiMesh transforms")
	hit=renderer.pick(Vector3(0.5,10,0.5),Vector3.DOWN)
	check(not hit.is_empty() and hit.position.y==1.5,"queued edit and undo converge to latest data")
	check(renderer.get_child_count()<=4,"renderer creates chunks rather than per-cell nodes")
	renderer.free()
	print("TERRAIN EDITOR RENDER: %d/%d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
