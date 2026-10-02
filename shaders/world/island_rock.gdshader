shader_type spatial;
render_mode diffuse_toon, specular_disabled, shadows_disabled, cull_disabled;
uniform float ground_y = -0.08;
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
	if (world_y > ground_y) {
		discard;
	}
	// Darker warm grey-brown at the lip, cool grey toward the tip (seed7_side).
	float t = clamp((-world_y - 0.08) / 6.4, 0.0, 1.0);
	vec3 warm = vec3(0.455, 0.378, 0.322);
	vec3 mid = vec3(0.388, 0.362, 0.345);
	vec3 cool = vec3(0.340, 0.355, 0.380);
	vec3 base = mix(warm, mid, smoothstep(0.0, 0.42, t));
	base = mix(base, cool, smoothstep(0.38, 1.0, t));
	base *= 1.0 + (jitter - 0.5) * 0.08;
	float wrap = clamp(world_n.y * 0.16 + 0.70, 0.52, 0.94);
	ALBEDO = base * wrap;
	ROUGHNESS = 1.0;
}
