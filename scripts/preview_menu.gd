extends CanvasLayer
## Esc overlay for the doorway shell. No save, no game systems.

var _panel: Control


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("preview_menu")
	hide()
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.06, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(shade)
	var col := VBoxContainer.new()
	col.position = Vector2(48, 48)
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	var title := Label.new()
	title.text = "Yunlu Village"
	title.add_theme_font_size_override("font_size", 28)
	col.add_child(title)
	_button(col, "Continue", resume)
	_button(col, "Quit", func() -> void: get_tree().quit())


func _button(parent: Node, caption: String, action: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(180, 40)
	b.pressed.connect(action)
	parent.add_child(b)


func is_open() -> bool:
	return visible


func resume() -> void:
	hide()
	get_tree().paused = false


func open_menu() -> void:
	show()
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if visible:
			resume()
		else:
			open_menu()
		get_viewport().set_input_as_handled()
