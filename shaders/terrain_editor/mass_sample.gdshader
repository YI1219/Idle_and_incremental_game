shader_type spatial;
render_mode cull_disabled;
// Flat matte gray for the rock-mass sample. No texture grain.
void fragment(){
	ALBEDO = vec3(0.63, 0.64, 0.66);
	ROUGHNESS = 0.94;
	SPECULAR = 0.04;
}
