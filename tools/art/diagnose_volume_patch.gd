extends SceneTree
## Read-only cause isolation. Does not revise the art or any editable source.
const Scene := preload('res://scenes/volume_patch_study.tscn')
const Document := preload('res://scripts/terrain_volume/patch_document.gd')
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
	var arrays: Array = study.body.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var groups: Dictionary = {}
	var mixed_triangles := 0
	var footprint_crossings := 0
	for i: int in range(0,points.size(),3):
		var lowest := 1.
		var highest := 0.
		var covered := 0
		for j: int in 3:
			var p := points[i+j]
			lowest = minf(lowest, colors[i+j].r)
			highest = maxf(highest, colors[i+j].r)
			if study.document.field.base.cover_columns.has(Vector2i(roundi(p.x/.25),roundi(p.z/.25))): covered += 1
			if not groups.has(p): groups[p] = Vector2(colors[i+j].r,colors[i+j].r)
			groups[p] = Vector2(minf(groups[p].x,colors[i+j].r),maxf(groups[p].y,colors[i+j].r))
		if lowest < .25 and highest > .75: mixed_triangles += 1
		if covered > 0 and covered < 3: footprint_crossings += 1
	var differing_positions := 0
	for range_value: Vector2 in groups.values():
		if range_value.y-range_value.x > .25: differing_positions += 1
	var debug := ShaderMaterial.new()
	debug.shader = Shader.new()
	debug.shader.code = '''shader_type spatial;
render_mode unshaded;
uniform bool show_normal = false;
varying vec3 world_normal;
void vertex(){world_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
 vec3 color=mix(vec3(.12,.14,.16),vec3(.34,.20,.08),COLOR.g);
 color=mix(color,vec3(.20,.70,.12),COLOR.r);
 if(show_normal)color=normalize(world_normal)*.5+.5;
 ALBEDO=color;
}'''
	study.body.material_override = debug
	study.water.hide()
	await capture('cover_without_lighting')
	debug.set_shader_parameter('show_normal', true)
	await capture('world_normals')
	# Export only the unedited conversion for distance-to-source analysis.
	var source_only := Document.new()
	if not source_only.load_preset():
		push_error('Diagnostic source preset failed'); quit(1); return
	source_only.field.samples.clear()
	var converted: Dictionary = Surface.build(source_only)
	var file := FileAccess.open(OUT+'converted_unedited.bin',FileAccess.WRITE)
	file.store_buffer(converted.terrain.get_faces().to_byte_array())
	file.close()
	var unchanged: bool = before == study.document.serialize()
	var valid := unchanged
	for item: Dictionary in captures: valid = valid and item.error == OK
	var report := {'captures':captures,'source_preset_sha256':before.source_sha256,
		'document_unchanged':unchanged,'geometry_changed':false,'art_variant_created':false,
		'cover_triangles_spanning_025_to_075':mixed_triangles,
		'triangles_crossing_boolean_planting_footprint':footprint_crossings,
		'coincident_positions_with_cover_difference_gt025':differing_positions,
		'unique_positions':groups.size(),'triangles':points.size()/3,
		'unedited_conversion_triangles':converted.triangles,
		'converted_triangle_sha256':FileAccess.get_sha256(OUT+'converted_unedited.bin'),
		'notes':'Diagnostic false colors, not proposed art. Normal-dependent cover differences may be intentional at hard top/wall creases; counts alone do not prove a bug. Inspect against rendered views. No shader, preset, save or official scene modified.'}
	FileAccess.open(OUT+'diagnosis.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t',true,true))
	print('VOLUME DIAGNOSIS: ',valid,'; ',mixed_triangles,' broad cover transitions; ',footprint_crossings,' footprint crossings')
	quit(0 if valid else 1)
