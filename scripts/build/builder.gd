extends Node3D
## Main-scene build transactions. Economy remains owned by IslandShell.
const Layout := preload("res://scripts/build/layout.gd")
const BuildPanel :=  preload("res://scripts/build/build_panel.gd")
const IslandGeometry := preload("res://scripts/world/island_geometry.gd")
const SAVE_PATH := "user://courtyard_layout_v1.json"
const MODEL := {"tree":["CommonTree_1",3.0],"rock":["Rock_Medium_1",.55],"bush":["Bush_Common",.65],"grass":["Grass_Common_Short",.3]}
var island: Node3D
var house: Node3D
var art: Node3D
var layout=Layout.new()
var nodes: Dictionary={}
var panel: CanvasLayer
var tool: String="select"
var selected: int=-1
var moving: int=-1
var notice: String="选择物件开始营造"
var hover_cell:=Layout.NOWHERE
var hover_reason: String="ok"
var _ghost: Node3D
var _ghost_key: String=""
var _overlay: MultiMeshInstance3D
var _grid: MeshInstance3D
var _water: Dictionary={}
var _painting:=false
var _stroke_last:=Layout.NOWHERE
var _stroke_seen: Dictionary={}
var _stroke_count:=0
var _stroke_broke:=false
var _preview_material: StandardMaterial3D
var _tile_material: StandardMaterial3D
func configure(p_island: Node3D,p_house: Node3D,p_art: Node3D) -> void:
	island=p_island
	house=p_house
	art=p_art
func _ready() -> void:
	add_to_group("sandbox_builder")
	for c in island.terrain._default_river():_water[c]=true
	refresh_rules()
	for row in [["tree",Vector2i(-6,-5)],["rock",Vector2i(-5,-5)],["tree",Vector2i(-6,1)],["rock",Vector2i(-5,2)],["tree",Vector2i(5,-5)],["rock",Vector2i(6,-5)]]:
		layout.place(row[0],row[1])
	_make_preview()
	panel=BuildPanel.new()
	panel.builder=self
	add_child(panel)
	panel.hide()
	rebuild_objects()
func refresh_rules() -> void:
	var reserved: Dictionary=island.sim.occupied.duplicate()
	for c in [Vector2i(-4,1),Vector2i(-4,2),Vector2i(0,2),Vector2i(0,3)]:reserved[c]="fixed"
	layout.configure(island.terrain.land_cells,island.terrain.water_cells,reserved)
func active() -> bool:return island!=null and island.build_mode
func set_active(value: bool) -> void:
	if value and not SpaceState.is_courtyard():return
	island.build_mode=value
	panel.visible=value
	_overlay.visible=value
	_grid.visible=value
	cancel()
	if value:
		var player:=get_tree().get_first_node_in_group("player")
		if player:
			player.sync_location()
			player.velocity=Vector3.ZERO
		_draw_grid()
func cancel() -> void:
	end_stroke()
	hover_cell=Layout.NOWHERE
	moving=-1
	selected=-1
	tool="select"
	_clear_ghost()
func choose(kind: String) -> void:
	end_stroke()
	hover_cell=Layout.NOWHERE
	moving=-1
	selected=-1
	tool=kind
	_clear_ghost()
	notice="点击地面放置" if Layout.CATALOG.has(kind) else "点击占地选择物件"
	if kind in ["land","erase_land"]:notice="按住左键拖动，连续"+("铺地" if kind=="land" else "收地")
func start_move() -> void:
	if selected<0:return
	moving=selected
	tool="move"
	_clear_ghost()
	notice="选择新位置；右键取消，原物件会保留"
func _player_cell() -> Vector2i:
	var player:=get_tree().get_first_node_in_group("player") as Node3D
	return island.sim.world_to_cell(player.global_position) if player and SpaceState.is_courtyard() else Layout.NOWHERE
