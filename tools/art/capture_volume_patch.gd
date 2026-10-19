extends SceneTree
const Scene := preload('res://scenes/volume_patch_study.tscn')
const OUT := 'res://art/review/terrain_fidelity/2026-10-19/volume_patch/'
var viewport: SubViewport
var study: Node3D
var captures: Array[Dictionary] = []
var states: Dictionary = {}
func _initialize() -> void:
	call_deferred('run')
func capture(label: String, at: Vector3, target: Vector3, size: float) -> void:
	study.camera.position = at
	study.camera.look_at(target)
	study.camera.size = size
	for i: int in 12:
		RenderingServer.force_draw(false)
		await process_frame
	RenderingServer.force_draw(false)
	var error := viewport.get_texture().get_image().save_png(OUT+label+'.png')
	captures.append({'file': label+'.png', 'error': error, 'position': str(at), 'target': str(target), 'size': size})
func record(label: String) -> void:
	states[label] = {'triangles': study.last_build.triangles, 'water_triangles': study.last_build.water_triangles,
		'build_ms': study.last_build.build_ms, 'mesh_ms': study.last_build.mesh_ms,
		'lake_valid': study.last_build.lake.valid, 'lake_reason': study.last_build.lake.reason,
		'overrides': study.document.field.samples.size()}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1671,941)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	study = Scene.instantiate()
	viewport.add_child(study)
	study.hud.hide()
	study.cursor.hide()
	study.set_process(false)
	record('initial')
	var before: Dictionary = study.document.serialize()
	# Matched source control: exact same camera, light and world-space material.
	var source_document := GLTFDocument.new()
	var source_state := GLTFState.new()
	var source_error := source_document.append_from_file('res://art/source/cliff_master_v2/2026-10-18/tripo/cliff_land_master_v2_white.glb', source_state)
	if source_error != OK:
		push_error('Source control import failed'); quit(1); return
	var original := source_document.generate_scene(source_state)
	viewport.add_child(original)
	original.rotation.y = -PI/2.
	var parts: Array[MeshInstance3D] = []
	_collect(original, parts)
	var points := PackedVector3Array()
	for part: MeshInstance3D in parts:
		for p: Vector3 in part.mesh.get_faces(): points.append(part.global_transform*p)
	var bounds := AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points: bounds = bounds.expand(p)
	var scale_value := 8.5/bounds.size.x
	original.scale = Vector3.ONE*scale_value
	original.position = Vector3(-bounds.get_center().x*scale_value,3.25-bounds.end.y*scale_value,-bounds.get_center().z*scale_value)
	var neutral := StandardMaterial3D.new()
	neutral.albedo_color = Color(.46,.47,.44)
	neutral.roughness = .95
	for part: MeshInstance3D in parts: part.material_override = neutral
	study.body.hide()
	study.water.hide()
	await capture('source_neutral', Vector3(9,8,15), Vector3(0,1.1,0), 7.)
	original.hide()
	study.body.show()
	var source_only = load('res://scripts/terrain_volume/patch_document.gd').new()
	if not source_only.load_preset():
		push_error('Source control preset failed'); quit(1); return
	source_only.field.samples.clear()
	study.body.mesh = load('res://scripts/terrain_volume/patch_surface.gd').build(source_only).terrain
	study.body.material_override = neutral
	await capture('converted_neutral', Vector3(9,8,15), Vector3(0,1.1,0), 7.)
	study.body.mesh = study.last_build.terrain
	study.body.material_override = study.material
	study.water.show()
	await capture('initial_play', Vector3(9,8,15), Vector3(0,1.1,0), 7.)
	await capture('initial_close', Vector3(6,5.4,10), Vector3(.3,1.7,.2), 5.)
	await capture('initial_reverse', Vector3(-9,6,-12), Vector3(0,1.1,0), 7.)
	await capture('initial_low', Vector3(8,-3,12), Vector3(0,1.,0), 7.)
	study.material.set_shader_parameter('detailed', false)
	await capture('simple_material', Vector3(6,5.4,10), Vector3(.3,1.7,.2), 5.)
	study.material.set_shader_parameter('detailed', true)
	study.document.begin_stroke()
	for z: float in [-4.,-3.,-2.,-1.,0.,1.,2.,3.,4.]:
		study.document.apply_brush(Vector3(.8,.2,z), .85, 'rock_cut')
	study.document.end_stroke()
	study.rebuild()
	record('tunnel')
	await capture('tunnel_play', Vector3(9,8,15), Vector3(0,1.1,0), 7.)
	await capture('tunnel_low', Vector3(3,1.,12), Vector3(.8,.4,0), 6.)
	study.document.undo()
	study.document.begin_stroke()
	for z: float in [-.3,.5,1.3,2.1,2.9,3.7,4.5]:
		study.document.apply_brush(Vector3(-.8,2.25,z), .75, 'rock_cut')
	study.document.end_stroke()
	study.rebuild()
	record('lake_breach')
	await capture('lake_breach', Vector3(9,8,15), Vector3(0,1.1,0), 7.)
	study.document.undo()
	study.rebuild()
	var restored: bool = before == study.document.serialize()
	await capture('restored', Vector3(9,8,15), Vector3(0,1.1,0), 7.)
	var valid := restored
	for item: Dictionary in captures: valid = valid and item.error == OK
	FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({
		'captures':captures,'states':states,'undo_restored':restored,'capture_success':valid,
		'godot':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),
		'resolution':[1671,941],'source_sha256':before.source_sha256,'art_accepted':false,
		'scope':'Native isolated sculpt study. No whole-island replacement, new house, high-poly bake or target-device claim. Small synchronous rebuild, not final async chunk architecture.'
	},'\t',true,true))
	print('VOLUME PATCH CAPTURES: ',valid,'; frames=',captures.size(),'; restored=',restored)
	quit(0 if valid else 1)
func _collect(node: Node, parts: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: parts.append(node)
	for child: Node in node.get_children(): _collect(child,parts)
