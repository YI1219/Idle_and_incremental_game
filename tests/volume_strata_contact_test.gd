extends SceneTree
const Doc := preload('res://tools/art/volume_module_document.gd')
const Surface := preload('res://scripts/terrain_volume/patch_surface.gd')
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func pixel(contact: Dictionary, key: Vector2i) -> Color:
	var uv: Vector2 = (Vector2(key)*.25-contact.origin)/contact.extent
	var image: Image = contact.map
	return image.get_pixel(roundi(uv.x*image.get_width()-.5),roundi(uv.y*image.get_height()-.5))
func _initialize() -> void:
	create_timer(30.).timeout.connect(func() -> void: push_error('Strata contact timed out'); quit(1))
	call_deferred('run')
func run() -> void:
	var doc := Doc.new()
	check(doc.load_preset(),'Module fixture loads')
	var saved: Dictionary = doc.serialize()
	var initial := Surface.build(doc)
	var dry_key := Vector2i(8,4)
	var source := Doc.new()
	source.load_preset()
	source.field.samples.clear()
	var source_top := Surface._top_grid(source.field)
	var source_h: float = source_top[dry_key]
	check(absf(pixel(initial.contact,dry_key).b-source_h)<.0001,'Contact stores the actual immutable source height rather than a constant channel')
	var water: Dictionary = {}
	for p: Vector3i in initial.lake.surface: water[Vector2i(p.x,p.z)] = true
	var masks_match := true
	var wet_count := 0
	var dry_count := 0
	var low: Vector3i = doc.field.base.low
	var size: Vector3i = doc.field.base.size
	for z: int in size.z:
		for x: int in size.x:
			var key := Vector2i(low.x+x,low.z+z)
			var wet: bool = water.has(key)
			var value: float = pixel(initial.contact,key).a
			masks_match = masks_match and absf(value-(1. if wet else 0.))<.0001
			if wet: wet_count += 1
			else: dry_count += 1
	check(masks_match and wet_count>5 and dry_count>50,'Wet channel follows actual basin columns, including dry columns inside the old radial extent')
	check(doc.serialize()==saved,'Building material data never changes terrain or lake data')
	doc.begin_stroke()
	doc.apply_brush(Vector3(2,2.6,1),1.3,'rock_plane',Vector3.UP)
	doc.end_stroke()
	var cut := Surface.build(doc)
	check(pixel(cut.contact,dry_key).r<source_h-.4 and absf(pixel(cut.contact,dry_key).b-source_h)<.0001,'Cut height changes independently of the preserved source soil level')
	var arrays: Array = cut.terrain.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var count := 0
	var grass := 0
	for i: int in vertices.size():
		var p := vertices[i]
		if Vector2(p.x-2,p.z-1).length()<.5 and p.y<source_h-.4 and normals[i].y>.8:
			count += 1
			if colors[i].r>.05: grass += 1
	check(count>10 and grass==0,'A deep upward-facing cut exposes rock rather than transferring the original turf')
	doc.undo()
	var restored := Surface.build(doc)
	check(doc.serialize()==saved and restored.contact.map.get_data()==initial.contact.map.get_data(),'Undo restores the full derived contact map exactly')
	doc.lake.enabled = false
	var drained := Surface.build(doc)
	var drained_mask := true
	for z: int in size.z:
		for x: int in size.x:
			if drained.contact.map.get_pixel(x,z).a!=0.: drained_mask = false
	check(drained_mask,'Draining clears every wet column')
	print('VOLUME STRATA CONTACT: ',checks-failures,'/',checks)
	quit(0 if failures==0 else 1)