func placement_reason(kind: String,cell: Vector2i,ignore: int=-1) -> String:
	var result: String=layout.evaluate(kind,cell,ignore,_player_cell())
	if result!="ok":return result
	var player:=get_tree().get_first_node_in_group("player") as Node3D
	if player and SpaceState.is_courtyard():
		var p:=Vector2(player.global_position.x,player.global_position.z)
		for c in layout.footprint(kind,cell):
			var nearest:=p.clamp(Vector2(c),Vector2(c)+Vector2.ONE)
			if p.distance_to(nearest)<.35:return "player"
	return "ok"
func commit_place(kind: String,cell: Vector2i) -> String:
	refresh_rules()
	var result:=placement_reason(kind,cell)
	if result=="ok":result=layout.place(kind,cell,_player_cell())
	if result=="ok":rebuild_objects()
	return result
func commit_move(id: int,cell: Vector2i) -> String:
	refresh_rules()
	var row: Dictionary=layout.find(id)
	if row.is_empty():return "missing"
	var result:=placement_reason(row.kind,cell,id)
	if result=="ok":result=layout.move(id,cell,_player_cell())
	if result=="ok":rebuild_objects()
	return result
func commit_remove(id: int) -> String:
	var result: String=layout.remove(id)
	if result=="ok":rebuild_objects()
	return result
func remove_selected() -> void:
	notice=explain(commit_remove(selected))
	selected=-1
	moving=-1
	tool="select"
	_clear_ghost()
func land_reason(cell: Vector2i,erase: bool) -> String:
	if erase:
		if not island.sim.has_cell(cell):return "no_land_delete"
		if cell==_player_cell():return "player"
		if layout.reserved.has(cell):return "reserved"
		if island.terrain.bridge_cells.has(cell):return "bridge"
		for row in layout.objects:
			if cell in layout.footprint(row.kind,row.cell) or (row.kind=="house" and cell in layout.approach(row.cell)):return "land_support"
	if not erase:
		var cost:=_xirang_cost(cell)
		if island.sim.xirang and not island.sim.xirang.can_afford(cost):return "no_xirang"
	var scratch=preload("res://scripts/sim/world_sim.gd").new(island.sim.cfg)
	scratch.from_dict(island.sim.to_dict())
	return scratch.try_delete(cell) if erase else scratch.try_place(cell)
func _xirang_cost(cell: Vector2i) -> float:
	if island.sim.xirang==null:return 0.0
	var after:=IslandGeometry.component_size_after_add(island.sim.cells_in_order,cell)
	return island.sim.xirang.quote_add(after)
func edit_land(cell: Vector2i,erase: bool) -> String:
	refresh_rules()
	var result:=land_reason(cell,erase)
	if result!="ok":return result
	island.sim.catch_up(island._clock_minutes)
	var spent:=0.0
	var refund:=0.0
	if erase and island.sim.xirang:
		refund=island.sim.xirang.quote_remove()
		island.sim.xirang.credit(refund)
	elif island.sim.xirang:
		spent=_xirang_cost(cell)
		if not island.sim.xirang.try_spend(spent):return "no_xirang"
	result=island.sim.try_delete(cell) if erase else island.sim.try_place(cell)
	if result!="ok":
		if erase and island.sim.xirang:island.sim.xirang.try_spend(refund)
		elif island.sim.xirang:island.sim.xirang.credit(spent)
		return result
	island.rebuild_instances()
	refresh_rules()
	_draw_grid()
	return result
func rebuild_objects() -> void:
	art.clear_communities()
	nodes.clear()
	var home: Vector2i=layout.find(0).cell
	house.position=Vector3(home.x,0,home.y-.2)
	SpaceState.house_door=house.to_global(Vector3(0,0,2.2))
	for row in layout.objects:
		if row.kind=="house":continue
		var node:=_render(row.kind,row.cell,art.get_node("NatureCommunities"))
		nodes[row.id]=node
		if row.kind!="grass":_collision(node,row.kind)
		var p:=node.global_position
		art._patches.append(Vector4(p.x,p.z,.65,.45))
	art._sync_contacts()
	var door: Vector3=SpaceState.house_door
	art.set_paths(PackedVector3Array([door,door+Vector3(0,0,1.4),Vector3(0,0,2.6)]))
	if is_instance_valid(_grid):_draw_grid()
