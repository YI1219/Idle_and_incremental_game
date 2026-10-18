extends 'res://tests/capture_rim_round.gd'
const StyledBase=preload('res://tools/art/storybook_island_field.gd')
var recipes:Dictionary={}
var whole_only:=false
var layout_kind:='original'
var quiet_backdrop:=false
var painted_texture:Texture2D
func painted_map()->Texture2D:
 if painted_texture==null:
  var image:=Image.load_from_file(ProjectSettings.globalize_path('res://assets/textures/terrain/stone_painted_v1.png'))
  assert(image!=null);image.generate_mipmaps();painted_texture=ImageTexture.create_from_image(image)
 return painted_texture
func retained_finish()->void:
 finish('retained_painted')
 var count:=0;var seen:Dictionary={}
 for material in editor.renderer.materials.values():
  if material is ShaderMaterial:
   material.set_shader_parameter('stone_mineral_map',painted_map())
   material.set_shader_parameter('stone_relief_strength',.03)
 for kind:String in editor.renderer.decoration.assets:
  for part:Dictionary in editor.renderer.decoration.assets[kind]:
   for key:String in ['mesh','render_mesh']:
    if not part.has(key):continue
    var mesh:Mesh=part[key]
    if seen.has(mesh):continue
    seen[mesh]=true
    for surface_index in mesh.get_surface_count():
     var old:Material=mesh.surface_get_material(surface_index)
     if old is ShaderMaterial:
      var material:ShaderMaterial=old.duplicate()
      material.set_shader_parameter('stone_mineral_map',painted_map())
      material.set_shader_parameter('stone_relief_strength',.03)
      mesh.surface_set_material(surface_index,material);count+=1
   if kind=='tree':
    var original:PackedVector3Array=part.mesh.get_faces()
    part.mesh=preload('res://scripts/terrain_editor/stone_normals.gd').soften(part.mesh,130.0,1.0)
    assert(original.to_byte_array()==part.mesh.get_faces().to_byte_array())
 editor.renderer.rebuild_all()
 print('RETAINED FINISH: mapped materials=',count,'; existing tree vertex bytes preserved, normals softened')
func digest(bytes:PackedByteArray)->String:
 var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func finish(style:String)->void:
 var surface:=ShaderMaterial.new()
 surface.shader=preload('res://tools/art/storybook_island_finish.gdshader')
 preload('res://scripts/terrain_editor/material_detail.gd').bind(surface)
 var palettes:Dictionary={
  'soft':[Color('a0a58d'),Color('6f8584'),Color('6f8656'),Color('9ca771')],
  'graphic':[Color('8c9e9c'),Color('617d85'),Color('79895a'),Color('a5ad76')],
  'terraced':[Color('b5a68a'),Color('8c9082'),Color('718c63'),Color('a3b47d')],
  'cumulus':[Color('9ba59b'),Color('6c8686'),Color('67865c'),Color('9eae79')],
  'cumulus_facets':[Color('81918a'),Color('526f78'),Color('67865c'),Color('9eae79')],
  'polyrock':[Color('8a9992'),Color('526e76'),Color('67865c'),Color('9eae79')],
  'polyrock_planes':[Color('8a9992'),Color('526e76'),Color('67865c'),Color('9eae79')],
  'polyrock_painted':[Color('8a9992'),Color('526e76'),Color('67865c'),Color('9eae79')],
  'retained_painted':[Color('8a9992'),Color('526e76'),Color('67865c'),Color('9eae79')]}
 var palette:Array=palettes[style]
 var lawn_base:Color=palette[2].srgb_to_linear()
 var lawn_high:Color=palette[3].srgb_to_linear()
 surface.set_shader_parameter('stone_tint',palette[0]);surface.set_shader_parameter('lower_tint',palette[1])
 surface.set_shader_parameter('grass_base',Vector3(lawn_base.r,lawn_base.g,lawn_base.b))
 surface.set_shader_parameter('grass_highlight',Vector3(lawn_high.r,lawn_high.g,lawn_high.b))
 surface.set_shader_parameter('layer_style',1.0 if style=='terraced' else 0.0)
 surface.set_shader_parameter('painted_rock_strength',.38 if style in ['cumulus_facets','polyrock','polyrock_planes'] else 0.0)
 surface.set_shader_parameter('facet_tone_strength',.12 if style=='polyrock_planes' else 0.0)
 if style=='polyrock_painted':
  surface.set_shader_parameter('stone_mineral_map',painted_map())
  surface.set_shader_parameter('painted_albedo_strength',.72)
 editor.renderer.materials.sculpted_terrain=surface
 editor.renderer.materials.rim_green.set_shader_parameter('grass_base',Vector3(lawn_base.r,lawn_base.g,lawn_base.b))
 editor.renderer.materials.rim_green.set_shader_parameter('grass_highlight',Vector3(lawn_high.r,lawn_high.g,lawn_high.b))
 # Keep original direction/scene, soften dominant cliff shadow to match this
 # deliberately matte, low-detail terrain rather than adding dramatic grading.
 for node:Node in editor.get_children():
  if node is DirectionalLight3D and node.shadow_enabled:
   node.light_angular_distance=3.2;node.shadow_opacity=.82
  if node is WorldEnvironment:
   node.environment.ssao_intensity=.9;node.environment.ssao_power=1.2
