extends SceneTree
## Render directional sky math against the original angular path over a full sphere.
var checks:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	if DisplayServer.get_name()=="headless":quit(2);return
	var views:Array[SubViewport]=[]
	var materials:Array[ShaderMaterial]=[]
	for fast:bool in [false,true]:
		var view:=SubViewport.new();view.size=Vector2i(256,128);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);views.append(view)
		var rect:=ColorRect.new();rect.size=Vector2(view.size);view.add_child(rect)
		var shader:=Shader.new()
		shader.code='shader_type canvas_item;\n#include "res://shaders/terrain_editor/sky_palette.gdshaderinc"\nvoid fragment(){float a=(UV.x*2.0-1.0)*3.14159265;float e=(UV.y-.5)*3.14159265;vec3 d=vec3(sin(a)*cos(e),sin(e),-cos(a)*cos(e));if(UV.x<.004){d=vec3(0.0,1.0,0.0);}else if(UV.x<.008){d=vec3(0.0,-1.0,0.0);}if(UV.x>=.008&&UV.x<.012){d=normalize(vec3(.0001,1.0,.0001));}if(UV.x>=.012&&UV.x<.016){d=vec3(-0.0,1.0,-0.0);}else if(UV.x>=.016&&UV.x<.020){d=vec3(-0.0,-1.0,0.0);}vec3 c=EXPR;COLOR=vec4(c*.20,1.0);}'.replace('EXPR','sky_gradient_factors(sky_view_factors(d))' if fast else 'sky_gradient(sky_coord(d))')
		var material:=ShaderMaterial.new();material.shader=shader;rect.material=material;materials.append(material)
	for night:bool in [false,true]:
		for material:ShaderMaterial in materials:
			material.set_shader_parameter("sky_horizon",Color(.44,.58,.68) if night else Color(.97,.91,.79))
			material.set_shader_parameter("sky_zenith",Color(.18,.28,.42) if night else Color(.50,.69,.79))
		for i:int in 8:RenderingServer.force_draw(false);await process_frame
		var before:Image=views[0].get_texture().get_image();var after:Image=views[1].get_texture().get_image()
		var error:float=0.0;var maximum:float=0.0
		for y:int in before.get_height():
			for x:int in before.get_width():
				var a:Color=before.get_pixel(x,y);var b:Color=after.get_pixel(x,y)
				var diff:float=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)));error+=diff;maximum=maxf(maximum,diff)
		error/=float(before.get_width()*before.get_height())
		check(maximum<=2.01/255.0,"directional sky preserves full-sphere colour within two 8-bit levels;night="+str(night))
		check(error<.05/255.0,"directional sky has negligible average colour error;night="+str(night))
		print("SKY ERROR night=",night," max=",maximum," mean=",error)
	for view:SubViewport in views:view.free()
	print("SKY DIRECTION ",checks," checks, ",failures," failures");quit(1 if failures else 0)