func _render(kind: String,cell: Vector2i,parent: Node3D) -> Node3D:
	var pivot:=Node3D.new()
	parent.add_child(pivot)
	pivot.global_position=Vector3(cell.x+.5,0,cell.y+.5)
	if kind=="house":
		pivot.global_position=Vector3(cell.x,0,cell.y-.2)
		var model=preload("res://assets/buildings/cottage/cottage_tripo.glb").instantiate()
		pivot.add_child(model)
		model.rotation.y=-PI/2
		model.position=Vector3(-.624,0,.2)
	else:
		var item: Array=MODEL[kind]
		art.add_model(item[0],pivot.global_position,item[1],.3,pivot)
	return pivot
func _collision(node: Node3D,kind: String) -> void:
	var body:=StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=0
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(.8,.8,.8)
	shape.shape=box
	shape.position.y=box.size.y*.5
	body.add_child(shape)
	node.add_child(body)
func _make_preview() -> void:
	_preview_material=StandardMaterial3D.new()
	_preview_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.albedo_color=Color(.3,.8,.65,.38)
	_tile_material=_preview_material.duplicate()
	var cube:=BoxMesh.new()
	cube.size=Vector3(.96,.025,.96)
	cube.material=_tile_material
	_overlay=MultiMeshInstance3D.new()
	_overlay.multimesh=MultiMesh.new()
	_overlay.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	_overlay.multimesh.mesh=cube
	_overlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_overlay)
	_overlay.hide()
	_grid=MeshInstance3D.new()
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color=Color(.78,.86,.74,.32)
	_grid.material_override=material
	_grid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid)
	_grid.hide()
func _draw_grid() -> void:
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for c in island.terrain.land_cells:
		for edge in [[Vector3(c.x,.028,c.y),Vector3(c.x+1,.028,c.y)],[Vector3(c.x,.028,c.y),Vector3(c.x,.028,c.y+1)]]:
			mesh.surface_add_vertex(edge[0]);mesh.surface_add_vertex(edge[1])
	mesh.surface_end()
	_grid.mesh=mesh
func _clear_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
		_ghost=null
	_ghost_key=""
func _tint(node: Node) -> void:
	if node is GeometryInstance3D:
		node.material_override=_preview_material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():_tint(child)
func preview_at(cell: Vector2i) -> void:
	hover_cell=cell
	var kind: String=tool
	if tool=="move" and not layout.find(moving).is_empty():kind=layout.find(moving).kind
	var cells: Array[Vector2i]=[]
	if Layout.CATALOG.has(kind):
		hover_reason=placement_reason(kind,cell,moving)
		cells=layout.footprint(kind,cell)
		if _ghost_key!=kind:
			_clear_ghost()
			_ghost=_render(kind,cell,self)
			_tint(_ghost)
			_ghost_key=kind
		_ghost.global_position=Vector3(cell.x,0,cell.y-.2) if kind=="house" else Vector3(cell.x+.5,0,cell.y+.5)
	elif tool=="land" or tool=="erase_land":
		_clear_ghost()
		hover_reason=land_reason(cell,tool=="erase_land")
		cells.append(cell)
	else:
		_clear_ghost()
		var id: int=layout.at(cell)
		hover_reason="ok" if id>=0 else "empty"
		if id>=0:
			var row: Dictionary=layout.find(id)
			cells=layout.footprint(row.kind,row.cell)
	var color:=Color(.24,.72,.56,.40) if hover_reason=="ok" else Color(.88,.28,.22,.42)
	_preview_material.albedo_color=color
	_tile_material.albedo_color=color
	_overlay.multimesh.instance_count=cells.size()
	for i in cells.size():_overlay.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(cells[i].x+.5,.05,cells[i].y+.5)))
