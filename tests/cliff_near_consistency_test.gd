extends SceneTree
## Verifies sculpted interior terrace steps, narrow expanded peninsulas,
## near-end locality, grounded outcrops, and threaded worker chunk parity.
const Data = preload("res://scripts/terrain_editor/terrain_data.gd")
const Contours = preload("res://scripts/terrain_editor/contour_terrain.gd")
const Decoration = preload("res://scripts/terrain_editor/terrain_decoration.gd")
const RimOutcrops = preload("res://scripts/terrain_editor/rim_outcrops.gd")
const RimBalding = preload("res://scripts/terrain_editor/cliff_rim_balding.gd")
const Geometry = preload("res://scripts/terrain_editor/chunk_geometry.gd")
const Renderer = preload("res://scripts/terrain_editor/terrain_renderer.gd")

var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _changed_centers(before_cells: Dictionary, after_cells: Dictionary) -> Array[Vector2]:
	var all_keys: Dictionary = before_cells.duplicate()
	all_keys.merge(after_cells, true)
	var out: Array[Vector2] = []
	for cell: Vector2i in all_keys:
		var old_r: Dictionary = before_cells.get(cell, {})
		var new_r: Dictionary = after_cells.get(cell, {})
		if old_r.get("height") != new_r.get("height") or old_r.get("water") != new_r.get("water"):
			out.append(Vector2(cell) + Vector2(0.5, 0.5))
	return out

func _min_dist_to_any(p: Vector2, centers: Array[Vector2]) -> float:
	var best := INF
	for q: Vector2 in centers:
		best = minf(best, p.distance_to(q))
	return best

func _find_expand_target(data: RefCounted) -> Vector2:
	var best := Vector2(-11.5, 4.5)
	var best_score := -INF
	for cell: Vector2i in data.cells:
		var rec: Dictionary = data.cells[cell]
		if int(rec.get("water", -1)) >= 0 or float(rec.height) > 2.2:
			continue
		var has_empty := false
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not data.cells.has(cell + d):
				has_empty = true
				break
		if not has_empty:
			continue
		var p := Vector2(cell) + Vector2(0.5, 0.5)
		var score := -absf(p.x - (-11.5)) * 0.5 + p.y * 1.1
		if score > best_score:
			best_score = score
			best = p + Vector2(0.0, 1.35)
	return best

func _collect_layout_snapshot(deco: RefCounted) -> Dictionary:
	var cols: Dictionary = {}
	for col: Dictionary in deco._columns:
		var key := Vector3i((Vector3(col.edge.x, col.pose.origin.y, col.edge.y) * 100.0).round())
		cols[key] = [col.kind, col.pose]
	var masses: Dictionary = {}
	for m: Dictionary in deco._mass:
		var o: Vector3 = (m.pose as Transform3D).origin
		var key := Vector3i((o * 100.0).round())
		masses[key] = [m.kind, m.pose]
	var outcrops: Dictionary = {}
	for oc: Dictionary in deco._outcrops:
		var o: Vector3 = (oc.pose as Transform3D).origin
		var key := Vector3i((o * 100.0).round())
		outcrops[key] = [oc.kind, oc.pose]
	return {"cols": cols, "masses": masses, "outcrops": outcrops}

