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
	print("TERRAIN WATERFALL: %d/%d passed"%[checks-failures,checks])
	quit(1 if failures else 0)
