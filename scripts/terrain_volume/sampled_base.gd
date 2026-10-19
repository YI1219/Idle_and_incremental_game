extends RefCounted
## An immutable sampled source. Sculpt overrides belong to PatchDocument.
const STEP := .25
const AIR := .5
var low := Vector3i.ZERO
var size := Vector3i.ZERO
var values := PackedFloat32Array()
var surface_cells: Array[Vector3i] = []
var source_sha256 := ''
var cover_columns: Dictionary = {}
func configure(preset: Resource) -> bool:
	if preset == null or preset.get_meta('step', 0.) != STEP:
		return false
	low = preset.get_meta('low', Vector3i.ZERO)
	size = preset.get_meta('size', Vector3i.ZERO)
	values = preset.get_meta('density', PackedFloat32Array())
	if size.x < 2 or size.y < 2 or size.z < 2 or size.x * size.y * size.z != values.size():
		return false
	for value: float in values:
		if not is_finite(value) or value < -AIR or value > AIR:
			return false
	source_sha256 = preset.get_meta('source_sha256', '')
	# This source's authored planting surface is its broad upper cap. Small
	# upward rock ledges around the lower wall are not additional grassland.
	for z: int in size.z:
		for x: int in size.x:
			for y: int in range(size.y - 1, -1, -1):
				if node_value(low + Vector3i(x,y,z)) < 0:
					if (low.y+y)*STEP >= 2.85:
						cover_columns[Vector2i(low.x+x, low.z+z)] = true
					break
	for z: int in range(size.z - 1):
		for y: int in range(size.y - 1):
			for x: int in range(size.x - 1):
				var minimum := AIR
				var maximum := -AIR
				var p := low + Vector3i(x, y, z)
				for corner: Vector3i in [Vector3i.ZERO, Vector3i(1,0,0), Vector3i(0,1,0), Vector3i(0,0,1), Vector3i(1,1,0), Vector3i(1,0,1), Vector3i(0,1,1), Vector3i.ONE]:
					var value := node_value(p + corner)
					minimum = minf(minimum, value)
					maximum = maxf(maximum, value)
				if minimum < 0 and maximum >= 0:
					surface_cells.append(p)
	return not source_sha256.is_empty() and not surface_cells.is_empty()
func node_value(key: Vector3i) -> float:
	var p := key - low
	if p.x < 0 or p.y < 0 or p.z < 0 or p.x >= size.x or p.y >= size.y or p.z >= size.z:
		return AIR
	return values[(p.z * size.y + p.y) * size.x + p.x]
func tag(_p: Vector3, _normal: Vector3) -> Dictionary:
	# Cover is classified from the edited top after meshing, never an old cap height.
	return {'color': Color(0, 0, 0, 1), 'uv': Vector2.ZERO}