func _verify_interior_terrace_relief() -> void:
	var data := Data.new()
	data.make_preset(0)
	data.seed = 7301
	var field := Contours.new()
	field.refresh(data)
	var deco := Decoration.new()
	deco.load_assets()
	deco._column_layout(field, data.seed)
	var valid_normals := true
	for n: Vector3 in field.surfaces.cliff.normals:
		if not n.is_finite() or absf(n.length() - 1.0) > 0.001:
			valid_normals = false
			break
	check(valid_normals, "all contour cliff and sculpted terrace normals are finite unit vectors")

	var field2 := Contours.new()
	field2.refresh(data)
	preload("res://scripts/terrain_editor/rim_union.gd").apply(field2, deco._columns, deco.assets, deco.fit_core_to_feet, deco.blend_core_joints)
	var pre_seal_verts: int = field2.surfaces.cliff.vertices.size()
	field2.close_unclad_dry_steps(deco._columns, deco.assets)
	var verts: PackedVector3Array = field2.surfaces.cliff.vertices
	var norms: PackedVector3Array = field2.surfaces.cliff.normals
	var uvs: PackedVector2Array = field2.surfaces.cliff.uv
	var seal_verts: int = verts.size() - pre_seal_verts
	check(seal_verts >= 36, "close_unclad_dry_steps generates multi-band sculpted terrace faces")

	var distinct_dirs: Dictionary = {}
	var max_relief := 0.0
	var min_relief := INF
	var uv_valid := true
	var y_valid := true
	for i in range(pre_seal_verts, verts.size()):
		var v: Vector3 = verts[i]
		var n: Vector3 = norms[i]
		var uv: Vector2 = uvs[i]
		if uv.y <= 0.5 or (absf(uv.x - 5.0) > 0.02 and absf(uv.x - 3.5) > 0.02 and absf(uv.x - 2.5) > 0.02):
			uv_valid = false
		if v.y < 1.44 or v.y > 5.01:
			y_valid = false
		distinct_dirs[Vector3i((n * 10.0).round())] = true
		var h := uv.x
		var p2 := Vector2(v.x, v.z)
		var best_d := INF
		var best_signed := 0.0
		for loop: PackedVector2Array in field2.land_regions.get(h, []):
			for k in loop.size():
				var a: Vector2 = loop[k]
				var b: Vector2 = loop[(k + 1) % loop.size()]
				var cp := Geometry2D.get_closest_point_to_segment(p2, a, b)
				var dist := p2.distance_to(cp)
				if dist < best_d:
					best_d = dist
					var seg := b - a
					if seg.length_squared() > 0.00001:
						var out := Vector2(seg.y, -seg.x).normalized()
						best_signed = (p2 - cp).dot(out)
					else:
						best_signed = dist
		max_relief = maxf(max_relief, best_signed)
		min_relief = minf(min_relief, best_signed)
	check(uv_valid, "sculpted dry interior terrace walls preserve UV=(cap_height, 1.0)")
	check(y_valid, "sculpted dry interior terrace walls remain strictly bounded between upper and lower terrace floors")
	check(distinct_dirs.size() >= 8, "sculpted dry interior terrace walls have multi-facet sculpted normals (got %d)" % distinct_dirs.size())
	check(min_relief >= -0.02 and max_relief <= 0.255 and max_relief > 0.05, "interior terrace relief stays within [0, 0.255m] (got [%.3f, %.3f])" % [min_relief, max_relief])

	var ext_shoulders: Array = []
	for m: Dictionary in deco._mass:
		if not m.get("is_interior", false) and m.get("is_shoulder", false):
			ext_shoulders.append(m)
	check(ext_shoulders.size() >= 2 and ext_shoulders.size() <= 6, "Option A restrained layout keeps 2..6 clean primary-secondary shoulders (got %d)" % ext_shoulders.size())
	check(deco._outcrops.is_empty(), "loose rim boulder props are left to player placement")

	var bald_data: Dictionary = RimBalding.build(data, field)
	check(not bald_data.is_empty(), "RimBalding builds cliff-into-turf proximity field")
	var bald_hits := 0
	var lush_hits := 0
	for h_key in field.lawn_boundaries:
		var h_val := float(h_key)
		for loop: PackedVector2Array in field.lawn_boundaries[h_key]:
			if Contours._area(loop) <= 0.0: continue
			for i in loop.size():
				var a: Vector2 = loop[i]
				var b: Vector2 = loop[(i + 1) % loop.size()]
				if a.distance_to(b) < 0.25: continue
				var dir := (b - a).normalized()
				var out := Vector2(dir.y, -dir.x)
				var mid := (a + b) * 0.5
				if not field.surface_at(mid + out * 0.42).is_empty(): continue
				var sample := RimBalding.sample_at(bald_data, mid - out * 0.22)
				if sample.x > 0.25 or sample.y > 0.25:
					bald_hits += 1
				elif sample.x < 0.01 and sample.y < 0.01 and Contours.contains(field.lawn_boundaries[h_key], mid - out * 0.22):
					lush_hits += 1
	check(bald_hits >= 6 and lush_hits >= 12, "cliff rim combines exposed-stone balding patches (%d) with lush meadow rims (%d)" % [bald_hits, lush_hits])

