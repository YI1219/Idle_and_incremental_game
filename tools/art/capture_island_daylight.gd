extends 'res://tools/art/capture_storybook_island.gd'
## One bounded coordinated palette/light study; all terrain/prop buffers fixed.
func photo(target:Vector3,distance:float,yaw:float,pitch:float)->void:
 super.photo(target-Vector3.UP*2.0,distance,yaw,pitch)
func daylight()->Dictionary:
 var surface:ShaderMaterial=editor.renderer.materials.sculpted_terrain
 surface.shader=preload('res://tools/art/island_daylight_finish.gdshader')
 var base:=Color('78a85c').srgb_to_linear();var high:=Color('a9c57b').srgb_to_linear()
 for material in editor.renderer.materials.values():
  if material is ShaderMaterial:
   material.set_shader_parameter('grass_base',Vector3(base.r,base.g,base.b))
   material.set_shader_parameter('grass_highlight',Vector3(high.r,high.g,high.b))
 for node:Node in editor.get_children():
  if node is DirectionalLight3D and node.shadow_enabled:
   node.light_color=Color('fff4dd');node.light_energy=1.05;node.light_angular_distance=3.5;node.shadow_opacity=.86
  elif node is WorldEnvironment:
   node.environment.ambient_light_color=Color('c0d2e4');node.environment.ambient_light_energy=.64
   node.environment.ssao_intensity=1.1;node.environment.ssao_power=1.25
 var bounce:=DirectionalLight3D.new();bounce.name='SoftSkyBounce'
 bounce.rotation_degrees=Vector3(45,15,0);bounce.light_color=Color('c5d7e3');bounce.light_energy=.20;bounce.shadow_enabled=false;bounce.light_specular=0
 editor.add_child(bounce)
 return {'rule':'daylight1','grass_srgb':['78a85c','a9c57b'],'sun_srgb':'fff4dd','sun_energy':1.05,'ambient_srgb':'c0d2e4','ambient_energy':.64,'underside_bounce_srgb':'c5d7e3','underside_bounce_energy':.20,'scope':'Coordinated full-scene finish study, not single-variable isolation or shipped-game algorithm claim. No geometry, data, view or prop-placement change.'}
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-19/island_daylight/'
 if FileAccess.file_exists(OUT+'captures.json'):push_error('Preserve daylight evidence');quit(1);return
 layout_kind='courtyard';quiet_backdrop=true
 DirAccess.make_dir_recursive_absolute(OUT)
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var reports:Dictionary={}
 for style:String in ['control','daylight']:
  editor=load('res://scenes/beautiful_island.tscn').instantiate();viewport.add_child(editor)
  editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false);editor.camera.reparent(editor,true)
  var payload:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://art/work/retained_island/2026-10-19/proportion/shallow.layout'))
  assert(editor.data.deserialize(payload));editor.renderer.rebuild_all()
  var before:Dictionary=editor.data.serialize()
  var surface=editor.renderer.contours.surfaces.sculpted_terrain
  var hash:=digest(surface.vertices.to_byte_array());var rule:Dictionary={}
  if style=='daylight':rule=daylight()
  var props:Array=[]
  for entry:Dictionary in editor.renderer.props.entries:
   if entry.node.visible:props.append(str(entry.node.name))
  reports[style]={'rule':rule,'vertex_sha256':hash,'layout_sha256':JSON.stringify(before,'',true,true).sha256_text(),'triangles':surface.vertices.size()/3,'props':props,'art_accepted':false}
  await views(style)
  assert(hash==digest(surface.vertices.to_byte_array()) and before==editor.data.serialize())
  editor.queue_free();await process_frame
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'stages':reports,'captures':captures,'scope':'Exact same shallow terrain vertices/data/major props and five global cameras. Native coordinated grass/rock palette and lighting comparison. Tools-only, no adoption/user art acceptance.'},'\t',true,true))
 print('NATIVE DAYLIGHT STUDY: ',captures.size(),' frames');quit()
