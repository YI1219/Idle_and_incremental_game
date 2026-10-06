extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var data:=Data.new();data.make_preset(0)
	var field:=Contours.new();field.refresh(data)
	var gradients:=0;var invalid:=0;var edges:=0
	for chunk in field.triangle_chunks:
		var mesh:ArrayMesh=field.build(chunk).cliff
		if mesh.get_surface_count()==0:continue
		var colors:PackedColorArray=mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		for i in range(0,colors.size(),3):
			var minimum:float=minf(colors[i].a,minf(colors[i+1].a,colors[i+2].a))
			var maximum:float=maxf(colors[i].a,maxf(colors[i+1].a,colors[i+2].a))
			if maximum-minimum>.1:gradients+=1
			if maximum>.9:edges+=1
			if minimum<-.00001 or maximum>1.00001:invalid+=1
	print("PUBLISHED TURF TRANSITION: ",gradients," gradient faces, ",edges," cap faces, ",invalid," invalid")
	quit(0 if gradients>100 and edges>100 and invalid==0 else 1)