func _verify_expand_narrow_peninsula() -> void:
	var data := Data.new()
	data.make_preset(0)
	data.seed = 7301
	var target := _find_expand_target(data)
	var narrow_at := target + Vector2(0.0, 0.85)
	var f_before := Contours.new()
	f_before.refresh(data)
	data.begin_stroke()
	data.apply_brush(narrow_at, 1.35, "expand", false, 1.5, 7)
	data.end_stroke()
	var field := Contours.new()
	field.refresh(data)
	var deco := Decoration.new()
	deco.load_assets()
	deco._column_layout(field, data.seed)
	var checked_near := 0
	var checked_narrow := 0
	var worst_narrow_drop := 0.0
	var worst_any_drop := 0.0
	var max_back_punch := 0.0
	for col: Dictionary in deco._columns:
		if col.get("is_step", false):
			continue
		var edge: Vector2 = col.edge
		var faces: PackedVector3Array = deco.assets[col.kind][0].faces
		var pose: Transform3D = col.pose
		var out_v := Vector2(pose.basis.z.x, pose.basis.z.z).normalized()
		if edge.distance_to(narrow_at) < 5.5 and f_before.surface_at(edge - out_v * 0.25).is_empty():
			checked_near += 1
			var prof: Dictionary = field._cliff_profile(edge, out_v).duplicate()
			if not field.levels.is_empty():
				field._outer_profile(edge, out_v, prof)
			var foot_y: float = field._profile_point(edge, Contours.BOTTOM, out_v, prof).y
			var col_bottom := INF
			for p: Vector3 in faces:
				var w: Vector3 = pose * p
				col_bottom = minf(col_bottom, w.y)
			var drop_val: float = foot_y - col_bottom
			worst_any_drop = maxf(worst_any_drop, drop_val)
			var lspan := 0.6
			for d_p: float in [0.6, 1.0, 1.4, 1.8, 2.2, 2.8, 3.5, 4.4]:
				if not field.surface_at(edge - out_v * d_p).is_empty():
					lspan = d_p
				else:
					break
			if lspan <= 2.4:
				checked_narrow += 1
				worst_narrow_drop = maxf(worst_narrow_drop, drop_val)
		# Verify inward heel (-z in local column space) never exits through opposite empty cliff void:
		for p: Vector3 in faces:
			if p.z >= -0.28:
				continue
			var w: Vector3 = pose * p
			var xz := Vector2(w.x, w.z)
			if (xz - edge).dot(out_v) < -0.85 and field.surface_at(xz).is_empty():
				var edge_dist := INF
				for loop: PackedVector2Array in field.rim_regions.get(col.pose.origin.y, []):
					for i in loop.size():
						edge_dist = minf(edge_dist, xz.distance_to(Geometry2D.get_closest_point_to_segment(xz, loop[i], loop[(i + 1) % loop.size()])))
				max_back_punch = maxf(max_back_punch, edge_dist)
	check(checked_near >= 4 and checked_narrow >= 2, "expanded peninsula generated multiple near and narrow rim columns (near=%d, narrow=%d)" % [checked_near, checked_narrow])
	check(worst_narrow_drop <= 0.50, "narrow peninsula flank columns fit local hull foot without hanging fangs (drop=%.3f)" % worst_narrow_drop)
	check(worst_any_drop <= 1.00, "mainland-junction expanded columns stay within underside keel tuck (drop=%.3f)" % worst_any_drop)
	check(max_back_punch <= 0.20, "narrow peninsula columns do not punch heels through opposite cliff faces (max_punch=%.3f)" % max_back_punch)

