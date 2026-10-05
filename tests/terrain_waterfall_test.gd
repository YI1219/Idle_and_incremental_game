extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Geometry=preload("res://scripts/terrain_editor/chunk_geometry.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func shared_edge(field:Contours,label:String)->void:
	field.surfaces.waterfall=Geometry.Surface.new()
	# A straight outlet with a shared vertex over differently edited receivers.
	field._falls(PackedVector2Array([Vector2(0,0),Vector2(2,0),Vector2(4,0),Vector2(4,4),Vector2(0,4)]),3.545)
	var vertices:PackedVector3Array=field.surfaces.waterfall.vertices
	for height in [1.9,2.2,2.7,3.2]:
		var crossings:Array=[]
		for i in range(0,vertices.size(),3):
			for side in 3:
				var a:=vertices[i+side]
				var b:=vertices[i+(side+1)%3]
				if absf(a.x-2)>.00001 or absf(b.x-2)>.00001 or a.z>0 or b.z>0:continue
				if absf(a.y-b.y)<.00001 or height<minf(a.y,b.y) or height>maxf(a.y,b.y):continue
				crossings.append(a.lerp(b,(height-a.y)/(b.y-a.y)).z)
		check(crossings.size()>=2,label+": both curtains reach the shared edge")
		if crossings.size()>=2:check(float(crossings.max())-float(crossings.min())<.00001,label+": curtains agree at the same world height")
func run()->void:
	var data:=Data.new()
	for z in range(-3,4):
		for x in 4:
			data.cells[Vector2i(x,z)]={"height":(1.5 if x<2 else .5) if z<0 else 3.0,"water":-1 if z<0 else 7}
	var field:=Contours.new()
	field.refresh(data)
	shared_edge(field,"mixed landing heights")
	data.begin_stroke()
	data.apply_brush(Vector2(.5,-1.5),1.6,"lower",false,1.5,3)
	data.end_stroke()
	field.refresh(data)
	shared_edge(field,"lowered receiving terrain")
	data.begin_stroke()
	data.apply_brush(Vector2(3,-1.5),1.55,"contract",false,1.5,3)
	data.end_stroke()
	field.refresh(data)
	shared_edge(field,"partially removed receiving terrain")
	var wide_data:=Data.new()
	for z in range(-3,4):
		for x in range(-8,8):wide_data.cells[Vector2i(x,z)]={"height":1.0 if z<0 else 3.0,"water":3 if z<0 else 7}
	var wide:=Contours.new()
	wide.refresh(wide_data)
	wide.surfaces.waterfall=Geometry.Surface.new()
	wide._falls(PackedVector2Array([Vector2(-8,0),Vector2(8,0),Vector2(8,3),Vector2(-8,3)]),3.545)
	var largest_span:=0.0
	var row:Dictionary={}
	var wide_vertices:PackedVector3Array=wide.surfaces.waterfall.vertices
	for i in range(0,wide_vertices.size(),3):
		for side in 3:
			var a:=wide_vertices[i+side]
			var b:=wide_vertices[i+(side+1)%3]
			largest_span=maxf(largest_span,Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z)))
	for v in wide_vertices:
		if absf(v.y-2.0)<.00001 and v.z<0 and absf(v.x)<6.0:row[v.x]=v.z
	check(largest_span<1.0,"Wide outlet triangles have enough lateral resolution to follow folded flow")
	var columns:=row.keys()
	columns.sort()
	var turns:=0
	var previous_slope:=0.0
	for i in range(1,columns.size()):
		var slope:float=row[columns[i]]-row[columns[i-1]]
		if absf(slope)<.0001:continue
		if previous_slope*slope<0:turns+=1
		previous_slope=slope
	check(turns>=4,"Wide outlet has repeated physical folds rather than one bowed plane")
	var splash_data:=Data.new()
	for z in range(-3,4):
		for x in 4:splash_data.cells[Vector2i(x,z)]={"height":1.0 if z<0 else 3.0,"water":3 if z<0 else 7}
	var splash:=Contours.new()
	splash.refresh(splash_data)
	var raised:=false
	var faded:=false
	for i in splash.surfaces.bank.vertices.size():
		var v:Vector3=splash.surfaces.bank.vertices[i]
		if v.y>1.65 and v.y<2.0:raised=true
		if v.y<2.0 and splash.surfaces.bank.colors[i].a<.1:faded=true
	check(raised,"fall into water has raised splash volume above receiving surface")
	check(faded,"splash perimeter fades into receiving water")
	var gradient:=false
	for chunk in [Vector2i(0,-1),Vector2i.ZERO]:
		var mesh:ArrayMesh=splash.build(chunk).bank
		if mesh.get_surface_count()==0:continue
		var arrays:Array=mesh.surface_get_arrays(0)
		var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		for i in range(0,colors.size(),3):
			if absf(colors[i].a-colors[i+1].a)>.3 or absf(colors[i].a-colors[i+2].a)>.3:gradient=true
	check(gradient,"published chunk triangles preserve the splash opacity gradient")
	# Trace through actual curtain triangles toward the island. A rock in front
	# of a curtain interrupts the stream even when both meshes are individually valid.
	var reference_data:=Data.new()
	reference_data.make_preset(0)
	var reference:=Contours.new()
	reference.refresh(reference_data)
	var cliffs:PackedVector3Array=reference.surfaces.cliff.vertices
	var falls:PackedVector3Array=reference.surfaces.waterfall.vertices
	var blocked:=0
	var samples:=0
	for i in range(0,falls.size(),3):
		var point:Vector3=(falls[i]+falls[i+1]+falls[i+2])/3.0
		if point.y< -4.4:continue
		var normal:Vector3=reference.surfaces.waterfall.normals[i]
		normal=Vector3(normal.x,0,normal.z).normalized()
		if normal.length_squared()<.5:continue
		var origin:=point+normal*3.0
		samples+=1
		for j in range(0,cliffs.size(),3):
			var a:=cliffs[j];var b:=cliffs[j+1];var c:=cliffs[j+2]
			if point.y<minf(a.y,minf(b.y,c.y)) or point.y>maxf(a.y,maxf(b.y,c.y)):continue
			var hit=Geometry3D.ray_intersects_triangle(origin,-normal,a,b,c)
			if hit!=null and origin.distance_to(hit)<2.99:
				blocked+=1
				break
	check(samples>150 and blocked==0,"Reference waterfall clears actual cliff triangles (%d blocked of %d samples)"%[blocked,samples])

	print("TERRAIN WATERFALL: %d/%d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
