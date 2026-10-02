// Noisy ground-contact band. ground_y is declared by the including shader.
float gc_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float gc_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(gc_hash(i), gc_hash(i + vec2(1.0, 0.0)), f.x),
		mix(gc_hash(i + vec2(0.0, 1.0)), gc_hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

vec3 blend_ground_contact(vec3 src, vec3 world) {
	float n = gc_noise(world.xz * 7.5);
	float reach = mix(0.10, 0.15, n);
	float jag = gc_noise(world.xz * 13.0 + vec2(2.3, 8.1));
	float edge = mix(reach * 0.62, reach, jag);
	float above = world.y - ground_y;
	float band = (1.0 - smoothstep(edge * 0.22, edge, above)) * smoothstep(-0.03, 0.008, above);
	vec3 darkened = src * mix(1.0, 0.55, band);
	vec3 grass = vec3(0.47, 0.52, 0.33);
	return mix(darkened, grass, band * 0.25);
}
