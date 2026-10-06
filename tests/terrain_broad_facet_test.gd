extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var data=Data.new()
	data.make_preset(0)
	var field=Contours.new()
	field.refresh(data)
	var vertices:PackedVector3Array=field.surfaces.cliff.vertices
	var normals:PackedVector3Array=field.surfaces.cliff.normals
	var broad:=0
	var planar:=0
	var invalid:=0
	for i in range(0,vertices.size(),3):
		var a:=vertices[i]
		var b:=vertices[i+1]
		var c:=vertices[i+2]
		var span:float=maxf(a.y,maxf(b.y,c.y))-minf(a.y,minf(b.y,c.y))
		if span<.55:continue
		broad+=1
		var face:=-(b-a).cross(c-a).normalized()
		for j in 3:
			if not normals[i+j].is_finite() or absf(normals[i+j].length()-1.0)>.001 or face.dot(normals[i+j])<.25:invalid+=1
		if face.dot(normals[i])>.9999 and face.dot(normals[i+1])>.9999 and face.dot(normals[i+2])>.9999:planar+=1
	print("BROAD CLIFF FACETS: ",broad," large faces; ",planar," planar normals")
	# Selective creases replace the obsolete requirement that every broad
	# triangle be a flat shaded face. Geometric normals remain unit, finite
	# and in the actual face hemisphere; both sharp and blended faces occur.
	print("BROAD NORMAL VALIDITY: ",invalid," invalid entries")
	quit(0 if broad>=100 and planar>0 and planar<broad and invalid==0 else 1)
