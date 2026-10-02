shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;
uniform vec4 shallow : source_color = vec4(0.55, 0.82, 0.74, 0.62);
uniform vec4 deep : source_color = vec4(0.04, 0.26, 0.32, 0.84);
uniform vec4 seam_tint : source_color = vec4(0.03, 0.07, 0.08, 1.0);
uniform sampler2D shore_map : filter_linear, repeat_disable;
uniform vec2 shore_origin = vec2(0.0);
uniform float shore_span = 1.0;
uniform float shore_max = 2.2;
uniform float shore_ready = 0.0;
varying vec3 world_pos;
varying float edge_hint;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	edge_hint = COLOR.r;
}

void fragment() {
	vec2 uv = (world_pos.xz - shore_origin) / max(shore_span, 0.001);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float sampled = texture(shore_map, uv).r * shore_max;
	float dist = mix(edge_hint * 1.2, sampled, shore_ready * inside);
	vec2 p = world_pos.xz;
	float swell = sin(p.x * 2.4 + TIME * 0.41) * sin(p.y * 2.9 - TIME * 0.29);
	vec3 col = mix(shallow.rgb, deep.rgb, smoothstep(0.18, 1.55, dist));
	col += swell * 0.016;
	float bright = 1.0 - smoothstep(0.06, 1.55, dist);
	col = mix(col, col * vec3(1.20, 1.26, 1.16) + vec3(0.04, 0.07, 0.05), bright * 0.5);
	float seam = exp(-dist * 6.5);
	col = mix(col, seam_tint.rgb, seam * 0.7);
	float band = smoothstep(0.05, 0.16, dist) * (1.0 - smoothstep(0.85, 1.2, dist));
	float crest = smoothstep(0.62, 0.94, sin(dist * 19.0 - TIME * 0.85));
	float gate = smoothstep(0.45, 0.66, noise(p * 0.58 + vec2(TIME * 0.035, dist * 0.4)));
	float brk = smoothstep(0.38, 0.7, noise(vec2(p.x * 1.7 + dist * 2.6, p.y * 1.5)));
	col = mix(col, col * vec3(1.16, 1.2, 1.14) + vec3(0.07, 0.09, 0.07), crest * gate * brk * band * 0.55);
	ALBEDO = col;
	ALPHA = mix(0.5, 0.82, smoothstep(0.1, 0.95, dist));
	ROUGHNESS = mix(0.24, 0.1, clamp(dist / 1.4, 0.0, 1.0));
	SPECULAR = 0.4;
}
