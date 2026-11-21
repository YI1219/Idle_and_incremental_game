extends SceneTree
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Field = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Current = preload("res://scripts/terrain_editor/terrain_decoration.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func interiors(deco: RefCounted) -> Array:
	var result: Array = []
	for mass: Dictionary in deco._mass:
		if mass.get("is_interior", false): result.append(mass)
	return result

func _initialize() -> void:
	# Snapshot is evaluated in memory without registering another global class.
	var before := GDScript.new()
	before.source_code = FileAccess.get_file_as_string("res://art/lookdev/20261113_cliff_foot/checks/source_before/terrain_decoration.gd").replace("class_name TerrainDecoration\n", "")
	if before.reload() != OK: quit(1); return
	var old: RefCounted = before.new()
	old.load_assets()
	var current := Current.new()
	current.assets = old.assets
	for fixture: Vector2i in [Vector2i(7301,0),Vector2i(2104,0),Vector2i(4242,1),Vector2i(913,2)]:
		var data := Data.new()
		data.make_preset(fixture.y)
		data.seed = fixture.x
		var old_field := Field.new()
		old_field.refresh(data)
		old._column_layout(old_field, data.seed)
		var field := Field.new()
		field.refresh(data)
		current._column_layout(field, data.seed)
		check(old._columns == current._columns, "%s main columns and crowns remain exact" % fixture)
		check(interiors(old) == interiors(current), "%s interior step rocks remain exact" % fixture)
		check(old._mass.size() == current._mass.size(), "%s outer rocks retain their count" % fixture)
		for key: String in old_field.surfaces:
			var a: RefCounted = old_field.surfaces[key]
			var b: RefCounted = field.surfaces[key]
			check(a.vertices == b.vertices and a.normals == b.normals and a.colors == b.colors and a.uv == b.uv, "%s %s terrain arrays remain exact" % [fixture, key])
	print("CLIFF FOOT PROTECTION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
