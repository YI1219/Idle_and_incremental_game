extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	create_timer(30.).timeout.connect(func() -> void: push_error('Grass contact test timed out'); quit(1))
	call_deferred('run')
func run() -> void:
	var path := 'res://tools/art/volume_grass_contact.gd'
	if not ResourceLoader.exists(path):
		check(false,'Existing grass contact study is not implemented'); quit(1); return
	var modules := OS.get_cmdline_user_args().has('--modules')
	var doc = load('res://tools/art/volume_module_document.gd' if modules else 'res://tools/art/volume_refined_document.gd').new()
	doc.load_preset()
	var saved: Dictionary = doc.serialize()
	var grass: Dictionary = load(path).build(doc)
	check(grass.mesh.get_faces().size()>0 and grass.anchors.size()>5,'Real existing grass triangles are published with supported anchors')
	check(grass.unsupported_roots==0 and grass.root_checks>100,'Every emitted root vertex passes actual-volume support checks')
	var valid_roots := true
	var max_root_distance := 0.
	var max_root_density := -INF
	var faces: PackedVector3Array = grass.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for p: Vector3 in grass.roots:
		# Inspect the direct display buffer; Mesh.get_faces() instead snaps
		# its helper TriangleMesh to0.1mm. A1.5cm floating gap must still fail.
		var nearest := Vector3(INF,INF,INF)
		var distance := INF
		for q: Vector3 in faces:
			var current := p.distance_squared_to(q)
			if current<distance:
				distance = current
				nearest = q
		valid_roots = valid_roots and distance<.0002*.0002 and is_finite(nearest.y) and doc.field.value_at(nearest)<=.0001
		max_root_distance = maxf(max_root_distance,sqrt(distance))
		max_root_density = maxf(max_root_density,doc.field.value_at(nearest))
	check(valid_roots,'Independent inspection finds actual emitted root positions inside the edited solid')
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(faces.to_byte_array())
	print('VOLUME GRASS ROOT EVIDENCE: ',JSON.stringify({'roots':grass.roots.size(),'maximum_position_drift_m':max_root_distance,'maximum_actual_density':max_root_density,'mesh_sha256':hash.finish().hex_encode()}))
	check(doc.serialize()==saved,'Decorative contact never changes the authoritative terrain')
	if modules:
		var dry_low_anchor := false
		for p: Vector3 in grass.anchors:
			if p.y<float(doc.lake.level)-.1: dry_low_anchor = true
		check(dry_low_anchor,'Dry lower land outside the isolated pond can carry grass below its water level')
	var first: Vector3 = grass.anchors[0]
	doc.begin_stroke()
	doc.apply_brush(first,.55,'rock_cut')
	doc.end_stroke()
	var cut: Dictionary = load(path).build(doc)
	check(not cut.anchors.has(first),'A real local cut removes the old grass anchor')
	check(doc.undo() and doc.serialize()==saved,'Local contact edit remains ordinary undoable sculpt data')
	doc.begin_stroke()
	for x: float in [-3.,0.,3.]:
		for y: float in [0.,2.]:
			for z: float in [-1.,1.]: doc.apply_brush(Vector3(x,y,z),2.5,'rock_cut')
	doc.end_stroke()
	var erased: Dictionary = load(path).build(doc)
	check(erased.mesh.get_surface_count()==0 and erased.anchors.is_empty(),'Erasing the solid removes derived grass rather than leaving decorative ground')
	doc.undo()
	var restored: Dictionary = load(path).build(doc)
	check(restored.mesh.get_faces()==grass.mesh.get_faces() and doc.serialize()==saved,'Undo deterministically restores terrain and grass together')
	print('VOLUME MODULE GRASS CONTACT: ' if modules else 'VOLUME GRASS CONTACT: ',checks-failures,'/',checks)
	quit(0 if failures==0 else 1)
