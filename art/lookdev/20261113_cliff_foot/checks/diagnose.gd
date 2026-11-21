extends SceneTree
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Field = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration = preload("res://scripts/terrain_editor/terrain_decoration.gd")

func bottom(part: Dictionary, pose: Transform3D) -> float:
	var y: float = INF
	for p: Vector3 in part.mesh.get_faces(): y = minf(y, (pose*p).y)
	return y

func _initialize() -> void:
	var deco := Decoration.new()
	deco.load_assets()
	for fixture: Vector2i in [Vector2i(7301,0),Vector2i(2104,0),Vector2i(4242,1),Vector2i(913,2)]:
		var data := Data.new()
		data.make_preset(fixture.y)
		data.seed = fixture.x
		var field := Field.new()
		field.refresh(data)
		deco._column_layout(field, data.seed)
		for mass: Dictionary in deco._mass:
			if mass.get("is_interior",false): continue
			var parent: Dictionary = {}
			var distance: float = INF
			for column: Dictionary in deco._columns:
				if column.is_step or column.cell != mass.cell: continue
				if column.pose.basis.z.normalized().dot(mass.pose.basis.z.normalized()) < .97: continue
				var delta := Vector2(column.pose.origin.x-mass.pose.origin.x,column.pose.origin.z-mass.pose.origin.z).length_squared()
				if delta < distance: parent = column; distance = delta
			var low: float = bottom(deco.assets[mass.kind][0], mass.pose)
			var prof: Dictionary = field._cliff_profile(parent.edge, Vector2(parent.outward.x,parent.outward.z)).duplicate()
			field._outer_profile(parent.edge,Vector2(parent.outward.x,parent.outward.z),prof)
			var core: Vector3 = field._profile_point(parent.edge,Field.BOTTOM,Vector2(parent.outward.x,parent.outward.z),prof)
			print("ROOT seed=",fixture.x," cell=",mass.cell," root=",low," parent=",bottom(deco.assets[parent.kind][0],parent.pose) if not parent.is_empty() else NAN," core=",core.y," origin=",mass.pose.origin," height=",mass.pose.basis.y.length())
	quit()
