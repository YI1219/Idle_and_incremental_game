extends SceneTree
const Scene := preload('res://scenes/volume_patch_study.tscn')
const Profile := preload('res://tools/art/volume_bank_profile.gd')
const OUT := 'res://art/review/terrain_fidelity/2026-10-20/volume_bank/'
var viewport: SubViewport
var study: Node3D
var captures: Array[Dictionary] = []
var states: Dictionary = {}
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
	var error := viewport.get_texture().get_image().save_png(OUT+name+'.png')
	captures.append({'file':name+'.png','error':error,'at':str(at),'target':str(target),'size':size_value})
func record(name: String) -> void:
	states[name] = {'triangles':study.last_build.triangles,'water_triangles':study.last_build.water_triangles,
		'build_ms':study.last_build.build_ms,'lake_valid':study.last_build.lake.valid,
		'water_level':study.document.lake.level,'center_floor':study.document.field.height_at(Vector2(-.8,0))}
func views(name: String) -> void:
	await capture(name+'_play',Vector3(9,8,15),Vector3(0,1.1,0),7.)
	await capture(name+'_close',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	await capture(name+'_reverse',Vector3(-9,6,-12),Vector3(0,1.1,0),7.)
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
	var original: Dictionary = study.document.serialize()
	record('sphere')
	await views('sphere')
	study.document = Profile.make()
	if study.document == null:
		push_error('Profile factory failed'); quit(1); return
	study.rebuild()
	record('profile')
	var candidate: Dictionary = study.document.serialize()
	var unchanged_outer := _outer_digest(original) == _outer_digest(candidate)
	await views('profile')
	FileAccess.open(OUT+'profile_v1.json',FileAccess.WRITE).store_string(JSON.stringify(candidate,'',true,true))
	study.document.begin_stroke()
	for z: float in [-.3,.5,1.3,2.1,2.9,3.7,4.5]:
		study.document.apply_brush(Vector3(-.8,2.25,z),.75,'rock_cut')
	study.document.end_stroke()
	study.rebuild()
	record('breach')
	await capture('profile_breach',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	study.document.undo()
	study.rebuild()
	var restored: bool = study.document.serialize()==candidate
	await capture('profile_restored',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	var valid: bool = restored and unchanged_outer and states.profile.lake_valid and not states.breach.lake_valid
	for item: Dictionary in captures: valid = valid and item.error==OK
	FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({
		'captures':captures,'states':states,'profile_restored':restored,'outer_samples_identical':unchanged_outer,
		'capture_success':valid,'source_preset_sha256':candidate.source_sha256,'art_accepted':false,
		'outer_check_scope':'Outside the original sphere brush support, including its finite signed-distance band; not only the visible water/bank outline.',
		'godot':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),
		'scope':'One lake design change: sphere/low water versus designed profile/higher water. Same source rock, camera, shader, textures and lights. Not a single scalar parameter change. No full-island, default preset/save, paid model job or mother-rock shape replacement.'
	},'\t',true,true))
	print('VOLUME BANK CAPTURES: ',valid,'; frames=',captures.size(),'; restored=',restored,'; outer=',unchanged_outer)
	quit(0 if valid else 1)
func _outer_digest(payload: Dictionary) -> String:
	# Compare outside the full old brush envelope, not only its visible basin.
	# Three negative near-surface knots atX.75,Y2.75,Z±.25 change by<=.056m
	# when the old sphere distance band is retired, without a sign change.
	# The immutable underlying source is identical in both documents.
	var reach := 1.25 + .5
	var low := ((Vector3(-.8,3.35,0)-Vector3.ONE*reach)/.25).floor()*.25
	var high := ((Vector3(-.8,3.35,0)+Vector3.ONE*reach)/.25).ceil()*.25
	var rows: Array = []
	for row: Dictionary in payload.rocks:
		var p := Vector3(row.x,row.y,row.z)*.25
		if p.min(low)!=low or p.max(high)!=high: rows.append(row)
	return JSON.stringify(rows,'',true,true)
