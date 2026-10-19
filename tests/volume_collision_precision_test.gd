extends SceneTree
const Scene := preload('res://scenes/volume_patch_study.tscn')
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func zeros(vertices: PackedVector3Array) -> int:
	var result := 0
	for i: int in range(0,vertices.size(),3):
		if (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length_squared()==0.: result += 1
	return result
func _initialize() -> void:
	create_timer(30.).timeout.connect(func() -> void: push_error('Precise collision test timed out'); quit(1))
	call_deferred('run')
func run() -> void:
	var scene := Scene.instantiate()
	root.add_child(scene)
	for path: String in ['res://scripts/terrain_volume/patch_document.gd','res://tools/art/volume_refined_document.gd','res://tools/art/volume_module_document.gd']:
		scene.document = load(path).new()
		scene.document.load_preset()
		scene.document.field.samples.clear()
		scene.document.field._height_bounds_dirty = true
		scene.document.lake.enabled = false
		scene.rebuild()
		var arrays: Array = scene.body.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var collider: PackedVector3Array = scene.collision.shape.get_faces()
		check(zeros(vertices)==0,'Direct display vertex buffer is nondegenerate: '+path)
		check(collider==vertices and zeros(collider)==0,'Actual collision retains every displayed triangle exactly: '+path)
		print('PRECISE COLLISION SOURCE: ',JSON.stringify({'source':path,'display_triangles':vertices.size()/3,'display_degenerate':zeros(vertices),'mesh_get_faces_degenerate':zeros(scene.body.mesh.get_faces()),'collision_degenerate':zeros(collider)}))
	print('VOLUME COLLISION PRECISION: ',checks-failures,'/',checks)
	scene.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
