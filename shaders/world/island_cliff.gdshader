shader_type spatial;
render_mode unshaded, shadows_disabled;
varying vec3 world_pos;
varying vec3 world_n;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float bands = smoothstep(0.28, 0.72, fract(-world_pos.y * 0.42 + hash(world_pos.xz * 0.15) * 0.2));
	vec3 deep = vec3(0.42, 0.36, 0.30);
	vec3 high = vec3(0.68, 0.60, 0.50);
	vec3 rock = mix(deep, high, bands);
	float wrap = clamp(world_n.y * 0.40 + 0.62, 0.28, 1.0);
	float rim = pow(clamp(1.0 - abs(world_n.y), 0.0, 1.0), 1.3) * 0.18;
	float turf = smoothstep(0.55, 0.92, world_n.y) * COLOR.r;
	vec3 grass = vec3(0.40, 0.48, 0.30);
	vec3 color = mix(rock * wrap, grass, turf);
	ALBEDO = color + vec3(0.78, 0.74, 0.66) * rim;
}
