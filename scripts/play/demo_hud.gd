extends CanvasLayer
var status: Label
var hint: Label
var action: Label
func _ready() -> void:
	layer=10
	var root:=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var title:=_label(root,Vector2(30,24),28)
	title.text="识海 · 云庭"
	status=_label(root,Vector2(32,63),15)
	action=_label(root,Vector2(32,100),15)
	hint=_label(root,Vector2.ZERO,15)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left=30
	hint.offset_top=-58
	hint.offset_right=1230
	hint.offset_bottom=-28
	hint.text="WASD 行走    J / 左键 挥剑    K / 右键 拆招    空格 闪避    Q / E 转镜头    滚轮 缩放    B 营造    Esc 暂停"
func _label(parent: Node,at: Vector2,size: int) -> Label:
	var label:=Label.new()
	label.position=at
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("f4eee0"))
	label.add_theme_color_override("font_shadow_color",Color(0.08,.16,.16,.8))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
func _process(_delta: float) -> void:
	var player:=get_tree().get_first_node_in_group("player")
	var arena:=get_tree().get_first_node_in_group("combat_arena")
	var island:=get_tree().get_first_node_in_group("island_shell")
	var location: String="洞天小屋" if SpaceState.is_inside() else ("云外探幽" if SpaceState.is_exploring() else "初见云庭")
	status.text=location+"  /  基础试玩"
	if island and island.sim:
		status.text+="    灵泉 %.0f    药草 %d" % [island.sim.total_pool(),island.sim.craft.total_herbs()]
	if SpaceState.is_courtyard() and arena and player:
		action.text="气血 %.0f  护体 %.0f  身法 %d/2    %s" % [player.ward_state.health,player.ward_state.ward,player.actions.charges,arena.notice]
	elif SpaceState.is_inside():
		action.text="回到南侧门口即可离屋"
	else:
		action.text="左路拾取，右路观察；走回入口撤离，7 收进行囊"
	hint.text="WASD 行走    J / 左键 挥剑    K / 右键 拆招    空格 闪避    Q / E 转镜头    滚轮 缩放    B 营造    Esc 暂停"
	if island and island.build_mode and SpaceState.is_courtyard():
		hint.text="左键 放置 / 选择    右键 取消    中键拖动 视野    Q / E 转镜头    滚轮 缩放    B 完成营造"
		action.text="营造中 · 右侧选择物件，左键放置，右键取消，B 结束"
