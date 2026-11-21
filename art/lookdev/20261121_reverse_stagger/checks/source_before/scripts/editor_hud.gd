extends CanvasLayer
## Lightweight CanvasLayer host for ShihaiHUD (legacy debug slab retired).

var editor: Node3D
var panel: PanelContainer
var status: Label
var diagnostics: Label
var shihai_hud: Control
const SAVE_PATH := "user://terrain_editor/layout.json"

func _ready() -> void:
	panel = PanelContainer.new()
	panel.visible = false
	add_child(panel)
	status = Label.new()
	status.visible = false
	add_child(status)
	diagnostics = Label.new()
	diagnostics.visible = false
	add_child(diagnostics)

func bind_shihai_hud(hud_control: Control) -> void:
	shihai_hud = hud_control

func set_sculpt_panel_visible(_sculpt_visible: bool) -> void:
	if panel != null:
		panel.visible = false

func is_over_panel(screen: Vector2) -> bool:
	if not visible:
		return false
	if shihai_hud != null and shihai_hud.visible and shihai_hud.has_method("is_over_ui"):
		if bool(shihai_hud.call("is_over_ui", screen)):
			return true
	return false

func update_diagnostics() -> void:
	pass
