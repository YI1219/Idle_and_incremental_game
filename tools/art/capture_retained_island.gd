extends 'res://tools/art/capture_storybook_island.gd'
var WORK:='res://art/work/retained_island/2026-10-18/'
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/beautiful_island/retained_union/'
 layout_kind='courtyard';quiet_backdrop=true
 var styles:Array=['retained_source','retained_union','retained_union_soft']
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with('--input='):WORK=arg.trim_prefix('--input=')
  elif arg.begins_with('--output='):OUT=arg.trim_prefix('--output=')
  elif arg=='--turf':styles=['retained_union_turf']
 DirAccess.make_dir_recursive_absolute(OUT)
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var reports:Dictionary={}
 for style:String in styles:
  editor=load('res://scenes/terrain_editor.tscn').instantiate();viewport.add_child(editor)
  editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
  var file:='control.layout' if style=='retained_source' else 'candidate.layout'
  var payload:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK+file))
  assert(editor.data.deserialize(payload))
  if style=='retained_source':assert(editor.data.set_sculpt_base(false))
  var saved_before:Dictionary=editor.data.serialize()
  var stock:ShaderMaterial=editor.renderer.materials.sculpted_terrain
  retained_finish()
  # Same existing mineral shading family as source crowns, not the invented
  # smooth-body shader from previous art trials. Reassign after finish helper.
  editor.renderer.materials.sculpted_terrain=stock
  stock.set_shader_parameter('stone_mineral_map',painted_map())
  stock.set_shader_parameter('stone_relief_strength',.03)
  for chunk:Vector2i in editor.renderer.chunks:
   var instance:MeshInstance3D=editor.renderer.chunks[chunk].get_node_or_null('sculpted_terrain')
   if instance!=null:instance.material_override=stock
  backdrop()
  var normal_report:Dictionary={}
  if style=='retained_union_soft':normal_report=smooth_style_normals()
  if style=='retained_union_turf':
   normal_report=preload('res://tools/art/actual_top_turf.gd').apply(editor.renderer.contours,editor.data.rocks)
   for chunk:Vector2i in editor.renderer.chunks:
    var instance:MeshInstance3D=editor.renderer.chunks[chunk].get_node_or_null('sculpted_terrain')
    if instance!=null:instance.mesh=editor.renderer.contours.build(chunk).sculpted_terrain
  for spec in [['water','water_time'],['lake_bed','caustic_time'],['waterfall','flow_time'],['bank','foam_time']]:editor.renderer.materials[spec[0]].set_shader_parameter(spec[1],1.25)
  var props:Array=[]
  for entry:Dictionary in editor.renderer.props.entries:
   if entry.node.visible:props.append(str(entry.node.name))
  var report:Dictionary={'style':style,'input':WORK+file,'saved_version':editor.data.serialize().version,'cells':editor.data.cells.size(),'cell_sha256':JSON.stringify(editor.data.serialize().cells).sha256_text(),'visible_props':props,'ordinary_data_loader':true,'density_records':editor.data.rocks.samples.size(),'normal_report':normal_report,'source_draws':editor.renderer.decoration._columns.size(),'art_accepted':false}
  if style!='retained_source':
   var surface=editor.renderer.contours.surfaces.sculpted_terrain
   var points:PackedVector3Array=surface.vertices
   FileAccess.open(WORK+style+'.bin',FileAccess.WRITE).store_buffer(points.to_byte_array())
   report['triangles']=points.size()/3;report['mesh_vertex_sha256']=digest(points.to_byte_array())
   FileAccess.open(WORK+'native.layout',FileAccess.WRITE).store_string(JSON.stringify(editor.data.serialize(),'\t',true,true))
  await views(style)
  assert(saved_before==editor.data.serialize())
  reports[style]=report;print('RETAINED NATIVE: ',report)
  editor.queue_free();await process_frame
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'captures':captures,'stages':reports,'adapter':RenderingServer.get_video_adapter_name(),'renderer':RenderingServer.get_current_rendering_method(),'scope':'Actual source draw versus ordinary v4scalar union, same native scene/cameras/material family. Soft case changes normals only. Fresh geometry/support/history/editor checks and user art acceptance still required.'},'\t'))
 print('RETAINED ISLAND CAPTURES: ',captures.size());quit()
