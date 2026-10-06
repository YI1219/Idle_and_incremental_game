shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
// Palette endpoints are already linear, matching the original shader constants.
uniform vec3 dark_color = vec3(0.25,0.38,0.065);
uniform vec3 light_color = vec3(0.58,0.69,0.12);
void fragment(){
	vec4 source=texture(albedo_tex,UV);
	float lightness=dot(source.rgb,vec3(0.299,0.587,0.114));
	ALBEDO=mix(dark_color,light_color,lightness);
	ALPHA=source.a;
	ALPHA_SCISSOR_THRESHOLD=0.2;
	ROUGHNESS=0.95;
}