func click_cell(cell: Vector2i) -> void:
	if tool=="select":
		selected=layout.at(cell)
		notice="已选中 "+Layout.CATALOG[layout.find(selected).kind].label if selected>=0 else "此处没有可选物件"
	elif tool=="move":
		var result:=commit_move(moving,cell)
		notice=explain(result)
		if result=="ok":cancel()
	elif tool=="land" or tool=="erase_land":notice=explain(edit_land(cell,tool=="erase_land"))
	else:notice=explain(commit_place(tool,cell))
func begin_stroke(cell: Vector2i) -> void:
	if not active() or tool not in ["land","erase_land"]:return
	_painting=true
	_stroke_last=cell
	_stroke_seen.clear()
	_stroke_count=0
	_stroke_broke=false
	_paint_cell(cell)
func continue_stroke(cell: Vector2i) -> void:
	if not _painting:return
	var steps:=maxi(absi(cell.x-_stroke_last.x),absi(cell.y-_stroke_last.y))
	if steps>64:
		# A large camera/pointer jump must not paint an unintended long strip.
		end_stroke()
		return
	var previous:=_stroke_last
	for i in range(1,steps+1):
		var point:=Vector2i(Vector2(_stroke_last).lerp(Vector2(cell),float(i)/steps).round())
		if point.x!=previous.x and point.y!=previous.y:_paint_cell(Vector2i(point.x,previous.y))
		_paint_cell(point)
		previous=point
	_stroke_last=cell
func _paint_cell(cell: Vector2i) -> void:
	if _stroke_broke or _stroke_seen.has(cell):return
	_stroke_seen[cell]=true
	var result:=edit_land(cell,tool=="erase_land")
	if result=="ok":
		_stroke_count+=1
		notice=("已铺设 %d 格" if tool=="land" else "已收回 %d 格") % _stroke_count
	elif result=="no_xirang":
		_stroke_broke=true
		notice=explain(result)
	elif result not in ["already_land","no_land","no_land_delete"] or _stroke_count==0:notice=explain(result)
	hover_cell=Layout.NOWHERE
func end_stroke() -> void:
	_painting=false
	_stroke_broke=false
	_stroke_last=Layout.NOWHERE
	_stroke_seen.clear()
func _input(event: InputEvent) -> void:
	# Release must be observed even when the pointer is over UI.
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:end_stroke()
	if _painting and event is InputEventMouseMotion and panel.contains_point(event.position):end_stroke()
	if get_tree().paused:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_B:
			var space:=get_tree().get_first_node_in_group("space_controller")
			if SpaceState.is_courtyard() and (space==null or not space.is_transitioning()):set_active(not active())
			get_viewport().set_input_as_handled()
		elif active() and event.physical_keycode==KEY_ESCAPE:
			if tool!="select" or selected>=0:cancel()
			else:set_active(false)
			get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
	if not active():return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if tool in ["land","erase_land"]:begin_stroke(island.pick_cell_at(event.position))
			else:click_cell(island.pick_cell_at(event.position))
			get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			cancel()
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and _painting:
		continue_stroke(island.pick_cell_at(event.position))
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_DELETE:
		remove_selected()
		get_viewport().set_input_as_handled()
func _process(_delta: float) -> void:
	if not active():return
	if not SpaceState.is_courtyard():
		set_active(false)
		return
	var over_ui:=get_viewport().gui_get_hovered_control()!=null
	if over_ui:end_stroke()
	_overlay.visible=not over_ui
	if is_instance_valid(_ghost):_ghost.visible=not over_ui
	if not over_ui:
		var cell: Vector2i=island._pick_cell()
		if cell!=hover_cell or Layout.CATALOG.has(tool) or tool=="move":preview_at(cell)
	panel.refresh()