func apply_layout()->void:
 if layout_kind=='original':return
 assert(layout_kind=='courtyard')
 var records:Dictionary={}
 for z in range(-13,3):
  for x in range(-19,-3):
   var q:=(Vector2(x+.5,z+.5)-Vector2(-11,-5))/Vector2(7.3,6.4)
   if q.length_squared()>.98+.07*sin(float(x)*.8+float(z)*.5):continue
   records[Vector2i(x,z)]={'height':3.5,'water':-1}
 editor.data.cells.assign(records);editor.data.revision+=1
 editor.renderer.rebuild_all()
func backdrop()->void:
 if not quiet_backdrop:return
 editor.landscape.hide()
 for node:Node in editor.get_children():
  if node is WorldEnvironment:
   node.environment.background_mode=Environment.BG_COLOR
   node.environment.background_color=Color('a7bfc0')
   node.environment.fog_enabled=false;node.environment.glow_enabled=false
func smooth_style_normals(principal:bool=false)->Dictionary:
 var surface=editor.renderer.contours.surfaces.sculpted_terrain
 var before:=digest(surface.vertices.to_byte_array())
 var nodes:Dictionary={};var points:Dictionary={}
 var volume=editor.data.rocks
 for i in surface.vertices.size():
  var p:Vector3=surface.vertices[i]
  if not points.has(p):
   var q:=p/.25;var key:=Vector3i(q.floor());var f:=q-Vector3(key)
   var axes:Array[int]=[0,1,2];axes.sort_custom(func(a:int,b:int):return f[a]>f[b])
   var first:=key;first[axes[0]]+=1
   var second:=first;second[axes[1]]+=1
   for node:Vector3i in [key,first,second,key+Vector3i.ONE]:
    if not nodes.has(node):nodes[node]=volume.gradient(node)
   points[p]=((nodes[key] as Vector3)*(1.0-f[axes[0]])+(nodes[first] as Vector3)*(f[axes[0]]-f[axes[1]])+(nodes[second] as Vector3)*(f[axes[1]]-f[axes[2]])+(nodes[key+Vector3i.ONE] as Vector3)*f[axes[2]]).normalized()
  surface.normals[i]=volume.base.principal_normal(p) if principal else points[p]
 editor.renderer.contours._index_triangles()
 for chunk:Vector2i in editor.renderer.chunks:
  var instance:MeshInstance3D=editor.renderer.chunks[chunk].get_node_or_null('sculpted_terrain')
  if instance!=null:instance.mesh=editor.renderer.contours.build(chunk).sculpted_terrain
 assert(before==digest(surface.vertices.to_byte_array()))
 return {'same_vertex_bytes':true,'normal_occurrences':surface.normals.size(),'unique_points':points.size(),'method':'Active3Dprincipal plane normal constraints, same geometry' if principal else 'Tetrahedrally interpolated authoritative-field gradients for intentionally smooth sculptural finish.'}
func photo(target:Vector3,distance:float,yaw:float,pitch:float)->void:
 var a:=deg_to_rad(yaw);var b:=deg_to_rad(pitch)
 editor.camera.position=target+Vector3(sin(a)*cos(b),sin(b),cos(a)*cos(b))*distance
 editor.camera.look_at(target)
func views(tag:String)->void:
 if layout_kind=='courtyard':
  photo(Vector3(-11,2.4,-5),29,16,34);await capture(tag+'_whole')
  if whole_only:return
  photo(Vector3(-11,3.8,-6),20,16,35);await capture(tag+'_play')
  photo(Vector3(-12,2.5,0),13,16,25);await capture(tag+'_close')
  photo(Vector3(-11,2.4,-5),27,196,32);await capture(tag+'_reverse')
  photo(Vector3(-11,1,-5),26,36,5);await capture(tag+'_low')
  return
 frame(Vector2(-2,-1),32,16,30);await capture(tag+'_whole')
 if whole_only:return
 frame(Vector2(-10,-5),13,16,30);await capture(tag+'_play')
 frame(Vector2(-13,2),8,16,30);await capture(tag+'_close')
 editor.camera.position=Vector3(-31,8,-20);editor.camera.look_at(Vector3(-7,2,-3));await capture(tag+'_reverse')
 editor.camera.position=Vector3(24,-4,22);editor.camera.look_at(Vector3(4,1,2));await capture(tag+'_low')
