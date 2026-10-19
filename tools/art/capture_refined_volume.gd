extends SceneTree
const Scene := preload('res://scenes/volume_patch_study.tscn')
const Profile := preload('res://tools/art/volume_bank_profile.gd')
const Refined := preload('res://tools/art/volume_refined_document.gd')
const OUT := 'res://art/review/terrain_fidelity/2026-10-20/volume_shape/'
var viewport: SubViewport
var study: Node3D
var captures: Array[Dictionary] = []
var states: Dictionary = {}
func output_dir() -> String:
	return OUT
func _initialize() -> void:
	call_deferred('run')
func capture(name: String, at: Vector3, target: Vector3, size_value: float) -> void:
	study.camera.position = at
	study.camera.look_at(target)
	study.camera.size = size_value
	for i: int in 10:
		RenderingServer.force_draw(false)
		await process_frame
	RenderingServer.force_draw(false)
	var error := viewport.get_texture().get_image().save_png(output_dir()+name+'.png')
	captures.append({'file':name+'.png','error':error,'at':str(at),'target':str(target),'size':size_value})
func record(name: String) -> void:
	states[name] = {'triangles':study.last_build.triangles,'water_triangles':study.last_build.water_triangles,
		'build_ms':study.last_build.build_ms,'lake_valid':study.last_build.lake.valid,
		'source_sha256':study.document.field.base.source_sha256}
func views(name: String) -> void:
	await capture(name+'_play',Vector3(9,8,15),Vector3(0,1.1,0),7.)
	await capture(name+'_close',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	await capture(name+'_reverse',Vector3(-9,6,-12),Vector3(0,1.1,0),7.)
	await capture(name+'_low',Vector3(9,-3,14),Vector3(0,1.1,0),7.)
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
	study.document = Profile.make()
	study.rebuild()
	record('old_shape_new_bank')
	await views('old')
	study.document = Refined.new()
	if not study.document.load_preset(): quit(1); return
	study.rebuild()
	record('refined_shape_new_bank')
	await views('refined')
	var saved: Dictionary = study.document.serialize()
	FileAccess.open(OUT+'refined_v1.json',FileAccess.WRITE).store_string(JSON.stringify(saved,'',true,true))
	study.document.begin_stroke()
	for z: float in [-2.,-1.2,-.4,.4,1.2,2.]: study.document.apply_brush(Vector3(1.,.8,z),.7,'rock_cut')
	study.document.end_stroke()
	study.rebuild()
	record('tunnel')
	await capture('refined_tunnel',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	study.document.undo()
	study.document.begin_stroke()
	for z: float in [-.3,.5,1.3,2.1,2.9,3.7,4.5]: study.document.apply_brush(Vector3(-.8,2.25,z),.75,'rock_cut')
	study.document.end_stroke()
	study.rebuild()
	record('breach')
	await capture('refined_breach',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	study.document.undo()
	study.rebuild()
	var restored: bool = study.document.serialize()==saved
	await capture('refined_restored',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	var normal_material := StandardMaterial3D.new()
	normal_material.albedo_color = Color(.48,.48,.48)
	normal_material.roughness = 1.
	study.body.material_override = normal_material
	for refined: bool in [false,true]:
		study.document = Refined.new() if refined else load('res://scripts/terrain_volume/patch_document.gd').new()
		study.document.load_preset()
		study.document.field.samples.clear()
		study.document.field._height_bounds_dirty = true
		study.document.lake.enabled = false
		study.rebuild()
		await capture(('refined' if refined else 'old')+'_neutral',Vector3(9,8,15),Vector3(0,1.1,0),7.)
	var valid: bool = restored and states.refined_shape_new_bank.lake_valid and not states.breach.lake_valid
	for item: Dictionary in captures: valid = valid and item.error==OK
	FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({
		'captures':captures,'states':states,'restored_exactly':restored,'capture_success':valid,
		'godot':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),
		'scope':'Same scene, camera, lights, material and lake profile. Only the existing-source lower body changes. Neutral views omit pond and surface maps. Local art unaccepted; default/source/save untouched.'
	},'\t',true,true))
	print('REFINED VOLUME CAPTURES: ',valid,'; frames=',captures.size(),'; restored=',restored)
	quit(0 if valid else 1)
