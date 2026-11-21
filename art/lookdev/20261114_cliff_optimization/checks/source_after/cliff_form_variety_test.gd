extends SceneTree
## Closed solid forms and multiple relief breaks; visual acceptance needs native captures.
const Shard = preload("res://scripts/terrain_editor/procedural_shard.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func front_at(faces: PackedVector3Array, y: float) -> float:
	var front: float = -INF
	for i: int in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(0,y,2), Vector3(0,y,-2), faces[i], faces[i+1], faces[i+2])
		if hit != null: front = maxf(front, hit.z)
	return front
func _initialize() -> void:
	var distinct_profiles: Dictionary = {}
	for arch: int in 8:
		var built: Dictionary = Shard.build(16+arch*9)
		var mesh: ArrayMesh = built.mesh
		var faces: PackedVector3Array = mesh.get_faces()
		check(faces == Shard.build(16+arch*9).mesh.get_faces(), "form %d deterministic" % arch)
		var edges: Dictionary = {}
		var crown: Dictionary = {}
		var directions: Dictionary = {}
		var collar_clear: bool = true
		var safe: bool = true
		for i: int in range(0, faces.size(), 3):
			for j: int in 3:
				var a: Vector3 = faces[i+j]
				var b: Vector3 = faces[i+(j+1)%3]
				safe = safe and a.is_finite() and a.y <= .00001 and absf(a.x) <= .59
				if absf(a.y) < .00001: crown[a] = true
				if a.y > -.04201 and absf(a.y) > .00001 and absf(a.y+.042) > .00001: collar_clear = false
				var ka := Vector3i((a*100000).round())
				var kb := Vector3i((b*100000).round())
				var key: Array = [ka,kb] if str(ka)<str(kb) else [kb,ka]
				edges[key] = edges.get(key,0)+1
				directions[key] = directions.get(key,0)+(1 if str(ka)<str(kb) else -1)
		var closed: bool = true
		for count: int in edges.values(): closed = closed and count == 2
		check(closed, "form %d closed two-face edges" % arch)
		var oriented: bool = true
		for direction: int in directions.values(): oriented = oriented and direction == 0
		check(oriented and collar_clear, "form %d collar remains above body and shared edge winding agrees" % arch)
		check(safe, "form %d finite and stays within placement guard" % arch)
		check(crown.size() == 10 and crown.has(Vector3(0,0,.02)), "form %d canonical crown" % arch)
		var planar: bool = true
		var first_body: int = 81
		var end_body: int = faces.size()-27
		# Skip only the crown-to-shoulder transition; broad body quads
		# remain planar through the pitched shelves and inward bevels.
		for offset: int in range(first_body+54,end_body,6):
			var n0 := (faces[offset+1]-faces[offset]).cross(faces[offset+2]-faces[offset]).normalized()
			var n1 := (faces[offset+4]-faces[offset+3]).cross(faces[offset+5]-faces[offset+3]).normalized()
			planar = planar and n0.dot(n1) > cos(deg_to_rad(1))
		check(planar, "form %d broad cleavage quads stay planar" % arch)
		var prev: float = front_at(faces,-.18)
		var had_inward: bool = false
		var zig_zag: bool = false
		var sig_parts: PackedInt32Array = PackedInt32Array()
		for k: int in range(1,75):
			var z: float = front_at(faces, -.18-float(k)*.01)
			var slope: float = z-prev
			if slope < -.0015:
				had_inward = true
			elif had_inward and slope > .0015:
				zig_zag = true
			if k in [20, 42, 64]:
				sig_parts.append(roundi(z * 200.0))
			prev = z
		check(not zig_zag, "form %d tapers monotonically without wasp-waist zig-zag reversals" % arch)
		distinct_profiles[str(sig_parts)] = true
	check(distinct_profiles.size() >= 4, "forms retain >= 4 distinct hard bevel profiles (got %d)" % distinct_profiles.size())
	print("CLIFF FORM VARIETY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
