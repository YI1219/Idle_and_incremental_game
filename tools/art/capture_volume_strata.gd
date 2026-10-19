extends 'res://tools/art/capture_refined_volume.gd'
const Modules := preload('res://tools/art/volume_module_document.gd')
const Grass := preload('res://tools/art/volume_grass_contact.gd')
const REVIEW := 'res://art/review/terrain_fidelity/2026-10-20/volume_strata/'
var legacy_shader := Shader.new()
var grass_node := MeshInstance3D.new()
var pairs: Array[Dictionary] = []
var gpu: Dictionary = {}
func output_dir() -> String:
	return REVIEW
func digest() -> String:
	var arrays: Array = study.body.mesh.surface_get_arrays(0)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array())
	hash.update((arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).to_byte_array())
	return hash.finish().hex_encode()
func variant(shader: Shader) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = shader
	for name: String in ['stone_detail_map','stone_mineral_map','ground_detail_map','detailed','use_contact_field','grass_contact_depth','grass_contact_slope','soil_contact_depth','contact_field','contact_origin','contact_extent','lake_center','lake_level','lake_enabled']:
		result.set_shader_parameter(name,study.material.get_shader_parameter(name))
	return result
func publish(name: String) -> void:
	study.rebuild()
	grass_node.mesh = Grass.build(study.document).mesh
	record(name)
func pair(name: String, at: Vector3, target: Vector3, span: float) -> void:
	var saved: Dictionary = study.document.serialize()
	var before := digest()
	var old := variant(legacy_shader)
	old.set_shader_parameter('lake_enabled',study.document.lake.enabled)
	study.body.material_override = old
	await capture(name+'_before',at,target,span)
	study.body.material_override = study.material
	await capture(name+'_after',at,target,span)
	pairs.append({'state':name,'same_document':saved==study.document.serialize(),'same_vertices_normals':before==digest(),'mesh_sha256':before})
func debug_shader() -> Shader:
	var result := Shader.new()
	# Instrument actual production calculations; no independent shader formula.
	result.code = FileAccess.get_file_as_string('res://shaders/terrain_editor/volume_patch.gdshader').replace('ALBEDO=color;','ALBEDO=vec3(0.); EMISSION=vec3(cover,local_soil,wet);')
	return result
func debug_image() -> Image:
	study.body.material_override = variant(debug_shader())
	study.camera.position = Vector3(0,16,.001)
	study.camera.look_at(Vector3(0,2,0),Vector3.FORWARD)
	study.camera.size = 7.
	study.water.hide()
	grass_node.hide()
	for i: int in 10:
		RenderingServer.force_draw(false)
		await process_frame
	RenderingServer.force_draw(false)
	return viewport.get_texture().get_image()
func channel_at(image: Image, at: Vector2) -> Color:
	var h: float = study.document.field.height_at(at)
	var p: Vector2 = study.camera.unproject_position(Vector3(at.x,h,at.y))
	return image.get_pixel(roundi(p.x),roundi(p.y))
func run() -> void:
	create_timer(60.).timeout.connect(func() -> void: push_error('Strata native capture timed out'); quit(1))
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
	legacy_shader.code = FileAccess.get_file_as_string(REVIEW+'legacy_volume_patch.gdshader')
	var grass_material := ShaderMaterial.new()
	grass_material.shader = preload('res://shaders/terrain_editor/volume_grass.gdshader')
	grass_node.material_override = grass_material
	study.add_child(grass_node)
	study.document = Modules.new()
	if not study.document.load_preset(): quit(1); return
	publish('initial')
	var saved: Dictionary = study.document.serialize()
	var initial_hash := digest()
	await pair('pond',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	await pair('low',Vector3(9,-3,14),Vector3(0,1.1,0),7.)
	study.document.begin_stroke()
	study.document.apply_brush(Vector3(2,2.6,1),1.3,'rock_plane',Vector3.UP)
	study.document.end_stroke()
	publish('cut')
	await pair('cut',Vector3(6,6.6,10),Vector3(1.,2.5,.8),4.5)
	var image := await debug_image()
	image.save_png(REVIEW+'cut_classification.png')
	var cut := channel_at(image,Vector2(2,1))
	var uncut := channel_at(image,Vector2(2,-1))
	var bed := channel_at(image,Vector2(-.75,0))
	gpu = {'cut_cover':cut.r,'uncut_cover':uncut.r,'bed_wet':bed.b,'cut_wet':cut.b,
		'actual_gpu_contact_matches':(study.material.get_shader_parameter('contact_field') as Texture2D).get_image().get_data()==study.last_build.contact.map.get_data()}
	study.document.undo()
	publish('restored')
	var restored: bool = saved==study.document.serialize() and initial_hash==digest()
	study.body.material_override = study.material
	grass_node.show()
	study.water.visible = study.last_build.lake.valid
	study.document.begin_stroke()
	for z: float in [-.3,.5,1.3,2.1,2.9,3.7,4.5]: study.document.apply_brush(Vector3(-.8,2.25,z),.75,'rock_cut')
	study.document.end_stroke()
	publish('breach')
	await pair('breach',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	image = await debug_image()
	image.save_png(REVIEW+'breach_classification.png')
	var wet_pixels := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c := image.get_pixel(x,y)
			if c.b>.15 and c.b>c.r+.1 and c.b>c.g+.1: wet_pixels += 1
	gpu['breach_wet_pixels'] = wet_pixels
	var valid: bool = restored and not states.breach.lake_valid and gpu.cut_cover<.05 and gpu.uncut_cover>.5 and gpu.bed_wet>.5 and gpu.cut_wet<.05 and wet_pixels==0 and gpu.actual_gpu_contact_matches
	for item: Dictionary in captures: valid = valid and item.error==OK
	for item: Dictionary in pairs: valid = valid and item.same_document and item.same_vertices_normals
	FileAccess.open(REVIEW+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'captures':captures,'states':states,'pairs':pairs,'gpu':gpu,'restored_exactly':restored,'valid':valid,'godot':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),
		'scope':'Actual same-geometry old/new production-shader comparison with identical grass and camera/light. GPU false colors instrument production calculations; no art approval, default/save/source modification, target-device or whole-scene claim. Water TIME live.'},'\t',true,true))
	print('VOLUME STRATA NATIVE: ',valid,'; ',JSON.stringify(gpu))
	quit(0 if valid else 1)
