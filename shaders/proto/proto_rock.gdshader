shader_type spatial;
// Flat face normals come from the mesh. Brightness is per MultiMesh instance
// (INSTANCE_CUSTOM). A MeshInstance core leaves custom at 0 and stays neutral.
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform float top_y = 0.4;
uniform float bottom_y = -4.2;
uniform float clip_above = 0.08;
varying float world_y;
varying vec3 world_pos;
varying float gain;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	vec4 wp = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world_y = wp.y;
	world_pos = wp.xyz;
	gain = 1.0;
	if (INSTANCE_CUSTOM.a > 0.5) {
		gain = clamp(INSTANCE_CUSTOM.r, 0.9, 1.1);
	}
}

void fragment() {
	float span = max(top_y - bottom_y, 0.001);
	float t = clamp((top_y - world_y) / span, 0.0, 1.0);
	if (world_y > clip_above) {
		discard;
	}
	vec3 warm = vec3(0.70, 0.50, 0.34);
	vec3 midc = vec3(0.52, 0.44, 0.38);
	vec3 cool = vec3(0.40, 0.42, 0.45);
	vec3 base = mix(warm, midc, smoothstep(0.08, 0.48, t));
	base = mix(base, cool, smoothstep(0.42, 0.92, t));
	float cell = hash(floor(world_pos * vec3(1.15, 0.85, 1.15)));
	base *= 0.90 + cell * 0.18;
	base *= gain;
	ALBEDO = base;
	ROUGHNESS = 1.0;
}
