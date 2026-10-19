extends RefCounted
## Derived display only: all solids and water clipping read the same field.
const Mesher := preload('res://scripts/terrain_editor/rock_sculpt_mesh.gd')
const Surface := preload('res://scripts/terrain_editor/chunk_geometry.gd').Surface
const Normals := preload('res://scripts/terrain_editor/stone_normals.gd')
const STEP := .25
static func build(doc: RefCounted) -> Dictionary:
	var start := Time.get_ticks_usec()
	var solid = Mesher.build(doc.field)
	var mesh_us := Time.get_ticks_usec() - start
	if solid.vertices.is_empty():
		var empty_status: Dictionary = doc.lake_status()
		return {'terrain': ArrayMesh.new(), 'water': ArrayMesh.new(), 'lake': empty_status, 'top': {},
			'contact': {},
			'mesh_ms': mesh_us/1000., 'build_ms': (Time.get_ticks_usec()-start)/1000.,
			'triangles': 0, 'water_triangles': 0}
	# Recover face normals before applying a deliberate, tighter crease rule.
	for i: int in range(0, solid.vertices.size(), 3):
		var n: Vector3 = -(solid.vertices[i+1]-solid.vertices[i]).cross(solid.vertices[i+2]-solid.vertices[i]).normalized()
		for j: int in 3: solid.normals[i+j] = n
	var mesh: ArrayMesh = Normals.soften(solid.mesh(), 42., 1.)
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var top := _top_grid(doc.field)
	var status: Dictionary = doc.lake_status()
	var contact := contact_field(doc,top,status)
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	for i: int in solid.vertices.size():
		var p: Vector3 = solid.vertices[i]
		var h := top_height(top, Vector2(p.x, p.z))
		var depth := h - p.y
		var cover := (1. - smoothstep(.06, .28, absf(depth))) * smoothstep(.35, .82, normals[i].y)
		var soil := (1. - smoothstep(.12, .48, absf(depth))) * smoothstep(-.5, .2, normals[i].y)
		var source_depth := top_height(doc.field.base.surface_heights,Vector2(p.x,p.z))-p.y
		cover *= 1.-smoothstep(.12,.35,source_depth)
		soil *= 1.-smoothstep(.22,.65,source_depth)
		var covered: bool = doc.field.base.cover_columns.has(Vector2i(roundi(p.x/STEP), roundi(p.z/STEP)))
		if not covered:
			cover = 0.
			soil = 0.
		var wet := 0.
		if status.valid and p.y < float(doc.lake.level) + .12:
			wet = wet_at(contact,Vector2(p.x,p.z))*(1.-smoothstep(.12,.32,depth))*smoothstep(-.1,.35,normals[i].y)
			wet *= 1.-smoothstep(float(doc.lake.level)+.04,float(doc.lake.level)+.12,p.y)
			cover *= 1. - wet
		colors.append(Color(cover, soil, wet, 1.))
		uv.append(Vector2(h, float(doc.lake.level)))
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var water := _water(doc, status)
	return {'terrain': mesh, 'water': water, 'lake': status, 'top': top,
		'contact': contact,
		'mesh_ms': mesh_us / 1000., 'build_ms': (Time.get_ticks_usec()-start)/1000.,
		'triangles': solid.vertices.size()/3, 'water_triangles': water.get_faces().size()/3}
