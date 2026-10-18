extends RefCounted
## Coordinated preview finish, original asset position buffers preserved.
const PAINTED:Texture2D=preload('res://assets/textures/terrain/stone_painted_v1.png')
static func apply(editor)->void:
 var image:=PAINTED.get_image()
 assert(image!=null);image.generate_mipmaps()
 var painted:=ImageTexture.create_from_image(image)
 var surface:ShaderMaterial=editor.renderer.materials.sculpted_terrain
 surface.shader=preload('res://shaders/terrain_editor/island_finish.gdshader')
 for material in editor.renderer.materials.values():
  if material is ShaderMaterial:
   material.set_shader_parameter('stone_mineral_map',painted)
   material.set_shader_parameter('stone_relief_strength',.03)
   var base:=Color('7c9758').srgb_to_linear();var high:=Color('b2b977').srgb_to_linear()
   material.set_shader_parameter('grass_base',Vector3(base.r,base.g,base.b))
   material.set_shader_parameter('grass_highlight',Vector3(high.r,high.g,high.b))
 var seen:Dictionary={}
 for kind:String in editor.renderer.decoration.assets:
  for part:Dictionary in editor.renderer.decoration.assets[kind]:
   for key:String in ['mesh','render_mesh']:
    if not part.has(key):continue
    var mesh:Mesh=part[key]
    if seen.has(mesh):continue
    seen[mesh]=true
    for index in mesh.get_surface_count():
     var old:Material=mesh.surface_get_material(index)
     if old is ShaderMaterial:
      var material:ShaderMaterial=old.duplicate()
      material.set_shader_parameter('stone_mineral_map',painted)
      material.set_shader_parameter('stone_relief_strength',.03)
      mesh.surface_set_material(index,material)
   if kind=='tree':
    var before:PackedVector3Array=part.mesh.get_faces()
    part.mesh=preload('res://scripts/terrain_editor/stone_normals.gd').soften(part.mesh,130.0,1.0)
    assert(before.to_byte_array()==part.mesh.get_faces().to_byte_array())
 editor.landscape.hide()
 for node:Node in editor.get_children():
  if node is DirectionalLight3D and node.shadow_enabled:
   node.light_angular_distance=3.2;node.shadow_opacity=.82
  if node is WorldEnvironment:
   node.environment.ssao_intensity=.9;node.environment.ssao_power=1.2
   node.environment.background_mode=Environment.BG_COLOR
   node.environment.background_color=Color('a7bfc0')
   node.environment.fog_enabled=false;node.environment.glow_enabled=false
