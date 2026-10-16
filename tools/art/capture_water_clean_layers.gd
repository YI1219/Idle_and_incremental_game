extends 'res://tests/capture_rim_round.gd'
## Diagnostic only: isolate the source of pale pond patches in the real scene.
func run()->void:
 OUT='res://art/review/terrain_fidelity/2026-10-16/water_clean_layers/'
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load('res://scenes/terrain_editor.tscn').instantiate();viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 for spec in [['water','water_time'],['lake_bed','caustic_time'],['waterfall','flow_time'],['bank','foam_time']]:
  editor.renderer.materials[spec[0]].set_shader_parameter(spec[1],1.25)
 var water:ShaderMaterial=editor.renderer.materials.water
 var original:Shader=water.shader
 # Preserve old diagnostics when production changes; current is not a fixed baseline.
 var source_hash:=original.code.sha256_text()
 OUT+='shader_'+source_hash.substr(0,12)+'/'
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var code:=original.code.replace('#include "terrain_morph.gdshaderinc"',FileAccess.get_file_as_string('res://shaders/terrain_editor/terrain_morph.gdshaderinc'))
 var specular_rx:=RegEx.new();specular_rx.compile('SPECULAR=[^;]+')
 var modes=['current','no_ssr','no_specular','flat_normal','no_caustic']
 if OS.get_cmdline_user_args().has('strengths'):modes=['spec25','spec35']
 for mode in modes:
  water.shader=original;water.set_shader_parameter('reflection_strength',0.0 if mode=='no_ssr' else .28)
  editor.renderer.materials.lake_bed.set_shader_parameter('caustic_strength',0.0 if mode=='no_caustic' else .12)
  if mode=='no_specular' or mode=='flat_normal' or mode.begins_with('spec'):
   var variant:=Shader.new()
   variant.code=specular_rx.sub(code,'SPECULAR=0.0') if mode=='no_specular' else code.replace('vec3 normal_world=normalize(vec3(-slope.x,1.0,-slope.y));','vec3 normal_world=vec3(0.0,1.0,0.0);')
   if mode.begins_with('spec'):variant.code=specular_rx.sub(code,'SPECULAR=.'+mode.trim_prefix('spec'))
   water.shader=variant
  editor.camera.position=Vector3(1,10,12);editor.camera.look_at(Vector3(-3,3.5,2));await capture(mode+'_shore')
  editor.camera.position=Vector3(-4,5,9);editor.camera.look_at(Vector3(-3,3.5,0));await capture(mode+'_grazing')
 water.shader=original;water.set_shader_parameter('reflection_strength',.28)
 editor.renderer.materials.lake_bed.set_shader_parameter('caustic_strength',.12)
 var report_name='strength_captures.json' if OS.get_cmdline_user_args().has('strengths') else 'captures.json'
 FileAccess.open(OUT+report_name,FileAccess.WRITE).store_string(JSON.stringify({'captures':captures,'modes':modes,'water_shader_sha256':source_hash,'production_specular':specular_rx.search(code).get_string(),'water_phase':1.25,'source':'Actual default scene; current means the recorded production shader, not a fixed baseline; diagnostic layers only; no source mutation; mist/cloud clocks remain live'},'\t'))
 print('WATER CLEAN LAYERS: ',captures.size());quit()
