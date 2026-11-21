extends SceneTree
## Outer shoulder rocks finish above the solid island foot, including their
## real slanted vertices. A nominal model height previously let them overhang.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Field = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration = preload("res://scripts/terrain_editor/terrain_decoration.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func mesh_bottom(mesh: Mesh, pose: Transform3D) -> float:
	var result: float = INF
	for p: Vector3 in mesh.get_faces(): result = minf(result, (pose*p).y)
	return result

func contour_foot(field: RefCounted, at: Vector2, outward: Vector2) -> float:
	var profile: Dictionary = field._cliff_profile(at, outward).duplicate()
	field._outer_profile(at, outward, profile)
	return field._profile_point(at, Field.BOTTOM, outward, profile).y

func verify_endpoints(assets: Dictionary) -> void:
	# Uniform dry land has no terrace/fall trimming: the run endpoints are
	# known independently of the fitting code, while its underlying foot slopes.
	var data := Data.new()
	for z: int in range(-12, 13):
		for x: int in range(-15, 16):
			data.cells[Vector2i(x,z)] = {"height":3.5,"water":-1}
	var field := Field.new()
	field.refresh(data)
	var checked: int = 0
	var end_dominates: int = 0
	for loop: PackedVector2Array in field.land_regions[3.5]:
		for run: Array in Decoration.new()._stable_runs(loop, 3.5):
			var a: Vector2 = run[0]
			var b: Vector2 = run[1]
			var dir: Vector2 = (b-a).normalized()
			var outward := Vector2(dir.y,-dir.x)
			var probe := Decoration.new()
			probe.assets = assets
			probe._rim_run(field, a, b, run[2], 3.5, data.seed)
			if probe._columns.size() != 1 or probe._mass.size() != 1: continue
			var mass: Dictionary = probe._mass[0]
			if mass.get("is_interior",false): continue
			var center: Vector2 = probe._columns[0].edge
			var center_y: float = contour_foot(field, center, outward)
			var end_y: float = maxf(contour_foot(field, a, outward), contour_foot(field, b, outward))
			var bottom: float = mesh_bottom(assets[mass.kind][0].mesh, mass.pose)
			check(bottom >= maxf(center_y,end_y)+.3495, "outer shoulder clears both known span ends with its 0.35m margin")
			checked += 1
			if end_y > center_y+.05: end_dominates += 1
	check(checked >= 3 and end_dominates >= 1, "endpoint fixture includes multiple shoulders and an end shallower than its center")

func verify_foot(deco: RefCounted, field: RefCounted, label: String) -> Dictionary:
	var core_bottom: float = INF
	for p: Vector3 in field.surfaces.cliff.vertices: core_bottom = minf(core_bottom, p.y)
	var poses: Dictionary = {}
	for mass: Dictionary in deco._mass:
		if mass.get("is_interior", false): continue
		var parent: Dictionary = {}
		var nearest: float = INF
		for col: Dictionary in deco._columns:
			if col.is_step or col.cell != mass.cell: continue
			if col.pose.basis.z.normalized().dot(mass.pose.basis.z.normalized()) < .97: continue
			var delta := Vector2(col.pose.origin.x-mass.pose.origin.x, col.pose.origin.z-mass.pose.origin.z).length_squared()
			if delta < nearest: parent = col; nearest = delta
		check(not parent.is_empty(), "%s outer shoulder has a parent at %s" % [label, mass.cell])
		if parent.is_empty(): continue
		var bottom: float = mesh_bottom(deco.assets[mass.kind][0].mesh, mass.pose)
		var parent_bottom: float = mesh_bottom(deco.assets[parent.kind][0].mesh, parent.pose)
		var outward := Vector2(parent.outward.x, parent.outward.z)
		var profile: Dictionary = field._cliff_profile(parent.edge, outward).duplicate()
		field._outer_profile(parent.edge, outward, profile)
		var local_foot: Vector3 = field._profile_point(parent.edge, Field.BOTTOM, outward, profile)
		check(bottom >= core_bottom+.10, "%s shoulder %s hangs below solid core: %.3f < %.3f" % [label, mass.cell, bottom, core_bottom+.10])
		check(bottom >= parent_bottom+.10, "%s shoulder %s hangs below its main rock: %.3f < %.3f" % [label, mass.cell, bottom, parent_bottom+.10])
		check(bottom >= local_foot.y+.10, "%s shoulder %s hangs below its local contour foot: %.3f < %.3f" % [label, mass.cell, bottom, local_foot.y+.10])
		check(mass.pose.basis.determinant() > .1, "%s shoulder %s retains a solid volume" % [label, mass.cell])
		poses[mass.cell] = [mass.kind, mass.pose]
	check(poses.size() >= 3, "%s exercises several outer shoulders" % label)
	return poses

func _initialize() -> void:
	var deco := Decoration.new()
	deco.load_assets()
	verify_endpoints(deco.assets)
	for fixture: Vector2i in [Vector2i(7301,0), Vector2i(2104,0), Vector2i(4242,1), Vector2i(913,2)]:
		var data := Data.new()
		data.make_preset(fixture.y)
		data.seed = fixture.x
		var field := Field.new()
		field.refresh(data)
		deco._column_layout(field, data.seed)
		var label: String = "seed %d" % fixture.x
		var before: Dictionary = verify_foot(deco, field, label)
		if fixture.x != 7301: continue
		data.begin_stroke()
		data.apply_brush(Vector2(-14,4), 2.2, "lower", false, 3.5, 7, 3.5)
		data.end_stroke()
		field.refresh(data)
		deco._column_layout(field, data.seed)
		verify_foot(deco, field, "edited outer edge")
		data.undo()
		field.refresh(data)
		deco._column_layout(field, data.seed)
		check(verify_foot(deco, field, "undo") == before, "undo restores outer shoulder poses")
	print("CLIFF OUTER FOOT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
