extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	# A wide plateau with a diagonal cell staircase. Its smoothed edge passes
	# through raw missing-cell corners, without making the actual land thin.
	var data:=Data.new()
	for z in range(-6,7):
		for x in range(-6,7):
			if x+z<=6:data.cells[Vector2i(x,z)]={"height":3.5,"water":-1}
	var field:=Contours.new()
	field.refresh(data)
	var lowest:=INF
	for vertex in field.surfaces.cliff.vertices:lowest=minf(lowest,vertex.y)
	var cap_line:=-INF
	for point:Vector3 in field.surfaces.grass.vertices:
		if point.x>=1 and point.x<=5 and point.z>=1 and point.z<=5:cap_line=maxf(cap_line,point.x+point.z)
	var sampled:=0
	var furthest:=-INF
	for point:Vector3 in field.surfaces.cliff.vertices:
		if point.y>lowest+.60 or point.x<1 or point.x>5 or point.z<1 or point.z>5:continue
		sampled+=1
		furthest=maxf(furthest,point.x+point.z)
	check(sampled>10,"The broad diagonal cliff foot is present in the inspected region")
	# Compare the actual smoothed grass edge, rather than its old raw-cell line. The approved blunt shell has less
	# contraction than the old bowl. Keep a finite setback at the true foot;
	# narrow-wall overlap and actual triangle aspect are checked separately.
	check(is_finite(cap_line) and furthest<cap_line-.20,"Broad diagonal cliff feet taper instead of exposing thin cell-corner blades (furthest x+z %.4f)"%furthest)
	print("TERRAIN CLIFF TAPER: %d/%d passed, sampled %d foot vertices, furthest %.4f"%[checks-failures,checks,sampled,furthest])
	quit(1 if failures else 0)
