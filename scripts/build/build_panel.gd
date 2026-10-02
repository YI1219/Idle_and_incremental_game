extends CanvasLayer
var builder: Node3D
var surface: PanelContainer
var title: Label
var area: Label
var status: Label
var feedback: Label
var move_button: Button
var remove_button: Button
var buttons: Dictionary={}
func _ready() -> void:
	layer=25
	var panel:=PanelContainer.new()
	surface=panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left=-294
	panel.offset_right=-20
	panel.offset_top=118
	panel.offset_bottom=760
	var paper:=StyleBoxFlat.new()
	paper.bg_color=Color("eee9da")
	paper.border_color=Color("9daea2")
	paper.set_border_width_all(1)
	paper.set_corner_radius_all(8)
	paper.content_margin_left=18
	paper.content_margin_right=18
	paper.content_margin_top=16
	paper.content_margin_bottom=16
	panel.add_theme_stylebox_override("panel",paper)
	add_child(panel)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	panel.add_child(column)
	title=_label(column,"庭院营造",23)
	_label(column,"布置草木 · 安放山石 · 搬迁小屋",13)
	buttons["select"]=_button(column,"选择 / 搬移",func():builder.choose("select"))
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",7)
	column.add_child(grid)
	for item in [["tree","乔木"],["rock","山石"],["bush","灌木"],["grass","草丛"],["land","铺设陆地"],["erase_land","收回陆地"],["raise","抬升"],["lower","下压"],["flatten","平整"],["smooth","平滑"]]:
		var key: String=item[0]
		buttons[key]=_button(grid,item[1],func():builder.choose(key))
	area=_label(column,"",13)
	status=_label(column,"",15)
	status.custom_minimum_size.y=30
	var actions:=HBoxContainer.new()
	column.add_child(actions)
	move_button=_button(actions,"搬移",func():builder.start_move())
	remove_button=_button(actions,"移除",func():builder.remove_selected())
	feedback=_label(column,"",14)
	feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size=Vector2(235,62)
	var saves:=HBoxContainer.new()
	column.add_child(saves)
	_button(saves,"保存布局",func():
		var result: String=builder.save_layout()
		builder.notice="布局已保存" if result=="ok" else builder.explain(result))
	_button(saves,"读取布局",func():
		var result: String=builder.load_layout()
		builder.notice="已读取上次保存的布局" if result=="ok" else builder.explain(result))
	_label(column,"布局仅保存摆放与土地，不回退资源。",12)
	_label(column,"按住左键拖动铺地 / 收地 / 塑形\nAlt 自由高度 · [ ] 半径 · 右键取消 · B 完成",13)
	_label(column,"草木试摆暂不收费；泉眼与生产设施保留。",12)
	_button(column,"完成营造",func():builder.set_active(false))
func _label(parent: Node,text: String,size: int) -> Label:
	var label:=Label.new()
	label.text=text
	label.add_theme_color_override("font_color",Color("354b46"))
	label.add_theme_font_size_override("font_size",size)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
func _button(parent: Node,text: String,action: Callable) -> Button:
	var button:=Button.new()
	button.text=text
	button.custom_minimum_size=Vector2(112,35)
	button.focus_mode=Control.FOCUS_NONE
	var normal:=StyleBoxFlat.new()
	normal.bg_color=Color("dddccd")
	normal.set_corner_radius_all(4)
	var hover:=normal.duplicate()
	hover.bg_color=Color("b9d0c3")
	button.add_theme_stylebox_override("normal",normal)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",hover)
	button.add_theme_color_override("font_color",Color("284b43"))
	button.add_theme_color_override("font_hover_color",Color("173f34"))
	button.add_theme_color_override("font_pressed_color",Color("173f34"))
	button.add_theme_font_size_override("font_size",15)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
func refresh() -> void:
	var xirang_points:=0.0
	if builder.island.sim.xirang:xirang_points=builder.island.sim.xirang.points
	area.text="土地 %d / %d 格\n息壤 %.1f" % [builder.island.sim.cell_count(),int(builder.island.sim.cfg.land().hard_area_cap),xirang_points]
	var row: Dictionary=builder.layout.find(builder.selected)
	status.text="已选："+builder.Layout.CATALOG[row.kind].label if not row.is_empty() else "选中物件后可搬移或移除"
	move_button.disabled=row.is_empty() or builder.moving>=0
	remove_button.disabled=row.is_empty() or builder.selected==0 or builder.moving>=0
	var allowed: String={"land":"可以铺设","erase_land":"可以收回","raise":"抬升地形","lower":"下压或挖穿","flatten":"平整到台地","smooth":"平滑"}.get(builder.tool,"可以放置")
	var hint: String="点击占地选择物件" if builder.tool=="select" else (allowed if builder.hover_reason=="ok" else builder.explain(builder.hover_reason))
	feedback.text=builder.notice+"\n"+hint
	for key in buttons:
		buttons[key].modulate=Color("82bda7") if key==builder.tool else Color.WHITE

func contains_point(point: Vector2) -> bool:
	return visible and surface.get_global_rect().has_point(point)
