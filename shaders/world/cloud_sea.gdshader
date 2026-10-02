shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 base_color : source_color = vec4(0.93, 0.91, 0.84, 1.0);
uniform vec4 shade_color : source_color = vec4(0.52, 0.61, 0.66, 1.0);
uniform vec4 sun_tint : source_color = vec4(0.96, 0.88, 0.72, 1.0);
uniform float density = 0.88;
uniform float scroll = 0.012;
varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(11.2, 3.7);
		a *= 0.55;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (fbm(world_pos.xz * 0.04) - 0.5) * 0.55;
}

void fragment() {
	vec2 p = world_pos.xz * 0.028;
	vec2 drift = vec2(TIME * scroll, TIME * scroll * 0.37);
	float banks = fbm(p + drift);
	float wisps = fbm(p * 1.85 - drift * 1.4 + 4.0);
	float cloud = smoothstep(0.34, 0.58, mix(banks, wisps, 0.42));
	float fade = smoothstep(150.0, 22.0, length(world_pos.xz));
	vec3 color = mix(shade_color.rgb, base_color.rgb, cloud);
	color = mix(color, sun_tint.rgb, cloud * cloud * 0.35);
	ALBEDO = color;
	ALPHA = clamp(mix(0.55, 0.96, cloud) * fade, 0.0, 0.96);
}
