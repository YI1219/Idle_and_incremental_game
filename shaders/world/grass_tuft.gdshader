shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Root-to-tip gradient, multiplied by the per-tuft tint stored in COLOR.rgb.
varying float tip;

void vertex() {
	tip = COLOR.a;
	// Upward normals so blades take the same light as the meadow.
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 root = vec3(0.24, 0.30, 0.14);
	vec3 leaf = vec3(0.58, 0.64, 0.34);
	ALBEDO = mix(root, leaf, tip) * COLOR.rgb;
	ROUGHNESS = 0.94;
}
