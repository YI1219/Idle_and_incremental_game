extends 'res://tools/art/capture_refined_volume.gd'
const Planes := preload('res://tools/art/volume_plane_document.gd')
const REVIEW := 'res://art/review/terrain_fidelity/2026-10-20/volume_planes/'
func output_dir() -> String:
	return REVIEW
func run() -> void:
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
	record('lower_return')
	await views('lower_return')
	study.document = Planes.new()
	if not study.document.load_preset(): quit(1); return
	study.rebuild()
	record('side_planes')
	await views('side_planes')
	var saved: Dictionary = study.document.serialize()
	FileAccess.open(REVIEW+'side_planes_v1.json',FileAccess.WRITE).store_string(JSON.stringify(saved,'',true,true))
	study.document.begin_stroke()
	for z: float in [-2.,-1.2,-.4,.4,1.2,2.]: study.document.apply_brush(Vector3(1.,.8,z),.7,'rock_cut')
	study.document.end_stroke()
	study.rebuild()
	record('tunnel')
	await capture('side_planes_tunnel',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	study.document.undo()
	study.document.begin_stroke()
	for z: float in [-.3,.5,1.3,2.1,2.9,3.7,4.5]: study.document.apply_brush(Vector3(-.8,2.25,z),.75,'rock_cut')
	study.document.end_stroke()
	study.rebuild()
	record('breach')
	await capture('side_planes_breach',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	study.document.undo()
	study.rebuild()
	var restored: bool = study.document.serialize()==saved
	await capture('side_planes_restored',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	var neutral := StandardMaterial3D.new()
	neutral.albedo_color = Color(.48,.48,.48)
	neutral.roughness = 1.
	study.body.material_override = neutral
	for planes: bool in [false,true]:
		study.document = Planes.new() if planes else Refined.new()
		study.document.load_preset()
		study.document.field.samples.clear()
		study.document.field._height_bounds_dirty = true
		study.document.lake.enabled = false
		study.rebuild()
		await capture(('side_planes' if planes else 'lower_return')+'_neutral',Vector3(9,8,15),Vector3(0,1.1,0),7.)
	var valid: bool = restored and states.side_planes.lake_valid and not states.breach.lake_valid
	for item: Dictionary in captures: valid = valid and item.error==OK
	FileAccess.open(REVIEW+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({
		'captures':captures,'states':states,'restored_exactly':restored,'capture_success':valid,
		'godot':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),
		'scope':'Same cameras/lights/narrow contact/lake profile. Side-plane compression changes existing mother only; water TIME live. Neutral views omit maps and pond. No original/default/save changes or art acceptance.'
	},'\t',true,true))
	print('VOLUME SIDE PLANES CAPTURES: ',valid,'; frames=',captures.size(),'; restored=',restored)
	quit(0 if valid else 1)
