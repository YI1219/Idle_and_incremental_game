extends Node3D
## Main-scene build transactions. Economy remains owned by IslandShell.
const Layout := preload("res://scripts/build/layout.gd")
const BuildPanel :=  preload("res://scripts/build/build_panel.gd")
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
var snap_line:=true
var _snap_origin:=Layout.NOWHERE
var _snap_axis: String=""
var _snap_diagonal:=Vector2i.ZERO
var _snap_guide: MeshInstance3D
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
	for row in [["tree",Vector2i(-6,-5)],["rock",Vector2i(-5,-5)],["tree",Vector2i(-6,1)],["rock",Vector2i(-5,2)],["tree",Vector2i(5,-5)],["rock",Vector2i(6,-5)],["bush",Vector2i(6,-6)],["grass",Vector2i(-5,-6)],["bush",Vector2i(6,-3)],["grass",Vector2i(1,-6)],["rock",Vector2i(6,2)]]:
		layout.place(row[0],row[1])
	_author_floating_island()
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
	if kind in ["land","erase_land","raise_land","sink_land"]:
		var action: String={"land":"扩建","erase_land":"收缩","raise_land":"抬升","sink_land":"下沉"}[kind]
		notice="按住左键拖动"+action+("，默认贴齐吸附线" if snap_line else "，吸附已关闭")
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
			if cell in layout.footprint(row.kind,row.cell) or (row.kind=="house" and cell in layout.approach(row.cell)):return "overlap"
	var scratch=preload("res://scripts/sim/world_sim.gd").new(island.sim.cfg)
	scratch.from_dict(island.sim.to_dict())
	return scratch.try_delete(cell) if erase else scratch.try_place(cell)
func edit_land(cell: Vector2i,erase: bool) -> String:
	refresh_rules()
	var result:=land_reason(cell,erase)
	if result!="ok":return result
	island.sim.catch_up(island._clock_minutes)
	result=island.sim.try_delete(cell) if erase else island.sim.try_place(cell)
	if result=="ok":
		island.rebuild_instances()
		refresh_rules()
		_draw_grid()
	return result
func edit_height(cell: Vector2i,delta: int) -> String:
	refresh_rules()
	if not island.sim.has_cell(cell):return "no_land"
	if island.terrain.bridge_cells.has(cell):return "bridge"
	var current: int=island.terrain.level_of(cell)
	var next:=clampi(current+delta,0,island.terrain.MAX_LEVEL)
	if next==current:return "height_floor" if delta<0 else "height_cap"
	if next==0:island.terrain.heights.erase(cell)
	else:island.terrain.heights[cell]=next
	island.sim.catch_up(island._clock_minutes)
	island.rebuild_instances()
	refresh_rules()
	rebuild_objects()
	_draw_grid()
	return "ok"
func _author_floating_island() -> void:
	var terrain: Node3D=island.terrain
	var water: Dictionary={}
	for cell in terrain._default_river():
		if terrain.land_cells.has(cell):water[cell]=true
	for x in range(2,6):
		for z in range(-4,-1):
			var pond:=Vector2i(x,z)
			if pond not in [Vector2i(3,-2),Vector2i(3,-3)] and terrain.land_cells.has(pond):water[pond]=true
	for cell in [Vector2i(4,-1),Vector2i(5,-1)]:
		if terrain.land_cells.has(cell):water[cell]=true
	var authored: Dictionary={}
	for cell in terrain.land_cells:
		var level:=_preset_level(cell)
		if level>0:authored[cell]=level
	terrain.custom_water=water
	terrain.use_custom_water=true
	terrain.heights=authored
	terrain.sculpted=true
	terrain.configure(island.sim.cells_in_order)
	refresh_rules()
func _preset_level(cell: Vector2i) -> int:
	if cell in [Vector2i(2,1),Vector2i(3,1),Vector2i(4,1),Vector2i(5,1),Vector2i(6,1)]:return 0
	if cell in [Vector2i(4,0),Vector2i(5,0)]:return 0
	if cell.y<=-1:return 3
	if cell.x<=1 and cell.y<=2:return 3
	if cell.y==0 and cell.x<=2:return 1
	return 0
func cell_surface(cell: Vector2i) -> float:
	return island.terrain.surface_y(cell) if island and island.terrain else 0.0
func rebuild_objects() -> void:
	art.clear_communities()
	nodes.clear()
	var home: Vector2i=layout.find(0).cell
	house.position=Vector3(home.x,cell_surface(home),home.y-.2)
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
	var y:=cell_surface(cell)
	pivot.global_position=Vector3(cell.x+.5,y,cell.y+.5)
	if kind=="house":
		pivot.global_position=Vector3(cell.x,y,cell.y-.2)
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
	material.albedo_color=Color(.84,.9,.8,.25)
	_grid.material_override=material
	_grid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid)
	_grid.hide()
