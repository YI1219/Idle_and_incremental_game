extends 'res://scripts/terrain_editor/editor.gd'
## Reversible playable study; old workshop and its user save stay separate.
const CASES=['courtyard_7301','courtyard_7319','bay_7301','bay_7319']
const LABELS=['圆庭 · 种子 7301','圆庭 · 种子 7319','曲湾 · 种子 7301','曲湾 · 种子 7319']
const PREVIEW_SAVE='user://beautiful_island/layout.json'
var selected_case:=0
func _ready()->void:
 super._ready()
 renderer.contours=preload('res://scripts/terrain_editor/island_contours.gd').new()
 preload('res://scripts/terrain_editor/island_finish.gd').apply(self)
 hud.free();hud=preload('res://scripts/terrain_editor/island_hud.gd').new();hud.editor=self;add_child(hud)
 var pivot:=Node3D.new();pivot.name='CameraFocus';pivot.position.y=2.4;add_child(pivot)
 camera.reparent(pivot,false)
 select_preset(0)
func select_preset(kind:int)->void:
 if kind<0 or kind>=CASES.size():return
 cancel_input()
 var preset:Resource=load('res://assets/terrain_editor/island_presets/'+CASES[kind]+'.res')
 if preset==null or not data.deserialize(preset.layout):
  push_error('Cannot load island preset: '+CASES[kind]);return
 selected_case=kind
 renderer.rebuild_all()
 camera._center=Vector2(-11,-5);camera._center_goal=camera._center
 camera._height=16.2;camera.height_goal=16.2
 camera._yaw=16;camera._yaw_goal=16;camera._pitch=34;camera._pitch_goal=34
 camera.advance(0)
func save_layout(path:String)->Error:
 return super.save_layout(PREVIEW_SAVE if path=='user://terrain_editor/layout.json' else path)
func load_layout(path:String)->Error:
 return super.load_layout(PREVIEW_SAVE if path=='user://terrain_editor/layout.json' else path)
func _unhandled_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_HOME:
  camera.recenter(Vector2(-11,-5));get_viewport().set_input_as_handled()
 else:super._unhandled_input(event)
