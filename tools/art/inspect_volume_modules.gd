extends SceneTree
const SOURCES := {
	'medium':'res://assets/nature/quaternius/Rock_Medium_1.gltf',
	'main':'res://assets/nature/refined/cliff_main_v4.glb',
	'tall':'res://assets/nature/refined/cliff_tall_v2.glb'}
const WORK := 'res://art/work/volume_modules/2026-10-20/'
const OUT := 'res://art/review/terrain_fidelity/2026-10-20/volume_modules/'
func _initialize() -> void:
	call_deferred('run')
func collect(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: result.append(node)
	for child: Node in node.get_children(): collect(child,result)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(WORK)
	DirAccess.make_dir_recursive_absolute(OUT)
	var report: Dictionary = {'sources':[],'scope':'Existing source inspection, no geometry changes. Catalog uniformly fits each source to2.8m maximum dimension, order medium/main/tall. Neutral imported normals; not an authored assembly or accepted game scene.'}
	var viewport: SubViewport
	var study: Node3D
	var headless := DisplayServer.get_name()=='headless'
	if not headless:
		viewport = SubViewport.new()
		viewport.size = Vector2i(1671,941)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		study = load('res://scenes/volume_patch_study.tscn').instantiate()
		viewport.add_child(study)
		study.body.hide()
		study.water.hide()
		study.cursor.hide()
		study.hud.hide()
		study.set_process(false)
	var order := 0
	for id: String in SOURCES:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(SOURCES[id],state)!=OK: quit(1); return
		var source := document.generate_scene(state)
		var wrapper := Node3D.new()
		(root if headless else viewport).add_child(wrapper)
		wrapper.add_child(source)
		var parts: Array[MeshInstance3D] = []
		collect(source,parts)
		var points := PackedVector3Array()
		for part: MeshInstance3D in parts:
			for p: Vector3 in part.mesh.get_faces(): points.append(part.global_transform*p)
		if points.is_empty(): quit(1); return
		var bounds := AABB(points[0],Vector3.ZERO)
		for p: Vector3 in points: bounds = bounds.expand(p)
		var binary := FileAccess.open(WORK+id+'.bin',FileAccess.WRITE)
		binary.store_buffer(points.to_byte_array())
		binary.close()
		report.sources.append({'id':id,'path':SOURCES[id],'file_sha256':FileAccess.get_sha256(SOURCES[id]),
			'triangles':points.size()/3,'bounds_low':[bounds.position.x,bounds.position.y,bounds.position.z],
			'bounds_high':[bounds.end.x,bounds.end.y,bounds.end.z],
			'triangles_sha256':FileAccess.get_sha256(WORK+id+'.bin')})
		if not headless:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(.48,.48,.48)
			material.roughness = 1.
			for part: MeshInstance3D in parts: part.material_override = material
			var factor := 2.8/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
			wrapper.scale = Vector3.ONE*factor
			wrapper.position = Vector3((order-1)*3.3,0,0)-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
		order += 1
	FileAccess.open(WORK+'sources.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t',true,true))
	if not headless:
		for back: bool in [false,true]:
			study.camera.position = Vector3(7,6,16) if not back else Vector3(-7,6,-16)
			study.camera.look_at(Vector3(0,1.,0))
			study.camera.size = 6.4
			for i: int in 10:
				RenderingServer.force_draw(false)
				await process_frame
			RenderingServer.force_draw(false)
			var error := viewport.get_texture().get_image().save_png(OUT+('catalog_back' if back else 'catalog_front')+'.png')
			if error!=OK: quit(1); return
	print('EXISTING ROCK MODULE INSPECTION: ',report.sources)
	quit()
