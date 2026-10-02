shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;
uniform vec4 shallow : source_color = vec4(0.22, 0.62, 0.58, 0.90);
uniform vec4 deep : source_color = vec4(0.05, 0.32, 0.38, 0.96);
uniform vec4 foam_color : source_color = vec4(0.86, 0.94, 0.92, 0.92);
varying vec3 world_pos;
varying float shore;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	shore = COLOR.r;
}

void fragment() {
	float depth = clamp(shore, 0.0, 1.0);
	vec2 p = world_pos.xz;
	float n1 = sin(p.x * 3.2 + TIME * 0.52) + sin(p.y * 4.0 - TIME * 0.38);
	float n2 = sin(p.x * 7.6 - p.y * 5.1 + TIME * 0.88);
	vec3 col = mix(shallow.rgb, deep.rgb, smoothstep(0.08, 0.72, depth));
	col += n1 * 0.025;
	float foam = (1.0 - smoothstep(0.0, 0.22, depth)) * (0.80 + n2 * 0.08);
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 0.70));
	ALBEDO = col;
	ALPHA = mix(0.82, 0.95, smoothstep(0.05, 0.55, depth));
}
