extends "res://tests/capture_rim_round.gd"
## Actual scene layer isolation, with a frozen fall/mist phase for comparison.
func expanded(code:String)->String:
 return code.replace('#include "terrain_morph.gdshaderinc"',FileAccess.get_file_as_string('res://shaders/terrain_editor/terrain_morph.gdshaderinc'))
func variant(code:String,phase:float=.5)->Shader:
 var shader:=Shader.new();shader.code=expanded(code).replace('TIME',str(phase));return shader
func run()->void:
 OUT='res://art/review/terrain_fidelity/2026-10-15/waterfall_finish/'
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 editor=load('res://scenes/terrain_editor.tscn').instantiate();viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 var material:ShaderMaterial=editor.renderer.materials.waterfall
 var code:=material.shader.code
 var mist:ShaderMaterial=editor.renderer.mist.multimesh.mesh.material
 var mist_code:=mist.shader.code
 mist.shader=variant(mist_code)
 var args:=OS.get_cmdline_user_args()
 var foam:ShaderMaterial=editor.renderer.materials.bank
 var foam_code:=foam.shader.code
 var water:ShaderMaterial=editor.renderer.materials.water
 var water_code:=water.shader.code
 if args.has('baseline'):
  code=FileAccess.get_file_as_string(OUT+'baseline_waterfall.gdshader.txt')
  foam_code=FileAccess.get_file_as_string(OUT+'baseline_foam.gdshader.txt')
  mist_code=FileAccess.get_file_as_string(OUT+'baseline_mist.gdshader.txt')
 for veil:Dictionary in editor.renderer.contours.fall_veils:
  print('ACTUAL FALL VEIL: ',veil)
  var tag:='external' if veil.external else 'receiving'
  var center:Vector3=veil.lip+Vector3.DOWN*(1.8 if veil.external else (veil.lip.y-veil.foot.y)*.5)
  var out:=Vector3(veil.out.x,0,veil.out.y)
  editor.camera.position=center+out*8.0+Vector3(2.5,2.0,0)
  editor.camera.look_at(center)
  if not args.is_empty():
   for phase:float in [.5,1.2,2.4]:
    material.shader=variant(code,phase);mist.shader=variant(mist_code,phase);foam.shader=variant(foam_code,phase);water.shader=variant(water_code,phase)
    editor.renderer.materials.lake_bed.set_shader_parameter('caustic_time',phase)
    await capture(args[0]+'_'+tag+'_'+str(phase).replace('.','_'))
   continue
  for layer:String in ['current','no_mist','no_specular','unlit','no_foam']:
   editor.renderer.mist.visible=layer=='current'
   material.shader=variant(code.replace('SPECULAR = mix(.35,.08,white);','SPECULAR = 0.0;') if layer=='no_specular' else code.replace('render_mode blend_mix','render_mode unshaded,blend_mix') if layer=='unlit' else code)
   for chunk:Node in editor.renderer.chunks.values():
    var bank=chunk.get_node_or_null('bank')
    if bank:bank.visible=layer!='no_foam'
   await capture('layers_'+tag+'_'+layer)
 FileAccess.open(OUT+('layers' if args.is_empty() else args[0])+'_captures.json',FileAccess.WRITE).store_string(JSON.stringify(captures,'\t'))
 print('WATERFALL LAYERS: ',captures.size());quit()
