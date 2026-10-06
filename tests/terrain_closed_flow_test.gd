extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
var failures:=0
func _initialize()->void:call_deferred("run")
func run()->void:
	var data:=Data.new()
	for z in range(-5,6):
		for x in range(-5,6):
			var upper:bool=absi(x)<=1 and absi(z)<=1
			data.cells[Vector2i(x,z)]={"height":3.0 if upper else 1.0,"water":7 if upper else 3}
	var field:=Contours.new()
	field.refresh(data)
	var impact_vertices:=0
	var sectors:Dictionary={}
	for index in field.surfaces.bank.vertices.size():
		var point:Vector3=field.surfaces.bank.vertices[index]
		if point.y<1.8 and field.surfaces.bank.colors[index].b>.5:
			impact_vertices+=1
			sectors[Vector2i(signf(point.x-.5),signf(point.z-.5))]=true
	if impact_vertices==0 or sectors.size()<4:
		failures+=1;push_error("A fully exposed upper pond needs supported receiving foam around its ring, not a collapsed centroid")
	var wet_feet:=0
	var dry_feet:=0
	var vertices:PackedVector3Array=field.surfaces.waterfall.vertices
	for i in vertices.size():
		var point:Vector3=vertices[i]
		var metadata:Color=field.surfaces.waterfall.colors[i]
		if point.y>1.7:continue
		var receiver_fraction:float=metadata.a if metadata.a<.5 else metadata.r if metadata.b==0 else 0.0
		if receiver_fraction>.39:wet_feet+=1
		if point.y<0 and receiver_fraction==0:dry_feet+=1
	if wet_feet==0 or dry_feet==0:
		failures+=1;push_error("Wet receivers aerate their falling foot; outer falls must keep zero receiver aeration")
	print("CLOSED FLOW: impact vertices=",impact_vertices,", receiving sectors=",sectors.size(),", wet feet=",wet_feet,", dry feet=",dry_feet,", failures=",failures)
	quit(1 if failures else 0)
