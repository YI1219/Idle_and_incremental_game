extends "res://tests/capture_rim_round.gd"
## Isolate actual water layers at one fixed camera before choosing a finish.
func run()->void:
 OUT='res://art/review/terrain_fidelity/2026-10-15/water_finish/'
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load('res://scenes/terrain_editor.tscn').instantiate();viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 editor.camera.position=Vector3(1,10,12);editor.camera.look_at(Vector3(-3,3.5,2))
 var water:ShaderMaterial=editor.renderer.materials.water
 if OS.get_cmdline_user_args().has('motion'):
  for time in 4:
   editor.renderer.materials.lake_bed.set_shader_parameter('caustic_time',float(time))
   await capture('motion_'+str(time))
  FileAccess.open(OUT+'motion_captures.json',FileAccess.WRITE).store_string(JSON.stringify(captures,'\t'))
  print('WATER PRODUCTION MOTION: ',captures.size());quit();return
 var original:Shader=water.shader
 for spec:Array in [['current',true,true],['no_reflection',false,true],['flat_normal',true,false],['bed_only',false,false]]:
  var code:=original.code.replace('#include "terrain_morph.gdshaderinc"',FileAccess.get_file_as_string('res://shaders/terrain_editor/terrain_morph.gdshaderinc'))
  if not spec[2]:code=code.replace('vec3 normal_world=normalize(vec3(-slope.x,1.0,-slope.y));','vec3 normal_world=vec3(0.0,1.0,0.0);')
  var shader:=Shader.new();shader.code=code
  water.shader=shader;water.set_shader_parameter('reflection_strength',.28 if spec[1] else 0.0)
  await capture('probe_'+spec[0])
 water.shader=original;water.set_shader_parameter('reflection_strength',.28)
 var bed:ShaderMaterial=editor.renderer.materials.lake_bed
 var plain:=Shader.new();plain.code='shader_type spatial; render_mode cull_disabled; void fragment(){ALBEDO=vec3(.30,.32,.25);ROUGHNESS=.85;SPECULAR=.20;}'
 bed.shader=plain
 await capture('probe_plain_bed')
 for chunk:Node3D in editor.renderer.chunks.values():
  var surface:=chunk.get_node_or_null('water')
  if surface:surface.hide()
 await capture('probe_exposed_bed')
 FileAccess.open(OUT+'probe_captures.json',FileAccess.WRITE).store_string(JSON.stringify(captures,'\t'))
 print('WATER MATERIAL PROBE: ',captures.size());quit()
