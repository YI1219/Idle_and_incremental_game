extends 'res://tools/art/capture_refined_volume.gd'
const REVIEW := 'res://art/review/terrain_fidelity/2026-10-20/volume_modules/'
const OLD := 'res://art/work/volume_shape/2026-10-20/cliff_land_v2_lower_return_v1.glb'
const ASSEMBLED := 'res://art/work/volume_modules/2026-10-20/three_rock_assembly_v1.glb'
func output_dir() -> String:
	return REVIEW
func collect(node: Node, parts: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: parts.append(node)
	for child: Node in node.get_children(): collect(child,parts)
func source_mesh(path: String) -> ArrayMesh:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path,state)!=OK: return null
	var source := document.generate_scene(state)
	viewport.add_child(source)
	var parts: Array[MeshInstance3D] = []
	collect(source,parts)
	var vertices := PackedVector3Array()
	for part: MeshInstance3D in parts:
		for p: Vector3 in part.mesh.get_faces(): vertices.append(part.global_transform*p)
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i: int in range(0,vertices.size(),3):
		var n := -(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
		for j: int in 3: normals[i+j] = n
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	source.queue_free()
	return load('res://scripts/terrain_editor/stone_normals.gd').soften(mesh,42.,1.)
func run() -> void:
	create_timer(45.).timeout.connect(func() -> void: push_error('Module form capture timed out'); quit(1))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1671,941)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	study = Scene.instantiate()
	viewport.add_child(study)
	study.water.hide()
	study.cursor.hide()
	study.hud.hide()
	study.set_process(false)
	var neutral := StandardMaterial3D.new()
	neutral.albedo_color = Color(.48,.48,.48)
	neutral.roughness = 1.
	study.body.material_override = neutral
	for item: Array in [['lower_source',OLD],['assembled_source',ASSEMBLED]]:
		study.body.mesh = source_mesh(item[1])
		if study.body.mesh==null: quit(1); return
		states[item[0]] = {'source':item[1],'sha256':FileAccess.get_sha256(item[1]),'triangles':study.body.mesh.get_faces().size()/3}
		await views(item[0])
	var valid := true
	for frame: Dictionary in captures: valid = valid and frame.error==OK
	FileAccess.open(REVIEW+'source_form_captures.json',FileAccess.WRITE).store_string(JSON.stringify({
		'captures':captures,'states':states,'capture_success':valid,'godot':Engine.get_version_info().string,
		'scope':'Unconverted source forms, same camera/light/neutral material/common42degree crease. No grass/pond/texture. Not an editable-scene or art acceptance claim.'
	},'\t',true,true))
	print('MODULE SOURCE FORM CAPTURES: ',valid,'; frames=',captures.size())
	quit(0 if valid else 1)
