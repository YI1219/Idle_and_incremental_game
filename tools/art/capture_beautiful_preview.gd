extends 'res://tools/art/capture_storybook_island.gd'
const WORK='res://art/work/retained_island/2026-10-18/'
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/beautiful_island/playable/'
 layout_kind='courtyard';quiet_backdrop=true
 var styles:Array=['courtyard_7301','courtyard_7319','bay_7301','bay_7319']
 for arg:String in OS.get_cmdline_user_args():
  if arg=='--whole-only':whole_only=true
  elif arg.begins_with('--cases='):styles=Array(arg.trim_prefix('--cases=').split(','))
  elif arg.begins_with('--output='):OUT=arg.trim_prefix('--output=')
 DirAccess.make_dir_recursive_absolute(OUT)
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var reports:Dictionary={}
 var start:=Time.get_ticks_msec()
 editor=load('res://scenes/beautiful_island.tscn').instantiate();viewport.add_child(editor)
 var startup_ms:=Time.get_ticks_msec()-start
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false);editor.renderer.animate_edits=false
 # The live camera uses a Y-focus pivot; fixed review cameras are global,
 # exactly as the control capture. Remove only that capture-time parenting.
 editor.camera.reparent(editor,true)
 for style:String in styles:
  var index:int=editor.CASES.find(style);assert(index>=0)
  start=Time.get_ticks_msec();editor.select_preset(index)
  var load_ms:=Time.get_ticks_msec()-start
  var before:Dictionary=editor.data.serialize()
  var points:PackedVector3Array=editor.renderer.contours.surfaces.sculpted_terrain.vertices
  var source_folder:String=WORK if index==0 else WORK+style+'/'
  DirAccess.make_dir_recursive_absolute(source_folder+'output_geometry')
  FileAccess.open(source_folder+'output_geometry/playable.bin',FileAccess.WRITE).store_buffer(points.to_byte_array())
  var props:Array=[]
  for entry:Dictionary in editor.renderer.props.entries:
   if entry.node.visible:props.append(str(entry.node.name))
  await views(style)
  for warm in 30:await process_frame
  var timings:Array=[]
  for frame in 120:
   var tick:=Time.get_ticks_usec();await process_frame
   timings.append((Time.get_ticks_usec()-tick)/1000.0)
  timings.sort()
  assert(editor.data.serialize()==before)
  reports[style]={'seed':editor.data.seed,'cells':editor.data.cells.size(),'density_records':editor.data.rocks.samples.size(),'ordinary_version':before.version,'major_props':props,'source_draws':editor.renderer.decoration._columns.size(),'triangles':points.size()/3,'vertex_sha256':digest(points.to_byte_array()),'cover':editor.renderer.contours.cover_report,'load_rebuild_ms':load_ms,'frame_ms_median':timings[60],'frame_ms_p95':timings[114],'frame_sample_count':120,'global_render_draw_calls':Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),'art_accepted':false}
  print('PLAYABLE NATIVE: ',style,' ',reports[style])
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'stages':reports,'captures':captures,'startup_ms':startup_ms,'adapter':RenderingServer.get_video_adapter_name(),'renderer':RenderingServer.get_current_rendering_method(),'processor':OS.get_processor_name(),'os':OS.get_name(),'resolution':[1671,941],'msaa':'4X','vsync_mode':DisplayServer.window_get_vsync_mode(),'performance_scope':'Development-machine native 1671x941SubViewport; elapsed frame samples include synchronization and app scheduling. Not target hardware/power/long-idle performance. Editing latency and complete support checks separate.','scope':'Actual separately launchable ordinary-data editor candidate; source props removed. Four fixed contour/seed cases, five matched cameras. Current visual study, no user art acceptance.'},'\t',true,true))
 editor.queue_free();await process_frame;print('PLAYABLE CAPTURES: ',captures.size());quit()
