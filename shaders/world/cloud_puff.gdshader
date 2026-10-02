shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform vec4 tint : source_color = vec4(0.97, 0.98, 0.99, 0.68);
varying vec3 world_n;

void vertex() {
	world_n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float soft = pow(abs(dot(normalize(world_n), normalize(VIEW))), 1.05);
	ALBEDO = tint.rgb;
	ALPHA = tint.a * mix(0.42, 1.0, soft);
	if (ALPHA < 0.04) {
		discard;
	}
}
