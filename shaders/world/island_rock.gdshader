shader_type spatial;
render_mode diffuse_toon, specular_disabled, shadows_disabled, cull_back;
varying float world_y;
varying vec3 world_n;
varying float jitter;

void vertex() {
	vec4 wp = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world_y = wp.y;
	world_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	jitter = COLOR.r;
}

void fragment() {
	float t = clamp((-world_y - 0.08) / 6.4, 0.0, 1.0);
	vec3 warm = vec3(0.608, 0.490, 0.392);
	vec3 mid = vec3(0.525, 0.475, 0.435);
	vec3 cool = vec3(0.435, 0.447, 0.475);
	vec3 base = mix(warm, mid, smoothstep(0.0, 0.42, t));
	base = mix(base, cool, smoothstep(0.38, 1.0, t));
	base *= 1.0 + (jitter - 0.5) * 0.10;
	float wrap = clamp(world_n.y * 0.28 + 0.72, 0.42, 1.05);
	ALBEDO = base * wrap;
	ROUGHNESS = 1.0;
}
