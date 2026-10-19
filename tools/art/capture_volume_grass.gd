extends 'res://tools/art/capture_refined_volume.gd'
const Grass := preload('res://tools/art/volume_grass_contact.gd')
const REVIEW := 'res://art/review/terrain_fidelity/2026-10-20/volume_grass/'
func output_dir() -> String:
	return REVIEW
func mesh_hash(mesh: Mesh) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(mesh.get_faces().to_byte_array())
	return hash.finish().hex_encode()
func grass_views(name: String) -> void:
	await capture(name+'_play',Vector3(9,8,15),Vector3(0,1.1,0),7.)
	await capture(name+'_close',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	await capture(name+'_reverse',Vector3(-9,6,-12),Vector3(0,1.1,0),7.)
	await capture(name+'_edge',Vector3(5,4.7,8),Vector3(.5,2.7,1.5),2.8)
func summary_of(grass: Dictionary) -> Dictionary:
	return {'anchors':grass.anchors.size(),'triangles':grass.triangles,'root_checks':grass.root_checks,
		'unsupported_roots':grass.unsupported_roots,'rejected_fans':grass.rejected_fans,'build_ms':grass.build_ms}
func run() -> void:
	create_timer(45.).timeout.connect(func() -> void: push_error('Grass capture timed out'); quit(1))
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
	study.material.set_shader_parameter('grass_contact_depth',Vector2(.02,.14))
	study.material.set_shader_parameter('grass_contact_slope',Vector2(.5,.9))
	study.material.set_shader_parameter('soil_contact_depth',Vector2(.08,.30))
	study.document = Refined.new()
	if not study.document.load_preset(): quit(1); return
	study.rebuild()
	var saved: Dictionary = study.document.serialize()
	var before_hash := mesh_hash(study.body.mesh)
	await grass_views('bare')
	var grass := Grass.build(study.document)
	var node := MeshInstance3D.new()
	node.mesh = grass.mesh
	var material := ShaderMaterial.new()
	material.shader = preload('res://shaders/terrain_editor/volume_grass.gdshader')
	node.material_override = material
	study.add_child(node)
	await grass_views('grass')
	var same_solid: bool = before_hash==mesh_hash(study.body.mesh) and study.document.serialize()==saved
	states['grass'] = summary_of(grass)
	var first: Vector3 = grass.anchors[0]
	var nearest := INF
	for anchor: Vector3 in grass.anchors:
		var distance := Vector2(anchor.x-.3,anchor.z-1.8).length_squared()
		if distance<nearest:
			nearest = distance
			first = anchor
	var cut_camera := first+Vector3(4,3,7)
	var cut_target := first-Vector3.UP*.12
	await capture('grass_cut_before',cut_camera,cut_target,2.8)
	study.document.begin_stroke()
	study.document.apply_brush(first,.55,'rock_cut')
	study.document.end_stroke()
	study.rebuild()
	var cut := Grass.build(study.document)
	node.mesh = cut.mesh
	states['cut'] = summary_of(cut)
	await capture('grass_cut',cut_camera,cut_target,2.8)
	study.document.undo()
	study.rebuild()
	var restored := Grass.build(study.document)
	node.mesh = restored.mesh
	var exact: bool = study.document.serialize()==saved and before_hash==mesh_hash(study.body.mesh) and mesh_hash(restored.mesh)==mesh_hash(grass.mesh)
	await capture('grass_restored',cut_camera,cut_target,2.8)
	var valid: bool = same_solid and exact and not cut.anchors.has(first)
	for item: Dictionary in captures: valid = valid and item.error==OK
	FileAccess.open(REVIEW+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({
		'captures':captures,'states':states,'same_solid_and_data':same_solid,'restore_exactly':exact,'capture_success':valid,
		'terrain_sha256':before_hash,'grass_sha256':mesh_hash(grass.mesh),
		'source_preset_sha256':saved.source_sha256,'godot':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),
		'scope':'Same lower-return mother, shore, narrow contact, camera and lights. Existing supported grass only; side-plane candidate not adopted. Water TIME live. No new ground, tree/rock tool, source/default/save change or art acceptance.'
	},'\t',true,true))
	print('VOLUME GRASS CAPTURES: ',valid,'; frames=',captures.size(),'; same solid=',same_solid,'; restored=',exact)
	quit(0 if valid else 1)