func run():
 OUT='res://art/review/terrain_fidelity/2026-10-18/beautiful_island/'
 var styles:Array=['control','soft','graphic','terraced']
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with('--styles='):styles=Array(arg.trim_prefix('--styles=').split(','))
  elif arg.begins_with('--output='):OUT=arg.trim_prefix('--output=')
  elif arg=='--whole-only':whole_only=true
  elif arg.begins_with('--layout='):layout_kind=arg.trim_prefix('--layout=')
  elif arg=='--quiet-backdrop':quiet_backdrop=true
 DirAccess.make_dir_recursive_absolute(OUT)
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 for style:String in styles:
  editor=load('res://scenes/terrain_editor.tscn').instantiate();viewport.add_child(editor)
  editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
  var start:=Time.get_ticks_msec()
  apply_layout();backdrop()
  var original_cells:Dictionary=editor.data.cells.duplicate(true)
  var normal_report:Dictionary={}
  if style=='retained_painted':retained_finish()
  if style not in ['control','retained_painted']:
   assert(editor.data.set_sculpt_base(true))
   var field=load('res://tools/art/polyhedral_island_field.gd').new() if style.begins_with('polyrock') else (load('res://tools/art/cumulus_island_field.gd').new() if style.begins_with('cumulus') else StyledBase.new())
   assert(field.configure_style(editor.data.cells,style,editor.data.seed))
   editor.data.rocks.base=field;editor.data.rocks._height_bounds_dirty=true
   editor.data.revision+=1
   finish(style)
   editor.renderer.rebuild_all()
   normal_report=smooth_style_normals(style=='polyrock_planes')
   assert(editor.data.cells==original_cells)
  for spec in [['water','water_time'],['lake_bed','caustic_time'],['waterfall','flow_time'],['bank','foam_time']]:editor.renderer.materials[spec[0]].set_shader_parameter(spec[1],1.25)
  var support:Array=[]
  for entry:Dictionary in editor.renderer.props.entries:
   if entry.node.visible:support.append(str(entry.node.name))
  recipes[style]={'style':style,'layout_kind':layout_kind,'quiet_backdrop':quiet_backdrop,'normal_report':normal_report,'seed':editor.data.seed,'cells':editor.data.cells.size(),'cells_sha256':JSON.stringify(editor.data.serialize().cells).sha256_text(),'original_cells_unchanged':editor.data.cells==original_cells,'visible_props':support,'post_scene_style_build_ms':Time.get_ticks_msec()-start,'lobes':editor.data.rocks.base.lobes.size() if style not in ['control','retained_painted'] else 0,'experimental_field_not_portable_profile':style not in ['control','retained_painted'],'not_user_art_accepted':true}
  if style not in ['control','retained_painted']:
   var field_values:PackedFloat32Array=editor.data.rocks.base.values
   var skin=editor.renderer.contours.surfaces.sculpted_terrain
   var points:PackedVector3Array=skin.vertices
   FileAccess.open(OUT+style+'.bin',FileAccess.WRITE).store_buffer(points.to_byte_array())
   recipes[style]['density_values_sha256']=digest(field_values.to_byte_array())
   recipes[style]['mesh_vertex_sha256']=digest(points.to_byte_array())
   recipes[style]['triangles']=points.size()/3
   recipes[style]['geometry_not_yet_finite_checked']=true
  print('BEAUTY STYLE READY: ',style,' ',recipes[style])
  await views(style)
  editor.queue_free();await process_frame
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'captures':captures,'recipes':recipes,'adapter':RenderingServer.get_video_adapter_name(),'renderer':RenderingServer.get_current_rendering_method(),'resolution':[1671,941],'lighting_difference':'Candidates soften sun angular distance3.2/shadow opacity.82 and SSAO.9/power1.2 as coordinated finish; control retains original. Clouds/mist live, water phase fixed1.25.', 'scope':'Stage1finished native alternatives, original cells/buildings/trees retained; styles use real experimental density authority, not portable saved profiles yet. No editor/default adoption or art acceptance.'},'\t'))
 print('BEAUTY CAPTURES: ',captures.size());quit()
