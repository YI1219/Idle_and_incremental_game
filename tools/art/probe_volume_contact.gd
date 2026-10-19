extends SceneTree
## Matched adopted/legacy contact control; no source geometry or save change.
const Scene := preload('res://scenes/volume_patch_study.tscn')
const Surface := preload('res://scripts/terrain_volume/patch_surface.gd')
const OUT := 'res://art/review/terrain_fidelity/2026-10-20/volume_diagnosis/'
var viewport: SubViewport
var study: Node3D
var captures: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred('run')
func capture(name: String) -> void:
	for i: int in 10:
		RenderingServer.force_draw(false)
		await process_frame
	RenderingServer.force_draw(false)
	var error := viewport.get_texture().get_image().save_png(OUT+name+'.png')
	captures.append({'file':name+'.png','error':error})
func digest(mesh: ArrayMesh) -> String:
	var hash_value := HashingContext.new()
	hash_value.start(HashingContext.HASH_SHA256)
	var arrays := mesh.surface_get_arrays(0)
	hash_value.update((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array())
	hash_value.update((arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).to_byte_array())
	return hash_value.finish().hex_encode()
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
	study.camera.position = Vector3(6,5.4,10)
	study.camera.look_at(Vector3(.3,1.7,.2))
	study.camera.size = 5.
	var before: Dictionary = study.document.serialize()
	var before_digest := digest(study.body.mesh)
	study.material.set_shader_parameter('use_contact_field',false)
	await capture('contact_vertex')
	study.material.set_shader_parameter('use_contact_field',true)
	await capture('contact_fragment')
	var image: Image = study.last_build.contact.map
	var dimensions := image.get_size()
	var after_digest := digest(study.body.mesh)
	var valid: bool = before == study.document.serialize() and before_digest == after_digest
	for item: Dictionary in captures: valid = valid and item.error == OK
	FileAccess.open(OUT+'contact_probe.json',FileAccess.WRITE).store_string(JSON.stringify({
		'captures':captures,'document_unchanged':before==study.document.serialize(),
		'vertices_normals_sha256_before':before_digest,'vertices_normals_sha256_after':after_digest,
		'texture_size':[dimensions.x,dimensions.y],'texture_cpu_bytes':image.get_data_size(),
		'scope':'Native old vertex/new adopted per-fragment material control in isolated study only. Same mesh/normals/camera/light; no source/default geometry change or art acceptance.'
	},'\t',true,true))
	study.document.begin_stroke()
	for z: float in [-4.,-3.,-2.,-1.,0.,1.,2.,3.,4.]:
		study.document.apply_brush(Vector3(.8,.2,z),.85,'rock_cut')
	study.document.end_stroke()
	study.rebuild()
	study.camera.position = Vector3(3,1.,12)
	study.camera.look_at(Vector3(.8,.4,0))
	study.camera.size = 6.
	await capture('contact_tunnel')
	study.document.undo()
	study.document.begin_stroke()
	for z: float in [-.3,.5,1.3,2.1,2.9,3.7,4.5]:
		study.document.apply_brush(Vector3(-.8,2.25,z),.75,'rock_cut')
	study.document.end_stroke()
	study.rebuild()
	study.camera.position = Vector3(6,5.4,10)
	study.camera.look_at(Vector3(.3,1.7,.2))
	study.camera.size = 5.
	await capture('contact_breach')
	var breached: bool = not study.water.visible and not study.last_build.lake.valid
	study.document.undo()
	study.rebuild()
	var restored: bool = before == study.document.serialize() and digest(study.body.mesh)==before_digest
	valid = valid and restored and breached
	for item: Dictionary in captures: valid = valid and item.error == OK
	FileAccess.open(OUT+'contact_edit_probe.json',FileAccess.WRITE).store_string(JSON.stringify({
		'captures':captures,'source_restored':restored,'breach_water_hidden':breached,
		'contact_refreshed_with_edits':study.material.get_shader_parameter('use_contact_field')==true,
		'build_ms_restored':study.last_build.build_ms,'art_accepted':false
	},'\t',true,true))
	print('VOLUME CONTACT PROBE: ',valid,'; exact geometry/normal identity=',before_digest==after_digest)
	quit(0 if valid else 1)
