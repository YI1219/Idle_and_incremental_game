shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec4 grass_a : source_color = vec4(0.58, 0.69, 0.36, 1.0);
uniform vec4 grass_b : source_color = vec4(0.68, 0.78, 0.44, 1.0);
uniform vec4 earth : source_color = vec4(0.56, 0.40, 0.26, 1.0);
varying vec3 world_pos;
varying vec3 world_n;
varying float kind;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	kind = COLOR.r;
}

void fragment() {
	vec2 p = world_pos.xz;
	float broad = noise(p * 0.22);
	float mid = noise(p * 1.35 + 1.7);
	vec3 grass = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.32, 0.68, broad));
	float mottled = (broad - 0.5) * 0.18 + (mid - 0.5) * 0.10;
	grass *= clamp(1.0 + mottled, 0.88, 1.12);
	vec3 albedo = mix(earth.rgb, grass, clamp(kind, 0.0, 1.0));
	float up = clamp(world_n.y, 0.0, 1.0);
	albedo *= mix(0.78, 1.0, up);
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
}
