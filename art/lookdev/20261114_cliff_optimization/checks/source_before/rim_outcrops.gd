extends RefCounted
## Rim-Breaking Headland Crag Boulders (3B: 岛角岬头局部破圈裸岩簇, aligned with Cliff Refs 01 & 04).
## Straddles exterior cliff corners & promontory headlands so select heavy chiseled boulders
## emerge cleanly above/beyond the grass rim while plunging down into the multi-tier cliff stack below.
const Paths = preload("res://scripts/terrain_editor/terrain_paths.gd")
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")
const TREES = [Vector2(-15.6, -3.2), Vector2(-3.8, -7.8), Vector2(5.5, -2.2), Vector2(15.4, 1.8)]
const BLUFF_CENTER := Vector2(-5.65, 7.20)

static func clear(p: Vector2, field = null) -> bool:
	if p.distance_to(Vector2(-11.0, -7.0)) < 3.1:
		return false
	# Keep generous serene space around the waterside Song stone bench (10.7,-2.0), lantern (12.4,-2.35), Taihu rock & bamboo:
	if p.distance_to(Vector2(11.4, -2.2)) < 4.35 or p.distance_to(Vector2(-9.6, -5.4)) < 2.8 or p.distance_to(Vector2(-7.2, -6.5)) < 2.6:
		return false
	if p.x > -11.0 and p.x < -6.5 and p.y > -6.5 and p.y < -2.4:
		return false
	for tree: Vector2 in TREES:
		if p.distance_to(tree) < 2.15:
			return false
	for i in Paths.POINTS.size() - 1:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, Paths.POINTS[i], Paths.POINTS[i + 1])) < 1.85:
			return false
	if field != null:
		for veil: Dictionary in field.fall_veils:
			var lip: Vector3 = veil.lip
			if p.distance_to(Vector2(lip.x, lip.z)) < float(veil.half_width) + 2.85:
				return false
	return true

static func pose_for(mesh: Mesh, p: Vector2, h: float, size: Vector3, yaw: float, burial: float) -> Transform3D:
	var box := mesh.get_aabb()
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(size / box.size)
	var foot := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	return Transform3D(basis, Vector3(p.x, h - burial, p.y) - basis * foot)

static func dry_surface(field, p: Vector2, h: float) -> bool:
	if not field.contains(field.rim_regions.get(h, []), p):
		return false
	for water: int in field.water_regions:
		if water * 0.5 >= h - 0.001 and field.contains(field.water_regions[water], p):
			return false
	var original: Dictionary = field.surface_at(p)
	return original.is_empty() or (original.water < 0 and original.height <= h + 0.01)

