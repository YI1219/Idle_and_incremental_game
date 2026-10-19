extends RefCounted
## One local authored lake profile on the preserved source; no live-save input.
const Document := preload('res://scripts/terrain_volume/patch_document.gd')
const STEP := .25
static func make() -> RefCounted:
	var doc := Document.new()
	if not doc.load_preset(): return null
	apply_to(doc)
	return doc
static func apply_to(doc: RefCounted) -> void:
	# This is a fresh comparison document. Retire only its default sphere cut.
	doc.field.samples.clear()
	doc.lake = {'center':[-.8,0.], 'level':3., 'enabled':true}
	var center := Vector2(-.8,0.)
	var radii := Vector2(1.35,.88)
	for z: int in range(-6,7):
		for x: int in range(-10,4):
			var at := Vector2(x,z)*STEP
			var radius := ((at-center)/radii).length()
			if radius>1.: continue
			# Shallow water sits inside a broad, continuous dry-to-wet bank.
			# The source cap remains authoritative where it is already lower.
			var bed := lerpf(2.55,3.25,smoothstep(0.,1.,radius))
			for y: int in range(8,16):
				var key := Vector3i(x,y,z)
				var old: float = doc.field.base.node_value(key)
				var cut := minf(y*STEP-bed,(1.-radius)*radii.y)
				var value := roundf(clampf(maxf(old,cut),-.5,.5)*100000.)/100000.
				if absf(value)<.00001: value=.00002
				if value != old: doc.field.samples[key] = value
	doc.field._height_bounds_dirty = true
