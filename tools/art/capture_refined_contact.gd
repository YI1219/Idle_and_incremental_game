extends SceneTree
const Scene := preload('res://scenes/volume_patch_study.tscn')
const Refined := preload('res://tools/art/volume_refined_document.gd')
const OUT := 'res://art/review/terrain_fidelity/2026-10-20/volume_shape/'
var viewport: SubViewport
var study: Node3D
var captures: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred('run')
func geometry_hash() -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(study.body.mesh.get_faces().to_byte_array())
	return hash.finish().hex_encode()
func capture(name: String, at: Vector3, target: Vector3, size_value: float) -> void:
	study.camera.position = at
	study.camera.look_at(target)
	study.camera.size = size_value
	for i: int in 10:
		RenderingServer.force_draw(false)
		await process_frame
	RenderingServer.force_draw(false)
	var error := viewport.get_texture().get_image().save_png(OUT+name+'.png')
	captures.append({'file':name+'.png','error':error,'at':str(at),'target':str(target),'size':size_value})
func run() -> void:
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
	study.document = Refined.new()
	if not study.document.load_preset(): quit(1); return
	study.rebuild()
	var before := FileAccess.get_sha256(Refined.REFINED)
	var mesh_hash := geometry_hash()
	for narrow: bool in [false,true]:
		study.material.set_shader_parameter('grass_contact_depth',Vector2(.02,.14) if narrow else Vector2(.06,.28))
		study.material.set_shader_parameter('grass_contact_slope',Vector2(.5,.9) if narrow else Vector2(.35,.82))
		study.material.set_shader_parameter('soil_contact_depth',Vector2(.08,.30) if narrow else Vector2(.12,.48))
		var name := 'narrow' if narrow else 'wide'
		await capture(name+'_play',Vector3(9,8,15),Vector3(0,1.1,0),7.)
		await capture(name+'_close',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
		await capture(name+'_reverse',Vector3(-9,6,-12),Vector3(0,1.1,0),7.)
	var unchanged: bool = before==FileAccess.get_sha256(Refined.REFINED) and mesh_hash==geometry_hash()
	var valid: bool = unchanged
	for item: Dictionary in captures: valid = valid and item.error==OK
	FileAccess.open(OUT+'contact_comparison.json',FileAccess.WRITE).store_string(JSON.stringify({
		'captures':captures,'geometry_sha256':mesh_hash,'source_sha256':before,'geometry_unchanged':unchanged,
		'capture_success':valid,'new_depth_range':[.02,.14],'new_slope_range':[.5,.9],'new_soil_range':[.08,.30],
		'godot':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),
		'scope':'Same refined mother and pond. Per-fragment depth/slope ranges narrow only the grass/soil contact; no new silhouette or physical grass. Defaults unchanged; local art unaccepted.'
	},'\t',true,true))
	print('REFINED CONTACT CAPTURES: ',valid,'; frames=',captures.size(),'; geometry unchanged=',unchanged)
	quit(0 if valid else 1)