static func _turf_slice_hull(faces: PackedVector3Array, pose: Transform3D, slice_y: float, grow_m: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(0, faces.size(), 3):
		var w0: Vector3 = pose * faces[i]
		var w1: Vector3 = pose * faces[i + 1]
		var w2: Vector3 = pose * faces[i + 2]
		var tri := [w0, w1, w2]
		for k in 3:
			var va: Vector3 = tri[k]
			var vb: Vector3 = tri[(k + 1) % 3]
			if va.y >= slice_y:
				pts.append(Vector2(va.x, va.z))
			if (va.y - slice_y) * (vb.y - slice_y) < 0.0:
				var t := (slice_y - va.y) / (vb.y - va.y)
				var ix := va.lerp(vb, t)
				pts.append(Vector2(ix.x, ix.z))
	if pts.size() < 3:
		return PackedVector2Array()
	var hull := Geometry2D.convex_hull(pts)
	if grow_m > 0.001 and hull.size() >= 3:
		var grown := Geometry2D.offset_polygon(hull, grow_m, Geometry2D.JOIN_MITER)
		if not grown.is_empty():
			return grown[0]
	return hull

static func supported_crag(field, faces: PackedVector3Array, pose: Transform3D, h: float, out: Vector2, max_project: float = 1.18) -> bool:
	# Rim-breaking crags straddle the outer cliff rim: inner portion sits solidly rooted in
	# the dry rim cap (h), while the outer chiseled shoulder juts boldly beyond the grass lip
	# into open exterior cliff air (never overlapping lower terraces or lakes).
	var slice := _turf_slice_hull(faces, pose, h - 0.25, 0.0)
	if slice.size() < 3:
		return false
	var lo := slice[0]
	var hi := slice[0]
	for q: Vector2 in slice:
		lo = lo.min(q)
		hi = hi.max(q)
	var total := 0
	var backed := 0
	for z in range(floori(lo.y / 0.22), ceili(hi.y / 0.22) + 1):
		for x in range(floori(lo.x / 0.22), ceili(hi.x / 0.22) + 1):
			var p := Vector2(x, z) * 0.22
			if not Geometry2D.is_point_in_polygon(p, slice):
				continue
			total += 1
			if dry_surface(field, p, h):
				backed += 1
				continue
			var surface: Dictionary = field.surface_at(p)
			if not surface.is_empty():
				return false
			var distance := INF
			for loop: PackedVector2Array in field.rim_regions.get(h, []):
				for i in loop.size():
					distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, loop[i], loop[(i + 1) % loop.size()])))
			if distance > max_project:
				return false
	if total == 0:
		return false
	var ratio := float(backed) / float(total)
	if ratio < 0.16 or ratio > 0.84:
		return false
	# Ensure solid island interior behind the crag so narrow brushed peninsulas stay clean:
	var center_xz := Vector2(pose.origin.x, pose.origin.z)
	var back_probe: Dictionary = field.surface_at(center_xz - out * 1.35)
	if back_probe.is_empty():
		return false
	return true

static func build(deco, field, seed_value: int) -> Array:
	var result: Array = []
	var anchors: Array[Vector2] = []
	var kind := "rim_outcrop"
	var mesh: Mesh = deco.assets[kind][0].mesh
	var faces: PackedVector3Array = Geometry.faces_of(mesh)

	# Collect candidate exterior cliff columns and score convex corners / promontory headlands:
	var candidates: Array = []
	for col: Dictionary in deco._columns:
		if col.get("is_step", false):
			continue
		var edge: Vector2 = col.edge
		var h: float = col.pose.origin.y
		var out := Vector2(col.outward.x, col.outward.z)
		var tan2 := Vector2(col.tangent.x, col.tangent.z)
		if not field.surface_at(edge + out * 2.0).is_empty():
			continue
		var prof: Dictionary = field._cliff_profile(edge, out)
		if h - float(prof.bottom) < 2.85 or float(prof.inset) < 0.92:
			continue
		if edge.distance_to(BLUFF_CENTER) < 4.6 or not clear(edge - out * 0.15, field) or deco._water_distance(field, edge, h) < 2.10:
			continue
		# Detect convex headland corners: flanking points stepped forward along tangent fall outside land!
		var conv := 0.0
		if field.surface_at(edge + tan2 * 2.35 + out * 0.28).is_empty():
			conv += 0.35
		if field.surface_at(edge - tan2 * 2.35 + out * 0.28).is_empty():
			conv += 0.35
		if field.surface_at(edge + tan2 * 3.10 - out * 0.22).is_empty():
			conv += 0.25
		if field.surface_at(edge - tan2 * 3.10 - out * 0.22).is_empty():
			conv += 0.25
		var cell := Vector2i((edge * 2.0).floor())
		var choice: float = deco.random_at(cell, seed_value, 4200)
		var ang := atan2(edge.y + 1.5, edge.x)
		var head_wave := 0.5 + 0.5 * cos(ang * 3.0 - 0.45 + float(seed_value % 53) * 0.11)
		var score := conv * 0.58 + head_wave * 0.28 + choice * 0.24
		if score < 0.52:
			continue
		candidates.append({"col": col, "score": score, "choice": choice, "cell": cell})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))

	for item: Dictionary in candidates:
		if anchors.size() >= 3:
			break
		var col: Dictionary = item.col
		var edge: Vector2 = col.edge
		var h: float = col.pose.origin.y
		var out := Vector2(col.outward.x, col.outward.z)
		var cell: Vector2i = item.cell
		var choice: float = item.choice

		var spaced := true
		for anchor: Vector2 in anchors:
			if anchor.distance_to(edge) < 14.5:
				spaced = false
				break
		if not spaced:
			continue

		var c2: float = deco.random_at(cell, seed_value, 4211)
		var c3: float = deco.random_at(cell, seed_value, 4212)
		var rise := lerpf(0.38, 0.64, c2)
		var drop := lerpf(0.95, 1.45, c3)
		var size := Vector3(lerpf(1.65, 2.25, choice), drop + rise, lerpf(1.45, 1.95, c2))
		var yaw := atan2(out.x, out.y) + (c3 - 0.5) * 0.55
		var pose: Transform3D
		var fitted := false
		var chosen_p := edge
		for inset: float in [0.42, 0.28, 0.14]:
			var cand := edge + out * inset
			if not clear(cand - out * 0.35, field) or deco._water_distance(field, cand - out * 0.65, h) < 1.95:
				continue
			pose = pose_for(mesh, cand, h, size, yaw, drop)
			if supported_crag(field, faces, pose, h, out, 1.25):
				chosen_p = cand
				fitted = true
				break
		if not fitted:
			continue

		var turf_hull := _turf_slice_hull(faces, pose, h - 0.14, 0.08)
		result.append({"kind": kind, "pose": pose, "height": h, "anchor": chosen_p, "turf_hull": turf_hull})
		anchors.append(chosen_p)
	return result

