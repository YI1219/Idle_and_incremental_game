extends 'res://tools/art/capture_refined_volume.gd'
const Modules := preload('res://tools/art/volume_module_document.gd')
const Grass := preload('res://tools/art/volume_grass_contact.gd')
const REVIEW := 'res://art/review/terrain_fidelity/2026-10-20/volume_modules/'
const WORK := 'res://art/work/volume_modules/2026-10-20/'
var grass_node := MeshInstance3D.new()
func output_dir() -> String:
	return REVIEW
func publish(doc: RefCounted, name: String) -> void:
	study.document = doc
	study.rebuild()
	var grass := Grass.build(doc)
	grass_node.mesh = grass.mesh
	record(name)
	states[name]['grass_triangles'] = grass.triangles
	states[name]['grass_anchors'] = grass.anchors.size()
	states[name]['grass_roots'] = grass.root_checks
	states[name]['collision_matches_mesh'] = study.collision.shape.get_faces()==study.body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
func run() -> void:
	create_timer(60.).timeout.connect(func() -> void: push_error('Module patch capture timed out'); quit(1))
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
	var grass_material := ShaderMaterial.new()
	grass_material.shader = preload('res://shaders/terrain_editor/volume_grass.gdshader')
	grass_node.material_override = grass_material
	study.add_child(grass_node)
	var old := Refined.new()
	if not old.load_preset(): quit(1); return
	publish(old,'lower_patch')
	await views('lower_patch')
	var doc := Modules.new()
	if not doc.load_preset(): quit(1); return
	publish(doc,'module_patch')
	await views('module_patch')
	var saved: Dictionary = doc.serialize()
	FileAccess.open(REVIEW+'module_patch_v1.json',FileAccess.WRITE).store_string(JSON.stringify(saved,'',true,true))
	doc.begin_stroke()
	for z: float in [-2.,-1.2,-.4,.4,1.2,2.]: doc.apply_brush(Vector3(1.,.8,z),.7,'rock_cut')
	doc.end_stroke()
	publish(doc,'tunnel')
	await capture('module_patch_tunnel',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	doc.undo()
	doc.begin_stroke()
	for z: float in [-.3,.5,1.3,2.1,2.9,3.7,4.5]: doc.apply_brush(Vector3(-.8,2.25,z),.75,'rock_cut')
	doc.end_stroke()
	publish(doc,'breach')
	await capture('module_patch_breach',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	doc.undo()
	publish(doc,'restored')
	var exact: bool = doc.serialize()==saved
	await capture('module_patch_restored',Vector3(6,5.4,10),Vector3(.3,1.7,.2),5.)
	# Neutral conversion check against the unedited source, not the pond cut.
	doc.field.samples.clear()
	doc.field._height_bounds_dirty = true
	doc.lake.enabled = false
	publish(doc,'unedited_conversion')
	grass_node.hide()
	var neutral := StandardMaterial3D.new()
	neutral.albedo_color = Color(.48,.48,.48)
	neutral.roughness = 1.
	study.body.material_override = neutral
	var file := FileAccess.open(WORK+'converted.bin',FileAccess.WRITE)
	file.store_buffer(study.body.mesh.get_faces().to_byte_array())
	file.close()
	await capture('module_converted_neutral',Vector3(9,8,15),Vector3(0,1.1,0),7.)
	var valid: bool = exact and states.module_patch.lake_valid and not states.breach.lake_valid
	for item: Dictionary in captures: valid = valid and item.error==OK
	for state: Dictionary in states.values(): valid = valid and state.collision_matches_mesh
	FileAccess.open(REVIEW+'patch_captures.json',FileAccess.WRITE).store_string(JSON.stringify({
		'captures':captures,'states':states,'restored_exactly':exact,'capture_success':valid,
		'godot':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),
		'scope':'Same cameras/lights/terrain shader/grass/pond profile. Different derived source only. Source assembly1816tri vs old5028; converted neutral is unedited. Water TIME live. Actual document strokes/mesh collision, no official save/default or art acceptance.'
	},'\t',true,true))
	print('MODULE PATCH CAPTURES: ',valid,'; frames=',captures.size(),'; restored=',exact)
	quit(0 if valid else 1)
