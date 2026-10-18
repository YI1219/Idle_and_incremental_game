extends 'res://scripts/terrain_editor/editor_hud.gd'
## Compact study controls, all essential actions visible at 1280x720.
func _ready()->void:
 var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var font:FontFile=preload('res://assets/fonts/YunluUI-Regular.ttf')
 font.allow_system_fallback=false
 var theme:=Theme.new();theme.default_font=font;root.theme=theme
 root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
 panel=PanelContainer.new();panel.position=Vector2(16,16);panel.custom_minimum_size=Vector2(232,0)
 var style:=StyleBoxFlat.new();style.bg_color=Color('203b36ed');style.set_corner_radius_all(10)
 style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=14;style.content_margin_bottom=14
 panel.add_theme_stylebox_override('panel',style);root.add_child(panel)
 var column:=VBoxContainer.new();column.add_theme_constant_override('separation',8);panel.add_child(column)
 column.add_child(_label('浮庭 · 美术试作',19))
 column.add_child(_label('同一片可塑形地形 · 独立存档',12))
 var presets:=OptionButton.new();presets.name='TerrainPresets'
 for label:String in editor.LABELS:presets.add_item(label)
 presets.item_selected.connect(func(index:int):editor.select_preset(index));column.add_child(presets)
 column.add_child(HSeparator.new())
 var tools:=OptionButton.new();tools.name='TerrainTools'
 for label:String in ['抬高地表','降低地表','放置土地','移除土地','绘制水面','移除水面','塑形 · 增加岩体','塑形 · 削去岩体','塑形 · 切出平面','塑形 · 隆起岩面','塑形 · 局部柔化','塑形 · 棱面切削']:tools.add_item(label)
 tools.select(7);editor.tool='rock_cut'
 column.add_child(tools)
 var radius:=HSlider.new();radius.name='BrushRadius';radius.min_value=.49;radius.max_value=4;radius.step=.1;radius.value=editor.radius
 radius.value_changed.connect(func(value:float):editor.radius=value)
 column.add_child(_label('笔刷大小',12));column.add_child(radius)
 tools.item_selected.connect(func(index:int):
  editor.cancel_input()
  editor.tool=['raise','lower','expand','contract','water','dry','rock_add','rock_cut','rock_plane','rock_shoulder','rock_smooth','rock_cleave'][index])
 var levels:=HBoxContainer.new();levels.add_child(_label('放置高度',12))
 var height:=SpinBox.new();height.min_value=-4;height.max_value=12;height.step=.5;height.value=editor.build_height
 height.value_changed.connect(func(value:float):editor.build_height=value);levels.add_child(height);column.add_child(levels)
 var history:=HBoxContainer.new();_button(history,'撤销',func():editor.cancel_input();editor.data.undo());_button(history,'重做',func():editor.cancel_input();editor.data.redo());column.add_child(history)
 var files:=HBoxContainer.new();_button(files,'保存试作',func():_file_status(editor.save_layout(SAVE_PATH),'Saved'));_button(files,'读取试作',func():_file_status(editor.load_layout(SAVE_PATH),'Loaded'));column.add_child(files)
 _button(column,'重置当前岛形',func():editor.select_preset(presets.selected))
 var grid:=CheckButton.new();grid.text='显示编辑网格';grid.toggled.connect(func(enabled:bool):editor.renderer.materials.sculpted_terrain.set_shader_parameter('show_grid',enabled));column.add_child(grid)
 column.add_child(HSeparator.new())
 column.add_child(_label('左键拖动：编辑\n右键拖动 / Q E：环绕\nWASD / 中键：平移\n滚轮：缩放 · Home：回中\nCtrl+Z：撤销',12))
 status=_label('新候选 · 美术尚未验收',11);column.add_child(status)
 diagnostics=_label('',11);column.add_child(diagnostics);update_diagnostics()
func _file_status(error:Error,success:String)->void:
 status.text=('已保存试作' if success=='Saved' else '已读取试作') if error==OK else '存档操作失败：'+error_string(error)
