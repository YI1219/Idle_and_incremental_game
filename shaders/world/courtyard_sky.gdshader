shader_type sky;
uniform vec3 zenith_color : source_color = vec3(0.42, 0.60, 0.74);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.80, 0.76);
uniform vec3 nadir_color : source_color = vec3(0.38, 0.46, 0.54);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void sky() {
	float h = EYEDIR.y;
	vec3 upper = mix(horizon_color, zenith_color, smoothstep(0.0, 0.85, h));
	vec3 lower = mix(horizon_color, nadir_color, smoothstep(0.0, -0.7, h));
	vec3 color = mix(lower, upper, step(0.0, h));
	vec2 p = EYEDIR.xz / max(0.18, abs(h) + 0.28) * 1.6;
	float haze = noise(p) * 0.55 + noise(p * 2.2 + 3.1) * 0.45;
	color = mix(color, horizon_color, smoothstep(0.52, 0.86, haze) * 0.22 * (1.0 - smoothstep(0.15, 0.8, h)));
	COLOR = color;
}
