extends CanvasLayer
var editor:Node3D
var panel:PanelContainer
var status:Label
var diagnostics:Label
const SAVE_PATH:="user://terrain_editor/layout.json"
func _ready()->void:
	var root:=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel=PanelContainer.new()
	panel.position=Vector2(18,18)
	panel.custom_minimum_size=Vector2(246,0)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("203b36ed")
	style.set_corner_radius_all(10)
	style.content_margin_left=16
	style.content_margin_right=16
	style.content_margin_top=16
	style.content_margin_bottom=16
	panel.add_theme_stylebox_override("panel",style)
	root.add_child(panel)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	panel.add_child(column)
	var title:=_label("FLOATING GARDEN",19)
	column.add_child(title)
	column.add_child(_label("Terrain workshop · low quality",12))
	column.add_child(HSeparator.new())
	var tools:=OptionButton.new()
	for name in ["Raise land","Lower land","Expand island","Contract island","Paint water","Remove water"]:tools.add_item(name)
	tools.item_selected.connect(func(index:int):editor.cancel_input();editor.tool=["raise","lower","expand","contract","water","dry"][index])
	column.add_child(tools)
	column.add_child(_label("Brush radius",12))
	var radius:=HSlider.new()
	radius.min_value=0.49
	radius.max_value=8
	radius.step=0.1
	radius.value=editor.radius
	radius.value_changed.connect(func(value:float):editor.radius=value)
	column.add_child(radius)
	var snap:=CheckButton.new()
	snap.text="Snap to cells"
	snap.button_pressed=editor.snap
	snap.toggled.connect(func(enabled:bool):editor.snap=enabled)
	column.add_child(snap)
	column.add_child(_label("Off: free brush position\nTerrain remains cell-based",11))
	column.add_child(_label("Expansion height",12))
	var height:=SpinBox.new()
	height.min_value=-4
	height.max_value=12
	height.step=0.5
	height.value=editor.build_height
	height.value_changed.connect(func(value:float):editor.build_height=value)
	column.add_child(height)
	var water:=OptionButton.new()
	for level in 8:water.add_item("Water %d  ·  height %.1f"%[level+1,level*0.5])
	water.select(editor.water_level)
	water.item_selected.connect(func(index:int):editor.water_level=index)
	column.add_child(water)
	var grid:=CheckButton.new()
	grid.text="Show editing grid"
	grid.toggled.connect(func(enabled:bool):editor.renderer.materials.grass.set_shader_parameter("show_grid",enabled))
	column.add_child(grid)
	var history:=HBoxContainer.new()
	_button(history,"Undo",func():editor.cancel_input();editor.data.undo())
	_button(history,"Redo",func():editor.cancel_input();editor.data.redo())
	column.add_child(history)
	var files:=HBoxContainer.new()
	_button(files,"Save",func():_file_status(editor.save_layout(SAVE_PATH),"Saved"))
	_button(files,"Load",func():_file_status(editor.load_layout(SAVE_PATH),"Loaded"))
	column.add_child(files)
	var preset:=OptionButton.new()
	for name in ["Terraces & ponds","Long island","Holes & meadow"]:preset.add_item(name)
	preset.item_selected.connect(func(index:int):editor.select_preset(index))
	column.add_child(preset)
	_button(column,"Reset selected layout",func():editor.select_preset(preset.selected))
	column.add_child(HSeparator.new())
	column.add_child(_label("Drag left: edit terrain\nWASD / arrows: horizontal pan\nMiddle drag: horizontal pan\nWheel: height & zoom\nHome: recenter · Ctrl+Z: undo",12))
	status=_label("All visible land is editable",11)
	column.add_child(status)
	diagnostics=_label("",11)
	column.add_child(diagnostics)
	update_diagnostics()
func _label(text:String,size:int)->Label:
	var label:=Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("eef2d8"))
	return label
func _button(parent:Node,text:String,action:Callable)->void:
	var button:=Button.new()
	button.text=text
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
func is_over_panel(screen:Vector2)->bool:
	return panel!=null and panel.get_global_rect().has_point(screen)
func _file_status(error:Error,success:String)->void:
	status.text=success+" layout" if error==OK else "Layout: "+error_string(error)
func update_diagnostics()->void:
	diagnostics.text="%d cells · %d chunks · %d pending\n%d FPS · edit %.2f ms\n%d draw calls"%[editor.data.cells.size(),editor.renderer.chunks.size(),editor.data.dirty_chunks.size(),Engine.get_frames_per_second(),editor.last_edit_ms,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
