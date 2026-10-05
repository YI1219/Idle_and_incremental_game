shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
void fragment(){
	vec4 source=texture(albedo_tex,UV);
	float lightness=dot(source.rgb,vec3(0.299,0.587,0.114));
	ALBEDO=mix(vec3(0.20,0.34,0.035),vec3(0.58,0.69,0.12),lightness);
	ALPHA=source.a;
	ALPHA_SCISSOR_THRESHOLD=0.2;
	ROUGHNESS=0.95;
}
