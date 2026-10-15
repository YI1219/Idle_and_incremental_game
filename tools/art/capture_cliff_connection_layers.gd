extends "res://tests/capture_rim_round.gd"
## Isolate current crown/root/backing contributions at the actual rim camera.
func category(node:Node)->String:
 if node.name.begins_with('cliff_column'):return 'crown'
 if node.name.begins_with('underside_rock'):return 'root'
 if node.name=='stone_mantle':return 'mantle'
 if node.name=='cliff':return 'backing'
 return ''
func run()->void:
 var args:=OS.get_cmdline_user_args()
 var tag:='layers' if args.is_empty() else args[0]
 OUT='res://art/review/terrain_fidelity/2026-10-15/cliff_connection/'
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load('res://scenes/terrain_editor.tscn').instantiate();viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 frame(Vector2(-12,3),7,16,30)
 for layer:String in ['current','no_root','no_mantle','no_backing','no_crown_shadow','categories']:
  for chunk:Node in editor.renderer.chunks.values():
   for node:Node in chunk.get_children():
    var kind:=category(node)
    if kind=='':continue
    node.visible=not ((layer=='no_root' and kind=='root') or (layer=='no_mantle' and kind=='mantle') or (layer=='no_backing' and kind=='backing'))
    node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if layer=='no_crown_shadow' and kind=='crown' else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    if layer=='categories':
     var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
     material.albedo_color={'crown':Color(.8,.35,.15),'root':Color(.15,.4,.8),'mantle':Color(.6,.2,.65),'backing':Color(.17,.3,.27)}[kind]
     node.material_override=material
  await capture(tag+'_'+layer)
 FileAccess.open(OUT+tag+'_captures.json',FileAccess.WRITE).store_string(JSON.stringify(captures,'\t'));print('CLIFF CONNECTION LAYERS: ',captures.size());quit()
