extends SceneTree
## Export actual existing GLB triangles; --pack packs Blender-sampled data.
const SOURCE := 'res://art/source/cliff_master_v2/2026-10-18/tripo/cliff_land_master_v2_white.glb'
const WORK := 'res://art/work/volume_patch/2026-10-19/'
const PRESET := 'res://assets/terrain/volume_patch/source_rock_v1.res'
func _initialize() -> void:
	call_deferred('run')
func collect(node: Node, parts: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		parts.append(node)
	for child: Node in node.get_children():
		collect(child, parts)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(WORK)
	if OS.get_cmdline_user_args().has('--font'):
		var font := FontFile.new()
		font.data = FileAccess.get_file_as_bytes('res://assets/fonts/YunluVolumeUI-Regular.ttf')
		var font_error := ResourceSaver.save(font, 'res://assets/fonts/YunluVolumeUI-Regular.res')
		print('VOLUME FONT PACK: ',font_error)
		quit(0 if font_error == OK else 1)
		return
	if OS.get_cmdline_user_args().has('--pack'):
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORK + 'sampling.json'))
		var bytes := FileAccess.get_file_as_bytes(WORK + 'density.bin')
		var preset := Resource.new()
		preset.set_meta('density', bytes.to_float32_array())
		preset.set_meta('low', Vector3i(report.low[0], report.low[1], report.low[2]))
		preset.set_meta('size', Vector3i(report.size[0], report.size[1], report.size[2]))
		preset.set_meta('source_sha256', FileAccess.get_sha256(SOURCE))
		preset.set_meta('source', SOURCE)
		preset.set_meta('step', .25)
		preset.set_meta('triangles', report.input_topology.triangles)
		DirAccess.make_dir_recursive_absolute(PRESET.get_base_dir())
		var error := ResourceSaver.save(preset, PRESET)
		print('VOLUME PRESET PACK: ', error)
		quit(0 if error == OK else 1)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(SOURCE, state)
	if error != OK:
		push_error('Source import failed: ' + str(error)); quit(1); return
	var original := document.generate_scene(state)
	root.add_child(original)
	original.rotation.y = -PI / 2.
	var parts: Array[MeshInstance3D] = []
	collect(original, parts)
	var points := PackedVector3Array()
	for part: MeshInstance3D in parts:
		for p: Vector3 in part.mesh.get_faces():
			points.append(part.global_transform * p)
	if points.is_empty():
		push_error('Source has no triangles'); quit(1); return
	var bounds := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		bounds = bounds.expand(p)
	var scale_value := 8.5 / bounds.size.x
	var offset := Vector3(-bounds.get_center().x * scale_value, 3.25 - bounds.end.y * scale_value, -bounds.get_center().z * scale_value)
	for i: int in points.size():
		points[i] = points[i] * scale_value + offset
	var binary := FileAccess.open(WORK + 'source.bin', FileAccess.WRITE)
	binary.store_buffer(points.to_byte_array())
	binary.close()
	FileAccess.open(WORK + 'source.json', FileAccess.WRITE).store_string(JSON.stringify({
		'source': SOURCE, 'source_sha256': FileAccess.get_sha256(SOURCE),
		'triangle_sha256': FileAccess.get_sha256(WORK + 'source.bin'),
		'uniform_scale': scale_value, 'translation': str(offset), 'rotation_y': -90,
		'triangles': points.size() / 3, 'width': 8.5, 'top': 3.25,
		'scope': 'Existing source, rigid rotation + uniform scale + translation only; no new geometry or source overwrite.'
	}, '\t', true, true))
	original.queue_free()
	print('VOLUME SOURCE EXPORT: ', points.size() / 3, ' triangles')
	quit()
