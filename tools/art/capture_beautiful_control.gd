extends 'res://tools/art/capture_storybook_island.gd'
const WORK='res://art/work/retained_island/2026-10-18/'
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/beautiful_island/playable/control/'
 layout_kind='courtyard';quiet_backdrop=true
 DirAccess.make_dir_recursive_absolute(OUT)
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var reports:Dictionary={}
 for case:String in ['courtyard_7301','courtyard_7319','bay_7301','bay_7319']:
  var folder:String=WORK if case=='courtyard_7301' else WORK+case+'/'
  editor=load('res://scenes/terrain_editor.tscn').instantiate();viewport.add_child(editor)
  editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
  var payload:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+'control.layout'))
  assert(editor.data.deserialize(payload) and editor.data.set_sculpt_base(false))
  editor.renderer.rebuild_all();backdrop()
  var props:Array=[]
  for entry:Dictionary in editor.renderer.props.entries:
   if entry.node.visible:props.append(str(entry.node.name))
  reports[case]={'seed':editor.data.seed,'cells':editor.data.cells.size(),'cell_sha256':JSON.stringify(editor.data.serialize().cells).sha256_text(),'major_props':props,'source_draws':editor.renderer.decoration._columns.size(),'scope':'Same authored contour/seed with current original stock rendering and source crowns. Quiet backdrop shared for comparison; this is a compact fixture, not the full formal default island.'}
  await views(case)
  editor.queue_free();await process_frame
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'stages':reports,'captures':captures},'\t',true,true))
 print('CURRENT CONTROL CAPTURES: ',captures.size());quit()
