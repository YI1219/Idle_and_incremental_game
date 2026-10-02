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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	kind = COLOR.r;
}

void fragment() {
	float n = hash(floor(world_pos.xz * 1.7));
	float fine = hash(floor(world_pos.xz * 6.0 + 3.0));
	vec3 grass = mix(grass_a.rgb, grass_b.rgb, n * 0.65 + fine * 0.35);
	vec3 albedo = mix(earth.rgb, grass, clamp(kind, 0.0, 1.0));
	float up = clamp(world_n.y, 0.0, 1.0);
	albedo *= mix(0.78, 1.0, up);
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
}