func _draw_grid() -> void:
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for c in island.terrain.land_cells:
		var y:=cell_surface(c)+.028
		for edge in [[Vector3(c.x,y,c.y),Vector3(c.x+1,y,c.y)],[Vector3(c.x,y,c.y),Vector3(c.x,y,c.y+1)]]:
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
		_ghost.global_position=Vector3(cell.x,cell_surface(cell),cell.y-.2) if kind=="house" else Vector3(cell.x+.5,cell_surface(cell),cell.y+.5)
	elif tool in ["land","erase_land","raise_land","sink_land"]:
		_clear_ghost()
		hover_reason=_stroke_reason(cell)
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
	for i in cells.size():_overlay.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(cells[i].x+.5,cell_surface(cells[i])+.05,cells[i].y+.5)))
	_refresh_snap_guide(cell)
func click_cell(cell: Vector2i) -> void:
	if tool=="select":
		selected=layout.at(cell)
		notice="已选中 "+Layout.CATALOG[layout.find(selected).kind].label if selected>=0 else "此处没有可选物件"
	elif tool=="move":
		var result:=commit_move(moving,cell)
		notice=explain(result)
		if result=="ok":cancel()
	elif tool in ["land","erase_land","raise_land","sink_land"]:notice=explain(_apply_brush(cell))
	else:notice=explain(commit_place(tool,cell))
func _stroke_reason(cell: Vector2i) -> String:
	if tool=="raise_land":return _height_reason(cell,1)
	if tool=="sink_land":return _height_reason(cell,-1)
	return land_reason(cell,tool=="erase_land")
func _height_reason(cell: Vector2i,delta: int) -> String:
	if not island.sim.has_cell(cell):return "no_land"
	if island.terrain.bridge_cells.has(cell):return "bridge"
	var next:=clampi(island.terrain.level_of(cell)+delta,0,island.terrain.MAX_LEVEL)
	if next==island.terrain.level_of(cell):return "height_floor" if delta<0 else "height_cap"
	return "ok"
func _apply_brush(cell: Vector2i) -> String:
	if tool=="raise_land":return edit_height(cell,1)
	if tool=="sink_land":return edit_height(cell,-1)
	return edit_land(cell,tool=="erase_land")
func toggle_snap() -> void:
	snap_line=not snap_line
	_snap_axis=""
	notice="吸附线已开启，扩建、抬升和下沉会贴齐直线" if snap_line else "吸附已关闭，笔划跟随指针"
	if active():_refresh_snap_guide(hover_cell)
func _brush_tool() -> bool:
	return tool in ["land","erase_land","raise_land","sink_land"]
func begin_stroke(cell: Vector2i) -> void:
	if not active() or not _brush_tool():return
	_painting=true
	_stroke_last=cell
	_snap_origin=cell
	_snap_axis=""
	_stroke_seen.clear()
	_stroke_count=0
	_paint_cell(cell)
	_refresh_snap_guide(cell)
func continue_stroke(cell: Vector2i) -> void:
	if not _painting:return
	if snap_line:cell=_snapped_cell(cell)
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
	_refresh_snap_guide(cell)
func _snapped_cell(cell: Vector2i) -> Vector2i:
	var delta:=cell-_snap_origin
	if _snap_axis=="":
		if delta==Vector2i.ZERO:return cell
		var ax:=absi(delta.x)
		var az:=absi(delta.y)
		if ax>az:_snap_axis="row"
		elif az>ax:_snap_axis="column"
		else:
			_snap_axis="diagonal"
			_snap_diagonal=Vector2i(signi(delta.x),signi(delta.y))
	if _snap_axis=="row":return Vector2i(cell.x,_snap_origin.y)
	if _snap_axis=="column":return Vector2i(_snap_origin.x,cell.y)
	return _snap_origin+_snap_diagonal*maxi(absi(delta.x),absi(delta.y))
func _paint_cell(cell: Vector2i) -> void:
	if _stroke_seen.has(cell):return
	_stroke_seen[cell]=true
	var result:=_apply_brush(cell)
	if result=="ok":
		_stroke_count+=1
		var label: String={"land":"已扩建 %d 格","erase_land":"已收缩 %d 格","raise_land":"已抬升 %d 格","sink_land":"已下沉 %d 格"}[tool]
		notice=label % _stroke_count
	elif result not in ["already_land","no_land","no_land_delete","height_cap","height_floor"] or _stroke_count==0:notice=explain(result)
	hover_cell=Layout.NOWHERE
func end_stroke() -> void:
	_painting=false
	_stroke_last=Layout.NOWHERE
	_snap_axis=""
	_stroke_seen.clear()
	if active():_refresh_snap_guide(hover_cell)
func _ensure_snap_guide() -> void:
	if is_instance_valid(_snap_guide):return
	_snap_guide=MeshInstance3D.new()
	_snap_guide.name="SnapGuide"
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color=Color(0.96,0.78,0.28,0.95)
	material.no_depth_test=true
	_snap_guide.material_override=material
	_snap_guide.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_snap_guide)
	_snap_guide.hide()
