extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
var failures:=0
func _initialize()->void:call_deferred("run")
func run()->void:
	var data:=Data.new()
	data.make_preset(0)
	var field:=Contours.new()
	field.refresh(data)
	var vertices:PackedVector3Array=field.surfaces.cliff.vertices
	var large:=0
	var wedges:=0
	var max_edge:=0.0
	for i in range(0,vertices.size(),3):
		var a:=vertices[i];var b:=vertices[i+1];var c:=vertices[i+2]
		var area:float=(b-a).cross(c-a).length()*.5
		if area<.15:continue
		var longest:float=maxf(a.distance_to(b),maxf(a.distance_to(c),b.distance_to(c)))
		if maxf(a.y,maxf(b.y,c.y))-minf(a.y,minf(b.y,c.y))<.7:continue
		large+=1
		max_edge=maxf(max_edge,longest)
		if longest*longest/(2.0*area)>5.0:wedges+=1
	print("SHAPE DIAGNOSTIC: %d wedges / %d substantial cliff triangles, max edge %.3f"%[wedges,large,max_edge])
	# Catch broad visible needle faces, rather than tiny clipping slivers.
	if float(wedges)/maxi(1,large)>.08:failures+=1;push_error("Substantial cliff faces still form elongated wedges")
	var profile:={"top":1.5,"rock_top":1.5,"bottom":-4.5,"base":true,"water":-1,"inset":1.5}
	var foot:Vector3=field._profile_point(Vector2(10,6),-4.5,Vector2.RIGHT,profile)
	if foot.y< -3.25:failures+=1;push_error("Default-height shell still contracts to an unnecessarily deep global floor")
	profile.top=-4.0;profile.rock_top=-4.0
	var minimum:Vector3=field._profile_point(Vector2(10,6),-4.5,Vector2.RIGHT,profile)
	if minimum.y> -4.4 or not minimum.is_finite():failures+=1;push_error("Minimum legal land must retain a finite supporting shell below its surface")
	print("REWORK SHAPE: failures %d; default foot %s; minimum foot %s"%[failures,foot,minimum])
	quit(1 if failures else 0)
