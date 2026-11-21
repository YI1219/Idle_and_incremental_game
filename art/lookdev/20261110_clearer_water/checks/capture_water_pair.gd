extends "res://art/lookdev/20261110_clearer_water/checks/capture_water.gd"
## Render both water responses in the same instantiated world and frozen phase.
func _capture(label:String,time_progress:float)->void:
 if label=='cliff_close':return
 var water_material:ShaderMaterial=editor.renderer.materials.water
 var shader:Shader=water_material.shader
 var current_code:String=shader.code
 var before_path:String='res://art/lookdev/20261110_clearer_water/checks/water_before.gdshader.txt'
 var before_code:String=_expand_includes(FileAccess.get_file_as_string(before_path),'res://shaders/terrain_editor')
 var time_token:=RegEx.new()
 time_token.compile('\\bTIME\\b')
 shader.code=time_token.sub(before_code,str(PHASE),true)
 await super._capture(label+'_before',time_progress)
 captures[-1]['water_shader_snapshot_sha256']=FileAccess.get_sha256(before_path)
 captures[-1]['water_response']='before'
 shader.code=current_code
 await super._capture(label+'_after',time_progress)
 captures[-1]['water_shader_snapshot_sha256']=FileAccess.get_sha256('res://shaders/terrain_editor/water.gdshader')
 captures[-1]['water_response']='clearer'
