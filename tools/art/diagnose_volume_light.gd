extends 'res://tools/art/capture_refined_volume.gd'
## One-variable native light-direction diagnosis, no art/source promotion.
const Modules := preload('res://tools/art/volume_module_document.gd')
const Grass := preload('res://tools/art/volume_grass_contact.gd')
const REVIEW := 'res://art/review/terrain_fidelity/2026-10-20/volume_light_diagnosis/'
func output_dir() -> String:
	return REVIEW
func digest(mesh: Mesh) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	var arrays: Array = mesh.surface_get_arrays(0)
	for attribute: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR]: hash.update(arrays[attribute].to_byte_array())
	return hash.finish().hex_encode()
func run() -> void:
	create_timer(45.).timeout.connect(func() -> void: push_error('Light diagnosis timed out'); quit(1))
	DirAccess.make_dir_recursive_absolute(REVIEW)
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
	study.document = Modules.new()
	if not study.document.load_preset(): quit(1); return
	study.material.set_shader_parameter('grass_contact_depth',Vector2(.02,.14))
	study.material.set_shader_parameter('grass_contact_slope',Vector2(.5,.9))
	study.material.set_shader_parameter('soil_contact_depth',Vector2(.08,.30))
	study.rebuild()
	var grass := Grass.build(study.document)
	var node := MeshInstance3D.new()
	node.mesh = grass.mesh
	var grass_material := ShaderMaterial.new()
	grass_material.shader = preload('res://shaders/terrain_editor/volume_grass.gdshader')
	node.material_override = grass_material
	study.add_child(node)
	var saved: Dictionary = study.document.serialize()
	var before := digest(study.body.mesh)
	var grass_before := digest(node.mesh)
	var sun: DirectionalLight3D
	for child: Node in study.get_children():
		if child is DirectionalLight3D and child.shadow_enabled: sun = child
	if sun==null: push_error('Diagnostic key light absent'); quit(1); return
	var old_rotation := sun.rotation_degrees
	await views('current')
	sun.rotation_degrees = Vector3(old_rotation.x,-35.,old_rotation.z)
	await views('side_key')
	var valid: bool = study.document.serialize()==saved and before==digest(study.body.mesh) and grass_before==digest(node.mesh)
	for item: Dictionary in captures: valid = valid and item.error==OK
	var report := {'captures':captures,'same_document':study.document.serialize()==saved,'terrain_attributes_sha256':before,
		'same_terrain_attributes':before==digest(study.body.mesh),'same_grass_attributes':grass_before==digest(node.mesh),
		'current_sun_degrees':str(old_rotation),'diagnostic_sun_degrees':str(sun.rotation_degrees),
		'light_energy_unchanged':sun.light_energy,'capture_success':valid,
		'source_sha256':saved.source_sha256,'godot':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),
		'scope':'One-variable key-light yaw40 to -35 degrees; all geometry, normals, colors, materials, grass, pond, environment, fill, energy and exact cameras unchanged. Water TIME live. Diagnostic only, no source/default/save/style adoption, art or performance acceptance.'}
	FileAccess.open(REVIEW+'captures.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t',true,true))
	print('VOLUME LIGHT DIAGNOSIS: ',valid,'; frames=',captures.size(),'; geometry=',before)
	quit(0 if valid else 1)