static func trim_cover(surface, rocks: Array, assets: Dictionary):
	var result = Geometry.Surface.new()
	var footprints: Array = []
	var mesh_faces: Dictionary = {}
	for rock: Dictionary in rocks:
		if rock.kind == "rim_shelf":
			continue
		var poly: PackedVector2Array = rock.get("turf_hull", PackedVector2Array())
		if poly.size() < 3:
			if not mesh_faces.has(rock.kind):
				mesh_faces[rock.kind] = Geometry.faces_of(assets[rock.kind][0].mesh)
			poly = _turf_slice_hull(mesh_faces[rock.kind], rock.pose, float(rock.height) - 0.16, 0.02)
		if poly.size() < 3:
			continue
		var box := Rect2(poly[0], Vector2.ZERO)
		for q: Vector2 in poly:
			box = box.expand(q)
		footprints.append({"poly": poly, "height": rock.height, "box": box.grow(0.001)})
	var hidden: Dictionary = {}
	for i in range(0, surface.vertices.size(), 3):
		var key := Vector2(surface.uv[i].x, surface.colors[i].g)
		if hidden.has(key):
			continue
		var triangle := PackedVector2Array()
		for j in 3:
			var v: Vector3 = surface.vertices[i + j]
			triangle.append(Vector2(v.x, v.z))
		var tri_box := Rect2(triangle[0], Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
		for footprint: Dictionary in footprints:
			if absf(key.x - footprint.height) > 0.01:
				continue
			if not tri_box.intersects(footprint.box, true):
				continue
			var overlaps := false
			for p: Vector2 in triangle:
				if Geometry2D.is_point_in_polygon(p, footprint.poly):
					overlaps = true
					break
			if not overlaps and absf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])) > 0.000001:
				overlaps = not Geometry2D.intersect_polygons(triangle, footprint.poly).is_empty()
			if overlaps:
				hidden[key] = true
				break
	for i in range(0, surface.vertices.size(), 3):
		if hidden.has(Vector2(surface.uv[i].x, surface.colors[i].g)):
			continue
		for j in 3:
			result.vertices.append(surface.vertices[i + j])
			result.normals.append(surface.normals[i + j])
			result.colors.append(surface.colors[i + j])
			result.uv.append(surface.uv[i + j])
			result.uv2.append(surface.uv2[i + j])
	return result