func _verify_edit_locality_and_outcrops(seed_value: int) -> void:
	var data := Data.new()
	data.make_preset(0)
	data.seed = seed_value
	var exp_at := _find_expand_target(data)
	var edits := [
		{"name": "expand", "at": exp_at, "tool": "expand", "r": 2.2, "h": 1.5, "w": 7, "iters": 1},
		{"name": "contract", "at": Vector2(-12.0, -9.0), "tool": "contract", "r": 2.0, "h": 1.5, "w": 3, "iters": 1},
		{"name": "lower", "at": Vector2(-8.0, -5.0), "tool": "lower", "r": 3.2, "h": 1.5, "w": 7, "iters": 3},
		{"name": "raise", "at": Vector2(-6.5, 4.5), "tool": "raise", "r": 2.5, "h": 1.5, "w": 7, "iters": 3},
	]
	for ed: Dictionary in edits:
		var cur := Data.new()
		cur.make_preset(0)
		cur.seed = seed_value
		var base_cells: Dictionary = cur.cells.duplicate(true)
		var f_before := Contours.new()
		f_before.refresh(cur)
		var d_before := Decoration.new()
		d_before.load_assets()
		d_before._column_layout(f_before, seed_value)
		var snap_before := _collect_layout_snapshot(d_before)

		cur.begin_stroke()
		for _i in int(ed.iters):
			cur.apply_brush(ed.at, float(ed.r), String(ed.tool), false, float(ed.h), int(ed.w))
		cur.end_stroke()
		var changed := _changed_centers(base_cells, cur.cells)
		var f_after := Contours.new()
		f_after.refresh(cur)
		var d_after := Decoration.new()
		d_after.assets = d_before.assets
		d_after._column_layout(f_after, seed_value)
		var snap_after := _collect_layout_snapshot(d_after)

		for k: Vector3i in snap_before.cols:
			var p2 := Vector2(k.x, k.z) / 100.0
			if _min_dist_to_any(p2, changed) > 10.5:
				check(snap_after.cols.get(k) == snap_before.cols[k], "seed %d %s preserves distant column beyond 10.5m" % [seed_value, ed.name])
		for k: Vector3i in snap_before.masses:
			var p2 := Vector2(k.x, k.z) / 100.0
			if _min_dist_to_any(p2, changed) > 10.5:
				check(snap_after.masses.get(k) == snap_before.masses[k], "seed %d %s preserves distant buttress/accent beyond 10.5m" % [seed_value, ed.name])
		check(d_after._outcrops.is_empty(), "seed %d %s keeps auto rim outcrops disabled" % [seed_value, ed.name])

func _chunk_digest(renderer: Node3D, include_grass_verts: bool = true) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = renderer.chunks.keys()
	keys.sort()
	for ck: Vector2i in keys:
		var node: Node3D = renderer.chunks[ck]
		if node == null:
			continue
		var entries: Array = []
		for child: Node in node.get_children():
			if child is MeshInstance3D:
				var mi := child as MeshInstance3D
				var m: Mesh = mi.mesh
				if m != null and m.get_surface_count() > 0:
					var box := m.get_aabb()
					var arr := m.surface_get_arrays(0)
					var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					if not include_grass_verts and String(mi.name) == "grass":
						entries.append("MI:grass:%s:%s" % [str((box.position * 1000.0).round()), str((box.size * 1000.0).round())])
					else:
						entries.append("MI:%s:%d:%s:%s" % [String(mi.name), verts.size(), str((box.position * 1000.0).round()), str((box.size * 1000.0).round())])
			elif child is MultiMeshInstance3D:
				var mmi := child as MultiMeshInstance3D
				var mm := mmi.multimesh
				if mm != null and mm.instance_count > 0:
					var nm := String(mmi.name)
					var j := nm.find("_joined_")
					if j >= 0:
						nm = nm.substr(0, j + 7)
					if not include_grass_verts and nm == "grass_blades":
						entries.append("MM:grass_blades:present")
					else:
						var poses: Array[String] = []
						for idx in mm.instance_count:
							var t := mm.get_instance_transform(idx)
							poses.append("%s|%s|%s|%s" % [str((t.origin * 1000.0).round()), str((t.basis.x * 1000.0).round()), str((t.basis.y * 1000.0).round()), str((t.basis.z * 1000.0).round())])
						poses.sort()
						entries.append("MM:%s:%d:%s" % [nm, mm.instance_count, ",".join(poses)])
		entries.sort()
		out[ck] = entries
	return out

