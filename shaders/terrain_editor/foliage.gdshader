shader_type spatial;
#include "terrain_morph.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
// Palette endpoints are already linear, matching the original shader constants.
uniform vec3 dark_color = vec3(0.17,0.19,0.12);
uniform vec3 light_color = vec3(0.38,0.39,0.27);
void vertex(){
	if(terrain_morph_progress<1.0){vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(origin),0.0,0.0)).xyz;}
}
void fragment(){
	vec4 source=texture(albedo_tex,UV);
	float lightness=dot(source.rgb,vec3(0.299,0.587,0.114));
	ALBEDO=mix(dark_color,light_color,lightness);
	ALPHA=source.a;
	ALPHA_SCISSOR_THRESHOLD=0.2;
	ROUGHNESS=0.95;
}
