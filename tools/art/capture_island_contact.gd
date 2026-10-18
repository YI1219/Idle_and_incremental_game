extends 'res://tools/art/capture_storybook_island.gd'
## One geometry/data source, existing plants/house: isolate vertex-color
## coverage against a continuous world-space material boundary.
func mark_actual_caps()->Dictionary:
 var surface=editor.renderer.contours.surfaces.sculpted_terrain
 var roofs:Dictionary={};var owned:=0
 for i in surface.vertices.size():
  var p:Vector3=surface.vertices[i];var cap:float=surface.uv[i].x
  if surface.uv[i].y>=0 or p.y>cap+.02 or p.y<cap-.40 or surface.normals[i].y<-.10:continue
  var at:=Vector2(p.x,p.z)
  if not roofs.has(at):roofs[at]=editor.data.rocks.height_at(at)
  var roof:float=roofs[at]
  if not is_finite(roof) or absf(roof-cap)>.03:continue
  surface.colors[i].b=1.0;owned+=1
 editor.renderer.contours._index_triangles()
 for chunk:Vector2i in editor.renderer.chunks:
  var instance:MeshInstance3D=editor.renderer.chunks[chunk].get_node_or_null('sculpted_terrain')
  if instance!=null:instance.mesh=editor.renderer.contours.build(chunk).sculpted_terrain
 return {'owned_vertex_occurrences':owned,'unique_roof_queries':roofs.size(),'criterion':'Real topmost field roof within.03m of dry cap; side band no deeper than.4m supplies interpolation. Fragment grass actual depth only.045–.12m. Not a new shell/geometry.'}
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-19/island_contact/'
 var styles:Array=['control','world_boundary']
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with('--styles='):styles=Array(arg.trim_prefix('--styles=').split(','))
  elif arg.begins_with('--output='):OUT=arg.trim_prefix('--output=')
 layout_kind='courtyard';quiet_backdrop=true
 DirAccess.make_dir_recursive_absolute(OUT)
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var reports:Dictionary={}
 for style:String in styles:
  editor=load('res://scenes/beautiful_island.tscn').instantiate();viewport.add_child(editor)
  editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
  editor.camera.reparent(editor,true)
  var before:Dictionary=editor.data.serialize()
  var surface=editor.renderer.contours.surfaces.sculpted_terrain
  var vertex_hash:=digest(surface.vertices.to_byte_array());var rule:Dictionary={}
  if style=='world_boundary':
   rule=mark_actual_caps()
   editor.renderer.materials.sculpted_terrain.shader=preload('res://tools/art/island_contact_finish.gdshader')
  elif style in ['rooted_rim','rooted_low']:rule=preload('res://tools/art/island_rim_grass.gd').apply(editor,style=='rooted_low')
  var props:Array=[]
  for entry:Dictionary in editor.renderer.props.entries:
   if entry.node.visible:props.append(str(entry.node.name))
  reports[style]={'vertex_sha256':vertex_hash,'triangles':surface.vertices.size()/3,'layout_sha256':JSON.stringify(before,'',true,true).sha256_text(),'props':props,'rule':rule,'art_accepted':false}
  await views(style)
  assert(vertex_hash==digest(surface.vertices.to_byte_array()) and before==editor.data.serialize())
  editor.queue_free();await process_frame
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'stages':reports,'captures':captures,'scope':'Matched native contact experiments: identical terrain vertices and saved data. World boundary changes material coverage; rooted styles add instances of the existing grass module. No extra terrain, production adoption or user art acceptance.'},'\t',true,true))
 print('NATIVE CONTACT STUDY: ',captures.size(),' frames');quit()
