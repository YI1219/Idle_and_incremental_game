extends SceneTree
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
var checks := 0
var failures := 0
func check(ok:bool, message:String)->void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize()->void: call_deferred("run")
func run()->void:
	if not ResourceLoader.exists("res://scripts/terrain_editor/contour_terrain.gd"):
		check(false,"Terrain must expose shared organic contours and matching surface queries")
		quit(1)
		return
	var d := Data.new()
	for z in range(-6,7):
		for x in range(-6,7):
			if x*x+z*z<=36: d.cells[Vector2i(x,z)]={"height":1.5,"water":-1}
	for z in range(-2,3):
		for x in range(-2,3): d.cells.erase(Vector2i(x,z))
	var g = load("res://scripts/terrain_editor/contour_terrain.gd").new()
	g.refresh(d)
	check(g.surface_at(Vector2.ZERO).is_empty(),"contracted interior stays an actual hole in the rendered surface")
	check(g.surface_at(Vector2(4.5,0.5)).get("height",-99)==1.5,"continuous surface query matches grass cap")
	check(g.surface_at(Vector2(10,0)).is_empty(),"surface query excludes absent land")
	var diagonal := false
	for loop:PackedVector2Array in g.land_regions[1.5]:
		for i in loop.size():
			var delta := loop[(i+1)%loop.size()]-loop[i]
			if absf(delta.x)>.01 and absf(delta.y)>.01: diagonal=true
	check(diagonal,"organic boundary replaces orthogonal cell stairs")
	for chunk in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i.ZERO]:
		var mesh:Dictionary=g.build(chunk)
		for v in mesh.grass.get_faces():
			check(v.x>=chunk.x*8-.001 and v.x<=chunk.x*8+8+.001 and v.z>=chunk.y*8-.001 and v.z<=chunk.y*8+8+.001,"cap geometry stays within chunk ownership")
		var faces:PackedVector3Array=mesh.grass.get_faces()
		for i in range(0,faces.size(),3):
			for point in [Vector2.ZERO,Vector2(1,1),Vector2(-.8,1),Vector2(1,-.8)]:
				check(Geometry3D.ray_intersects_triangle(Vector3(point.x,10,point.y),Vector3.DOWN,faces[i],faces[i+1],faces[i+2])==null,"rendered triangles leave the contracted hole open")
	var cap:Array=g.build(Vector2i.ZERO).grass.surface_get_arrays(0)
	var cap_vertices:PackedVector3Array=cap[Mesh.ARRAY_VERTEX]
	var cap_normals:PackedVector3Array=cap[Mesh.ARRAY_NORMAL]
	check(cap_normals[0].y>.99 and (cap_vertices[1]-cap_vertices[0]).cross(cap_vertices[2]-cap_vertices[0]).y<0,"grass has upward normals with Godot clockwise front-face winding")
	var punctured=Data.new()
	for z in range(-10,11):
		for x in range(-10,11):punctured.cells[Vector2i(x,z)]={"height":1.5,"water":-1}
	for hole in [Vector2i(4,2),Vector2i(-5,4),Vector2i(2,-4)]:punctured.cells.erase(hole)
	var punctured_geometry=load("res://scripts/terrain_editor/contour_terrain.gd").new()
	punctured_geometry.refresh(punctured)
	for hole in [Vector2i(4,2),Vector2i(-5,4),Vector2i(2,-4)]:
		var faces:PackedVector3Array=punctured_geometry.build(Data.chunk_of(hole)).grass.get_faces()
		for i in range(0,faces.size(),3):check(Geometry3D.ray_intersects_triangle(Vector3(hole.x+.5,10,hole.y+.5),Vector3.DOWN,faces[i],faces[i+1],faces[i+2])==null,"small interior contractions cannot be filled by an enclosing cap triangle")
	var distant=Data.new()
	for z in range(-8,9):
		for x in range(-12,13):
			if x*x/144.0+z*z/64.0<=1:distant.cells[Vector2i(x,z)]={"height":1.5,"water":-1}
	var stable=load("res://scripts/terrain_editor/contour_terrain.gd").new()
	stable.refresh(distant)
	var original_boundary:Array=[]
	for loop:PackedVector2Array in stable.land_regions[1.5]:
		for p in loop:
			if p.x < -7:original_boundary.append(p)
	distant.begin_stroke()
	distant.apply_brush(Vector2(12.5,.5),1.6,"expand",false,1.5,3)
	distant.end_stroke()
	stable.refresh(distant)
	var edited_boundary:Array=[]
	for loop:PackedVector2Array in stable.land_regions[1.5]:
		for p in loop:
			if p.x < -7:edited_boundary.append(p)
	check(original_boundary==edited_boundary,"local editing preserves remote contour vertices so chunk boundaries cannot separate")
	var original:Dictionary=g.surface_at(Vector2(4.5,.5))
	d.begin_stroke()
	d.apply_brush(Vector2(4.5,.5),1.5,"raise",false,1.5,3)
	d.end_stroke()
	g.refresh(d)
	check(g.surface_at(Vector2(4.5,.5)).get("height",-99)==2.0,"raise updates visible contour surface")
	d.undo()
	g.refresh(d)
	check(g.surface_at(Vector2(4.5,.5))==original,"undo restores visible terrain")
	d.cells[Vector2i(4,0)]={"height":1.0,"water":3}
	d.invalidate(Vector2i(4,0))
	g.refresh(d)
	check(g.surface_at(Vector2(4.5,.5)).get("water",-1)==3,"water replaces surface through the same contour query")
	print("TERRAIN CONTOURS: %d/%d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
