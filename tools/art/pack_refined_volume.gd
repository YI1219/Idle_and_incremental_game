extends SceneTree
const WORK := 'res://art/work/volume_shape/2026-10-20/'
const SOURCE := WORK+'cliff_land_v2_lower_return_v1.glb'
const PRESET := 'res://assets/terrain/volume_patch/source_rock_lower_return_v1.res'
func _initialize() -> void:
	call_deferred('run')
func collect(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: result.append(node)
	for child: Node in node.get_children(): collect(child,result)
func max_distance(from: PackedVector3Array, to: PackedVector3Array) -> float:
	var buckets: Dictionary = {}
	for p: Vector3 in to:
		var key := Vector3i((p/.01).floor())
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(p)
	var result := 0.
	for p: Vector3 in from:
		var key := Vector3i((p/.01).floor())
		var nearest := INF
		for x: int in range(-1,2):
			for y: int in range(-1,2):
				for z: int in range(-1,2):
					for q: Vector3 in buckets.get(key+Vector3i(x,y,z),[]):
						nearest = minf(nearest,p.distance_to(q))
		result = maxf(result,nearest)
	return result
func run() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(SOURCE,state)!=OK:
		push_error('Refined GLB cannot be reimported'); quit(1); return
	var scene := document.generate_scene(state)
	root.add_child(scene)
	var parts: Array[MeshInstance3D] = []
	collect(scene,parts)
	var actual := PackedVector3Array()
	for part: MeshInstance3D in parts:
		for p: Vector3 in part.mesh.get_faces(): actual.append(part.global_transform*p)
	var file := FileAccess.open(WORK+'source.bin',FileAccess.READ)
	var expected: PackedVector3Array = file.get_buffer(file.get_length()).to_float32_array().to_byte_array().to_vector3_array()
	var forward := max_distance(expected,actual)
	var reverse := max_distance(actual,expected)
	if actual.size()!=15084 or maxf(forward,reverse)>.002:
		push_error('Refined GLB roundtrip geometry mismatch'); quit(1); return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORK+'sampling.json'))
	var density := FileAccess.get_file_as_bytes(WORK+'density.bin')
	var preset := Resource.new()
	preset.set_meta('density',density.to_float32_array())
	preset.set_meta('low',Vector3i(report.low[0],report.low[1],report.low[2]))
	preset.set_meta('size',Vector3i(report.size[0],report.size[1],report.size[2]))
	preset.set_meta('source_sha256',FileAccess.get_sha256(SOURCE))
	preset.set_meta('source',SOURCE)
	preset.set_meta('step',.25)
	preset.set_meta('triangles',5028)
	var error := ResourceSaver.save(preset,PRESET)
	FileAccess.open(WORK+'godot_export_check.json',FileAccess.WRITE).store_string(JSON.stringify({
		'godot':Engine.get_version_info().string,'triangles':actual.size()/3,
		'expected_to_imported_vertex_max_m':forward,'imported_to_expected_vertex_max_m':reverse,
		'preset':PRESET,'preset_sha256':FileAccess.get_sha256(PRESET),'pack_error':error,
		'scope':'Reimport of canonical GLB at identity transform. Vertex proximity only, not continuous surface bound or art acceptance.'
	},'\t',true,true))
	print('REFINED VOLUME PACK: ',error,'; export max delta=',maxf(forward,reverse))
	scene.queue_free()
	quit(0 if error==OK else 1)
