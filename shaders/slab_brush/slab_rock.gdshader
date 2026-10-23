shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

void fragment() {
	vec3 marker = vec3(UV.x, UV.y, 0.15);
	float top_w = clamp((marker.x - 0.5) * 8.0, 0.0, 1.0);
	vec3 rock = vec3(0.57, 0.55, 0.62);
	vec3 sage = vec3(0.34, 0.56, 0.32);
	ALBEDO = mix(rock, sage, top_w);
	ROUGHNESS = 0.94;
}
