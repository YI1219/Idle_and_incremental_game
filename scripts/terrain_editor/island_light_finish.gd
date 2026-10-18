extends RefCounted
## Optional lighter study, applied once after the shared retained-asset finish.
static func apply(editor)->void:
 editor.renderer.materials.sculpted_terrain.shader=preload('res://shaders/terrain_editor/island_light_finish.gdshader')
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
