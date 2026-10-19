extends SceneTree
## The first art gate must exercise the real volume, not decorative hole props.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred('run')
func run() -> void:
	var path := 'res://scripts/terrain_volume/patch_document.gd'
	if not ResourceLoader.exists(path):
		check(false, 'Authored-source volume document is not implemented')
		quit(1)
		return
	var doc = load(path).new()
	check(doc.load_preset(), 'Existing rock source loads as the actual editable solid')
	if doc.field.base == null:
		quit(1)
		return
	var initial: Dictionary = doc.serialize()
	check(doc.lake_status().valid, 'Initial carved lake has a closed basin')
	check(doc.field.value_at(Vector3(0, 0, 0)) < 0, 'Source interior is solid')
	var through := Vector3(.8, .2, 0)
	doc.begin_stroke()
	for z: float in [-4., -3., -2., -1., 0., 1., 2., 3., 4.]:
		doc.apply_brush(Vector3(.8, .2, z), .85, 'rock_cut')
	doc.end_stroke()
	check(doc.field.value_at(through) > 0, 'Tunnel removes actual rock through the body')
	check(doc.field.value_at(Vector3(.8, 1.5, 0)) < 0, 'Tunnel keeps a solid overhanging roof')
	check(doc.undo() and doc.serialize() == initial, 'One tunnel stroke undoes exactly')
	check(doc.redo() and doc.field.value_at(through) > 0, 'Tunnel redo restores the cut')
	var saved: Dictionary = doc.serialize()
	var copy = load(path).new()
	check(copy.deserialize(JSON.parse_string(JSON.stringify(saved, '', true, true))), 'Versioned volume save reloads')
	check(copy.serialize() == saved, 'Source identity, lake and sculpt overrides survive roundtrip')
	var bad := saved.duplicate(true)
	bad.source_sha256 = 'different source'
	check(not copy.deserialize(bad) and copy.serialize() == saved, 'Wrong-source save is rejected atomically')
	bad = saved.duplicate(true)
	bad.rocks.append({'x':4000,'y':0,'z':0,'density':-.5})
	check(not copy.deserialize(bad) and copy.serialize() == saved, 'Local study rejects distant samples without changing the scene')
	doc.undo()
	doc.begin_stroke()
	for z: float in [-.3, .5, 1.3, 2.1, 2.9, 3.7, 4.5]:
		doc.apply_brush(Vector3(-.8, 2.25, z), .75, 'rock_cut')
	doc.end_stroke()
	check(not doc.lake_status().valid, 'Lake breach is detected from three-dimensional connectivity')
	check(doc.undo() and doc.lake_status().valid, 'Undo repairs basin and water validity')
	check(doc.serialize() == initial, 'Lake validation does not mutate authored data')
	var surface_path := 'res://scripts/terrain_volume/patch_surface.gd'
	if not ResourceLoader.exists(surface_path):
		check(false, 'Edited surface and lake renderer is not implemented')
	else:
		var built: Dictionary = load(surface_path).build(doc)
		check(built.terrain.get_surface_count() > 0 and built.water.get_surface_count() > 0, 'Solid and clipped water have real geometry')
		var arrays: Array = built.terrain.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var grass := 0
		var lower_grass := 0
		for i: int in vertices.size():
			if colors[i].r > .5:
				grass += 1
				if vertices[i].y < 2.: lower_grass += 1
		check(grass > 50 and lower_grass == 0, 'Cover stays on upper land, not the bottom')
	# Actual tetrahedra connect same-sign face/body diagonals as well as axes.
	var diagonal = load(path).new()
	diagonal.load_preset()
	diagonal.field.samples.clear()
	var water_y := roundi(diagonal.lake.level/.25)
	var channel_start := Vector3i(-3, water_y, 0)
	for x: int in range(-16,18):
		for y: int in range(0,water_y+1):
			for z: int in range(-8,9): diagonal.field.samples[Vector3i(x,y,z)] = -.5
	for i: int in range(11):
		diagonal.field.samples[channel_start+Vector3i(i,0,i)] = .5
	check(not diagonal.lake_status().valid, 'A diagonal-only tetrahedral leak is not mistaken for a sealed basin')
	var pillar = load(path).new()
	pillar.load_preset()
	pillar.begin_stroke()
	pillar.apply_brush(Vector3(-.8,2.5,0), .35, 'rock_add')
	pillar.end_stroke()
	check(pillar.lake_status().valid, 'Adding an island at the lake center preserves the surrounding water')
	var erased = load(path).new()
	erased.load_preset()
	erased.begin_stroke()
	for x: float in [-3.,0.,3.]:
		for y: float in [0.,2.]:
			for z: float in [-1.,1.]: erased.apply_brush(Vector3(x,y,z),2.5,'rock_cut')
	erased.end_stroke()
	var empty_build: Dictionary = load(surface_path).build(erased)
	check(empty_build.has('terrain') and empty_build.terrain.get_surface_count() == 0, 'Completely erased terrain publishes a valid empty mesh')
	print('VOLUME PATCH: ', checks - failures, '/', checks)
	quit(0 if failures == 0 else 1)
