extends Node3D
## Hand-placed cliff faces for the seed-7301 preset's south break.
## Each child is one cropped face. The heightmap shell is still the island:
## joins, the closed underside, and every other edge stay on that shell.
## This is not a tiling system and it does not follow later brush edits.

const GRAY := Color(0.63, 0.64, 0.66)

var piece_count := 0

func _ready() -> void:
	name = "RockFaceSample"
	_compose()

func _compose() -> void:
	var south := Vector3(0.0, 0.0, 1.0)
	var west := Vector3(-1.0, 0.0, 0.0)
	# Low south lip from (4, 10) to (-1, 10), top 1.5. Several faces overlap.
	_run(Vector3(4.0, 1.5, 10.0), west, south, [
		["lip_in", 0.05, 0.0, -0.02],
		["face_setback", 0.0, 0.0, 0.0],
		["tuck_long", 0.10, 0.0, 0.0],
		["lip_out", 1.55, 0.0, 0.02],
		["face_broad", 1.45, 0.0, 0.0],
		["tuck_short", 2.55, 0.0, 0.02],
		["face_proud", 2.85, 0.0, 0.04],
		["lip_in", 3.15, 0.0, 0.0],
		["face_setback", 3.70, 0.0, -0.02],
		["tuck_long", 3.55, 0.0, 0.0],
		["lip_out", 4.35, 0.0, 0.02],
	])
	# One-metre west return at the low terrace. Faces, not a single end cap.
	_run(Vector3(-1.0, 1.5, 10.0), Vector3(0.0, 0.0, -1.0), west, [
		["lip_in", 0.0, 0.0, 0.0],
		["face_proud", 0.0, 0.0, 0.02],
		["tuck_short", 0.05, 0.0, 0.0],
		["cheek_low", 0.72, 0.0, 0.0],
	])
	# High south lip from (-2, 9) to (-7, 9), top 3.5. Different piece order.
	_run(Vector3(-2.0, 3.5, 9.0), west, south, [
		["cheek_high", -0.02, 0.0, -0.04],
		["cheek_low", -0.02, 0.0, -0.02],
		["lip_out", 0.15, 0.0, 0.02],
		["face_broad", 0.0, 0.0, 0.0],
		["tuck_short", 0.20, 0.0, 0.0],
		["lip_in", 1.70, 0.0, 0.0],
		["face_proud", 1.55, 0.0, 0.05],
		["tuck_long", 1.40, 0.0, 0.0],
		["face_setback", 2.70, 0.0, -0.03],
		["lip_out", 3.05, 0.0, 0.02],
		["tuck_short", 3.15, 0.0, 0.02],
		["face_broad", 3.40, 0.0, 0.0],
		["tuck_long", 3.50, 0.0, 0.0],
		["lip_in", 4.40, 0.0, 0.0],
		["corner_plug", 4.15, 0.0, 0.0],
	])
	# West return of the high corner. The plug above only fills the fold.
	_run(Vector3(-7.0, 3.5, 9.0), Vector3(0.0, 0.0, -1.0), west, [
		["lip_out", 0.05, 0.0, 0.0],
		["face_setback", 0.0, 0.0, 0.0],
		["tuck_short", 0.10, 0.0, 0.0],
	])

func _run(origin: Vector3, along: Vector3, out: Vector3, spots: Array) -> void:
	for spot in spots:
		var row: Array = spot
		_place(origin, along, out, String(row[0]), float(row[1]), float(row[2]), float(row[3]))

func _place(origin: Vector3, along: Vector3, out: Vector3, piece: String, at: float, lift: float, outward: float) -> void:
	var inst := MeshInstance3D.new()
	inst.name = "%s_%d" % [piece, piece_count]
	inst.mesh = _mesh(piece)
	inst.material_override = _material()
	inst.position = origin + along * at + Vector3.UP * lift + out * outward
	inst.basis = Basis(along, Vector3.UP, out)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(inst)
	piece_count += 1

func _mesh(piece: String) -> Mesh:
	var packed := load("res://assets/nature/rock_faces/%s.glb" % piece) as PackedScene
	var root := packed.instantiate()
	var found: Mesh = _find_mesh(root)
	root.free()
	return found

func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		var inst := node as MeshInstance3D
		if inst.mesh != null:
			return inst.mesh
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null

func _material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GRAY
	mat.roughness = 0.94
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat
