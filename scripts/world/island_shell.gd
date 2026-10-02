extends Node3D
## View + input for WorldSim. Does not own economy ticks.
## MultiMesh for the playable courtyard (up to 256 cells). Colors lerp in the view; n_i is already committed.

const WorldSimScript := preload("res://scripts/sim/world_sim.gd")

const PLAYABLE_AREA_CAP := 256 # The preserved visible courtyard already contains 130 cells.
const HUD_HZ := 4.0
const NOURISH := Color("889f7b")
const DORMANT := Color("6a7a62")

var build_mode := false
var terrain: Node3D
var sim: RefCounted
var _multimesh: MultiMesh
var _mesh_instance: MultiMeshInstance3D
var _spring_mesh: MeshInstance3D
var _facilities: Node3D
var _hud: Label
var _hint: Label
var _targets: PackedColorArray = PackedColorArray()
var _shown: PackedColorArray = PackedColorArray()
var _hud_accum := 0.0
var _clock_minutes := 0.0
var _terrain_visual_ready := false


func _ready() -> void:
	add_to_group("island_shell")
	sim = WorldSimScript.new()
	sim.reset_prefab()
	# One source of truth: register the former backdrop before building any surface.
	# Keep the original 48 cells first so existing production nourishment priority stays stable.
	sim.cfg.raw["land"]["hard_area_cap"] = PLAYABLE_AREA_CAP
	var initial: Dictionary = sim.to_dict()
	var IslandGeometry := preload("res://scripts/world/island_geometry.gd")
	for cell in IslandGeometry.courtyard_yard_cells():
		if not sim.has_cell(cell):
			initial.cells.append([cell.x, cell.y])
	sim.from_dict(initial)
	_build_mesh()
	_mesh_instance.hide()
	terrain = preload("res://scripts/world/river_terrain.gd").new()
	terrain.name = "RiverTerrain"
	add_child(terrain)
	_build_spring()
	_facilities = Node3D.new()
	_facilities.name = "Facilities"
	add_child(_facilities)
	_build_hud()
	rebuild_instances()


func is_walkable(world: Vector3) -> bool:
	return terrain.is_walkable(world) if terrain else sim.has_cell(sim.world_to_cell(world))


func _process(delta: float) -> void:
	_clock_minutes += delta / 60.0
	_hud_accum += delta
	if _hud_accum >= 1.0 / HUD_HZ:
		_hud_accum = 0.0
		sim.catch_up(_clock_minutes)
		_refresh_hud()
	_lerp_colors(delta)
	var camera := get_viewport().get_camera_3d()
	if camera and terrain and terrain.has_method("refresh_lod"):
		terrain.refresh_lod(camera.global_position)
	var clouds := get_tree().get_first_node_in_group("cloud_sea")
	if clouds and clouds.has_method("follow_islands") and terrain and terrain.has_method("island_disks"):
		clouds.follow_islands(terrain.island_disks())
	var islands_root := terrain.get_node_or_null("Islands") if terrain else null
	if islands_root:
		for child in islands_root.get_children():
			if child.has_method("settle") and child.has_method("is_active") and child.is_active():
				child.settle(_clock_minutes)


func _unhandled_input(event: InputEvent) -> void:
	# The dedicated controller owns building input and feedback in the playable scene.
	if get_tree().get_first_node_in_group("sandbox_builder") != null:
		if build_mode or (event is InputEventKey and event.physical_keycode == KEY_B):
			return
	if SpaceState.is_inside():
		return
	var exploring := SpaceState.is_exploring()
	var space := get_tree().get_first_node_in_group("space_controller")
	if space and space.is_input_blocked():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B and not exploring:
		build_mode = not build_mode
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if exploring and event.physical_keycode != KEY_7:
			return
		match event.physical_keycode:
			KEY_1:
				sim.catch_up(_clock_minutes)
				sim.set_land_budget(sim.land_budget - 0.4)
				rebuild_instances()
			KEY_2:
				sim.catch_up(_clock_minutes)
				sim.set_land_budget(sim.land_budget + 0.4)
				rebuild_instances()
			KEY_3:
				sim.catch_up(_clock_minutes)
				sim.add_protection(16)
				rebuild_instances()
			KEY_4:
				sim.catch_up(_clock_minutes)
				sim.add_protection(-16)
				rebuild_instances()
			KEY_5:
				sim.catch_up(_clock_minutes)
				sim.try_assign_research()
				rebuild_instances()
			KEY_6:
				sim.catch_up(_clock_minutes)
				sim.try_collect()
				rebuild_instances()
			KEY_7:
				sim.catch_up(_clock_minutes)
				sim.try_pack_overhead()
				rebuild_instances()
			KEY_8:
				sim.catch_up(_clock_minutes)
				sim.expedition_return()
				rebuild_instances()
			KEY_9:
				sim.catch_up(_clock_minutes)
				sim.expedition_fail()
				rebuild_instances()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if exploring:
		return
	if build_mode and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _pick_cell()
		sim.catch_up(_clock_minutes)
		var result := ""
		if event.shift_pressed:
			result = sim.try_delete(cell)
		else:
			result = sim.try_place(cell)
		if result == "ok":
			rebuild_instances()
		get_viewport().set_input_as_handled()


func rebuild_instances() -> void:
	sim.recompute()
	var n: int = sim.cell_count()
	_multimesh.instance_count = n
	_targets.resize(n)
	if _shown.size() != n:
		_shown.resize(n)
		for i in n:
			_shown[i] = _color_for(sim.cells_in_order[i])
	for i in n:
		var c: Vector2i = sim.cells_in_order[i]
		var xf := Transform3D()
		xf.origin = sim.cell_center(c) + Vector3(0.0, -0.08, 0.0)
		xf.basis = xf.basis.scaled(Vector3(0.96, 0.16, 0.96))
		_multimesh.set_instance_transform(i, xf)
		_targets[i] = _color_for(c)
		_multimesh.set_instance_color(i, _shown[i] if i < _shown.size() else _targets[i])
	_spring_mesh.position = Vector3(-2.0, 0.30, 1.1)
	_rebuild_facilities()
	_refresh_hud()
	if terrain:
		if not _terrain_visual_ready:
			terrain.configure(sim.cells_in_order)
			_terrain_visual_ready = true
		else:
			terrain.apply_cells_deferred(sim.cells_in_order)


func _rebuild_facilities() -> void:
	for child in _facilities.get_children():
		child.queue_free()
	if sim.craft == null:
		return
	for field in sim.craft.fields:
		_planter(field["cell"])
	_crate(sim.craft.bench["cell"])
	_lantern(sim.craft.research["cell"], 0.62)
	_lantern(Vector2i(0, 3), 0.92)


func _wood(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


func _planter(cell: Vector2i) -> void:
	var at: Vector3 = sim.cell_center(cell)
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.62, 0.10, 0.62)
	box.mesh = mesh
	box.material_override = _wood(Color("6b5340"))
	box.position = at + Vector3(0.0, 0.05, 0.0)
	_facilities.add_child(box)
	var soil := MeshInstance3D.new()
	var soil_mesh := BoxMesh.new()
	soil_mesh.size = Vector3(0.50, 0.04, 0.50)
	soil.mesh = soil_mesh
	soil.material_override = _wood(Color("3d3226"))
	soil.position = at + Vector3(0.0, 0.10, 0.0)
	_facilities.add_child(soil)


func _crate(cell: Vector2i) -> void:
	var at: Vector3 = sim.cell_center(cell)
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.38, 0.28, 0.38)
	box.mesh = mesh
	box.material_override = _wood(Color("8a6d4a"))
	box.position = at + Vector3(0.0, 0.14, 0.0)
	_facilities.add_child(box)
	var jar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.08
	cyl.height = 0.16
	cyl.radial_segments = 8
	jar.mesh = cyl
	jar.material_override = _wood(Color("b08968"))
	jar.position = at + Vector3(0.16, 0.36, 0.04)
	_facilities.add_child(jar)


func _lantern(cell: Vector2i, height: float) -> void:
	var at: Vector3 = sim.cell_center(cell)
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.09
	cyl.height = height * 0.62
	cyl.radial_segments = 8
	post.mesh = cyl
	post.material_override = _wood(Color("6e675c"))
	post.position = at + Vector3(0.0, cyl.height * 0.5, 0.0)
	_facilities.add_child(post)
	var cap := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.28, 0.14, 0.28)
	cap.mesh = prism
	cap.material_override = _wood(Color("5a5348"))
	cap.position = at + Vector3(0.0, cyl.height + 0.08, 0.0)
	_facilities.add_child(cap)
	var glow := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.055
	bulb.height = 0.11
	glow.mesh = bulb
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("e8c888")
	gmat.emission_enabled = true
	gmat.emission = Color("e6b35a")
	gmat.emission_energy_multiplier = 0.65
	glow.material_override = gmat
	glow.position = at + Vector3(0.0, cyl.height * 0.78, 0.0)
	_facilities.add_child(glow)


func _color_for(c: Vector2i) -> Color:
	var nourish: bool = bool(sim.nourished.get(c, true))
	if not sim.show_desaturation:
		return NOURISH
	return NOURISH if nourish else DORMANT


func _lerp_colors(delta: float) -> void:
	var n: int = _multimesh.instance_count
	if n == 0:
		return
	var t: float = clampf(delta / 3.0, 0.0, 1.0)
	for i in n:
		_shown[i] = _shown[i].lerp(_targets[i], t)
		_multimesh.set_instance_color(i, _shown[i])


func _pick_cell() -> Vector2i:
	return pick_cell_at(get_viewport().get_mouse_position())


func pick_cell_at(mouse: Vector2) -> Vector2i:
	return sim.world_to_cell(pick_world_at(mouse))


func pick_world_at(mouse: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var origin := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	if terrain and terrain.has_method("intersect_ray"):
		var hit: Vector3 = terrain.intersect_ray(origin, dir)
		if hit.is_finite():
			return hit
	if absf(dir.y) < 0.0001:
		return Vector3.ZERO
	var dist: float = -origin.y / dir.y
	if dist < 0.0:
		return Vector3.ZERO
	return origin + dir * dist


func _build_mesh() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	box.material = mat
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.mesh = box
	_mesh_instance = MultiMeshInstance3D.new()
	_mesh_instance.multimesh = _multimesh
	_mesh_instance.name = "LandMultiMesh"
	add_child(_mesh_instance)


func _build_spring() -> void:
	_spring_mesh = MeshInstance3D.new()
	_spring_mesh.name = "Spring"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.28
	cyl.bottom_radius = 0.34
	cyl.height = 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("7eb8c9")
	cyl.material = mat
	_spring_mesh.mesh = cyl
	add_child(_spring_mesh)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	layer.visible = false
	add_child(layer)
	_hud = Label.new()
	_hud.offset_left = 16
	_hud.offset_top = 40
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.add_theme_color_override("font_color", Color("2b3530"))
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	_hint = Label.new()
	_hint.offset_left = 16
	_hint.offset_top = 12
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color("2b3530"))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = "左键铺地  Shift删地  南沿云口出门  5研究  6收藏  7入包  Esc"
	layer.add_child(_hint)


func _refresh_hud() -> void:
	if SpaceState.is_exploring() and sim.trip:
		_hint.text = "走回入口撤离  左路拾取  右路观察  左路尽头是雾  7入包"
		var lines: PackedStringArray = sim.trip.questions(sim)
		var home := ""
		if sim.craft:
			home = "\n家里仍在转  药草 %d  药品 %d" % [sim.craft.total_herbs(), sim.craft.potions()]
		_hud.text = "%s\n%s\n%s%s" % [lines[0], lines[1], lines[2], home]
		return
	_hint.text = "左键铺地  Shift删地  南沿云口出门  5研究  6收藏  7入包  Esc"
	var L: Dictionary = sim.ledger_cache
	var until: float = sim.minutes_until_pool_full()
	var until_text := "已满" if until == 0.0 else ("—" if until == INF else "%.1f 分钟" % until)
	var forecast: Dictionary = sim.runtime_forecast()
	var run_m: float = float(forecast.get("minutes", INF))
	var run_text := "—" if run_m >= INF else ("已停" if run_m <= 1e-9 else "%.1f 分钟" % run_m)
	var reason := _zh(String(forecast.get("reason", "")))
	var extra := ""
	if sim.craft:
		extra = "\n药草 %d  药品 %d/%d" % [sim.craft.total_herbs(), sim.craft.potions(), int(sim.craft.bench["buffer"])]
		for line in sim.craft.status_lines():
			extra += "\n" + _zh_line(line)
		extra += "\n产线还能稳转 %s（%s）" % [run_text, reason]
		extra += "\n见闻 %d  已研 %d  头顶 %d/%d  行囊 %d  收藏 %s" % [
			(sim.knowledge.get("discovered", {}) as Dictionary).size(),
			(sim.knowledge.get("completed", {}) as Dictionary).size(),
			sim.items.overhead.size(),
			sim.items.overhead_k,
			sim.items.ids_in("bag").size(),
			"有" if sim.items.collection_id != "" else "空",
		]
	if sim.trip and String(sim.trip.outcome) == "failed":
		extra += "\n此行护体回村，随身丢失"
	elif sim.trip and String(sim.trip.outcome) == "withdrawn":
		extra += "\n此行主动撤离"
	_hud.text = "陆地 %d  免税 %d  付费养护 %d  未滋润 %d\n养护支出 %.2f  入池 %.2f  泉池 %.1f / %.0f\n预算 %.2f  保护额度 %d  还能入池 %s%s" % [
		sim.cell_count(),
		int(L.get("free", 0)),
		int(L.get("paid", 0)),
		int(L.get("dormant", 0)),
		float(L.get("maintenance", 0.0)),
		float(L.get("inflow", 0.0)),
		sim.total_pool(),
		float(sim.springs[0]["cap"]),
		sim.land_budget,
		sim.protection_quota,
		until_text,
		extra,
	]


func _zh(code: String) -> String:
	match code:
		"sow":
			return "播种"
		"grow":
			return "生长"
		"harvest":
			return "收获"
		"idle":
			return "空闲"
		"work":
			return "制作"
		"stock_done":
			return "药品储备完成"
		"output_full":
			return "输出满"
		"no_input":
			return "缺药草"
		"no_energy":
			return "缺气"
		"herb_full":
			return "药草缓冲满"
		"horizon":
			return "超过预览窗"
		"done":
			return "完成"
		"paused":
			return "样本离开已暂停"
		"already_done":
			return "主题已记录"
		"research":
			return "研究"
		"steady":
			return "持续"
		_:
			return code


func _zh_line(line: String) -> String:
	var out := line
	for key in ["sow", "grow", "harvest", "idle", "work", "stock_done", "output_full", "no_input", "no_energy", "done", "paused", "already_done"]:
		out = out.replace(key, _zh(key))
	return out
