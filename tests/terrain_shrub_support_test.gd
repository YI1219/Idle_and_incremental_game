extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration=preload("res://scripts/terrain_editor/terrain_decoration.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var deco=Decoration.new()
	deco.load_assets()
	# Chunk population loads repeatedly; base support must survive cached loads.
	deco.load_assets()
	var mesh:Mesh=deco.assets.bush[0].mesh
	var box:AABB=mesh.get_aabb()
	var vertices:PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# Test actual lower rendered vertices, including diagonal edge support.
	# This is finite base contact evidence, not a whole-canopy footprint proof.
	var roots:Dictionary={}
	for point:Vector3 in vertices:
		if point.y<=box.position.y+box.size.y*.08:roots[point]=true
	var data=Data.new()
	data.make_preset(0)
	var initial:Dictionary=data.serialize()
	var total:=0
	var unsupported:=0
	var coverage:=true
	for spec in [["default",Vector2.ZERO,0.0],["raise",Vector2(-13,2),2.3],["lower",Vector2(13,7),2.0],["expand",Vector2(18,4),2.6],["contract",Vector2(3,7),2.2]]:
		data.deserialize(initial)
		if spec[0]!="default":
			data.begin_stroke()
			data.apply_brush(spec[1],spec[2],spec[0],false,1.5,3)
			data.end_stroke()
		var field=Contours.new()
		field.refresh(data)
		deco.contours=field
		var chunks:Dictionary={}
		var plants:=0
		var misses:=0
		var checked:=0
		for cell:Vector2i in data.cells:chunks[Data.chunk_of(cell)]=true
		for chunk:Vector2i in chunks:
			for pose:Transform3D in deco.placements(data,chunk).bush:
				plants+=1
				for point:Vector3 in roots:
					var world:Vector3=pose*point
					var surface:Dictionary=field.surface_at(Vector2(world.x,world.z))
					checked+=1
					if surface.is_empty() or surface.water>=0 or absf(surface.height-pose.origin.y-.02)>.01:misses+=1
		coverage=coverage and plants>=10 and roots.size()>=3
		print(spec[0],": shrubs=",plants," base_points=",checked," unsupported=",misses)
		total+=checked
		unsupported+=misses
	print("SHRUB SUPPORT: ",total," actual base points; ",unsupported," unsupported; coverage=",coverage)
	quit(1 if unsupported>0 or not coverage else 0)
