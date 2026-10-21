extends SceneTree
const ContourTerrain = preload("res://scripts/terrain_editor/contour_terrain.gd")
## Geometric bounds for the exterior grass lip. Not an art acceptance.
var checks:=0
var failures:=0

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
	else:
		print("ok: ",message)

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var editor=load("res://scenes/terrain_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.set_process(false)
	_expect_lip(editor,"seed %d preset 0"%editor.data.seed)
	editor.data.seed=2104
	editor.renderer.rebuild_all()
	_expect_lip(editor,"seed 2104 preset 0")
	editor.data.seed=7301
	editor.select_preset(1)
	_expect_lip(editor,"seed 7301 preset 1")
	print("GRASS LIP CHECKS: ",checks," failures: ",failures)
	editor.free()
	quit(1 if failures>0 else 0)

func _expect_lip(editor,label:String)->void:
	var field=editor.renderer.contours
	var surface=field.surfaces.grass
	var vertices:PackedVector3Array=surface.vertices
	var normals:PackedVector3Array=surface.normals
	var colors:PackedColorArray=surface.colors
	var lowered:=0
	var tinted:=0
	var max_outside:=0.0
	var min_outside:=INF
	var min_lip_normal:=INF
	var interior:=0
	var below:=0
	var deepest_inside:=0.0
	var deepest_at:=Vector3.ZERO
	for i in vertices.size():
		var point:Vector3=vertices[i]
		var level:float=_level(field,point.y)
		var drop:float=level-point.y
		var outside:float=_outside(field.lawn_boundaries.get(level,[]),Vector2(point.x,point.z))
		if drop>0.28 or point.y>level+0.004:
			below+=1
			continue
		if outside<deepest_inside:
			deepest_inside=outside
			deepest_at=point
		if outside<-0.08:interior+=1
		if drop>0.06:
			lowered+=1
			max_outside=maxf(max_outside,outside)
			min_outside=minf(min_outside,outside)
			min_lip_normal=minf(min_lip_normal,normals[i].y)
			if colors[i].g<0.97:tinted+=1
	var skirt_inside:=_skirt_crossings(field,vertices)
	var rendered_lip:=0
	var rendered_flat:=0
	for chunk in editor.renderer.chunks.values():
		var grass=chunk.get_node_or_null("grass")
		if grass==null or grass.mesh==null or grass.mesh.get_surface_count()==0:continue
		var arrays:Array=grass.mesh.surface_get_arrays(0)
		var chunk_vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var chunk_normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in chunk_vertices.size():
			var drop:float=_level(field,chunk_vertices[i].y)-chunk_vertices[i].y
			if drop>0.06 and chunk_normals[i].y>0.35:rendered_lip+=1
			elif drop<0.004 and chunk_normals[i].y>0.98:rendered_flat+=1
	print("%s lowered=%d outside=%.3f..%.3f lip_normal=%.3f crossings=%d deepest=%.3f at %s"%[label,lowered,min_outside,max_outside,min_lip_normal,skirt_inside,deepest_inside,deepest_at])
	check(lowered>80,label+" has an exterior lip skirt")
	check(tinted*2>lowered,label+" lip carries a soil tint")
	check(min_outside>-0.02 and max_outside<0.45,label+" spill stays a short outward chamfer")
	check(min_lip_normal>0.35,label+" lip normals stay above the stone, not folded under")
	check(skirt_inside==0,label+" chamfer triangles stay outside the crown")
	check(deepest_inside>-0.02 and interior==0,label+" chamfer does not cut a trench into the crown")
	check(below==0,label+" no grass vertex leaves the lip band")
	check(rendered_lip>40 and rendered_flat>40,label+" chunk meshes keep the lip and the flat crown")

func _skirt_crossings(field,vertices:PackedVector3Array)->int:
	var crossings:=0
	for i in range(0,vertices.size(),3):
		var skirt:=false
		var centroid:=Vector3.ZERO
		for j in 3:
			centroid+=vertices[i+j]
			var level:float=_level(field,vertices[i+j].y)
			var drop:float=level-vertices[i+j].y
			var outside:float=_outside(field.lawn_boundaries.get(level,[]),Vector2(vertices[i+j].x,vertices[i+j].z))
			if drop>0.03 or outside>0.02:skirt=true
		if not skirt:continue
		centroid/=3.0
		var level:float=_level(field,centroid.y)
		if _outside(field.lawn_boundaries.get(level,[]),Vector2(centroid.x,centroid.z))<-0.03:crossings+=1
	return crossings

func _level(field,y:float)->float:
	var best:float=INF
	var found:float=y
	for level:float in field.levels:
		var distance:float=absf(level-y)
		if distance<best:
			best=distance
			found=level
	return found

func _outside(loops:Array,point:Vector2)->float:
	var distance:float=INF
	for loop:PackedVector2Array in loops:
		for i in loop.size():
			var a:Vector2=loop[i]
			var b:Vector2=loop[(i+1)%loop.size()]
			distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b)))
	if ContourTerrain.contains(loops,point):return -distance
	return distance