func _refresh_snap_guide(cell: Vector2i) -> void:
	_ensure_snap_guide()
	var guide_cell: Vector2i=_snap_origin if _painting else cell
	var show: bool=active() and snap_line and _brush_tool() and guide_cell!=Layout.NOWHERE and island.terrain.land_cells.has(guide_cell)
	if not show:
		_snap_guide.hide()
		return
	var origin:=_snap_origin if _painting else cell
	var axis:=_snap_axis if _painting and _snap_axis!="" else "row"
	var y:=cell_surface(origin)+.16
	var mesh:=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	if axis=="column":
		var min_z:=origin.y
		var max_z:=origin.y
		for sample in island.terrain.land_cells:
			if sample.x==origin.x:
				min_z=mini(min_z,sample.y)
				max_z=maxi(max_z,sample.y)
		mesh.surface_add_vertex(Vector3(origin.x+.5,y,min_z))
		mesh.surface_add_vertex(Vector3(origin.x+.5,y,max_z+1))
	elif axis=="diagonal":
		var far:=origin+_snap_diagonal*8
		mesh.surface_add_vertex(Vector3(origin.x+.5,y,origin.y+.5))
		mesh.surface_add_vertex(Vector3(far.x+.5,cell_surface(origin)+.16,far.y+.5))
	else:
		var min_x:=origin.x
		var max_x:=origin.x
		for sample in island.terrain.land_cells:
			if sample.y==origin.y:
				min_x=mini(min_x,sample.x)
				max_x=maxi(max_x,sample.x)
		mesh.surface_add_vertex(Vector3(min_x,y,origin.y+.5))
		mesh.surface_add_vertex(Vector3(max_x+1,y,origin.y+.5))
	mesh.surface_end()
	_snap_guide.mesh=mesh
	_snap_guide.show()
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
			if _brush_tool():begin_stroke(island.pick_cell_at(event.position))
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
	var authored: Array=[]
	var water: Array=[]
	for c in island.sim.cells_in_order:cells.append([c.x,c.y])
	for c in island.terrain.heights:authored.append([c.x,c.y,int(island.terrain.heights[c])])
	for c in island.terrain.water_cells:water.append([c.x,c.y])
	return {"version":3,"land":cells,"heights":authored,"water":water,"layout":layout.to_dict()}
func restore_snapshot(data: Variant) -> String:
	if not data is Dictionary or not Layout.integer(data.get("version")) or int(data.version) not in [1,2,3] or not data.get("land") is Array or not data.has("layout"):return "bad_save"
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
	var authored: Dictionary={}
	var saved_water: Dictionary={}
	if int(data.version)==3:
		if not data.get("heights") is Array or not data.get("water") is Array:return "bad_save"
		for row in data.heights:
			if not row is Array or row.size()!=3 or not Layout.integer(row[0]) or not Layout.integer(row[1]) or not Layout.integer(row[2]):return "bad_save"
			var level:=int(row[2])
			var height_cell:=Vector2i(int(row[0]),int(row[1]))
			if level<1 or level>island.terrain.MAX_LEVEL or not combined.has(height_cell) or authored.has(height_cell):return "bad_save"
			authored[height_cell]=level
		for row in data.water:
			if not Layout.valid_cell(row):return "bad_save"
			var water_cell:=Vector2i(int(row[0]),int(row[1]))
			if not combined.has(water_cell) or saved_water.has(water_cell):return "bad_save"
			saved_water[water_cell]=true
	for c in island.sim.occupied:
		if c not in cells:return "bad_save"
	if not combined.has(_player_cell()):return "player"
	var candidate=Layout.new()
	var water: Dictionary={}
	if int(data.version)==3:water=saved_water
	else:
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
	if int(data.version)==3:
		island.terrain.use_custom_water=true
		island.terrain.custom_water=saved_water.duplicate()
		island.terrain.heights=authored.duplicate()
		island.terrain.sculpted=true
	else:
		island.terrain.use_custom_water=false
		island.terrain.custom_water.clear()
		island.terrain.heights.clear()
		island.terrain.sculpted=false
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
	return {"ok":"已完成", "overlap":"占地被物件使用", "water":"不能放在水面上", "no_land":"需要完整陆地支撑", "reserved":"请避开泉眼、设施或云口", "entrance":"请留出小屋门前通路", "player":"请先让人物离开此处", "protected":"小屋可以搬迁，不能拆除", "missing":"请先选择物件", "empty":"空地", "bridge":"请保留桥梁及桥头的支撑地块", "already_land":"这里已有陆地", "not_adjacent":"新地块须与陆地边缘相邻", "area_cap":"已达到土地上限", "no_land_delete":"此处没有地块", "height_cap":"已经到最高台阶", "height_floor":"已经到最低台阶", "occupied":"地块上有固定设施", "seep_cap":"土地养护额度不足", "object_cap":"本轮物件上限为 128 个", "bad_save":"布局文件无效，当前庭院保持不变", "io_error":"无法写入布局文件", "no_save":"还没有保存的庭院布局"}.get(reason,"无法执行："+reason)