func snapshot() -> Dictionary:
	var cells: Array=[]
	for c in island.sim.cells_in_order:cells.append([c.x,c.y])
	return {"version":2,"land":cells,"layout":layout.to_dict()}
func restore_snapshot(data: Variant) -> String:
	if not data is Dictionary or not Layout.integer(data.get("version")) or int(data.version) not in [1,2] or not data.get("land") is Array or not data.has("layout"):return "bad_save"
	if data.land.is_empty() or data.land.size()>int(island.sim.cfg.land().hard_area_cap):return "bad_save"
	var cells: Array[Vector2i]=[]
	var combined: Dictionary={}
	for row in data.land:
		if not Layout.valid_cell(row):return "bad_save"
		var cell:=Vector2i(int(row[0]),int(row[1]))
		if cell in cells:return "bad_save"
		cells.append(cell)
		combined[cell]=true
	if data.version==1:
		# v1 stored only the 48-cell simulation plus edits; its backdrop was implicit.
		for x in range(-6,7):
			for z in range(-6,4):
				var cell:=Vector2i(x,z)
				if (x < -4 or x >= 4 or z < -2) and not combined.has(cell):
					cells.append(cell)
					combined[cell]=true
	if cells.size()>int(island.sim.cfg.land().hard_area_cap):return "area_cap"
	for c in island.sim.occupied:
		if c not in cells:return "bad_save"
	if not combined.has(_player_cell()):return "player"
	var candidate=Layout.new()
	var water: Dictionary={}
	for c in _water:
		if combined.has(c):water[c]=true
	candidate.configure(combined,water,layout.reserved)
	if candidate.restore(data.layout)!="ok":return "bad_save"
	# Check player clearance against candidate before modifying live state.
	var p:=_player_cell()
	for row in candidate.objects:
		if p in candidate.footprint(row.kind,row.cell):return "player"
	island.sim.catch_up(island._clock_minutes)
	var sim_data: Dictionary=island.sim.to_dict()
	sim_data.cells=[]
	for cell in cells:sim_data.cells.append([cell.x,cell.y])
	island.sim.from_dict(sim_data)
	layout=candidate
	island.rebuild_instances()
	refresh_rules()
	rebuild_objects()
	cancel()
	return "ok"
func save_layout(path: String=SAVE_PATH) -> String:
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return "io_error"
	file.store_string(JSON.stringify(snapshot(),"\t"))
	file.flush()
	var error:=file.get_error()
	file.close()
	if error!=OK:return "io_error"
	return "ok" if DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))==OK else "io_error"
func load_layout(path: String=SAVE_PATH) -> String:
	if not FileAccess.file_exists(path):return "no_save"
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>1024*1024:return "bad_save"
	return restore_snapshot(JSON.parse_string(file.get_as_text()))
static func explain(reason: String) -> String:
	return {"ok":"已完成", "overlap":"占地被物件使用", "land_support":"此处承托着物件，请先搬移再收地", "water":"不能放在水面上", "no_land":"需要完整陆地支撑", "reserved":"请避开泉眼、设施或云口", "entrance":"请留出小屋门前通路", "player":"请先让人物离开此处", "protected":"小屋可以搬迁，不能拆除", "missing":"请先选择物件", "empty":"空地", "bridge":"请保留桥梁及桥头的支撑地块", "already_land":"这里已有陆地", "not_adjacent":"新地块须与陆地边缘相邻", "area_cap":"已达到土地上限", "no_land_delete":"此处没有地块", "occupied":"地块上有固定设施", "seep_cap":"土地养护额度不足", "no_xirang":"息壤不足，无法继续铺地", "object_cap":"本轮物件上限为 128 个", "bad_save":"布局文件无效，当前庭院保持不变", "io_error":"无法写入布局文件", "no_save":"还没有保存的庭院布局"}.get(reason,"无法执行："+reason)
