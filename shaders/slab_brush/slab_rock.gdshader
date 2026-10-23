shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

void fragment() {
	vec3 marker = vec3(UV.x, UV.y, 0.15);
	float top_w = clamp((marker.x - 0.5) * 8.0, 0.0, 1.0);
	vec3 rock = vec3(0.60, 0.58, 0.64);
	vec3 sage = vec3(0.46, 0.64, 0.40);
	ALBEDO = mix(rock, sage, top_w);
	ROUGHNESS = 0.92;
}
