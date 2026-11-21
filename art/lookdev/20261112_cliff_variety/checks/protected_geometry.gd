extends SceneTree
const Before = preload("res://art/lookdev/20261112_cliff_variety/checks/source_before/procedural_shard.gd")
const After = preload("res://scripts/terrain_editor/procedural_shard.gd")
func _initialize() -> void:
	var checks: int = 0
	var failures: int = 0
	for i: int in 8:
		var seed_value: int = 16+i*9
		var old: Dictionary = Before.build(seed_value)
		var new: Dictionary = After.build(seed_value)
		var old_top: PackedVector3Array = []
		var new_top: PackedVector3Array = []
		for p: Vector3 in old.mesh.get_faces():
			if p.y >= -.04201: old_top.append(p)
		for p: Vector3 in new.mesh.get_faces():
			if p.y >= -.04201: new_top.append(p)
		checks += 1
		if old_top != new_top or old.cap_polygon != new.cap_polygon:
			failures += 1; push_error("Canonical crown/collar differs: %d" % i)
		var old_root: Dictionary = Before.build(seed_value,true)
		var new_root: Dictionary = After.build(seed_value,true)
		checks += 1
		if old_root.mesh.surface_get_arrays(0) != new_root.mesh.surface_get_arrays(0):
			failures += 1; push_error("Root geometry/normals/colors/UV differs: %d" % i)
	print("PROTECTED GEOMETRY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