static func contact_field(doc: RefCounted, top: Dictionary, status: Dictionary = {}) -> Dictionary:
	if status.is_empty(): status = doc.lake_status()
	var wet: Dictionary = {}
	for key: Vector3i in status.surface: wet[Vector2i(key.x,key.z)] = true
	var low: Vector3i = doc.field.base.low
	var size: Vector3i = doc.field.base.size
	var image := Image.create(size.x,size.z,false,Image.FORMAT_RGBAF)
	for z: int in size.z:
		for x: int in size.x:
			var key := Vector2i(low.x+x,low.z+z)
			var height: float = top.get(key,-100.)
			var original: float = doc.field.base.surface_heights.get(key,-100.)
			var planted := 1. if top.has(key) and doc.field.base.cover_columns.has(key) else 0.
			# Height padding avoids interpolation against the missing-column
			# sentinel; coverage remains zero outside the actual edited top.
			if height < -90.:
				var nearest := INF
				for dz: int in range(-2,3):
					for dx: int in range(-2,3):
						var neighbor := key+Vector2i(dx,dz)
						var distance := float(dx*dx+dz*dz)
						if top.has(neighbor) and distance < nearest:
							height = top[neighbor]
							nearest = distance
			# Source-height padding is independent: a fresh cut must never
			# lower its original soil level. Unplanted outside columns stay dry.
			if original < -90.:
				var nearest := INF
				for dz: int in range(-2,3):
					for dx: int in range(-2,3):
						var neighbor := key+Vector2i(dx,dz)
						var distance := float(dx*dx+dz*dz)
						if doc.field.base.surface_heights.has(neighbor) and distance<nearest:
							original = doc.field.base.surface_heights[neighbor]
							nearest = distance
			image.set_pixel(x,z,Color(height,planted,original,1. if wet.has(key) else 0.))
	return {'map': image,'origin': (Vector2(low.x,low.z)-Vector2.ONE*.5)*STEP,
		'extent': Vector2(size.x,size.z)*STEP}
static func wet_at(contact: Dictionary, p: Vector2) -> float:
	var image: Image = contact.map
	var q: Vector2 = (p-contact.origin)/contact.extent*Vector2(image.get_size())-Vector2.ONE*.5
	var low := Vector2i(q.floor())
	var f: Vector2 = q-Vector2(low)
	var value := 0.
	for dz: int in 2:
		for dx: int in 2:
			var key := low+Vector2i(dx,dz)
			if key.x<0 or key.y<0 or key.x>=image.get_width() or key.y>=image.get_height(): continue
			value += image.get_pixelv(key).a*(f.x if dx else 1.-f.x)*(f.y if dz else 1.-f.y)
	return value
static func _top_grid(field: RefCounted) -> Dictionary:
	var low: Vector3i = field.base.low
	var high: Vector3i = low + field.base.size - Vector3i.ONE
	for key: Vector3i in field.samples:
		low = low.min(key - Vector3i.ONE)
		high = high.max(key + Vector3i.ONE)
	var result: Dictionary = {}
	for z: int in range(low.z, high.z + 1):
		for x: int in range(low.x, high.x + 1):
			var above := .5
			for y: int in range(high.y, low.y - 1, -1):
				var below: float = field.node_value(Vector3i(x, y, z))
				if above >= 0 and below < 0:
					result[Vector2i(x, z)] = (y + 1. - above/(above-below)) * STEP
					break
				above = below
	return result
static func top_height(top: Dictionary, p: Vector2) -> float:
	var q := p/STEP
	var low := Vector2i(q.floor())
	var fraction := q - Vector2(low)
	var total := 0.
	var weight := 0.
	for dz: int in 2:
		for dx: int in 2:
			var key := low + Vector2i(dx, dz)
			if not top.has(key): continue
			var w := (fraction.x if dx else 1.-fraction.x) * (fraction.y if dz else 1.-fraction.y)
			total += float(top[key])*w
			weight += w
	return total/weight if weight > .0001 else -100.
static func _water(doc: RefCounted, status: Dictionary) -> ArrayMesh:
	var surface := Surface.new()
	if not status.valid: return surface.mesh()
	var cells: Dictionary = {}
	for key: Vector3i in status.surface:
		for dz: int in [-1, 0]:
			for dx: int in [-1, 0]: cells[Vector2i(key.x+dx, key.z+dz)] = true
	for cell: Vector2i in cells:
		var corners: Array[Vector3] = []
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
			corners.append(Vector3((cell.x+offset.x)*STEP, doc.lake.level, (cell.y+offset.y)*STEP))
		for indices: Array in [[0,1,2],[0,2,3]]:
			var polygon: Array[Vector3] = []
			for i: int in 3:
				var a := corners[indices[i]]
				var b := corners[indices[(i+1)%3]]
				var va: float = doc.field.value_at(a)
				var vb: float = doc.field.value_at(b)
				if va > 0: polygon.append(a)
				if (va > 0) != (vb > 0): polygon.append(a.lerp(b, va/(va-vb)))
			for i: int in range(1, polygon.size()-1):
				surface.triangle(polygon[0], polygon[i], polygon[i+1], Color.WHITE, true)
	return surface.mesh()
