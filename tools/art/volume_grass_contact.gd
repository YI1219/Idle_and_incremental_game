extends RefCounted
## Derived cosmetic blades only: no new ground, rock/tree props or placement tool.
const Surface := preload('res://scripts/terrain_editor/chunk_geometry.gd').Surface
const Models := preload('res://scripts/terrain_editor/terrain_models.gd')
const PatchSurface := preload('res://scripts/terrain_volume/patch_surface.gd')
const STEP := .25
static var _blades := PackedVector3Array()
static var _bounds := AABB()
static var _short_components := 0
static func _hash(p: Vector2) -> float:
	return fposmod(sin(p.dot(Vector2(127.1,311.7)))*43758.5453,1.)
static func _source() -> void:
	if not _blades.is_empty(): return
	var models := Models.new()
	for part: Dictionary in models._grass_models():
		var arrays: Array = part.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var graph: Dictionary = {}
		for i: int in range(0,indices.size(),3):
			for j: int in 3:
				var a: int = indices[i+j]
				var b: int = indices[i+(j+1)%3]
				if not graph.has(a): graph[a] = []
				if not graph.has(b): graph[b] = []
				graph[a].append(b)
				graph[b].append(a)
		var todo := graph.duplicate()
		while not todo.is_empty():
			var stack: Array = [todo.keys()[0]]
			var group: Dictionary = {}
			var low := INF
			var high := -INF
			while not stack.is_empty():
				var index: int = stack.pop_back()
				if not todo.has(index): continue
				todo.erase(index)
				group[index] = true
				stack.append_array(graph[index])
				var p: Vector3 = part.pose*vertices[index]
				low = minf(low,p.y)
				high = maxf(high,p.y)
			# This preserved source has three short9vertex leaves and six tall
			#21vertex wisps. Reuse the broad short leaves, not the entire tuft.
			if group.size()!=9 or high-low>.7: continue
			_short_components += 1
			for i: int in range(0,indices.size(),3):
				if not group.has(indices[i]): continue
				for j: int in 3:
					var p: Vector3 = part.pose*vertices[indices[i+j]]
					p.y -= low
					_blades.append(p)
	assert(_short_components==3,'The inspected grass-source component contract changed')
	_bounds = AABB(_blades[0],Vector3.ZERO)
	for p: Vector3 in _blades: _bounds = _bounds.expand(p)
static func _triangle(surface: RefCounted, a: Vector3, b: Vector3, c: Vector3) -> void:
	# The terrain Surface helper drops cross²<1e-8, too large for small grass
	# roots. Retain tiny *nondegenerate* source leaves rather than floating tips.
	var cross := -(b-a).cross(c-a)
	if cross.length_squared()<1e-14: return
	for p: Vector3 in [a,b,c]:
		surface.vertices.append(p)
		surface.normals.append(cross.normalized())
		surface.colors.append(Color.WHITE)
		surface.uv.append(Vector2.ZERO)
static func build(doc: RefCounted) -> Dictionary:
	var started := Time.get_ticks_usec()
	_source()
	var result := Surface.new()
	var top := PatchSurface._top_grid(doc.field)
	var anchors: Array[Vector3] = []
	var supported_roots := PackedVector3Array()
	var root_checks := 0
	var rejected := 0
	var foot := Vector3(_bounds.get_center().x,_bounds.position.y,_bounds.get_center().z)
	var keys := top.keys()
	keys.sort()
	for key: Vector2i in keys:
		var at := Vector2(key)*STEP
		var h: float = top[key]
		if h<2.95 or not doc.field.base.cover_columns.has(key): continue
		if doc.lake.enabled and h<float(doc.lake.level)+.12: continue
		var choice := _hash(at+Vector2(17,31))
		if choice<.42 or _hash((at*.75).floor()+Vector2(6,13))<.38: continue
		var outward := Vector2.ZERO
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var other := key+offset
			if not top.has(other) or float(top[other])<h-.3 or not doc.field.base.cover_columns.has(other):
				outward += Vector2(offset)
		if outward.length_squared()<.1: continue
		outward = outward.normalized()
		var tangent := Vector2(-outward.y,outward.x)
		for fan: int in 2:
			var center := at-outward*(.07+.045*fan)+tangent*(fan-.5)*.08
			var height: float = doc.field.height_at(center)
			if not is_finite(height) or absf(height-h)>.12: continue
			var scale_value: float = ([.21,.14][fan]+.025*choice)/maxf(_bounds.size.y,.001)
			var basis := Basis(Vector3(-outward.y,0,outward.x),-.38-.28*fan)*Basis(Vector3.UP,choice*TAU+fan*1.8)
			basis = basis.scaled(Vector3.ONE*scale_value)
			var pose := Transform3D(basis,Vector3(center.x,height-.009,center.y)-basis*foot)
			var roots: Dictionary = {}
			var projected: Dictionary = {}
			var supported := true
			for p: Vector3 in _blades:
				if p.y-_bounds.position.y>_bounds.size.y*.10: continue
				var root: Vector3 = pose*p
				if projected.has(root): continue
				var floor_y: float = doc.field.height_at(Vector2(root.x,root.z))
				var gradient: Vector3 = doc.field.gradient(Vector3i((root/STEP).round()))
				if not is_finite(floor_y) or absf(floor_y-height)>.08 or gradient.y<.65:
					supported = false; break
				# Conform to local slope without collapsing the lower stem onto
				# one plane. Only literal source-base points are buried roots.
				root.y += floor_y-height
				var is_root: bool = p.y-_bounds.position.y<.00001
				if is_root: root.y = floor_y-.009
				if is_root and doc.field.value_at(root)>.0001:
					supported = false; break
				projected[pose*p] = root
				if is_root: roots[pose*p] = root
			if not supported:
				rejected += 1
				continue
			for i: int in range(0,_blades.size(),3):
				var triangle: Array[Vector3] = []
				for j: int in 3:
					var p: Vector3 = pose*_blades[i+j]
					triangle.append(projected.get(p,p))
				_triangle(result,triangle[0],triangle[1],triangle[2])
			root_checks += roots.size()
			for p: Vector3 in roots.values(): supported_roots.append(p)
			anchors.append(Vector3(center.x,height,center.y))
	return {'mesh':result.mesh(),'anchors':anchors,'roots':supported_roots,'root_checks':root_checks,'unsupported_roots':0,
		'rejected_fans':rejected,'triangles':result.vertices.size()/3,'build_ms':(Time.get_ticks_usec()-started)/1000.,
		'source':'res://assets/nature/quaternius/Grass_Common_Short.gltf',
		'short_source_components':_short_components,
		'scope':'Three existing short leaf components only. Bottom10% follows the edited slope; literal base points are checked buried roots. Unsupported fans rejected. No new turf/ground, every-leaf support, prop placement or performance acceptance.'}
