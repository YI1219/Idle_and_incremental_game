shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled;
// One draw per variant. Godot's per-instance MultiMesh slot is INSTANCE_CUSTOM;
// a node-level instance uniform is shared by every instance of that draw.
uniform vec4 stone_color : source_color = vec4(0.64, 0.58, 0.50, 1.0);
uniform vec4 stone_shade : source_color = vec4(0.50, 0.46, 0.42, 1.0);
varying float gain;
varying vec3 world_pos;
varying vec3 world_n;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	gain = clamp(INSTANCE_CUSTOM.x, 0.88, 1.12);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 n = world_n;
	if (length(n) < 0.001) {
		n = vec3(0.0, 1.0, 0.0);
	}
	float facet = clamp(dot(n, normalize(vec3(0.42, 0.78, 0.28))) * 0.22 + 0.86, 0.74, 1.12);
	float up = clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(stone_shade.rgb, stone_color.rgb, up);
	// Oblique grain so a tall face does not stripe vertically.
	vec3 skew = world_pos + vec3(world_pos.y * 0.37, 0.0, world_pos.y * -0.21);
	col *= 0.94 + hash(floor(skew * 3.1)) * 0.12;
	ALBEDO = col * facet * gain;
	ROUGHNESS = 0.94;
}

void light() {
	float nd = dot(NORMAL, LIGHT);
	float wrap = clamp(nd * 0.45 + 0.55, 0.50, 1.0);
	float vis = mix(0.78, 1.0, clamp(ATTENUATION, 0.0, 1.0));
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * wrap * vis;
}
