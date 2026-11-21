extends "res://tests/grass_lip_soften_test.gd"
func run() -> void:
	var data := preload("res://scripts/terrain_editor/terrain_data.gd").new()
	data.make_preset(0)
	for seed_value: int in [7301,2104]:
		data.seed=seed_value
		var field := preload("res://scripts/terrain_editor/contour_terrain.gd").new()
		field.refresh(data)
		var decoration := preload("res://scripts/terrain_editor/terrain_decoration.gd").new()
		decoration.load_assets()
		decoration._column_layout(field,data.seed)
		var surface=field.surfaces.grass
		var bad: int = 0
		for i: int in surface.vertices.size():
			var p: Vector3 = surface.vertices[i]
			var level: float = _level(field,p.y)
			if level-p.y > .06 and level-p.y <= .28 and surface.normals[i].y <= .35:
				bad+=1
				if bad<=15:print("BAD ",seed_value," p ",p," n ",surface.normals[i]," level ",level," color ",surface.colors[i])
				if bad<=6:
					var base: int = floori(float(i)/3.0)*3
					var a: Vector3 = surface.vertices[base]
					var b: Vector3 = surface.vertices[base+1]
					var c: Vector3 = surface.vertices[base+2]
					print(" TRI ",a," / ",b," / ",c," normal ",-(b-a).cross(c-a).normalized()," outside ",_outside(field.lawn_boundaries[level],Vector2(p.x,p.z)))
		print("TOTAL BAD ",seed_value," ",bad)
	quit()