func _wait_settled(renderer: Renderer) -> void:
	var started := Time.get_ticks_msec()
	while (renderer.has_pending_updates() or renderer._worker_task != -1) and Time.get_ticks_msec() - started < 15000:
		renderer.flush_dirty(6)
		renderer._process(0.05)
		OS.delay_msec(10)
		await process_frame

func _verify_threaded_worker_parity() -> void:
	var scene: PackedScene = load("res://scenes/terrain_editor.tscn")
	var editor := scene.instantiate()
	root.add_child(editor)
	await process_frame
	editor.renderer.animate_edits = false
	editor.renderer.threaded_builds = true
	editor.renderer.rebuild_all()
	var initial_digest := _chunk_digest(editor.renderer)

	var exp_at := _find_expand_target(editor.data)
	var edits := [
		{"name": "expand", "at": exp_at, "tool": "expand", "r": 2.2, "h": 1.5, "w": 7, "iters": 1},
		{"name": "contract", "at": Vector2(-12.0, -9.0), "tool": "contract", "r": 2.0, "h": 1.5, "w": 3, "iters": 1},
		{"name": "lower", "at": Vector2(-8.0, -5.0), "tool": "lower", "r": 3.2, "h": 1.5, "w": 7, "iters": 3},
		{"name": "raise", "at": Vector2(-6.5, 4.5), "tool": "raise", "r": 2.5, "h": 1.5, "w": 7, "iters": 3},
	]
	for ed: Dictionary in edits:
		editor.data.begin_stroke()
		for _i in int(ed.iters):
			editor.data.apply_brush(ed.at, float(ed.r), String(ed.tool), false, float(ed.h), int(ed.w))
		editor.data.end_stroke()
		await _wait_settled(editor.renderer)
		check(not editor.renderer.has_pending_updates() and editor.renderer._worker_task == -1, "threaded worker settled cleanly after " + String(ed.name))

		var fresh := Renderer.new()
		root.add_child(fresh)
		var fresh_deco := Decoration.new()
		fresh_deco.assets = editor.renderer.decoration.assets
		fresh_deco._shrub_base = editor.renderer.decoration._shrub_base
		fresh_deco._vine_center = editor.renderer.decoration._vine_center
		fresh.decoration = fresh_deco
		fresh.configure(editor.data.copy())
		fresh.rebuild_all()
		fresh.rebuild_all()
		check(_chunk_digest(editor.renderer, false) == _chunk_digest(fresh, false), "threaded partial worker rebuild matches fresh rebuild_all() chunk-for-chunk after " + String(ed.name))
		root.remove_child(fresh)
		fresh.free()

		editor.data.undo()
		await _wait_settled(editor.renderer)
		check(_chunk_digest(editor.renderer, true) == initial_digest, "undo + threaded worker rebuild restores exact initial chunks after " + String(ed.name))

	root.remove_child(editor)
	editor.free()
	await process_frame

func _initialize() -> void:
	_verify_interior_terrace_relief()
	_verify_expand_narrow_peninsula()
	for s: int in [7301, 2104]:
		_verify_edit_locality_and_outcrops(s)
	await _verify_threaded_worker_parity()
	print("CLIFF NEAR CONSISTENCY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
