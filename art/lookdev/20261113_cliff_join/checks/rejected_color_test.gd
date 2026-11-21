extends SceneTree
## Read the real uploaded MultiMesh colors, rather than only source materials.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Field = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration = preload("res://scripts/terrain_editor/terrain_decoration.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Color upload check requires a native renderer")
		quit(1)
		return
	var before := GDScript.new()
	before.source_code = FileAccess.get_file_as_string("res://art/lookdev/20261113_cliff_foot/checks/source_before/terrain_decoration.gd").replace("class_name TerrainDecoration\n", "")
	if before.reload() != OK: quit(1); return
	var old: RefCounted = before.new()
	old.load_assets()
	var current := Decoration.new()
	current.assets = old.assets
	for fixture: Vector2i in [Vector2i(7301,0),Vector2i(2104,0),Vector2i(4242,1),Vector2i(913,2)]:
		var data := Data.new()
		data.make_preset(fixture.y)
		data.seed = fixture.x
		var old_field := Field.new()
		old_field.refresh(data)
		old._column_layout(old_field, data.seed)
		old.contours = old_field
		var field := Field.new()
		field.refresh(data)
		current._column_layout(field, data.seed)
		current.contours = field
		var chunks: Dictionary = {}
		for mass: Dictionary in old._mass:
			if not mass.get("is_interior", false): chunks[Data.chunk_of(mass.cell)] = true
		var compared: int = 0
		for chunk: Vector2i in chunks:
			var old_group := Node3D.new()
			var group := Node3D.new()
			old.populate(old_group, data, chunk)
			current.populate(group, data, chunk)
			for child: MultiMeshInstance3D in old_group.get_children():
				if not String(child.name).begins_with("underside_rock"): continue
				var other: MultiMeshInstance3D = group.get_node(NodePath(child.name))
				check(child.multimesh.instance_count == other.multimesh.instance_count, "%s %s instance counts" % [fixture, child.name])
				for i: int in child.multimesh.instance_count:
					check(child.multimesh.get_instance_color(i) == other.multimesh.get_instance_color(i), "%s %s instance %d preserves uploaded mineral color" % [fixture, child.name, i])
					compared += 1
			old_group.free()
			group.free()
		check(compared >= 3, "%s covers several uploaded shoulder colors" % fixture)
	print("CLIFF OUTER COLOR: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
