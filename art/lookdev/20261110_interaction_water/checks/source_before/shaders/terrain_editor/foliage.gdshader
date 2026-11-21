shader_type spatial;
#include "terrain_morph.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
// Palette endpoints are already linear, matching the original shader constants.
uniform vec3 dark_color = vec3(0.22,0.28,0.15);
uniform vec3 light_color = vec3(0.46,0.52,0.28);
varying vec3 world_up_normal;
void vertex(){
	vec3 w_n=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	// Upward spherical cluster normal bias (nicoo-474/procedural-tree Sec 7.4):
	// prevents two-sided leaf cards from flipping normals dark on backfaces.
	world_up_normal=normalize(mix(vec3(w_n.x,abs(w_n.y),w_n.z),vec3(0.0,1.0,0.0),0.74));
	if(terrain_morph_progress<1.0){vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(origin),0.0,0.0)).xyz;}
}
void fragment(){
	// Force fragment normal to the unflipped upward-biased normal (fixes cull_disabled half-black leaves).
	NORMAL=normalize((VIEW_MATRIX*vec4(normalize(world_up_normal),0.0)).xyz);
	vec4 source=texture(albedo_tex,UV);
	float lightness=dot(source.rgb,vec3(0.299,0.587,0.114));
	ALBEDO=mix(dark_color,light_color,clamp(lightness*1.08,0.0,1.0));
	ALPHA=source.a;
	ALPHA_SCISSOR_THRESHOLD=0.2;
	BACKLIGHT=ALBEDO*vec3(.42,.45,.26);
	ROUGHNESS=0.82;
	SPECULAR=0.12;
	RIM=0.18;
	RIM_TINT=0.45;
}
