shader_type spatial;
#include "terrain_morph.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
// Palette endpoints are already linear, matching the original shader constants.
uniform vec3 dark_color = vec3(0.17,0.19,0.12);
uniform vec3 light_color = vec3(0.38,0.39,0.27);
varying float rise;
void vertex(){
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	vec3 pivot=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	rise=world.y-pivot.y;
	if(terrain_morph_progress<1.0){VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(pivot),0.0,0.0)).xyz;}
}
void fragment(){
	vec4 source=texture(albedo_tex,UV);
	float lightness=dot(source.rgb,vec3(0.299,0.587,0.114));
	float contact=(1.0-smoothstep(0.0,.14,rise))*smoothstep(-.03,0.02,rise);
	ALBEDO=mix(dark_color,light_color,lightness)*mix(1.0,.72,contact);
	ALPHA=source.a;
	ALPHA_SCISSOR_THRESHOLD=0.2;
	ROUGHNESS=0.94;
	SPECULAR=0.04;
	vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
	NORMAL=normalize(mix(NORMAL,up,.22));
}
