extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Renderer=preload("res://scripts/terrain_editor/terrain_renderer.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func state(renderer)->Dictionary:
	var result:Dictionary={}
	for chunk in renderer.chunks:
		var contents:Dictionary={}
		for child in renderer.chunks[chunk].get_children():
			if child is MeshInstance3D:contents[child.name]=child.mesh.get_faces()
			elif child is MultiMeshInstance3D:
				var poses:Array=[]
				for i in child.multimesh.instance_count:poses.append(child.multimesh.get_instance_transform(i))
				contents[child.name]=poses
		result[chunk]=contents
	return result
func drain(renderer)->void:
	while renderer.has_pending_updates():renderer.flush_dirty(2)
func equivalent(renderer,label:String)->void:
	drain(renderer)
	var incremental:=state(renderer)
	renderer.rebuild_all()
	check(state(renderer)==incremental,label+" incremental meshes and decorations equal a fresh reconstruction")
func run()->void:
	var d:=Data.new()
	for z in range(-5,6):
		for x in range(-18,10):d.cells[Vector2i(x,z)]={"height":1.5,"water":-1}
	var renderer:=Renderer.new()
	root.add_child(renderer)
	renderer.decoration=load("res://scripts/terrain_editor/terrain_decoration.gd").new()
	renderer.configure(d)
	renderer.rebuild_all()
	var remote_cliff:PackedVector3Array=renderer.chunks[Vector2i(-2,0)].get_node("cliff").mesh.get_faces()
	for operation in ["lower","undo","contract","undo"]:
		if operation=="undo":d.undo()
		else:
			d.begin_stroke()
			d.apply_brush(Vector2(9.5,.5),.49,operation,true,1.5,3)
			d.end_stroke()
		var before:=state(renderer)
		renderer.flush_dirty(2)
		check(renderer.has_pending_updates() and state(renderer)==before,operation+" keeps the complete visible revision while chunks prepare")
		equivalent(renderer,operation)
		check(renderer.chunks[Vector2i(-2,0)].get_node("cliff").mesh.get_faces()==remote_cliff,operation+" preserves distant cliff shape")
	# Sustained input must not restart an in-flight revision indefinitely.
	var visible:=state(renderer)
	var publications:=0
	for frame in 40:
		d.begin_stroke()
		d.apply_brush(Vector2(-15.5+float(frame%20),-2.5),.49,"raise",true,1.5,3)
		d.end_stroke()
		renderer.flush_dirty(2)
		if state(renderer)!=visible:publications+=1;visible=state(renderer)
	check(publications>=3,"continuous painting publishes complete terrain revisions without starvation")
	equivalent(renderer,"continuous painting")
	for width in [1,8]:
		var thin:=Data.new()
		for x in width:thin.cells[Vector2i(x,0)]={"height":1.5,"water":-1}
		var shell=load("res://scripts/terrain_editor/contour_terrain.gd").new()
		shell.refresh(thin)
		var lower_side:=INF
		var upper_side:=-INF
		for point in shell.surfaces.cliff.vertices:
			if point.y<-4.2:lower_side=minf(lower_side,point.z);upper_side=maxf(upper_side,point.z)
		check(lower_side>.01 and upper_side<.99,"single-cell-width cliff bottoms remain inside their support without inversion")
	var far:=Data.new()
	for z in range(100,106):
		for x in range(100,106):far.cells[Vector2i(x,z)]={"height":1.5,"water":-1}
	renderer.configure(far)
	renderer.rebuild_all()
	var minimum:=INF
	for chunk in renderer.chunks:
		for point in renderer.chunks[chunk].get_node("cliff").mesh.get_faces():minimum=minf(minimum,point.x)
	check(minimum>98,"off-origin islands retain a locally tapered silhouette")
	far.cells[Vector2i(102,102)].water=3
	far.invalidate(Vector2i(102,102))
	drain(renderer)
	# A separate wet cell spills into empty sky. Its visible curtain extends below the base.
	var wet:=Data.new()
	wet.cells[Vector2i.ZERO]={"height":1.0,"water":3}
	renderer.configure(wet)
	renderer.rebuild_all()
	var fall_hit:Dictionary={}
	for chunk in renderer.chunks:
		var fall=renderer.chunks[chunk].get_node_or_null("waterfall")
		if fall==null:continue
		var faces:PackedVector3Array=fall.mesh.get_faces()
		for i in range(0,faces.size(),3):
			var center:Vector3=(faces[i]+faces[i+1]+faces[i+2])/3.0
			if center.y>=-6:continue
			var normal:Vector3=(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
			fall_hit=renderer.pick(center+normal*3,-normal)
			if not fall_hit.is_empty():break
		if not fall_hit.is_empty():break
	check(not fall_hit.is_empty(),"visible lower waterfalls remain pickable below the cliff base")
	var house:=Data.new()
	house.make_preset(0)
	renderer.configure(house)
	renderer.rebuild_all()
	var cottage=renderer.props.get_node("ReferenceCottage")
	check(cottage.visible,"reference cottage starts supported")
	house.begin_stroke()
	house.apply_brush(Vector2(-10.5,-6.5),.49,"contract",true,1.5,3)
	house.end_stroke()
	drain(renderer)
	check(not cottage.visible,"interior footprint holes remove cottage support")
	renderer.free()
	print("TERRAIN INCREMENTAL: %d/%d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
