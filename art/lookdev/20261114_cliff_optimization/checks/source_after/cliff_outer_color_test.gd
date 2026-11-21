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

func colors_in(group: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for child: MultiMeshInstance3D in group.get_children():
		if not String(child.name).begins_with("underside_rock"): continue
		for i: int in child.multimesh.instance_count:
			result[child.multimesh.get_instance_transform(i)]=child.multimesh.get_instance_color(i)
	return result

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Color upload check requires a native renderer")
		quit(1)
		return
	var before := GDScript.new()
	before.source_code = FileAccess.get_file_as_string("res://art/lookdev/20261113_cliff_foot/checks/source_before/terrain_decoration.gd").replace("class_name TerrainDecoration\n", "")
	if before.reload() != OK: quit(1); return
	var hist_after := GDScript.new()
	hist_after.source_code = FileAccess.get_file_as_string("res://art/lookdev/20261113_cliff_join/checks/source_after/terrain_decoration.gd").replace("class_name TerrainDecoration\n", "")
	if hist_after.reload() != OK: quit(1); return
	var old: RefCounted = before.new()
	old.load_assets()
	var after: RefCounted = hist_after.new()
	after.assets = old.assets
	var current := Decoration.new()
	current.load_assets()
	for fixture: Vector2i in [Vector2i(7301,0),Vector2i(2104,0),Vector2i(4242,1),Vector2i(913,2)]:
		var data := Data.new()
		data.make_preset(fixture.y)
		data.seed = fixture.x
		var old_field := Field.new()
		old_field.refresh(data)
		old._column_layout(old_field, data.seed)
		old.contours = old_field
		var after_field := Field.new()
		after_field.refresh(data)
		after._column_layout(after_field, data.seed)
		after.contours = after_field
		var field := Field.new()
		field.refresh(data)
		current._column_layout(field, data.seed)
		current.contours = field
		var hist_chunks: Dictionary = {}
		for mass: Dictionary in old._mass:
			if not mass.get("is_interior", false): hist_chunks[Data.chunk_of(mass.cell)] = true
		var hist_compared: int = 0
		for chunk: Vector2i in hist_chunks:
			var old_group := Node3D.new()
			var after_group := Node3D.new()
			old.populate(old_group, data, chunk)
			after.populate(after_group, data, chunk)
			var before_colors: Dictionary = colors_in(old_group)
			var after_colors: Dictionary = colors_in(after_group)
			check(before_colors==after_colors,"%s chunk %s hist preserves every uploaded rock color at its original pose" % [fixture,chunk])
			hist_compared+=before_colors.size()
			old_group.free()
			after_group.free()
		check(hist_compared >= 3, "%s hist covers several uploaded shoulder colors" % fixture)
		var chunks: Dictionary = {}
		var ext_expected := 0
		for mass: Dictionary in current._mass:
			chunks[Data.chunk_of(mass.cell)] = true
			if not mass.get("is_interior", false): ext_expected += 1
		check(ext_expected >= 3, "%s produces multiple exterior shoulders" % fixture)
		var ext_checked := 0
		var int_checked := 0
		for chunk: Vector2i in chunks:
			var group := Node3D.new()
			current.populate(group, data, chunk)
			var uploaded: Dictionary = colors_in(group)
			for mass: Dictionary in current._mass:
				if Data.chunk_of(mass.cell) != chunk: continue
				var found_match := false
				var expected_color: Color = Decoration._stone_tone(mass.pose.origin)
				if mass.has("mesh"):
					if uploaded.has(mass.pose):
						var col_up: Color = uploaded[mass.pose]
						var max_diff := maxf(absf(col_up.r - expected_color.r), maxf(absf(col_up.g - expected_color.g), absf(col_up.b - expected_color.b)))
						check(max_diff < 0.0001, "%s chunk %s joined shoulder color matches _stone_tone" % [fixture, chunk])
						found_match = true
				else:
					var part: Dictionary = current.assets[mass.kind][0]
					var want_pose: Transform3D = mass.pose * part.pose
					if uploaded.has(want_pose):
						var col_up: Color = uploaded[want_pose]
						var max_diff := maxf(absf(col_up.r - expected_color.r), maxf(absf(col_up.g - expected_color.g), absf(col_up.b - expected_color.b)))
						check(max_diff < 0.0001, "%s chunk %s accent color matches _stone_tone" % [fixture, chunk])
						found_match = true
				check(found_match, "%s chunk %s uploads mass instance transform to MultiMesh" % [fixture, chunk])
				if mass.get("is_interior", false): int_checked += 1
				else: ext_checked += 1
			group.free()
		check(ext_checked >= 3, "%s covers uploaded exterior shoulder colors" % fixture)
	print("CLIFF OUTER COLOR: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
